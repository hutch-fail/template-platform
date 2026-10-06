---
schema: goal/v1
id: fixture-token-echo
scope: universe
title: Fixture echo emits FIXTURE_OK
fixture_dir: evals/fixtures/token-echo
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
budgets:
  max_wall_seconds: 60
success:
  require_all_hard_checks: true
---

# Decision

A pass lets us trust this fixture as a red-then-green harness check. It does not measure an agent.

# User outcome

A later agent test starts from a known broken script.

# Scope

| Covered | Not covered |
| --- | --- |
| The token-echo script and its golden patch | Agents, Graft, other tools |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | The script prints `WRONG_TOKEN` before the patch |
| The fix works | The script prints `FIXTURE_OK` after the patch |
| Nothing else breaks | The smoke check stays green |

# Dataset

One fixture script. No held-out cases.

# Grading

Program checks only. No second model.

# Acceptance gates

| Question | Pass | Fail |
| --- | --- | --- |
| Did the patch fix it? | Both checks pass after the patch, and the first check failed before it. | Either check is wrong. |

# Execution

`make eval/verify` applies `golden.patch`.

# Limitations

Do not weaken these checks. This goal does not test an agent.
