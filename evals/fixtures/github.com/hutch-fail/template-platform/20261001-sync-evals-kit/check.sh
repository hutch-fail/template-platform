#!/usr/bin/env bash
set -euo pipefail
root="${HERMES_EVAL_REPO_ROOT:-${HERMES_EVAL_SCAN_ROOT:-$PWD}}"
[[ -f "${root}/evals/scripts/eval-bars.sh" ]] || { echo "missing eval-bars.sh" >&2; exit 1; }
grep -q 'run_gha_bars' "${root}/evals/scripts/eval-bars.sh" || { echo "missing run_gha_bars after sync" >&2; exit 1; }
echo sync_evals_kit_ok
