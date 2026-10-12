---
name: "kick-the-tires"
description: >-
  Completion verification for runtime claims: install, configure, hire, run,
  publish, demo, integrate, converge, MCP/editor bridges, or generated
  artifacts. Forbids structure-only proof from satisfying live-behavior claims.
  Trigger on closeout, "kick the tires", or before marking done when the ask
  was live behavior.
---

# kick-the-tires

Use before marking an issue `done` when the human ask includes runtime behavior.

## Do

1. Restate the **observable final state** from the PRD/acceptance criteria.
2. Run the smallest proportionate live proof (probe, `--version`/`which` for
   install claims, editor/MCP round-trip when claimed, demo render/build).
3. Surface evidence outside the transient workspace (git-tracked log/artifact +
   PR URL, or durable work product).
4. Record waivers for anything not run (owner + board/PM/SDET decision id).
5. If proof is missing and no waiver exists, set disposition `blocked` or
   `in_review` — never `done`.

## Do not

- Treat factory/IaC/examples/docs presence as live proof.
- Close `done` because a child issue or TODO was filed.
- Claim editor/MCP control from client CLI install alone.
- Weaken, skip, or rewrite evals to manufacture green.

## Related

- Eval procedure: `evals/PROCESS.md` § Kick-the-tires / structure-only disposition
- Grader: `evals/scripts/grade-structure-only-disposition.sh`
- Universe pack: `evals/goals/universe/20261009-kick-the-tires-structure-only.md`
