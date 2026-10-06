#!/usr/bin/env bash
# P2P: after golden, org pre-commit shape is present; checks stay executable.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test -x "${here}/check.sh"
test -f "${here}/golden.patch"
cfg="${here}/.pre-commit-config.yaml"
test -f "${cfg}"
grep -Eq 'hutch-fail/pre-commit|github\.com/hutch-fail/pre-commit' "${cfg}"
grep -Eq '^[[:space:]]*-[[:space:]]*id:[[:space:]]*platform[[:space:]]*$' "${cfg}"
grep -Fq 'pre-commit-evals.sh' "${cfg}"
# Fresh-product kit marker (opted into evals) remains.
test -f "${here}/evals/harness/goal.sh"
exit 0
