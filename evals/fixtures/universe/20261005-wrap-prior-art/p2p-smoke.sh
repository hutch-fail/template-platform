#!/usr/bin/env bash
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
miss() { printf '%s\n' "$*" >&2; fail=1; }

rule="${root}/.cursor/rules/wrap-prior-art.mdc"
adapter="${root}/scripts/install-host-adapters.sh"
[[ -f "${rule}" ]] || miss "live hub missing wrap-prior-art.mdc"
[[ -f "${adapter}" ]] || miss "live hub missing install-host-adapters.sh"
if [[ -f "${rule}" ]]; then
  grep -qE 'alwaysApply:[[:space:]]*true' "${rule}" || miss "live rule must set alwaysApply: true"
fi
if [[ -f "${adapter}" ]] && ! grep -Fq 'wrap-prior-art.mdc' "${adapter}"; then
  miss "live install-host-adapters.sh must list wrap-prior-art.mdc"
fi
if [[ -f "${root}/PROCESS.md" ]] && ! grep -Fq 'wrap-prior-art.mdc' "${root}/PROCESS.md"; then
  miss "PROCESS.md must mention wrap-prior-art.mdc"
fi
[[ -f "${root}/docs/prior-art.md" ]] || miss "missing docs/prior-art.md"
if [[ "${fail}" -ne 0 ]]; then
  exit "${fail}"
fi
# Observable entrypoint effect (same contract as check.sh marker).
marker="${here}/.wrap-prior-art-p2p-ok"
printf 'wrap-prior-art p2p ok\n' >"${marker}"
[[ -f "${marker}" ]] || {
  printf 'error: failed to write p2p marker\n' >&2
  exit 1
}
exit 0
