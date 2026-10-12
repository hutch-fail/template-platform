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
test -x "${here}/samples/good-desktop/check.sh"
test -f "${here}/samples/good-desktop/goal.md"
test -x "${here}/samples/bad-desktop/check.sh"
test -f "${here}/samples/bad-desktop/goal.md"
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
test -f "${kit}/harness/lib/jev_pack_quality_judge.py"
test -f "${kit}/harness/lib/pack_quality_select.py"
test -f "${here}/samples/jev-good/goal.md"
test -f "${here}/samples/jev-good/expected.yaml"
test -f "${here}/samples/jev-bad-mirror/expected.yaml"
test -f "${here}/samples/README-jev.md"
grep -q 'export HERMES_EVAL_CHANGED_PATHS' "${kit}/scripts/eval-bars.sh"
grep -q 'jev_pack_quality_judge' "${here}/check.sh"
if awk '
  /make/ && /meta\/calibrate/ && !/grep/ && !/awk/ && !/printf/ && !/^[[:space:]]*#/ {
    exit 0
  }
  END { exit 1 }
' "${here}/check.sh"; then
  printf 'error: Tier2 must not call meta/calibrate\n' >&2
  exit 1
fi
exit 0
