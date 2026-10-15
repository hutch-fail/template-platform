#!/usr/bin/env bash
# P2P: same as check after golden (thin workflow).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${here}/check.sh"
