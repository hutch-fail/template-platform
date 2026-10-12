---
schema: goal/v1
id: 20261006-pack-quality-pr-scope-readable-fail
title: Pack-quality LLM judge is PR-scoped and fails with a how-to-pass
scope: universe
fixture_dir: evals/fixtures/universe/20260929-meta-eval-pack-quality
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
pack_quality: required
---

# Executive overview

We will stop the universe LiteLLM pack-quality judge from grading every
historic goal that opted into `# Executive overview`. A green result means CI
only judges goal markdown added or modified on the PR, and a fail names the
file, the failed axis, what that axis means, and how to pass — without asking
the author to decode a one-line model note. The check is a program contract
(path filter + canned stderr). It does not need a live model call.

# Decision

A pass lets us believe that `make eval/bars` on a pull request will not fail
because an untouched historic pack lacked a slogan, and that a Tier-3 fail is
readable without opening the rubric source. A pass does not let us believe
every legacy pack is high quality, that axis scores from the model are
calibrated, or that a bolted “hard for humans” sentence is enough.

This authoring run must not pass while the kit still tree-scans Tier 3 or
prints only JSON `notes` on fail.

# User outcome

Authors changing a harness file (or one new goal) see only those packs judged.
When axis 4 fails, they get a specific missing claim and an example fix, not
`Lacks explicit justification that the task is hard for humans/adversarial`.

# Scope

| Covered | Not covered |
| --- | --- |
| HERMES_EVAL_CHANGED_PATHS filter for Tier3 (and changed-path lint when set) | Dropping Tier3 or axis 4 |
| Code-owned how-to-pass stderr for each failed axis | Soft product trajectory LLM judges |
| adversarial_warning requires a specific human-easy-to-get-wrong reason | Rewriting historic packs |
| Fixture F2P still scans the demo pack (ignore path env) | Merging OptMem demo |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Changed-path filter | `pack_quality_select.py` with HERMES_EVAL_CHANGED_PATHS listing only a new goal does not emit a planted historic goal |
| No changed goals | Selector with an empty changed list (non-fixture) emits no tree-wide goals |
| Canned fail text | `llm_pack_quality_judge.py --format-fail` prints path, axis, `what this means`, `how to pass`, and that a slogan is not enough for adversarial_warning |
| eval-bars export | `eval-bars.sh` with a path argv exports HERMES_EVAL_CHANGED_PATHS containing that path |
| Fixture still self-contained | PACK_QUALITY_FIXTURE scan ignores changed-path env (demo pack still linted) |

# Dataset

Train: this fixture’s thin demo pack (existing F2P) plus planted historic vs
PR-new markdown in a throwaway directory. Hold-out: real hub goals such as
`goals/universe/20261002-local-eval-gates.md` are not rewritten; they must
simply stop blocking unrelated PRs. No live LiteLLM call in the contract.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Changed-path filter / empty list | program (`check.sh` → pack_quality_select.py) | File lists, no model |
| Canned fail text | program (`--format-fail`) | Stderr shape |
| eval-bars export | program (`test_eval_bars.sh` / check.sh probe) | Env after argv |
| Fixture ignore env | program (check.sh under PACK_QUALITY_FIXTURE) | Demo pack still checked |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Assert-red then verify? | Certified red on baseline kit; verify green after implement + golden | Already green, or still tree-scanning |
| Unrelated PR blocked by historic pack? | No — historic not in selector output | Historic still listed |
| Fail readable? | how-to-pass present without reading Success criteria of the judged pack | Only model `notes` |

# Execution

One authoring pass on `feat/pack-quality-pr-scope` from `origin/main`. No live
LLM required for the contract. `PRE_COMMIT=1` still skips Tier2/3 keys.

# Limitations

Does not prove the hosted LiteLLM model will score axis 4 the same as a human.
Does not migrate legacy packs. A slogan-only Limitations line is still a fail
on axis 4 by design: a careful human can paste that line while leaving the
judge scanning files the PR never touched, which is the easy-to-get-wrong
failure this pack is for.

# Result file

After the run, write `20261006-pack-quality-pr-scope-readable-fail-result.md`
beside this goal. Commit the result in a later local commit, not with this
goal or its fixture.
