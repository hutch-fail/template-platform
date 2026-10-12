#!/usr/bin/env bash
# P2P: live hub PROCESS.md + grader reject structure-only done.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test -x "${here}/check.sh"
test -f "${here}/golden.patch"
test -f "${here}/cases/structure-only-done.json"
test -f "${here}/cases/structure-only-blocked.json"

root="${HERMES_EVAL_REPO_ROOT:-}"
if [[ -z "${root}" || ! -d "${root}" ]]; then
  printf 'HERMES_EVAL_REPO_ROOT unset or not a directory\n' >&2
  exit 1
fi
if [[ -f "${root}/harness/goal.sh" ]]; then
  :
elif [[ -f "${root}/evals/harness/goal.sh" ]]; then
  root="${root}/evals"
else
  printf 'harness/goal.sh not found under %s\n' "${root}" >&2
  exit 1
fi

fail=0
miss() {
  printf '%s\n' "$*" >&2
  fail=1
}

process="${root}/PROCESS.md"
grader="${root}/scripts/grade-structure-only-disposition.sh"
case_done="${here}/cases/structure-only-done.json"
case_blocked="${here}/cases/structure-only-blocked.json"

[[ -f "${process}" ]] || miss "live hub missing PROCESS.md"
[[ -x "${grader}" ]] || miss "live hub missing executable scripts/grade-structure-only-disposition.sh"

if [[ -f "${process}" ]]; then
  grep -Fq 'Kick-the-tires / structure-only disposition' "${process}" \
    || miss "live PROCESS.md missing Kick-the-tires / structure-only disposition"
  grep -qiE 'observable[[:space:]]+final[[:space:]]+state' "${process}" \
    || miss "live PROCESS.md must require observable final state"
  grep -qiE 'fail-closed|certified[[:space:]]*red|assert-red' "${process}" \
    || miss "live PROCESS.md must require fail-closed / certified-red"
  grep -qiE 'blocked|in_review' "${process}" \
    || miss "live PROCESS.md must forbid done for structure-only"
fi

if [[ -x "${grader}" ]]; then
  set +e
  "${grader}" "${case_done}"
  rc_done=$?
  "${grader}" "${case_blocked}"
  rc_blocked=$?
  set -e
  [[ "${rc_done}" -ne 0 ]] || miss "live grader must reject structure-only-done"
  [[ "${rc_blocked}" -eq 0 ]] || miss "live grader must allow structure-only-blocked"
fi

exit "${fail}"
