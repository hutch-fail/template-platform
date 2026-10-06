#!/usr/bin/env bash
# Unit matrix for eval/list + eval/select scope filters (host-only).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cli="${ROOT}/harness/goal.sh"
fx="evals/fixtures/github.com/hutch-fail/evals/20260921-eval-list-select"
fail=0

if [[ ! -f "${ROOT}/harness/lib/select.sh" ]]; then
  printf '✗ missing harness/lib/select.sh\n' >&2
  exit 1
fi
if ! grep -qE '^eval/list:' "${ROOT}/Makefile"; then
  printf '✗ Makefile missing eval/list\n' >&2
  exit 1
fi
if ! grep -qE '^eval/select:' "${ROOT}/Makefile"; then
  printf '✗ Makefile missing eval/select\n' >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "'"${tmp}"'"' EXIT

miss() {
  printf '✗ %s\n' "$*" >&2
  fail=1
}

write_goal() {
  local path="$1" id="$2"
  shift 2
  mkdir -p "$(dirname "${path}")"
  {
    printf '%s\n' '---'
    printf '%s\n' 'schema: goal/v1'
    printf '%s\n' "id: ${id}"
    printf '%s\n' "fixture_dir: ${fx}"
    printf '%s\n' 'f2p_check: check.sh'
    printf '%s\n' 'p2p_check: p2p-smoke.sh'
    for line in "$@"; do
      printf '%s\n' "${line}"
    done
    printf '%s\n' '---'
    printf '%s\n' '# unit'
  } >"${path}"
}

write_manifest() {
  local path="$1"
  shift
  mkdir -p "$(dirname "${path}")"
  {
    printf '%s\n' 'schema: evals-scope/v1'
    for line in "$@"; do
      printf '%s\n' "${line}"
    done
  } >"${path}"
}

recipe="${tmp}/recipe"
process="${tmp}/process"
mkdir -p "${recipe}/goals" "${process}/goals"

write_goal "${recipe}/goals/universe/20260921-u-uni.md" \
  '20260921-u-uni' 'scope: universe'
write_goal "${recipe}/goals/language/typescript/20260921-u-ts.md" \
  '20260921-u-ts' 'scope: language' 'languages: typescript'
write_goal "${recipe}/goals/language/python/20260921-u-py.md" \
  '20260921-u-py' 'scope: language' 'languages: python'
write_goal "${recipe}/goals/language/ui/20260921-u-ui.md" \
  '20260921-u-ui' 'scope: language' 'languages: ui'
write_goal "${recipe}/goals/github.com/acme/demo/20260921-u-repo.md" \
  '20260921-u-repo' 'scope: repo'
write_goal "${recipe}/goals/github.com/other/other/20260921-u-other.md" \
  '20260921-u-other' 'scope: repo'
write_goal "${process}/goals/scratch/20260921-u-active.md" \
  '20260921-u-active' 'scope: active'

write_manifest "${recipe}/scope.yaml" \
  'repo: github.com/acme/demo' \
  'languages:' \
  '  - typescript' \
  'opt_out:' \
  '  - id: 20260921-u-uni' \
  '    reason: "unit opt-out"'

set +e
out="$(
  HERMES_EVAL_RECIPE_ROOT="${recipe}" \
    EVALS_ROOT="${process}" \
    HERMES_EVALS_ROOT="${process}" \
    bash "${cli}" select 2>"${tmp}/err"
)"
rc=$?
set -e
if [[ "${rc}" -ne 0 ]]; then
  miss "select failed rc=${rc}: ${out} err=$(cat "${tmp}/err")"
fi

printf '%s\n' "${out}" | grep -q '20260921-u-uni' \
  && miss "opted-out universe present"
printf '%s\n' "$(cat "${tmp}/err")" | grep -qE 'opt_out.*20260921-u-uni' \
  || miss "missing opt_out stderr"
printf '%s\n' "${out}" | grep -q '20260921-u-ts' || miss "ts language missing"
printf '%s\n' "${out}" | grep -q '20260921-u-py' && miss "py language wrongly included"
printf '%s\n' "${out}" | grep -q '20260921-u-ui' && miss "ui language wrongly included with only typescript"
printf '%s\n' "${out}" | grep -q '20260921-u-repo' || miss "matching repo missing"
printf '%s\n' "${out}" | grep -q '20260921-u-other' && miss "other repo wrongly included"
printf '%s\n' "${out}" | grep -q '20260921-u-active' && miss "active wrongly included"

write_manifest "${recipe}/scope.yaml" \
  'repo: github.com/acme/demo' \
  'languages:' \
  '  - typescript'
set +e
out="$(
  HERMES_EVAL_RECIPE_ROOT="${recipe}" \
    EVALS_ROOT="${process}" \
    HERMES_EVALS_ROOT="${process}" \
    bash "${cli}" select 2>/dev/null
)"
rc=$?
set -e
[[ "${rc}" -eq 0 ]] || miss "select without opt_out failed"
printf '%s\n' "${out}" | grep -q '20260921-u-uni' || miss "universe missing when not opted out"

set +e
out="$(
  HERMES_EVAL_RECIPE_ROOT="${recipe}" \
    EVALS_ROOT="${process}" \
    HERMES_EVALS_ROOT="${process}" \
    EVALS_INCLUDE_ACTIVE=1 \
    bash "${cli}" select 2>/dev/null
)"
rc=$?
set -e
[[ "${rc}" -eq 0 ]] || miss "EVALS_INCLUDE_ACTIVE select failed"
printf '%s\n' "${out}" | grep -q '20260921-u-active' || miss "active missing with INCLUDE_ACTIVE"

set +e
out="$(
  HERMES_EVAL_RECIPE_ROOT="${recipe}" \
    EVALS_ROOT="${process}" \
    HERMES_EVALS_ROOT="${process}" \
    bash "${cli}" select 20260921-u-active 2>/dev/null
)"
rc=$?
set -e
[[ "${rc}" -eq 0 ]] || miss "GOAL=active select failed"
printf '%s\n' "${out}" | grep -q '20260921-u-active' || miss "active missing with GOAL="

set +e
list_out="$(
  HERMES_EVAL_RECIPE_ROOT="${recipe}" \
    EVALS_ROOT="${process}" \
    HERMES_EVALS_ROOT="${process}" \
    bash "${cli}" list 2>/dev/null
)"
rc=$?
set -e
[[ "${rc}" -eq 0 ]] || miss "list failed"
printf '%s\n' "${list_out}" | grep -qE '20260921-u-ts[[:space:]]+language' \
  || miss "list missing id+scope: ${list_out}"

# Missing manifest: soft defaults (empty languages ⇒ no language bars; universe still)
rm -f "${recipe}/scope.yaml"
set +e
out="$(
  HERMES_EVAL_RECIPE_ROOT="${recipe}" \
    EVALS_ROOT="${process}" \
    HERMES_EVALS_ROOT="${process}" \
    bash "${cli}" select 2>/dev/null
)"
rc=$?
set -e
[[ "${rc}" -eq 0 ]] || miss "select with missing manifest failed"
printf '%s\n' "${out}" | grep -q '20260921-u-uni' || miss "universe should apply with missing manifest"
printf '%s\n' "${out}" | grep -q '20260921-u-ts' && miss "language should not apply with empty languages"
printf '%s\n' "${out}" | grep -q '20260921-u-ui' && miss "ui should not apply with empty languages"

# languages: [ui] selects ui language goals only among language bars
write_manifest "${recipe}/scope.yaml" \
  'repo: github.com/acme/demo' \
  'languages:' \
  '  - ui'
set +e
out="$(
  HERMES_EVAL_RECIPE_ROOT="${recipe}" \
    EVALS_ROOT="${process}" \
    HERMES_EVALS_ROOT="${process}" \
    bash "${cli}" select 2>/dev/null
)"
rc=$?
set -e
[[ "${rc}" -eq 0 ]] || miss "select with languages ui failed"
printf '%s\n' "${out}" | grep -q '20260921-u-ui' || miss "ui language missing when languages: [ui]"
printf '%s\n' "${out}" | grep -q '20260921-u-ts' && miss "ts wrongly included with only ui"
printf '%s\n' "${out}" | grep -q '20260921-u-uni' || miss "universe missing with ui manifest"

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

printf '✓ select filters\n'
