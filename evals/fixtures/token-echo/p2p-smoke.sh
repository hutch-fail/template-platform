#!/usr/bin/env bash
# P2P smoke: fixture layout invariants that must stay green.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test -x "${here}/sut.sh"
test -x "${here}/check.sh"
test -f "${here}/golden.patch"
exit 0
