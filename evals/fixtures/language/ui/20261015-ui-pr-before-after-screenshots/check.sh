#!/usr/bin/env bash
# F2P: UI/UX PR before/after screenshot gate is wired in the hub pack gate + CI.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ---
# Baseline (notes != patched): always red for assert-red.
if ! grep -qx 'patched' "${here}/notes.txt" 2>/dev/null; then
  printf 'error: baseline fixture not patched (ui before/after F2P red)\n' >&2
  exit 1
fi
# ---
exec python3 "${here}/verify_wiring.py"
