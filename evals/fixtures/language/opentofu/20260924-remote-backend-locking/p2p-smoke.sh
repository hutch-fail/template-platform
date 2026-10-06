#!/usr/bin/env bash
# P2P: fixture still has backend.tf and executable checks after the patch.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test -x "${here}/check.sh"
test -f "${here}/golden.patch"
test -f "${here}/terraform/backend.tf"
# After golden: must not still be local-only.
if grep -qE 'backend[[:space:]]+"local"' "${here}/terraform/backend.tf"; then
  printf 'p2p: backend.tf still declares backend "local"\n' >&2
  exit 1
fi
grep -qE 'backend[[:space:]]+"[^"]+"' "${here}/terraform/backend.tf"
exit 0
