#!/usr/bin/env bash
# Host pre-commit entry — pack gate + goal schema parse + shared eval bars.
#
# Hosts call this one hook (after hutch-fail/pre-commit). On PRE_COMMIT=1 it
# fast-fails when a behavior-changing staged/branch diff lacks an eval fixture
# + pre-run goal (assert_pr_has_eval_pack --mode pre-commit). Result files are
# still deferred to pre-push / eval-ci (pre-push-evals.sh --mode ci). Then it
# parses staged/changed goal markdown (goal/v1 via assert_goals_schema) and
# runs universe bars and language families:
#   - (always) universe → no raw GH_APP_* Actions secrets, …
#   - languages: ui / design|scripts/ui-* → UI language bars
#   - *.tf / *.tf.json  → OpenTofu language bars (remote-backend, …)
#   - ansible/** / ansible.cfg → Ansible language bars (single-converge, …)
#   - .github/workflows/** / .github/actions/** → gha language bars
#   - *.ts / *.tsx / …  → typescript family (typecheck / test when present)
#
# Usage (pre-commit, pass_filenames: true):
#   bash evals/scripts/pre-commit-evals.sh [path...]
#
# Prefer make eval/bars / scripts/eval-bars.sh for local and CI equivalence.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Local fast-fail: same pack gate as CI, softer (no result required yet).
if [[ -n "${PRE_COMMIT:-}" ]]; then
  assert="${here}/../tests/unit/assert_pr_has_eval_pack.sh"
  if [[ -f "${assert}" ]]; then
    # No args + PRE_COMMIT → collect_precommit_paths (host or hub layout).
    bash "${assert}"
  fi
  schema="${here}/../tests/unit/assert_goals_schema.sh"
  if [[ -f "${schema}" ]]; then
    # Filenames from pre-commit when present; else staged/branch collection.
    bash "${schema}" "$@"
  fi
fi

exec bash "${here}/eval-bars.sh" "$@"
