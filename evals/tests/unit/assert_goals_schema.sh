#!/usr/bin/env bash
# Local pre-commit: parse staged/changed goal markdown (require goal/v1).
# Skips *-result.md. Invokes harness/goal.sh parse for each path.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GOAL_SH="${HUB_ROOT}/harness/goal.sh"

resolve_pack_roots() {
  if [[ -n "${EVALS_PACK_ROOT:-}" ]]; then
    ROOT="$(cd "${EVALS_PACK_ROOT}" && pwd)"
    return 0
  fi
  if [[ -d "${HUB_ROOT}/.git" ]]; then
    ROOT="${HUB_ROOT}"
    return 0
  fi
  ROOT="$(cd "${HUB_ROOT}/.." && pwd)"
}

is_goal_path() {
  local p="$1" base
  case "${p}" in
    goals/*.md|evals/goals/*.md) ;;
    *) return 1 ;;
  esac
  base="${p##*/}"
  case "${base}" in
    *-result.md|README.md|_schema.md) return 1 ;;
    *) return 0 ;;
  esac
}

evals_root_for_rel() {
  local rel="$1"
  case "${rel}" in
    evals/goals/*)
      printf '%s\n' "${ROOT}/evals"
      ;;
    goals/*)
      printf '%s\n' "${ROOT}"
      ;;
    *)
      printf '%s\n' "${HUB_ROOT}"
      ;;
  esac
}

collect_paths() {
  local base="" p
  if [[ "$#" -gt 0 ]]; then
    for p in "$@"; do
      printf '%s\n' "${p}"
    done
    return 0
  fi
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

self_test() {
  local tmp fail=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "'"${tmp}"'"' RETURN
  mkdir -p "${tmp}/goals/github.com/o/r"
  # fixture_dir must resolve via the kit (require_goal_v1), not EVALS_ROOT alone.
  cat >"${tmp}/goals/github.com/o/r/20261002-good.md" <<'EOF'
---
schema: goal/v1
id: 20261002-good
title: good
scope: repo
fixture_dir: evals/fixtures/universe/20261002-local-eval-gates
f2p_check: check.sh
solver: none
---

# Executive overview

Good schema self-test.
EOF
  cat >"${tmp}/goals/github.com/o/r/20261002-bad.md" <<'EOF'
---
id: 20261002-bad
title: bad
scope: repo
fixture_dir: evals/fixtures/universe/20261002-local-eval-gates
f2p_check: check.sh
solver: none
---

# Executive overview

Missing schema self-test.
EOF
  # Hub-style tree under EVALS_PACK_ROOT == tmp (goals/ at root).
  if ! EVALS_PACK_ROOT="${tmp}" bash "${SCRIPT_DIR}/assert_goals_schema.sh" \
    "goals/github.com/o/r/20261002-good.md" >/dev/null 2>&1; then
    printf '✗ self-test: good goal should parse\n' >&2
    fail=1
  fi
  if EVALS_PACK_ROOT="${tmp}" bash "${SCRIPT_DIR}/assert_goals_schema.sh" \
    "goals/github.com/o/r/20261002-bad.md" >/dev/null 2>&1; then
    printf '✗ self-test: bad goal must fail parse\n' >&2
    fail=1
  fi
  if [[ "${fail}" -ne 0 ]]; then
    exit 1
  fi
  printf '✓ goal schema gate\n'
}

resolve_pack_roots

if [[ ! -f "${GOAL_SH}" ]]; then
  printf 'error: missing %s\n' "${GOAL_SH}" >&2
  exit 1
fi

if [[ "$#" -eq 0 && -z "${PRE_COMMIT:-}" ]]; then
  self_test
  exit $?
fi

fail=0
cleanup_temps=()
trap 'rm -f "${cleanup_temps[@]+"${cleanup_temps[@]}"}"' EXIT

while IFS= read -r rel; do
  [[ -n "${rel}" ]] || continue
  is_goal_path "${rel}" || continue
  abs="${ROOT}/${rel}"
  if [[ ! -f "${abs}" ]]; then
    if git -C "${ROOT}" cat-file -e ":${rel}" 2>/dev/null; then
      abs="$(mktemp)"
      cleanup_temps+=("${abs}")
      git -C "${ROOT}" show ":${rel}" >"${abs}"
    else
      printf 'error: goal path not found: %s\n' "${rel}" >&2
      fail=1
      continue
    fi
  fi
  export EVALS_ROOT
  EVALS_ROOT="$(evals_root_for_rel "${rel}")"
  if ! bash "${GOAL_SH}" parse "${abs}" >/dev/null; then
    printf 'error: goal schema/frontmatter invalid: %s\n' "${rel}" >&2
    fail=1
  fi
done < <(collect_paths "$@")

exit "${fail}"
