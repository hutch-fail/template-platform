---
schema: goal/v1
id: 20261007-pack-quality-use-path-kick-tires
title: Tier-1 pack-quality rejects wiring-only greps for operator-use claims
scope: universe
fixture_dir: evals/fixtures/universe/20260929-meta-eval-pack-quality
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
pack_quality: required
---

# Executive overview

We will stop eval packs from claiming operators use ensure/heal/reconcile/seed/
mirror/bind while F2P only greps that the symbol exists. Tier-1 pack-quality
gains a use-path (kick-the-tires) lint with good-use/bad-use selftest samples,
PROCESS/template/skill guidance, and a re-entry cue so day-2 reconverge is not
silently ungraded. This extends the same ratchet family as launch-path.

# Decision

A pass lets us believe `make eval/bars` rejects wiring-only behavior packs and
accepts fixtures that exercise the entrypoint (and re-enter unless Limitations
say single-shot). A pass does not migrate every legacy product pack, prove live
Incus mounts, or enable soft trajectory judges.

This authoring run must not pass while use-path samples or lint are missing.

# User outcome

Authors writing ensure/seed/bind goals get a forced kick-the-tires shape.
Reviewers stop greenlighting “module exists” as “feature works.” The invent
symlink re-ensure miss class is caught in hermetic F2P when the pack claims
ensure without a second pass.

# Scope

| Covered | Not covered |
| --- | --- |
| use-path lint + good-use/bad-use selftest | Rewriting every product pack in-tree |
| PROCESS / templates / build-eval / goal-author | Live Paperclip skills/sync HTTP |
| Re-entry cue for ensure/seed-class exercise | Soft LLM trajectory judges |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Selftest | `good-use` passes; `bad-use` fails with `use-path` |
| Lint wired | `pack_quality_lint.py` calls `_use_path_errors` |
| Docs/skills | PROCESS “Use path vs wiring path”; templates + build-eval refuse grep-only |
| Bars unit | `test_eval_bars.sh` requires good-use/bad-use samples |
| Nothing else breaks | Existing good/bad/desktop selftest still green |

# Dataset

Synthetic good-use / bad-use under the shared meta-eval-pack-quality fixture.
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
| Selftest use-path? | good-use ok; bad-use use-path error | Either wrong |
| Guidance present? | PROCESS + template + build-eval mention kick-the-tires | Missing |

# Limitations

Does not prove every product pack already exercises reconverge. Sync/subtree
consumers pick up the hub lint on next redistribute. Live HTTP `skills/sync`
occupancy remains a product hold-out. Hold-out for this ratchet is the bad-use
wiring-only sample.

A careful author can still escape with an honest Limitations line
(`wiring-only grades` / `reconverge out of scope`) — that is intentional, not
a silent miss.

# Result file

After the run, write `20261007-pack-quality-use-path-kick-tires-result.md`
beside this goal. Commit the result in a later local commit.
