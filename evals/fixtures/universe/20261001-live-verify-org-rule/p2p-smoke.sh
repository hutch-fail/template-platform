#!/usr/bin/env bash
# P2P: fixture layout + live hub ships live-verify rule and adapter wiring.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test -x "${here}/check.sh"
test -f "${here}/golden.patch"
test -f "${here}/baseline/install-host-adapters.sh"

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

rule="${root}/.cursor/rules/live-verify.mdc"
adapter="${root}/scripts/install-host-adapters.sh"

[[ -f "${rule}" ]] || miss "live hub missing .cursor/rules/live-verify.mdc"
[[ -f "${adapter}" ]] || miss "live hub missing scripts/install-host-adapters.sh"

if [[ -f "${rule}" ]]; then
  grep -qE 'alwaysApply:[[:space:]]*true' "${rule}" || miss "live rule must set alwaysApply: true"
  grep -qiE 'ask before' "${rule}" || miss "live rule must ask before disruptive checks"
  if grep -qiE 'incus|volumes\.yaml|colima' "${rule}"; then
    miss "live rule must stay product-agnostic"
  fi
fi

if [[ -f "${adapter}" ]] && ! grep -Fq 'live-verify.mdc' "${adapter}"; then
  miss "live install-host-adapters.sh must list live-verify.mdc"
fi

# Procedure homes blurb present for redistributors.
if [[ -f "${root}/PROCESS.md" ]] && ! grep -Fq 'Procedure homes' "${root}/PROCESS.md"; then
  miss "PROCESS.md must document Procedure homes"
fi

exit "${fail}"
