#!/usr/bin/env bash
# F2P: scripts/sync-secrets.sh consumers must hard-pin GITHUB_OWNER.
# Skip (pass) when that script is absent.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_scan_root() {
  if [[ -n "${HERMES_EVAL_SCAN_ROOT:-}" && -d "${HERMES_EVAL_SCAN_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_SCAN_ROOT}" && pwd)"
    return 0
  fi
  printf '%s\n' "${here}"
}

root="$(resolve_scan_root)"
sync="${root}/scripts/sync-secrets.sh"
if [[ ! -f "${sync}" ]]; then
  exit 0
fi

has_literal_pin() {
  local file="$1"
  [[ -f "${file}" ]] || return 1
  grep -Eq '^[[:space:]]*GITHUB_OWNER="[^"$\\]+"' "${file}" \
    || grep -Eq "^[[:space:]]*GITHUB_OWNER='[^'$\\]+'" "${file}" \
    || grep -Eq '^[[:space:]]*GITHUB_OWNER=[A-Za-z0-9._-]+[[:space:]]*$' "${file}"
}

pinned=0
for f in "${root}/scripts/lib/env.sh" "${sync}"; do
  if has_literal_pin "${f}"; then
    pinned=1
    break
  fi
done

if [[ "${pinned}" -ne 1 ]]; then
  printf 'error: %s exists but GITHUB_OWNER is not a literal assignment in scripts/lib/env.sh or scripts/sync-secrets.sh (do not inherit from the parent shell)\n' \
    "${sync}" >&2
  exit 1
fi

exit 0
