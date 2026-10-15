---
schema: result/v1
id: 20261014-bash-budget-result
goal_id: 20261014-bash-budget
status: pass
---

# Executive outcome

Changed GitHub Actions YAML and eval `check.sh` files are now gated by a bash
budget (~12 consecutive content lines; YAML inline bash ≤35% of the file).
Historic fat files are not rewritten; CI enforces the budget on PR-scoped paths.
Authors get a named-file refactor hint on stderr.

# Result

**Recommendation:** Adopt

# Outcome

`make eval/assert-red` certifies the fat baseline red; `make eval/verify` is
green after `golden.patch`. Selftest samples agree. Without
`HERMES_EVAL_CHANGED_PATHS`, live scan skips after selftest.

# Proof

```text
$ make eval/assert-red GOAL=universe/20261014-bash-budget
assert-red OK: F2P is red on baseline (check.sh exit 1)
… run: block has 15 consecutive content lines … (max 12)
```

```text
$ make eval/verify GOAL=universe/20261014-bash-budget
bash_budget_ok files=3
verify OK: F2P+P2P green after golden.patch
```

```text
$ python3 harness/lib/bash_budget_lint.py --selftest \
    fixtures/universe/20261014-bash-budget/samples
bash_budget_selftest: 4/4 agree (errors=0)
```

# Manual verification

| Tier | Command / evidence | Result |
| --- | --- | --- |
| hermetic | assert-red → certified_red on fat `sample.yml` | Met |
| hermetic | verify → green after golden | Met |
| hermetic | selftest 4/4 agree | Met |
| hermetic | no `HERMES_EVAL_CHANGED_PATHS` → `bash_budget_skip` after selftest | Met |
