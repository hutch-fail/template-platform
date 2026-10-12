#!/usr/bin/env bash
# F2P: wrap-prior-art rule must exist and host adapters must list it.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rule="${here}/baseline/.cursor/rules/wrap-prior-art.mdc"
adapter="${here}/baseline/install-host-adapters.sh"

fail=0
miss() { printf '%s\n' "$*" >&2; fail=1; }

[[ -f "${adapter}" ]] || miss "missing baseline/install-host-adapters.sh"
if [[ "${fail}" -ne 0 ]]; then
  exit "${fail}"
fi

if [[ ! -f "${rule}" ]]; then
  miss "missing baseline/.cursor/rules/wrap-prior-art.mdc"
else
  grep -qE 'alwaysApply:[[:space:]]*true' "${rule}" || miss "wrap-prior-art.mdc must set alwaysApply: true"
  grep -qiE 'wrap|pin' "${rule}" || miss "wrap-prior-art.mdc must say wrap/pin"
  grep -qiE 'do not rewrite|unmodified|do not.*edit' "${rule}" || miss "wrap-prior-art.mdc must forbid rewriting upstream source"
fi

if ! grep -Fq 'wrap-prior-art.mdc' "${adapter}"; then
  miss "install-host-adapters.sh must list wrap-prior-art.mdc"
fi

exit "${fail}"
