---
schema: goal/v1
id: 20261008-pack-quality-live-path-kick-tires
title: Tier-1 pack-quality rejects probe-script greps for Host URL claims
scope: universe
fixture_dir: evals/fixtures/universe/20260929-meta-eval-pack-quality
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
pack_quality: required
---

# Executive overview

We will stop eval packs from claiming operators get a working `*.localhost` /
dashboard / curl-health while F2P only greps that a probe script mentions curl.
Tier-1 pack-quality gains a live-path lint that prefers doctor/`test/smoke`/
`make up` wiring, with good-live/bad-live selftest samples and PROCESS guidance.
This extends the same ratchet family as use-path and launch-path.

# Decision

A pass lets us believe `make eval/bars` rejects probe-script-only Host URL packs
and accepts fixtures that assert smoke/doctor invoke the probe. A pass does not
migrate every legacy product pack or curl a personal Incus guest in CI.

# User outcome

Operators running pack-quality `check.sh` (selftest) see live-path lint accept
`good-live` and reject `bad-live` (probe-script-only Host URL claims). The
lint entrypoint is what grades the claim — not a personal Incus curl in CI.

# Scope

| Covered | Not covered |
| --- | --- |
| live-path lint + good-live/bad-live selftest | Rewriting every product pack in-tree |
| PROCESS / templates / goal-author / live-verify | CI curling a personal Incus guest |
| Result PASS guard when sibling result lacks live-proof | Soft LLM trajectory judges |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Selftest | `check.sh --selftest` / lint selftest: `good-live` passes; `bad-live` fails with `live-path` |
| Lint wired | `pack_quality_lint.py` invokes `_live_path_errors` on Host URL claim shapes |
| Docs/skills | PROCESS “Live path vs probe-script path”; templates + goal-author |
| Bars unit | `test_eval_bars.sh` requires good-live/bad-live samples |
| Nothing else breaks | Existing good/bad/desktop/use selftest still green |

# Dataset

Synthetic good-live / bad-live under the shared meta-eval-pack-quality fixture.
Hold-out contrast is the pair itself; historic product packs grandfather until
they opt into `# Executive overview` / `pack_quality:` and trip the claim regex.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Selftest / lint / docs | program (`check.sh` + unit) | File-visible + selftest |
| Bars unit | program (`test_eval_bars.sh`) | Manifested samples |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Selftest live-path? | good-live ok; bad-live live-path error | Either wrong |
| Guidance present? | PROCESS + template + live-verify mention doctor/test-smoke | Missing |

# Limitations

This pack grades the **hub live-path lint entrypoint** (selftest samples), not
that every author already rewrote product packs or that a guest dashboard
returns HTTP 2xx. Sync/subtree consumers pick up the hub lint on next
redistribute. Real Incus HTTP remains a product `make test/smoke` hold-out.
Hold-out for this ratchet is the bad-live wiring-only sample.

Use-path / ensure reconverge is out of scope — this pack ratchets Host URL
live-path lint only (sibling use-path pack owns kick-the-tires for ensure/seed).

A careful author can still escape with an honest Limitations line
(`live-path out of scope` / `hermetic wiring only`) — then they must not PASS
the Host URL claim.

# Result file

After the run, write `20261008-pack-quality-live-path-kick-tires-result.md`
beside this goal. Commit the result in a later local commit.
