# Result

**Recommendation:** Adopt

Hub pack gate requires before/after screenshots (or `UI before/after: n/a — <reason>`)
in the PR description when the diff touches UI/UX paths. Wired via
`EVALS_PR_BODY` on eval-ci / eval-pack-gate; hermetic self-test green.

# Outcome

UI/UX-touching PRs fail closed in CI without visual evidence in the description;
local assert without `EVALS_PR_BODY` skips the screenshot gate.

# Blocking findings

None for the hub bar. Fleet redistribute / consumer hub pin bumps remain
follow-up.

# Evidence

- assert-red: F2P red on baseline (`notes.txt` unpatched)
- verify: F2P+P2P green after `golden.patch`
- `bash tests/unit/assert_pr_has_eval_pack.sh` → `✓ eval pack gate`
- RFV: bash-budget fail on fat `eval-ci.yml` run blocks + fixture shell →
  extracted `ci-eval-select-prepare.sh` / `ci-detect-node-bars.sh` +
  `verify_wiring.py`; removed F2P fixture from `run_ui_bars` (verify-only)

# Next action

Land hub PR; consumers pick up on next evals sync / pin bump. Authors of
UI/UX PRs include before/after images (or the n/a waiver) in the description.

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| `make eval/assert-red` + `make eval/verify` for this goal; assert self-test | certified_red then verify OK; `✓ eval pack gate` | this fixture `check.sh` + pack-gate self-test | hermetic |
