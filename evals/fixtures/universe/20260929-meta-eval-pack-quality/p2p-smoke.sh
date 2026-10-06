#!/usr/bin/env bash
# P2P: after golden, demo pack is well-formed; checks stay executable.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test -x "${here}/check.sh"
test -f "${here}/golden.patch"
test -f "${here}/PACK_QUALITY_FIXTURE"
test -x "${here}/samples/good/check.sh"
test -f "${here}/samples/good/goal.md"
test -f "${here}/samples/bad/goal.md"
# Golden replaces thin pack with executive demo.
test -f "${here}/goals/demo/thin-pack.md"
grep -q 'Executive overview' "${here}/goals/demo/thin-pack.md"
grep -Eq 'hold-out|holdout|train' "${here}/goals/demo/thin-pack.md"

resolve_kit() {
  local cand
  for cand in \
    "${HERMES_EVAL_KIT:-}" \
    "${EVALS_KIT:-}" \
    "${HERMES_EVAL_REPO_ROOT:-}" \
    "${HERMES_EVAL_REPO_ROOT:-}/evals" \
    "${here}/../../.." \
    "${here}/../../../evals"; do
    [[ -n "${cand}" && -d "${cand}" ]] || continue
    if [[ -f "${cand}/harness/lib/pack_quality_lint.py" ]]; then
      printf '%s\n' "$(cd "${cand}" && pwd)"
      return 0
    fi
  done
  return 1
}
kit="$(resolve_kit)"
test -f "${kit}/harness/lib/pack_quality_lint.py"
test -f "${kit}/harness/lib/llm_pack_quality_judge.py"
exit 0
