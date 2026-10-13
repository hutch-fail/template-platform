#!/usr/bin/env bash
# Minimal F2P for the Jev good sample — hermetic unit-test-shaped exercise.
set -euo pipefail
marker="${TMPDIR:-/tmp}/jev-good-sample.marker"
rm -f "${marker}"
# Stand-in for `node --test` / pytest: write the effect marker the goal grades.
: >"${marker}"
[[ -f "${marker}" ]] || exit 1
printf 'jev_good_sample_ok\n'
