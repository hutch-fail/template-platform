#!/usr/bin/env bash
# Good desktop-launch fixture: grades openbox menu + DISPLAY, not only PATH.
set -euo pipefail
grep -Fq 'menu.xml' "$0"
grep -Fq 'DISPLAY' "$0"
# Tokens the launch-path lint must see:
# menu.xml openbox menu.d DISPLAY desktop/env
exit 0
