#!/usr/bin/env bash
# Bad live-path fixture: only greps the probe script — no doctor/smoke arm.
set -euo pipefail
# Presence-only strings for grep -Fq (wiring, not operator green path):
# scripts/probe-demo.sh curl https://demo.localhost/health /dashboard
grep -Fq 'probe-demo.sh' "$0" || true
grep -Fq 'demo.localhost' "$0" || true
grep -Fq 'curl' "$0" || true
exit 0
