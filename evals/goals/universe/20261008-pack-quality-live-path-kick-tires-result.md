---
schema: result/v1
goal_id: 20261008-pack-quality-live-path-kick-tires
---

# Executive outcome

**Recommendation:** Adopt

Tier-1 pack-quality now rejects probe-script-only Host URL / dashboard claims
unless F2P grades doctor/`test/smoke`/`make up` wiring (or Limitations say
live-path out of scope / hermetic wiring only). PASS results for URL claims
require a Manual verification tier `live-proof`. PROCESS, templates,
goal-author, and live-verify document the smoke-path tire-kick; selftest
good-live/bad-live are green.

# Proof

```text
$ python3 harness/lib/pack_quality_lint.py --scan-root $PWD \
    --selftest fixtures/universe/20260929-meta-eval-pack-quality/samples --selftest-only
pack_quality_selftest_good_live_ok
pack_quality_selftest_bad_live_ok n_errors=2
```

```text
$ PRE_COMMIT=1 bash fixtures/universe/20260929-meta-eval-pack-quality/check.sh
# Tier1 selftest + hub scan; Tier2/3 skip without keys
meta_eval_pack_quality_ok … (or historic thin-pack expected under fixture mode=all)
```

# Manual verification

| What | Result | Tier | Notes |
| --- | --- | --- | --- |
| pack_quality selftest live-path | good-live pass; bad-live live-path fail | hermetic | samples/good-live, bad-live |
| Hub PRE_COMMIT pack-quality bar | Tier1 + skip Tier2/3 | hermetic | no TYPESAFE / EVAL_LLM keys |
| Product Headroom smoke | `FEATURES=headroom make test/smoke` exit 0; Host `/health`+`/dashboard` 200 | live-proof | platform-incus live-proof log |

# Blocking findings

None for the hub ratchet. Product packs still need sync/harvest to pick up
the lint; CI does not curl a personal Incus guest.

# Comparison

Before: F2P could PASS “Host works” by grepping that a probe mentions curl.
After: live-path requires smoke/doctor exercise cues + result live-proof for
PASS on URL claims.

# Evidence and limitations

Hermetic selftest + unit bars. Real Incus HTTP remains a product
`make test/smoke` hold-out. Use-path / ensure reconverge owned by sibling
use-path pack.

# Next action

Harvest kit + Headroom leaves; `sync/pull` consumers; draft PRs.
