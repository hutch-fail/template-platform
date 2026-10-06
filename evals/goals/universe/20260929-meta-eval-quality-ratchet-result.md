---
schema: result/v1
id: 20260929-meta-eval-quality-ratchet-result
goal_id: 20260929-meta-eval-quality-ratchet
status: pass
---

# Executive outcome

The universe pack-quality ratchet is live: Tier-1 deterministic lint (with
good/bad selftest) always runs on `make eval/bars`, Tier-2 Jev calibrate and
Tier-3 LiteLLM pack rubric follow the PRE_COMMIT / CI key-gate contract, and
`build-eval` / `hillclimb` skills plus executive templates are in the hub.
Soft LLM product judges in goal-judge stay deferred.

# Result

**Recommendation:** Adopt

# Outcome

Hub bars and this goal’s F2P/P2P path are green. New packs that opt into
`# Executive overview` or `pack_quality: required` get fail-closed structure
checks; legacy packs remain grandfathered until they opt in.

# Proof

```text
$ HERMES_EVAL_KIT=$PWD make eval/assert-red GOAL=universe/20260929-meta-eval-quality-ratchet
assert-red OK: F2P is red on baseline (check.sh exit 1)
verdict=certified_red
```

```text
$ HERMES_EVAL_KIT=$PWD make eval/verify GOAL=universe/20260929-meta-eval-quality-ratchet
pack_quality_selftest_good_ok
pack_quality_selftest_bad_ok n_errors=9
pack_quality_ok path=…/goals/demo/thin-pack.md
meta_eval_pack_quality_ok … mode=all
verify OK: F2P+P2P green after golden.patch
```

```text
$ HERMES_EVAL_KIT=$PWD HERMES_EVAL_SCAN_ROOT=$PWD PRE_COMMIT=1 make eval/bars
pack_quality_ok path=…/goals/universe/20260929-meta-eval-quality-ratchet.md
meta_eval_tier2_skip reason=no_TYPESAFE_API_KEY …
meta_eval_tier3_skip reason=no_EVAL_LLM_key_or_model …
meta_eval_pack_quality_ok … mode=opt-in
```

```text
$ bash tests/unit/test_eval_bars.sh && bash tests/unit/test_meta_dev_skills.sh
✓ eval-bars family detection
✓ meta-dev skills
```

# Blocking findings

None for the claimed scope. Live TypeSafe / LiteLLM authenticity still depends
on keys in CI.

# Next action

Land goal+fixture first; commit this result in a later local commit. Pass
`TYPESAFE_API_KEY` and `EVAL_LLM_*` + `EVAL_LLM_MODEL` into eval-ci when Tier2/3
should run fail-closed in CI.
