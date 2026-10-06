---
schema: result/v1
id: 20261002-local-eval-gates-result
goal_id: 20261002-local-eval-gates
status: pass
---

# Executive outcome

Local evals gates now catch missing `schema: goal/v1` at commit and missing
`<goal>-result.md` at push, without forcing the result into the same commit
as the goal/fixture.

# Result

**Recommendation:** Adopt

# Outcome

`pre-commit-evals.sh` runs soft pack + `assert_goals_schema` (`goal.sh parse`).
`pre-push-evals.sh` runs pack `--mode ci`. Universe bar
`20261002-local-eval-gates` fails closed until consumer configs list
`pre-push-evals.sh` and `default_install_hook_types` includes `pre-push`.

# Proof

```text
make eval/assert-red GOAL=universe/20261002-local-eval-gates
# assert-red OK: F2P is red on baseline (check.sh exit 1)

make eval/verify GOAL=universe/20261002-local-eval-gates
# verify OK: F2P+P2P green after golden.patch

bash tests/unit/assert_goals_schema.sh   # ✓ goal schema gate
bash tests/unit/assert_pr_has_eval_pack.sh  # ✓ eval pack gate
bash tests/unit/test_eval_bars.sh        # ✓ eval-bars family detection
```

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| `make eval/assert-red` / `eval/verify` | Red then green after golden | `fixtures/universe/20261002-local-eval-gates/check.sh` | hermetic |
| `bash tests/unit/assert_goals_schema.sh` | Good parse / bad schema fail | same unit self-test | hermetic |
| None — no live `git push` hook install exercised | — | Universe bar only asserts config shape (same limitation as platform bar) | none |

# Blocking findings

None.

# Comparison

Before: schema only via CI `eval/select`; result only via CI pack mode.
After: schema on pre-commit; result on pre-push; soft pack unchanged.

# Evidence and limitations

Does not prove every laptop ran `pre-commit install --hook-types pre-push`.
Fleet consumers must backfill root `.pre-commit-config.yaml` after kit sync.

# Next action

Redistribute kit; backfill `evals-pre-push` on consumers (starting with
service-meter); open hub PR.

# Manual verification

None — kit redistribute from hub 518db3f; eval-ci and pre-commit bars are the covering automated checks.
