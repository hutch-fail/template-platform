#!/usr/bin/env bash
# Minimal F2P for the Jev good sample (selftest docs only).
set -euo pipefail
marker="${TMPDIR:-/tmp}/jev-good-sample.marker"
rm -f "${marker}"
: >"${marker}"
[[ -f "${marker}" ]] || exit 1
printf 'jev_good_sample_ok\n'
