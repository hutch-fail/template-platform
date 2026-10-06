#!/usr/bin/env bash
# F2P: org live-verify rule must exist and host adapters must list it.
# Baseline still lacks the rule and the adapter entry. Do not grade origin/main alone.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rule="${here}/baseline/.cursor/rules/live-verify.mdc"
adapter="${here}/baseline/install-host-adapters.sh"

fail=0
miss() {
  printf '%s\n' "$*" >&2
  fail=1
}

[[ -f "${adapter}" ]] || miss "missing baseline/install-host-adapters.sh"
if [[ "${fail}" -ne 0 ]]; then
  exit "${fail}"
fi

if [[ ! -f "${rule}" ]]; then
  miss "missing baseline/.cursor/rules/live-verify.mdc"
else
  if ! grep -qE 'alwaysApply:[[:space:]]*true' "${rule}"; then
    miss "live-verify.mdc must set alwaysApply: true"
  fi
  if ! grep -qiE 'ask before' "${rule}"; then
    miss "live-verify.mdc must ask before disruptive live checks"
  fi
  if ! grep -qiE 'works|done' "${rule}"; then
    miss "live-verify.mdc must cover works/done claims"
  fi
  if ! grep -qiE 'real[[:space:]]+system|concrete evidence|live' "${rule}"; then
    miss "live-verify.mdc must require real-system evidence"
  fi
  if grep -qiE 'incus|volumes\.yaml|colima|meter\.localhost|paperclip' "${rule}"; then
    miss "live-verify.mdc must stay product-agnostic (no Incus/volumes/product hosts)"
  fi
fi

if ! grep -Fq 'live-verify.mdc' "${adapter}"; then
  miss "install-host-adapters.sh must list live-verify.mdc"
fi

exit "${fail}"
