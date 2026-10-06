#!/usr/bin/env bash
# Host/hub pre-push entry — CI-mode eval pack gate (fixture + goal + result).
#
# Soft pack (fixture + pre-run goal) stays on pre-commit via pre-commit-evals.sh.
# Result files are required here so two-commit authorship still works locally
# while a push without *-result.md fails before eval-ci.
#
# Usage (pre-push hook):
#   bash evals/scripts/pre-push-evals.sh
#   bash scripts/pre-push-evals.sh   # hub layout
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
assert="${here}/../tests/unit/assert_pr_has_eval_pack.sh"

if [[ ! -f "${assert}" ]]; then
  printf 'error: missing %s\n' "${assert}" >&2
  exit 1
fi

# Resolve product/hub root the same way the pack assert does.
if [[ -d "${here}/../.git" ]]; then
  root="$(cd "${here}/.." && pwd)"
else
  root="$(cd "${here}/../.." && pwd)"
fi

base=""
if git -C "${root}" rev-parse --verify origin/main >/dev/null 2>&1; then
  base="$(git -C "${root}" merge-base origin/main HEAD)"
elif git -C "${root}" rev-parse --verify main >/dev/null 2>&1; then
  base="$(git -C "${root}" merge-base main HEAD)"
fi

if [[ -z "${base}" ]]; then
  # No main ref — fall back to soft self-check of working tree vs empty is useless;
  # require at least staged+HEAD tip via pre-commit collection by invoking with PRE_COMMIT
  # is wrong for result. Use HEAD~0 only when alone.
  printf 'error: cannot resolve merge-base with main/origin/main for pack gate\n' >&2
  exit 1
fi

exec bash "${assert}" --mode ci --range "${base}...HEAD"
