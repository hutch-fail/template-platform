# Executive outcome

Adopt the Tier2 rewrite: Jev holistic pack-quality on changed goals, with
path-triggered `jev-*` sample selftest. Toy `meta/calibrate` is no longer
consumer fail-closed Tier2.

# Result

**Recommendation:** Adopt

# Outcome

- Universe bar `goals/universe/20260929-meta-eval-quality-ratchet.md` updated for
  Jev-on-changed-goals + demoted calibrate.
- Fixture `check.sh` Tier2 wires `jev_pack_quality_judge`; path-gate unit proves
  product-only changes skip sample selftest; judge/sample/`check.sh` changes run it.
- Labeled samples `jev-good` / `jev-bad-mirror` / `jev-bad-ambiguity` agree with
  live TypeSafe selftest (3/3).

# Proof

```text
$ bash tests/unit/test_eval_bars.sh
✓ eval-bars family detection

$ HERMES_EVAL_PROBE_JEV_SELFTEST_GATE=1 \
    HERMES_EVAL_CHANGED_PATHS='goals/universe/pr-new.md' \
    bash fixtures/universe/20260929-meta-eval-pack-quality/check.sh
jev_selftest_gate=skip

$ HERMES_EVAL_PROBE_JEV_SELFTEST_GATE=1 \
    HERMES_EVAL_CHANGED_PATHS='harness/lib/jev_pack_quality_judge.py' \
    bash fixtures/universe/20260929-meta-eval-pack-quality/check.sh
jev_selftest_gate=run

$ # F2P: baseline red, golden green + p2p
assert-red OK (thin demo fails Tier1); after golden.patch check + p2p-smoke exit 0

$ make meta/pack-judge-selftest
jev_pack_judge_selftest: 3/3 agree (errors=0)
```

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| `tests/unit/test_eval_bars.sh` | exit 0; path-gate + no calibrate | same unit in eval-ci | hermetic |
| F2P tempdir + `golden.patch` | baseline fail; check + p2p green | fixture check / p2p-smoke | hermetic |
| `make meta/pack-judge-selftest` | 3/3 agree | Tier2 path-triggered selftest | live-proof |

# Blocking findings

None.

# Comparison

| Question | What this run shows | Requirement | Result |
| --- | --- | --- | --- |
| Tier2 no longer calls calibrate? | `check.sh` awk gate + unit | No live make meta/calibrate | Met |
| Path-gate? | probe skip vs run | Product-only skip; judge change run | Met |
| Jev samples? | live selftest 3/3 | expected.yaml agree | Met |
| F2P? | baseline fail; golden pass | red then green | Met |

# Evidence and limitations

Hermetic unit/F2P plus one live TypeSafe selftest on the author machine and CI
eval-ci head. Does not prove every consumer pin has bumped yet — pin follow-up
is out of this hub PR.

# Next action

Merge hub; bump evals pin in consumer repos so product PRs get Jev Tier2.
