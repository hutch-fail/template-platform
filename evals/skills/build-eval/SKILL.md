---
name: build-eval
description: >-
  Design a new eval pack (interview → samples → cheapest grader → assert-red).
  Trigger on "build an eval", "design F2P", or from meta-dev / goal-author.
  Emits executive-voice goal+fixture; does not implement the product fix.
---

# build-eval

Atomic process skill for **authoring** eval packs. Compose under **meta-dev** /
**goal-author**. Inspired by Claude’s eval-design loop; mapped onto this hub’s
F2P/P2P + Dataset holdouts + Grading tables—not a copy of proprietary skills.

## Refuse

- Shipping a goal that is only frontmatter + empty tables
- Skipping `make eval/assert-red`
- Jumping to LiteLLM graders when a program check would suffice
- Soft LLM product trajectory judges (still deferred in **goal-judge**)

## Steps

1. **Interview** — What decision should a pass support? Who is the user? What
   must stay unproven (Limitations)?
2. **Sample order** — Prefer production traces → real bugs → hand-written →
   synthetic. Name hold-out / train|test in Dataset (or Limitations owns the gap).
3. **Cheapest grader** — program (`check.sh`) → person → Jev (`meta/`) →
   LiteLLM pack-quality last (`EVAL_LLM_*` / `OPENAI_*` + `EVAL_LLM_MODEL`).
4. **Write the pre-run report** — Copy `templates/goal.md`. Lead with
   **# Executive overview** (3–6 sentences a non-author can skim). Fill Decision,
   User outcome, Success criteria, Dataset, Grading, Acceptance gates.
5. **Human approve** — Show example tasks and the grader sketch before coding
   the fixture.
6. **Baseline + assert-red** — Fixture must fail on committed baseline:
   `make eval/assert-red GOAL=…` until certified red.
7. **Meta ratchet preflight** — When keys allow, run Tier1 lint
   (`harness/lib/pack_quality_lint.py`), Tier2 `make meta/calibrate`, Tier3
   `harness/lib/llm_pack_quality_judge.py` on the new goal. Missing keys: skip
   under `PRE_COMMIT=1` / fixture mode; fail closed in CI bars.

## Outputs

- Goal markdown (executive voice) + fixture (`check.sh`, optional `golden.patch`)
- assert-red manifest path
- Notes on which grader tier was chosen and why

## Related

- Next: **goal-develop** or **hillclimb**
- Orchestrator: **meta-dev**
- Docs: `docs/meta-eval-quality.md`
