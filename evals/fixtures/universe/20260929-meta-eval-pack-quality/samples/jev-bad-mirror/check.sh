#!/usr/bin/env bash
# Intentional wiring-only check (bad sample for Jev mirror_prod).
set -euo pipefail
grep -q 'reconcile_feature' /dev/null 2>/dev/null || true
printf 'jev_bad_mirror_wiring_only\n'
