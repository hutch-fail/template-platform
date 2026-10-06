#!/usr/bin/env bash
# P2P: fixture still has workflows + executable checks; golden must drop raw App secrets.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test -x "${here}/check.sh"
test -f "${here}/golden.patch"
sample="${here}/.github/workflows/sample-ci.yml"
test -f "${sample}"
if grep -Eq 'secrets\.GH_APP_ID|secrets\.GH_APP_PRIVATE_KEY' "${sample}"; then
  printf 'p2p: sample-ci.yml still references secrets.GH_APP_*\n' >&2
  exit 1
fi
grep -Fq '1password/load-secrets-action' "${sample}"
grep -Fq 'steps.op.outputs.GH_APP_ID' "${sample}"
grep -Fq 'op://' "${sample}"
exit 0
