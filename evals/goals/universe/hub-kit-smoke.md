---
schema: goal/v1
id: hub-kit-smoke
scope: universe
title: Hub kit ships with an eval pack
fixture_dir: evals/fixtures/hub-kit-smoke
f2p_check: check.sh
solver: none
budgets:
  max_wall_seconds: 30
success:
  require_all_hard_checks: true
---

# Decision

A pass means this PR carried a fixture, a pre-run goal, and a result so the
eval-pack CI gate is satisfied. It does not measure agent behavior.

# User outcome

Reviewers see the pack beside the hub kit change.

# Scope

| Covered | Not covered |
| --- | --- |
| Presence of fixture + goal + result on the branch | Harness correctness, skill quality |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Pack present | `check.sh`, this goal, and sibling result on the PR |

# Dataset

# Grading

# Acceptance gates

Set before the run.

| Gate | Bar |
| --- | --- |
| Pack files | In the PR range |

# Execution

# Limitations

Bare-minimum appeasement pack for the hub kit PR.
