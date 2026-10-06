#!/usr/bin/env bash
# A behavior-changing diff must carry an eval pack.
# CI mode: fixture check, pre-run goal, and post-run report.
# Pre-commit mode: fixture check and pre-run goal.
# tests/unit and runs/ do not count.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

resolve_pack_roots() {
  if [[ -n "${EVALS_PACK_ROOT:-}" ]]; then
    ROOT="$(cd "${EVALS_PACK_ROOT}" && pwd)"
    LAYOUT="host"
    return 0
  fi
  if [[ -d "${HUB_ROOT}/.git" ]]; then
    ROOT="${HUB_ROOT}"
    LAYOUT="hub"
    return 0
  fi
  ROOT="$(cd "${HUB_ROOT}/.." && pwd)"
  LAYOUT="host"
}

usage() {
  printf '%s\n' \
    "usage: assert_pr_has_eval_pack.sh [--mode ci|pre-commit] [--paths-file FILE | --range REV]" \
    "       with no args: self-test (or the branch range when PRE_COMMIT=1)" >&2
}

is_eval() {
  case "$1" in
    fixtures/*/check.sh|fixtures/*/p2p-smoke.sh) return 0 ;;
    evals/fixtures/*/check.sh|evals/fixtures/*/p2p-smoke.sh) return 0 ;;
    *) return 1 ;;
  esac
}

is_goal() {
  local base
  case "$1" in
    goals/*.md|evals/goals/*.md) ;;
    *) return 1 ;;
  esac
  base="${1##*/}"
  case "${base}" in
    *-result.md|README.md|_schema.md) return 1 ;;
    *) return 0 ;;
  esac
}

is_result() {
  case "$1" in
    goals/*-result.md|evals/goals/*-result.md) return 0 ;;
    *) return 1 ;;
  esac
}

is_outside() {
  if [[ "${LAYOUT}" == "hub" ]]; then
    case "$1" in
      fixtures/*|goals/*|runs/*|templates/*) return 1 ;;
      *) return 0 ;;
    esac
  else
    case "$1" in
      evals/*) return 1 ;;
      *) return 0 ;;
    esac
  fi
}

is_lockfile_path() {
  local base="${1##*/}"
  case "${base}" in
    package-lock.json|yarn.lock|pnpm-lock.yaml|npm-shrinkwrap.json|bun.lock|bun.lockb|poetry.lock|Pipfile.lock|uv.lock|Cargo.lock|go.sum|composer.lock|Gemfile.lock|.terraform.lock.hcl|Chart.lock)
      return 0
      ;;
    *) return 1 ;;
  esac
}

is_gha_pin_path() {
  case "$1" in
    .github/workflows/*.yml|.github/workflows/*.yaml) return 0 ;;
  esac
  if [[ "$1" == .github/actions/* && ( "$1" == *.yml || "$1" == *.yaml ) ]]; then
    return 0
  fi
  return 1
}

# Every added/removed line in the unified diff must be pin-only (or blank/comment).
diff_is_pin_only() {
  local path="$1" diff_range="${2:-}" diff=""
  if [[ -n "${diff_range}" ]]; then
    diff="$(git -C "${ROOT}" diff "${diff_range}" -- "${path}" 2>/dev/null || true)"
  else
    diff="$(
      {
        git -C "${ROOT}" diff --cached -- "${path}" 2>/dev/null || true
        local base=""
        if git -C "${ROOT}" rev-parse --verify origin/main >/dev/null 2>&1; then
          base="$(git -C "${ROOT}" merge-base origin/main HEAD 2>/dev/null || true)"
        elif git -C "${ROOT}" rev-parse --verify main >/dev/null 2>&1; then
          base="$(git -C "${ROOT}" merge-base main HEAD 2>/dev/null || true)"
        fi
        if [[ -n "${base}" ]]; then
          git -C "${ROOT}" diff "${base}" HEAD -- "${path}" 2>/dev/null || true
        fi
      } 2>/dev/null
    )"
  fi
  [[ -n "${diff}" ]] || return 1
  local line body
  while IFS= read -r line || [[ -n "${line}" ]]; do
    case "${line}" in
      '+++'*|'---'*) continue ;;
      '+'*|'-'*)
        body="${line#?}"
        body="${body#"${body%%[![:space:]]*}"}"
        [[ -n "${body}" ]] || continue
        case "${body}" in
          \#*) continue ;;
        esac
        if [[ "${body}" =~ ^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*.+@ ]]; then
          continue
        fi
        if [[ "${body}" =~ ^[[:space:]]*-?[[:space:]]*hub_ref:[[:space:]]* ]]; then
          continue
        fi
        if [[ "${body}" =~ ^[[:space:]]*-?[[:space:]]*rev:[[:space:]]* ]]; then
          continue
        fi
        return 1
        ;;
    esac
  done <<<"${diff}"
  return 0
}

path_is_dependency_bump() {
  local path="$1" diff_range="${2:-}"
  is_lockfile_path "${path}" && return 0
  if is_gha_pin_path "${path}"; then
    diff_is_pin_only "${path}" "${diff_range}"
    return $?
  fi
  return 1
}

paths_are_dependency_bump_only() {
  local diff_range="${1:-}"
  shift
  local path outside=0
  for path in "$@"; do
    [[ -n "${path}" ]] || continue
    is_outside "${path}" || continue
    outside=1
    path_is_dependency_bump "${path}" "${diff_range}" || return 1
  done
  [[ "${outside}" -eq 1 ]]
}

missing_kinds() {
  local mode="$1"
  shift
  local path outside=0 have_eval=0 have_goal=0 have_result=0
  for path in "$@"; do
    [[ -n "${path}" ]] || continue
    if is_outside "${path}"; then
      outside=1
    fi
    if is_eval "${path}"; then
      have_eval=1
    fi
    if is_goal "${path}"; then
      have_goal=1
    fi
    if is_result "${path}"; then
      have_result=1
    fi
  done
  if [[ "${outside}" -eq 0 ]]; then
    return 0
  fi
  if [[ "${have_eval}" -eq 0 ]]; then
    printf '%s\n' 'eval'
  fi
  if [[ "${have_goal}" -eq 0 ]]; then
    printf '%s\n' 'pre-run goal'
  fi
  if [[ "${mode}" == "ci" && "${have_result}" -eq 0 ]]; then
    printf '%s\n' 'post-run report'
  fi
}

# A result must say which checks were run by hand and which automated check now
# covers each (PROCESS.md "Manual verification becomes a test"). Only results
# added/changed in the diff are checked, so existing results are grandfathered.
result_has_manual_section() {
  awk '
    { l = tolower($0) }
    l ~ /^#+[[:space:]]+manual verification/ { in_sec = 1; next }
    in_sec && /^#+[[:space:]]/ { exit }
    in_sec && $0 ~ /[^[:space:]]/ { body = 1 }
    END { exit !(in_sec && body) }
  ' "$1"
}

result_content_problems() {
  local mode="$1" path
  shift
  [[ "${mode}" == "ci" ]] || return 0
  for path in "$@"; do
    [[ -n "${path}" ]] || continue
    is_result "${path}" || continue
    [[ -f "${ROOT}/${path}" ]] || continue
    result_has_manual_section "${ROOT}/${path}" || printf '%s\n' "${path}"
  done
}

report_missing() {
  local mode="$1" diff_range="${2:-}"
  shift 2
  local missing bad_results kind path
  if paths_are_dependency_bump_only "${diff_range}" "$@"; then
    printf '%s\n' 'eval pack gate: dependency-bump-only diff — skip' >&2
    return 0
  fi
  missing="$(missing_kinds "${mode}" "$@")"
  bad_results="$(result_content_problems "${mode}" "$@")"
  [[ -n "${missing}" || -n "${bad_results}" ]] || return 0
  if [[ -n "${missing}" ]]; then
    printf '%s\n' '✗ pull request changes code without an eval pack' >&2
    while IFS= read -r kind; do
      [[ -n "${kind}" ]] || continue
      printf '  missing: %s\n' "${kind}" >&2
    done <<<"${missing}"
  fi
  if [[ -n "${bad_results}" ]]; then
    printf '%s\n' '✗ result lacks a non-empty "# Manual verification" section (PROCESS.md: Manual verification becomes a test)' >&2
    while IFS= read -r path; do
      [[ -n "${path}" ]] || continue
      printf '  result: %s\n' "${path}" >&2
    done <<<"${bad_results}"
  fi
  return 1
}

read_paths_file() {
  local file="$1" line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "${line}" ]] || continue
    printf '%s\n' "${line}"
  done <"${file}"
}

paths_from_range() {
  local range="$1"
  git -C "${ROOT}" diff --name-only --diff-filter=ACMRD "${range}"
}

collect_precommit_paths() {
  local base=""
  if git -C "${ROOT}" rev-parse --verify origin/main >/dev/null 2>&1; then
    base="$(git -C "${ROOT}" merge-base origin/main HEAD)"
  elif git -C "${ROOT}" rev-parse --verify main >/dev/null 2>&1; then
    base="$(git -C "${ROOT}" merge-base main HEAD)"
  fi
  if [[ -n "${base}" ]]; then
    git -C "${ROOT}" diff --name-only --diff-filter=ACMRD "${base}" HEAD
  fi
  git -C "${ROOT}" diff --name-only --cached --diff-filter=ACMRD
}

check_list() {
  local mode="$1" diff_range="${2:-}"
  shift 2
  local -a paths=()
  local line
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    paths+=("${line}")
  done
  if [[ "${#paths[@]}" -eq 0 ]]; then
    return 0
  fi
  report_missing "${mode}" "${diff_range}" "${paths[@]}"
}

self_test() {
  local tmp bad good prerun unit_only runs_only
  tmp="$(mktemp -d)"
  trap 'rm -rf "'"${tmp}"'"' RETURN
  bad="${tmp}/bad"
  good="${tmp}/good"
  prerun="${tmp}/prerun"
  unit_only="${tmp}/unit-only"
  runs_only="${tmp}/runs-only"
  if [[ "${LAYOUT}" == "hub" ]]; then
    cat >"${bad}" <<'EOF'
docs/evals.md
skills/goal/SKILL.md
Makefile
tests/unit/test_evals_harness.sh
EOF
    cat >"${good}" <<'EOF'
docs/evals.md
skills/goal/SKILL.md
fixtures/github.com/hermes/hermes/20260919-selftest-pack/check.sh
goals/github.com/hermes/hermes/20260919-selftest-pack.md
goals/github.com/hermes/hermes/20260919-selftest-pack-result.md
EOF
    cat >"${prerun}" <<'EOF'
skills/goal/SKILL.md
fixtures/github.com/hermes/hermes/20260919-selftest-pack/check.sh
goals/github.com/hermes/hermes/20260919-selftest-pack.md
EOF
    printf '%s\n' 'tests/unit/test_infra_tools.sh' >"${unit_only}"
    cat >"${runs_only}" <<'EOF'
skills/goal/SKILL.md
runs/20260919-selftest-pack/manifest.json
EOF
  else
    cat >"${bad}" <<'EOF'
docs/infra-tools.md
scripts/instance/create.sh
EOF
    cat >"${good}" <<'EOF'
docs/infra-tools.md
evals/fixtures/github.com/hermes/hermes/20260919-selftest-pack/check.sh
evals/goals/github.com/hermes/hermes/20260919-selftest-pack.md
evals/goals/github.com/hermes/hermes/20260919-selftest-pack-result.md
EOF
    cat >"${prerun}" <<'EOF'
scripts/instance/create.sh
evals/fixtures/github.com/hermes/hermes/20260919-selftest-pack/check.sh
evals/goals/github.com/hermes/hermes/20260919-selftest-pack.md
EOF
    printf '%s\n' 'tests/unit/test_infra_tools.sh' >"${unit_only}"
    cat >"${runs_only}" <<'EOF'
scripts/instance/create.sh
evals/runs/20260919-selftest-pack/manifest.json
EOF
  fi
  local fail=0
  if bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${bad}" >/dev/null 2>&1; then
    printf '✗ self-test: ci mode accepted a pack-less diff\n' >&2
    fail=1
  fi
  if ! bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${good}" >/dev/null 2>&1; then
    printf '✗ self-test: ci mode rejected a full pack\n' >&2
    fail=1
  fi
  if ! bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode pre-commit --paths-file "${prerun}" >/dev/null 2>&1; then
    printf '✗ self-test: pre-commit mode rejected fixture plus goal\n' >&2
    fail=1
  fi
  if bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${prerun}" >/dev/null 2>&1; then
    printf '✗ self-test: ci mode accepted a missing result\n' >&2
    fail=1
  fi
  if bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${unit_only}" >/dev/null 2>&1; then
    printf '✗ self-test: unit test counted as a pack\n' >&2
    fail=1
  fi
  if bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${runs_only}" >/dev/null 2>&1; then
    printf '✗ self-test: runs/ counted as a pack\n' >&2
    fail=1
  fi
  # Result content rule (host layout, real files under a temp pack root).
  local pack="${tmp}/pack" rdir="${tmp}/pack/evals/goals/github.com/o/r" paths_ok="${tmp}/paths-result"
  mkdir -p "${rdir}"
  cat >"${paths_ok}" <<'PATHS'
scripts/instance/create.sh
evals/fixtures/github.com/o/r/20260919-x/check.sh
evals/goals/github.com/o/r/20260919-x.md
evals/goals/github.com/o/r/20260919-x-result.md
PATHS
  printf '# Proof\nok\n' >"${rdir}/20260919-x-result.md"
  if EVALS_PACK_ROOT="${pack}" bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${paths_ok}" >/dev/null 2>&1; then
    printf '✗ self-test: ci mode accepted a result without a Manual verification section\n' >&2
    fail=1
  fi
  printf '# Proof\nok\n\n# Manual verification\n\n# Next action\nnone\n' >"${rdir}/20260919-x-result.md"
  if EVALS_PACK_ROOT="${pack}" bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${paths_ok}" >/dev/null 2>&1; then
    printf '✗ self-test: ci mode accepted an empty Manual verification section\n' >&2
    fail=1
  fi
  printf '# Proof\nok\n\n## Manual verification\n\nNone — nothing was run by hand.\n' >"${rdir}/20260919-x-result.md"
  if ! EVALS_PACK_ROOT="${pack}" bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${paths_ok}" >/dev/null 2>&1; then
    printf '✗ self-test: ci mode rejected a result with a Manual verification section\n' >&2
    fail=1
  fi
  printf '# Proof\nok\n' >"${rdir}/20260919-x-result.md"
  if ! EVALS_PACK_ROOT="${pack}" bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode pre-commit --paths-file "${paths_ok}" >/dev/null 2>&1; then
    printf '✗ self-test: pre-commit mode must not require the result section\n' >&2
    fail=1
  fi
  local lock_only="${tmp}/lock-only"
  if [[ "${LAYOUT}" == "hub" ]]; then
    printf '%s\n' 'poetry.lock' >"${lock_only}"
  else
    printf '%s\n' 'poetry.lock' >"${lock_only}"
  fi
  local skip_msg
  skip_msg="$(bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${lock_only}" 2>&1 >/dev/null || true)"
  if ! printf '%s\n' "${skip_msg}" | grep -Fq 'dependency-bump-only diff — skip'; then
    printf '✗ self-test: lockfile-only diff did not skip pack gate\n' >&2
    fail=1
  fi
  if ! bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --paths-file "${lock_only}" >/dev/null 2>&1; then
    printf '✗ self-test: lockfile-only diff should pass without a pack\n' >&2
    fail=1
  fi
  local gha_repo="${tmp}/gha-repo"
  mkdir -p "${gha_repo}/.github/workflows"
  git -C "${gha_repo}" init -q
  git -C "${gha_repo}" config user.email 'eval@example.com'
  git -C "${gha_repo}" config user.name 'eval'
  cat >"${gha_repo}/.github/workflows/ci.yml" <<'WF'
name: ci
on: push
jobs:
  x:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
WF
  git -C "${gha_repo}" add .
  git -C "${gha_repo}" commit -q -m 'base'
  sed -i '' 's/checkout@v4/checkout@abc12345678901234567890123456789012345678/' "${gha_repo}/.github/workflows/ci.yml" 2>/dev/null \
    || sed -i 's/checkout@v4/checkout@abc12345678901234567890123456789012345678/' "${gha_repo}/.github/workflows/ci.yml"
  git -C "${gha_repo}" commit -q -am 'pin bump'
  if ! EVALS_PACK_ROOT="${gha_repo}" bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --range 'HEAD~1...HEAD' >/dev/null 2>&1; then
    printf '✗ self-test: workflow pin-only diff should pass without a pack\n' >&2
    fail=1
  fi
  git -C "${gha_repo}" reset --hard HEAD~1 -q
  cat >>"${gha_repo}/.github/workflows/ci.yml" <<'WF'

  y:
    runs-on: ubuntu-latest
WF
  git -C "${gha_repo}" commit -q -am 'logic change'
  if EVALS_PACK_ROOT="${gha_repo}" bash "${SCRIPT_DIR}/assert_pr_has_eval_pack.sh" --mode ci --range 'HEAD~1...HEAD' >/dev/null 2>&1; then
    printf '✗ self-test: workflow non-pin diff must still require a pack\n' >&2
    fail=1
  fi
  if [[ "${fail}" -ne 0 ]]; then
    exit 1
  fi
  printf '✓ eval pack gate\n'
}

resolve_pack_roots

mode="ci"
paths_file=""
range=""

if [[ "$#" -eq 0 ]]; then
  if [[ -n "${PRE_COMMIT:-}" ]]; then
    check_list pre-commit "" < <(collect_precommit_paths)
    exit $?
  fi
  self_test
  exit $?
fi

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --paths-file)
      paths_file="${2:-}"
      shift 2
      ;;
    --range)
      range="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

case "${mode}" in
  ci|pre-commit) ;;
  *)
    printf '✗ unknown mode: %s\n' "${mode}" >&2
    exit 2
    ;;
esac

if [[ -n "${paths_file}" && -n "${range}" ]]; then
  printf '✗ pass only one of --paths-file and --range\n' >&2
  exit 2
fi

if [[ -n "${paths_file}" ]]; then
  [[ -f "${paths_file}" ]] || {
    printf '✗ paths file not found: %s\n' "${paths_file}" >&2
    exit 2
  }
  check_list "${mode}" "" < <(read_paths_file "${paths_file}")
elif [[ -n "${range}" ]]; then
  check_list "${mode}" "${range}" < <(paths_from_range "${range}")
else
  usage
  exit 2
fi
