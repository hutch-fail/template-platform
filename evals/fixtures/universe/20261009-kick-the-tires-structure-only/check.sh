#!/usr/bin/env bash
# F2P: kick-the-tires procedure + structure-only disposition grader.
# Baseline omits the PROCESS section and ships a broken always-allow grader.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
process="${here}/baseline/PROCESS.md"
grader="${here}/baseline/scripts/grade-structure-only-disposition.sh"
case_done="${here}/baseline/cases/structure-only-done.json"

fail=0
miss() {
  printf '%s\n' "$*" >&2
  fail=1
}

[[ -f "${process}" ]] || miss "missing baseline/PROCESS.md"
[[ -f "${grader}" ]] || miss "missing baseline/scripts/grade-structure-only-disposition.sh"
[[ -f "${case_done}" ]] || miss "missing baseline/cases/structure-only-done.json"

if [[ -f "${process}" ]]; then
  grep -Fq 'Kick-the-tires / structure-only disposition' "${process}" \
    || miss "PROCESS.md missing Kick-the-tires / structure-only disposition section"
  grep -qiE 'observable[[:space:]]+final[[:space:]]+state' "${process}" \
    || miss "PROCESS.md must require PM observable final state before build"
  grep -qiE 'fail-closed|certified[[:space:]]*red|assert-red' "${process}" \
    || miss "PROCESS.md must require SDET fail-closed / certified-red gate"
  grep -qiE 'blocked|in_review' "${process}" \
    || miss "PROCESS.md must say structure-only ⇒ blocked/in_review, not done"
  grep -qiE 'structure-only|IaC|examples' "${process}" \
    || miss "PROCESS.md must name the structure-only / IaC regression"
fi

if [[ -x "${grader}" && -f "${case_done}" ]]; then
  set +e
  "${grader}" "${case_done}"
  rc=$?
  set -e
  if [[ "${rc}" -eq 0 ]]; then
    miss "grader must REJECT disposition=done for structure-only-done case (got exit 0)"
  fi
else
  miss "grader not executable or case missing"
fi

exit "${fail}"
