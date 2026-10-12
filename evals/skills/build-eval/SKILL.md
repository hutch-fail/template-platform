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
- Reimplementing a named upstream instead of pinning it and wrapping (see
  `docs/prior-art.md` and `.cursor/rules/wrap-prior-art.mdc`)
- Behavior / operator-use claims graded only by wiring greps (`grep -Fq` the
  symbol) with no kick-the-tires exercise (`PROCESS.md` “Use path vs wiring
  path”; Tier-1 use-path lint)

## Steps

1. **Interview** — What decision should a pass support? Who is the user? What
   must stay unproven (Limitations)? Ask: how would an operator **kick the
   tires** on day 1 and on reconverge (`make ensure`)? That path belongs in
   Success criteria + `check.sh`, or Limitations owns “wiring-only /
   single-shot only.”
2. **Sample order** — Prefer production traces → real bugs → hand-written →
   synthetic. Name hold-out / train|test in Dataset (or Limitations owns the gap).
3. **Cheapest grader** — program (`check.sh`) → person → Jev (`meta/`) →
   LiteLLM pack-quality last (`EVAL_LLM_*` / `OPENAI_*` + `EVAL_LLM_MODEL`).
   Prefer a hermetic **exercise** (call the entrypoint twice when reconverge
   matters) over a grep of the implementing file.
4. **Write the pre-run report** — Copy `templates/goal.md`. Lead with
   **# Executive overview** (3–6 sentences a non-author can skim). Fill Decision,
   User outcome, Success criteria, Dataset, Grading, Acceptance gates.
5. **Human approve** — Show example tasks and the grader sketch before coding
   the fixture.
6. **Baseline + assert-red** — Fixture must fail on committed baseline:
   `make eval/assert-red GOAL=…` until certified red.
7. **Meta ratchet preflight** — When keys allow, run Tier1 lint
   (`harness/lib/pack_quality_lint.py`), Tier2 Jev pack-quality on changed
   goals (`harness/lib/jev_pack_quality_judge.py`; sample selftest only when
   judge/samples change — not toy `meta/calibrate`), Tier3
   `harness/lib/llm_pack_quality_judge.py` on **goal files this PR adds or
   changes** (`HERMES_EVAL_CHANGED_PATHS`). Missing keys: skip under
   `PRE_COMMIT=1` / fixture mode; fail closed in CI bars. A Tier-3 fail prints
   canned `what this means` / `how to pass` per axis — a slogan (“hard for
   humans”) is not enough for `adversarial_warning`.

## Outputs

- Goal markdown (executive voice) + fixture (`check.sh`, optional `golden.patch`)
- assert-red manifest path
- Notes on which grader tier was chosen and why

## Related

- Next: **goal-develop** or **hillclimb**
- Orchestrator: **meta-dev**
- Docs: `docs/meta-eval-quality.md`
