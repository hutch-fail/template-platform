# Executive outcome

Wrap-don't-rewrite is an org procedure: Cursor rule, host adapters, PROCESS.md,
and `docs/prior-art.md`. The OptMem pin is the instance of the rule.

# Result

**Recommendation:** Adopt

# Outcome

- Fixture baseline omits `wrap-prior-art.mdc` and the adapter listing; F2P is red.
- After golden, the rule is `alwaysApply` and forbids rewriting upstream source;
  the adapter lists `wrap-prior-art.mdc`.
- Live hub ships the rule, adapter entry, PROCESS pointer, and docs.

# Proof

```text
assert-red OK: F2P is red on baseline (check.sh exit 1)
verify OK: F2P+P2P green after golden.patch
```

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| `make eval/assert-red GOAL=universe/20261005-wrap-prior-art` | certified red | fixture `check.sh` | hermetic |
| `make eval/verify GOAL=universe/20261005-wrap-prior-art` | F2P+P2P green | `p2p-smoke.sh` | hermetic |

# Blocking findings

None.

# Comparison

| Question | What this run shows | Requirement | Result |
| --- | --- | --- | --- |
| Baseline red? | assert-red | F2P red | Met |
| Live wired? | p2p-smoke | rule + adapters + PROCESS + docs | Met |

# Evidence and limitations

Does not prove every laptop re-ran `install-host-adapters.sh`.

# Next action

Merge with the OptMem pack. Consumers pick up the rule on sync/pull + adapters.

# Manifest

`runs/20261005-wrap-prior-art/`

# Jev re-grade (2026-10-12)

`jev_pack_quality_judge.py` → pass (all six axes) after aligning User outcome + entrypoint effects with Success criteria.
