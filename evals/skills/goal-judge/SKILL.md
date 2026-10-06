---
name: goal-judge
description: >-
  Score a goal with the eval harness (verify / solve / run / report). Trigger on
  "judge goal", "verify goal", or after goal-develop / goal-solve. Fail closed
  on red manifests. Soft LLM rubric judges are not implemented.
---

# goal-judge

Run harness judges and interpret manifests. Fail closed. Do **not** invent
scores.

## Static path (TB1)

```bash
make eval/verify GOAL=<id>   # golden.patch then F2P+P2P
make eval/run GOAL=<id>
make eval/report GOAL=<id>
```

- **Harness pass:** manifest `verdict=pass`. Write `<goal>-result.md` beside the
  goal (`templates/result.md` shape). Lead with Adopt / Hold / Inconclusive.
  Include a **Proof** section with at least one fenced or quoted harness snippet
  (`make eval/assert-red` / `verify` / `bars` exits, key check lines, score
  deltas). The harness copy under `runs/` is not that file. Do not read a
  harness pass as Adopt. A green check with no result file beside the goal is
  not done. Commit the result in a later local commit, not with the goal or the
  fixture (`result-not-with-eval`). Both commits may be in one pull request.
  Squash or merge may combine them. Do not say an agent used a tool unless that
  agent was started in the runtime under test.
- **Fail:** any non-pass — return manifest path; do not claim success

## Agent solver path (TB2a)

When the goal has `solver: agent` (after **goal-solve** or develop):

```bash
make eval/solve GOAL=<id>
make eval/report GOAL=<id>
```

Hard success is still static F2P + P2P after the solver exits. Transcript is
under `runs/<id>/<run>/transcript.txt`. Override CLI with
`HERMES_EVAL_SOLVER_BIN`.

## Paired arms

When the goal sets `control_overlay` and `treatment_overlay`:

```bash
make eval/ab GOAL=<id>
make eval/report GOAL=<id>
```

`compare.json` `verdict=pass` means the written gates passed (quality, then wall and token ratios). The decision report can still be Inconclusive when tokens were not counted, or when the solvers were mocks. Do not install from that report. Soft LLM rubrics stay out of scope.

## Soft LLM rubrics (not implemented)

Trajectory / rubric scoring as pass criteria is **out of scope** (TB2b). Do not
invent rubric grades. Say hard checks only. Tier-3 LiteLLM in the universe
pack-quality ratchet grades **eval pack** quality only — see
`docs/meta-eval-quality.md`.

## Forbidden

- Declaring green without a pass manifest
- Weakening evals to pass
- Silently substituting a different goal id

## Related

- Prior: **goal-develop**, **goal-solve**, or **hillclimb**
- CLI: **goal**
- Orchestrator: **meta-dev**
