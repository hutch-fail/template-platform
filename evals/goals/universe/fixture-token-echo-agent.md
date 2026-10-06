---
schema: goal/v1
id: fixture-token-echo-agent
scope: universe
title: Agent solver flips token-echo SUT (TB2a)
fixture_dir: evals/fixtures/token-echo
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: agent
solver_bin: evals/fixtures/token-echo/mock-solver.sh
solver_prompt: evals/fixtures/token-echo/solver-prompt.md
max_wall_seconds: 60
---

# Decision

A pass lets us say a solver can fix this one script without changing the checks. A mock solver does not measure a live model.

# User outcome

The script prints the expected token after the solver runs.

# Scope

| Covered | Not covered |
| --- | --- |
| The token-echo script and the configured solver | Graft, Promptfoo, Inspect, a quality model |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | The script prints `WRONG_TOKEN` before the solver |
| The fix works | The script prints `FIXTURE_OK` after the solver |
| Nothing else breaks | The smoke check stays green |

# Dataset

One fixture script. Default solver is a mock with no network.

# Grading

Program checks only. No second model grades the writing.

# Acceptance gates

| Question | Pass | Fail |
| --- | --- | --- |
| Did the solver fix it? | Both checks pass after the solver, and the first check failed before it. | Either check is wrong. |

# Execution

`make eval/solve` runs `solver_bin`. Override with `HERMES_EVAL_SOLVER_BIN`. Wall limit 60 seconds.

# Limitations

Do not weaken these checks. A mock pass is not a live-model result.
