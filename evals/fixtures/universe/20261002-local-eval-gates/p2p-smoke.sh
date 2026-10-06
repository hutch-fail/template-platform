#!/usr/bin/env bash
# P2P: after golden, pre-push hook present; checks stay executable.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test -x "${here}/check.sh"
test -f "${here}/golden.patch"
cfg="${here}/.pre-commit-config.yaml"
test -f "${cfg}"
grep -Fq 'pre-push-evals.sh' "${cfg}"
grep -Eq 'default_install_hook_types:.*pre-push' "${cfg}"
grep -Fq 'pre-commit-evals.sh' "${cfg}"
test -f "${here}/evals/harness/goal.sh"
exit 0
