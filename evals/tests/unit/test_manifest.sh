#!/usr/bin/env bash
# Unit checks for shared scope.yaml reader + doctor-scope (host-only).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cli="${ROOT}/harness/goal.sh"
fail=0

if [[ ! -f "${ROOT}/harness/lib/manifest.sh" ]]; then
  printf '✗ missing harness/lib/manifest.sh\n' >&2
  exit 1
fi
if ! grep -qE '^[[:space:]]*load_scope_manifest[[:space:]]*\(\)' "${ROOT}/harness/lib/manifest.sh"; then
  printf '✗ manifest.sh missing load_scope_manifest()\n' >&2
  exit 1
fi
if grep -qE 'evals-scope/v1' "${ROOT}/harness/lib/select.sh"; then
  printf '✗ select.sh still embeds scope.yaml parse\n' >&2
  exit 1
fi
if ! grep -qE 'load_scope_manifest' "${ROOT}/harness/lib/select.sh"; then
  printf '✗ select.sh does not call load_scope_manifest\n' >&2
  exit 1
fi
if ! grep -qE '^eval/doctor-scope:' "${ROOT}/Makefile"; then
  printf '✗ Makefile missing eval/doctor-scope\n' >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "'"${tmp}"'"' EXIT

miss() {
  printf '✗ %s\n' "$*" >&2
  fail=1
}

write_manifest() {
  local path="$1"
  shift
  mkdir -p "$(dirname "${path}")"
  {
    for line in "$@"; do
      printf '%s\n' "${line}"
    done
  } >"${path}"
}

run_doctor() {
  local recipe="$1"
  HERMES_EVAL_RECIPE_ROOT="${recipe}" \
    bash "${cli}" doctor-scope
}

recipe="${tmp}/recipe"
mkdir -p "${recipe}/goals"

set +e
out="$(run_doctor "${recipe}" 2>"${tmp}/err-missing")"
rc=$?
set -e
[[ "${rc}" -eq 0 ]] || miss "missing exit ${rc}"
combined="$(printf '%s\n%s\n' "${out}" "$(cat "${tmp}/err-missing")")"
printf '%s\n' "${combined}" | grep -qiE 'scope\.yaml|create|hint|missing' \
  || miss "missing should hint create"
printf '%s\n' "${combined}" | grep -q 'doctor-scope: ready' \
  || miss "missing should print ready"

write_manifest "${recipe}/scope.yaml" \
  'schema: wrong/v0' \
  'repo: github.com/acme/demo'
set +e
out="$(run_doctor "${recipe}" 2>"${tmp}/err-invalid")"
rc=$?
set -e
[[ "${rc}" -ne 0 ]] || miss "invalid schema should fail"
printf '%s\n' "$(cat "${tmp}/err-invalid")${out}" | grep -qiE 'schema|evals-scope' \
  || miss "invalid schema should mention schema"

write_manifest "${recipe}/scope.yaml" \
  'schema: evals-scope/v1' \
  'repo: github.com/acme/demo' \
  'opt_out:' \
  '  - id: 20260921-probe'
set +e
out="$(run_doctor "${recipe}" 2>"${tmp}/err-reason")"
rc=$?
set -e
[[ "${rc}" -ne 0 ]] || miss "opt_out without reason should fail"
printf '%s\n' "$(cat "${tmp}/err-reason")${out}" | grep -qiE 'reason' \
  || miss "should mention reason"

write_manifest "${recipe}/scope.yaml" \
  'schema: evals-scope/v1' \
  'repo: github.com/acme/demo' \
  'languages:' \
  '  - typescript' \
  'opt_out:' \
  '  - id: 20260921-probe' \
  '    reason: "unit probe"'
set +e
out="$(run_doctor "${recipe}" 2>"${tmp}/err-ok")"
rc=$?
set -e
[[ "${rc}" -eq 0 ]] || miss "valid exit ${rc}: ${out}"
printf '%s\n' "${out}" | grep -q 'doctor-scope: ready' \
  || miss "valid should print ready"

if [[ "${fail}" -eq 0 ]]; then
  printf '✓ test_manifest.sh\n'
fi
exit "${fail}"
