---
name: goal-solve
description: >-
  Run TB2a agent-solver evals: assert-red then make eval/solve. Trigger on
  "solve goal", "agent solver", or when a goal has solver: agent. Uses coding
  agent CLIs or mock-solver — not harness API keys.
---

# goal-solve

Drive the **agent solver** path for goals with `solver: agent`.

## Steps

1. Confirm frontmatter: `solver: agent`, `solver_bin`, `solver_prompt`
2. Certify baseline still red:

```bash
make eval/assert-red GOAL=<id>
```

3. Run solver + hard checks:

```bash
make eval/solve GOAL=<id>
# live CLI example:
# HERMES_EVAL_SOLVER_BIN=claude make eval/solve GOAL=<id>
```

4. Hand off to **goal-judge** / `make eval/report` for the manifest.

## Notes

- Hard success = F2P + P2P only (no soft rubrics).
- Deterministic CI uses `solver_bin` pointing at a mock `.sh` (see
  `fixture-token-echo-agent`).
- Soft LLM judges and Graft/Promptfoo are out of scope.

## Related

- Prior: **goal-author**
- Alternate develop: **goal-develop** (human/impl without solver)
- Next: **goal-judge**
- Orchestrator: **meta-dev**
