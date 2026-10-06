---
name: hypothesis-playground
description: >-
  Draft a hypothesis and convert it into a dated goal, then certify F2P
  red. Trigger on "hypothesis playground", "draft a hypothesis", or turning a
  claim into an eval. Does not run the A/B judge or install Graft.
---

# hypothesis-playground

One job: turn a written claim into a **goal/v1** and certify it red.

Scoring stays on `make eval/ab` (skill **goal** / **goal-judge**). This skill
does not install Graft or any other intervention as a default. Meta work still
goes through **meta-dev** (author → develop|solve → judge).

## Write

Copy `templates/goal.md` for any eval. The filled example is
`goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab.md`.
Show that file when asked for the pre-run report. Do not recap it.
After the run, write `<goal>-result.md` beside the goal. The example is
`goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab-result.md`.
A green check with no result file beside the goal is not done. Commit the
result in a later local commit, not with the goal or the fixture. Both commits
may be in one pull request. Squash or merge may combine them. A fixture with
`check.sh` needs a goal whose `fixture_dir` points at it.
If the claim is that an agent used a tool, the check starts that agent in the
runtime under test. A config file, a throwaway projector run, or a library
script is not that agent. One agent does not stand in for the others.
For a paired-arm hypothesis, copy [`hypothesis.md`](hypothesis.md) instead: same
specification fields, plus the arm frontmatter. Keep the task narrow. Set `model_pin`
to `free-medium`, `dev-auto`, or `hermes-free`.

Required frontmatter: `schema: hypothesis/v1`, date-prefixed `id`, `goal_rel`
(`github.com/<slug>/<repo>/YYYYMMDD-<kebab>`), fixture checks, overlays, solver.

## Convert

From the hub root:

```bash
bash harness/hypothesis-to-goal.sh --assert-red path/to/hypothesis.md
```

From a host with this hub at `./evals`:

```bash
bash evals/harness/hypothesis-to-goal.sh --assert-red path/to/hypothesis.md
```

That writes `goals/<goal_rel>.md` under `EVALS_ROOT` / `HERMES_EVALS_ROOT`
(default: this evals tree) and runs `assert-red`. Add `--seed` only when the
goal should also land in this hub’s tracked `goals/`.

The fixture directory must already exist under the hub (or host `evals/`) tree
(`require_goal_v1` checks the repo path). The playground sample is
`fixtures/github.com/hermes/hermes/20260918-playground-mini-svc/`.

## Then

Hand the `GOAL=` path to **goal-judge** (`make eval/ab`). The harness writes
`result.md` beside `manifest.json` from `templates/result.md`.
`make eval/report` prints that result. Do not claim an intervention won from
mock solvers (`adoption=inconclusive`).

Free-model pin and optional board posting: `docs/hypothesis-playground.md`.
