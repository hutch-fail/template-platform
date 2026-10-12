---
schema: result/v1
id: 20261006-pack-quality-pr-scope-readable-fail-result
goal_id: 20261006-pack-quality-pr-scope-readable-fail
status: pass
---

# Executive outcome

Tier-3 pack-quality no longer grades the historic archive on every PR. eval-bars
exports `HERMES_EVAL_CHANGED_PATHS`; the selector only emits those goal files
(or nothing). A fail prints file, axis, what it means, and how to pass — a
slogan is not enough for `adversarial_warning`.

# Result

**Recommendation:** Adopt

# Outcome

A harness-only PR cannot fail because `20261002-local-eval-gates` exists. A
cold reader of CI stderr can see how to pass without opening the rubric.

# Proof

```text
$ make eval/assert-red GOAL=universe/20261006-pack-quality-pr-scope-readable-fail
assert-red OK: F2P is red on baseline (check.sh exit 1)
verdict=certified_red
```

```text
$ make eval/verify GOAL=universe/20261006-pack-quality-pr-scope-readable-fail
pack_quality_pr_scope_contract_ok
meta_eval_pack_quality_ok … mode=all
verify OK: F2P+P2P green after golden.patch
```

```text
$ python3 harness/lib/llm_pack_quality_judge.py --format-fail \
    --path goals/universe/example.md --axis adversarial_warning
error: pack-quality LLM fail path=goals/universe/example.md
axis adversarial_warning: FAIL
what this means: The pack must state a specific reason a careful human …
how to pass: … A slogan-only line such as 'this pack is hard for humans' is not enough.
```

```text
$ python3 harness/lib/pack_quality_select.py --scan-root "$tmp" \
    --changed-paths 'goals/universe/pr-new.md'
…/goals/universe/pr-new.md
# historic.md not listed
```

```text
$ bash tests/unit/test_eval_bars.sh
✓ eval-bars family detection
```

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| `python3 harness/lib/llm_pack_quality_judge.py --format-fail …` | canned how-to-pass on stderr, slogan named | `check.sh` `run_pr_scope_contracts` | hermetic |
| `pack_quality_select.py` planted historic vs pr-new | historic omitted | same contract | hermetic |
| `HERMES_EVAL_DUMP_CHANGED_PATHS=1 bash scripts/eval-bars.sh goals/universe/pr-new.md` | prints that path | `test_eval_bars.sh` | hermetic |

# Blocking findings

None for the claimed scope. Live LiteLLM axis scores are still model-dependent
when `EVAL_LLM_MODEL` is set.

# Next action

Land this branch on `main`, then rebase OptMem PRs (#75 / #77) onto it.
