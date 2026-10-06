---
schema: goal/v1
id: 20261002-local-eval-gates
title: Local pre-commit parses goal/v1; pre-push requires the post-run result
scope: universe
fixture_dir: evals/fixtures/universe/20261002-local-eval-gates
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

# Executive overview

CI already rejects goals missing `schema: goal/v1` and PRs missing
`<goal>-result.md`. Local pre-commit only soft-gates the pack (fixture +
pre-run goal) and never parses goal frontmatter, so authors learn those
failures only in eval-ci. This pack proves the kit catches schema on
pre-commit and the full pack (including result) on pre-push, while keeping
result out of the commit hook so two-commit authorship still works.

Write this before any run. Say what decision the result is allowed to support.

# Decision

A pass lets us say every recipe consumer’s product root lists a local
pre-push hook that runs `pre-push-evals.sh`, and that the kit’s
`pre-commit-evals.sh` parses staged goal markdown via `harness/goal.sh parse`
while soft pack mode still accepts fixture + goal without a result.

A pass does not prove `pre-commit install --hook-types pre-push` was run on
a given laptop, or that every historical goal already has `schema: goal/v1`.

This authoring run must not pass while the fixture baseline still lacks the
pre-push hook or while the kit lacks the local gate scripts/behavior.

# User outcome

An author who adds a goal without `schema: goal/v1` fails at `git commit`.
An author who ships behavior + fixture + goal but forgets the result fails at
`git push`, not only in eval-ci. The intermediate commit with fixture + goal
and no result still succeeds locally.

# Scope

| Covered | Not covered |
| --- | --- |
| `${HERMES_EVAL_SCAN_ROOT}/.pre-commit-config.yaml` includes `pre-push-evals.sh` | Live `pre-commit install` |
| Kit `pre-commit-evals.sh` invokes `goal.sh parse` on goal paths | Full `eval/select` on every commit |
| Kit `pre-push-evals.sh` runs pack gate `--mode ci` | Requiring result in `--mode pre-commit` |
| Soft pack still accepts fixture + goal without result | Rewriting legacy goals |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | Fixture has platform + evals-pre-commit only; `check.sh` exits non-zero |
| Consumer shape | After `golden.patch`, config references `pre-push-evals.sh`; `check.sh` exits 0 |
| Schema gate in kit | Kit `pre-commit-evals.sh` calls `goal.sh parse` (or shared assert) for goal paths |
| Pre-push entrypoint | Kit ships `scripts/pre-push-evals.sh` that invokes pack `--mode ci` |
| Soft pack preserved | Pack `--mode pre-commit` accepts fixture + goal without result |
| Hard pack on push path | Pack `--mode ci` rejects the same paths without a result |
| Bad schema fails parse | `goal.sh parse` on a goal missing `schema: goal/v1` exits non-zero |
| Nothing else breaks | `p2p-smoke.sh` stays green |

# Dataset

One fresh-product fixture (org pre-commit present, pre-push missing). Kit
behavior is graded against the resolved evals kit (`HERMES_EVAL_KIT`).
No train|test split; hold-out is deferred — fleet consumer backfills after
redistribute are the live check that config shape fails closed outside this
fixture.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Config + kit scripts + pack modes | Program (`check.sh`) | Directly visible in YAML/scripts and pack assert exit codes |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Did local gates land without requiring result at commit? | F2P fails before patch; F2P+P2P pass after; soft pack still green without result | Soft pack requires result, or checks wrong |

# Execution

`make eval/assert-red` then implement kit + golden, then `make eval/verify`.

# Limitations

Does not install hooks on developer machines. Does not rewrite every legacy
goal that lacks `schema: goal/v1` until that goal is touched. Does not run
full `eval/select` at commit time.

# Result file

After the run, write `<same-folder>/<same-name>-result.md` beside this goal.
Commit the result in a later local commit, not with this goal or its fixture.
