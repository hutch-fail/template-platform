#!/usr/bin/env bash
set -euo pipefail
echo ok
python3 - <<'PY'
print("helper")
PY
