---
name: hillclimb
description: >-
  Optimize eval performance or cost-at-parity with train/test discipline.
  Trigger on "hillclimb", "optimize the eval", or after build-eval when
  iterating patches. Finishes with executive result + proof snippets.
---

# hillclimb

Atomic process skill for **iterating** after a certified-red pack exists.
Compose under **meta-dev** / **goal-judge**. One attributable change per round.

## Refuse

- Pasting raw failure transcripts into prompts (contamination)
- Multiple unrelated patches in one round
- Declaring Adopt without a sibling `<goal>-result.md` that includes proof
- Enabling soft LLM product judges in **goal-judge**

## Steps

1. **Split** — Random train/test (or hold-out named in the goal Dataset). Never
   tune on the full set silently.
2. **One change** — Single patch, prompt edit, or grader tweak per round. Record
   what moved.
3. **Measure** — `make eval/verify` / `eval/solve` / `eval/bars` as the goal
   requires. Prefer program checks; Jev/LiteLLM only when the pack already
   gates them.
4. **Revert rule** — If test is flat or regresses, revert the change before the
   next round.
5. **Stall** — Bucket failures (tooling vs ambiguity vs missing context) before
   adding capacity.
6. **Result** — Update `<goal>-result.md` in executive language:
   - Recommendation: Adopt / Hold / Inconclusive
   - Plain-language outcome
   - **Proof** section with at least one fenced or quoted harness snippet
     (`assert-red` / `verify` / `bars` exits, key check lines, score deltas)
7. **Commit discipline** — Result in a **later** local commit than goal+fixture
   (`result-not-with-eval`).

## Related

- Prior: **build-eval** / **goal-develop**
- Judge: **goal-judge**
- Docs: `docs/meta-eval-quality.md`
