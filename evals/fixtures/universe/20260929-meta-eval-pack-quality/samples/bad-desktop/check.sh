#!/usr/bin/env bash
# Bad desktop-launch fixture: PATH-only proof of a GUI app.
set -euo pipefail
command -v demo-gui >/dev/null
exit 0
