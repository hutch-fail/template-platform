---
schema: goal/v1
id: 20260929-meta-eval-quality-ratchet
title: Universal three-tier eval pack-quality ratchet (deterministic → Jev → LiteLLM)
scope: universe
fixture_dir: evals/fixtures/universe/20260929-meta-eval-pack-quality
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
pack_quality: required
---

# Executive overview

We are putting a universal quality bar on every eval pack this hub ships: the
goal must read like an executive brief, the fixture must be checkable, and
optional Jev/LiteLLM tiers must fail closed in CI when keys are configured for
bars. This pack proves the ratchet itself—starting red on a thin demo goal,
going green after the golden shape—without turning on soft LLM judges for
product agent trajectories.

# Decision

A pass lets us say `make eval/bars` always runs Tier-1 deterministic pack-quality
lint (selftest good/bad + opt-in/executive packs), Tier-2 `meta/calibrate` when
`TYPESAFE_API_KEY` is set (skip under `PRE_COMMIT=1` / fixture mode when unset),
and Tier-3 LiteLLM pack rubric when `EVAL_LLM_*`/`OPENAI_*` plus `EVAL_LLM_MODEL`
are set (same skip contract). Skills `build-eval` and `hillclimb` exist for the
Claude-inspired authoring/optimize loop, and templates lead with executive
narrative plus proof snippets in results.

A pass does not let us claim soft trajectory LLM rubrics inside `goal-judge`,
nor that every legacy goal already meets the executive opt-in bar.

This authoring run must not pass while the fixture demo pack is still thin.

# User outcome

Authors get atomic skills to build and hillclimb evals. Reviewers and executives
skim a goal before the run and a result with proof after. CI fails closed when
new packs skip structure, holdout discipline, or (when keys are present) Jev /
LiteLLM pack-quality gates.

# Scope

| Covered | Not covered |
| --- | --- |
| Universe Tier1 lint + selftest samples | Soft LLM product trajectory judges |
| Tier2 meta/calibrate key-gate | Migrating all legacy goals to executive opt-in |
| Tier3 LiteLLM pack rubric key+model gate | Anthropic proprietary claude-api skill internals |
| build-eval + hillclimb skills + templates | Installing agent tools without green verdict |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | Fixture demo pack fails Tier1; `check.sh` exits non-zero |
| The fix works | After `golden.patch`, demo pack + selftest green; `check.sh` exits 0 |
| Bars wired | `run_universe_bars` invokes this check |
| Tier2/3 contract | Missing keys skip under PRE_COMMIT/fixture; fail closed otherwise |
| Skills + docs | build-eval, hillclimb, templates, meta-dev/goal-author/goal-judge updated |
| Nothing else breaks | `p2p-smoke.sh` stays green |

# Dataset

Synthetic good/bad samples under the fixture plus one demo pack (thin → golden).
Good/bad selftest is the hold-out contrast for the linter; demo pack is the F2P
train case. Hub goals without `# Executive overview` / `pack_quality:` remain
grandfathered until they opt in.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Starts broken / fix works | program (`check.sh`) | Direct fixture scan |
| Bars wired | program (`test_eval_bars.sh` + grep) | Manifested in eval-bars.sh |
| Tier2/3 contract | program (unit + check branches) | Env matrix without secrets |
| Skills + docs | program (unit skill contracts) | Files and references |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Assert-red then verify? | Certified red; verify green after golden | Either wrong |
| eval/bars on hub? | Tier1 ok; Tier2/3 skip or pass with keys | Silent skip in CI without PRE_COMMIT |
| Soft judges still deferred? | goal-judge unit still says out of scope | Soft LLM required for product judge |

# Execution

`make eval/assert-red GOAL=universe/20260929-meta-eval-quality-ratchet`, implement
bar + skills, then `make eval/verify` and `make eval/bars` (use `PRE_COMMIT=1`
locally when TypeSafe/LiteLLM keys are unset).

# Limitations

Does not prove live TypeSafe or LiteLLM authenticity beyond what keys allow in
the environment. Does not rewrite legacy packs. Does not enable soft LLM
rubrics in goal-judge.

# Result file

After the run, write `20260929-meta-eval-quality-ratchet-result.md` beside this
goal with executive outcome and proof snippets. Commit the result in a later
local commit, not with this goal or its fixture. Both commits may be in one
pull request. Squash or merge may combine them.
