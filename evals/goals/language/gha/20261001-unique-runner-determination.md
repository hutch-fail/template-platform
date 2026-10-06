---
schema: goal/v1
id: 20261001-unique-runner-determination
title: Unique runner-determination concurrency groups
scope: language
languages: gha
fixture_dir: evals/fixtures/language/gha/20261001-unique-runner-determination
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

# Decision

A pass lets us claim Blacksmith `determine-runner` jobs no longer share a bare
`group: runner-determination` concurrency group (siblings cancelled across
workflows on busy PR opens). Groups are scoped per workflow+job like
machine-layers.

# User outcome

Editing `.github/workflows/**` does not reintroduce a shared concurrency group
that cancels sibling determine-runner jobs.

# Scope

| Covered | Not covered |
| --- | --- |
| Bare `group: runner-determination` under product `.github/workflows` | Other concurrency names; cancel-in-progress policy; non-Blacksmith runners |
| Prefer unique `runner-determination-${{ github.workflow }}-${{ github.job }}` | Hub pin bumps for thin callers |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | Fixture ships bare `group: runner-determination`; check exits non-zero |
| Patch repairs | Apply `golden.patch` → check exits 0 |
| Thin callers | No workflows or no bare group → pass |

# Result file

Write `20261001-unique-runner-determination-result.md` beside this goal after the run.
