---
schema: goal/v1
id: 20260929-pre-commit-platform
title: Recipe consumers must include org pre-commit (platform + evals-pre-commit)
scope: universe
fixture_dir: evals/fixtures/universe/20260929-pre-commit-platform
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

Write this before any run. Say what decision the result is allowed to support.

# Decision

A pass lets us say every recipe consumer’s product root has a
`.pre-commit-config.yaml` that pins `hutch-fail/pre-commit` with `id: platform`
and a local hook whose entry runs `pre-commit-evals.sh` (product path
`evals/scripts/…` or hub path `scripts/…`).

A pass does not prove hooks are installed (`pre-commit install`), that the
pinned `rev:` is current, or that every future CI/CD guideline is present —
those land as additional **universe** bars on the same rail.

This authoring run must not pass while the fixture baseline still lacks the
org pre-commit shape.

# User outcome

A developer opts a new repository into evals. On the next PR, `make eval/bars`
(eval-ci / pre-commit) fails closed until they backfill the canonical org
pre-commit config. Later CI/CD guidelines follow the same universe →
redistribute → next-PR-fails-until-backfill loop.

# Scope

| Covered | Not covered |
| --- | --- |
| `${HERMES_EVAL_SCAN_ROOT}/.pre-commit-config.yaml` | Nested fixtures under `fixtures/` |
| Require `id: platform` from `hutch-fail/pre-commit` | Live `pre-commit install` / hook execution |
| Require entry invoking `pre-commit-evals.sh` | Pin freshness / suite contents inside `platform` |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | Fixture has evals kit marker but no org pre-commit config; `check.sh` exits non-zero |
| The fix works | After `golden.patch`, platform + evals-pre-commit present; `check.sh` exits 0 |
| Nothing else breaks | `p2p-smoke.sh` stays green |

# Dataset

One fresh-product fixture (opted into evals, missing pre-commit). Product
pre-commit and eval-ci scan the caller tree the same way
(`HERMES_EVAL_SCAN_ROOT`).

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Org pre-commit shape | Program (`check.sh`) | Directly visible in YAML |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Did the patch add org pre-commit? | F2P fails before patch; F2P+P2P pass after | Either check wrong |

# Execution

`make eval/assert-red` then wire shared `eval/bars` (universe always-on), then
`make eval/verify`.

# Limitations

Does not install hooks or run the `platform` suite. Does not invent product CI
files beyond what the golden documents.

# Result file

After the run, write `20260929-pre-commit-platform-result.md` beside this goal.
Commit the result in a later local commit, not with this goal or its fixture.
Both commits may be in one pull request. Squash or merge may combine them.
