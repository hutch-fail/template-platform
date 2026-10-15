#!/usr/bin/env bash
# P2P: fixture scripts present after golden.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ---
test -x "${here}/check.sh"
test -f "${here}/golden.patch"
test -f "${here}/notes.txt"
test -f "${here}/verify_wiring.py"
# ---
echo ui_pr_before_after_screenshots_p2p_ok
