# Hypothesis playground

Draft a claim, turn it into a goal, score control vs treatment on the eval
harness. Optional board posting (e.g. Paperclip) is a consumer concern — this
hub does not ship board scripts. Graft is not installed as a default.

## Loop

1. Copy `skills/hypothesis-playground/hypothesis.md`.
2. Convert and certify red:

```bash
bash harness/hypothesis-to-goal.sh --assert-red path/to/hypothesis.md
# host subtree:
# bash evals/harness/hypothesis-to-goal.sh --assert-red path/to/hypothesis.md
```

3. Score (mock solvers are the offline path):

```bash
make eval/ab GOAL=github.com/hermes/hermes/20260918-playground-mini-svc
make eval/ab GOAL=github.com/hermes/hermes/20260918-graft-mini-svc-ab
```

## Sample task

`fixtures/github.com/hermes/hermes/20260918-playground-mini-svc/` is a
few-file Python package. Baseline `GET /items/0` is wrong. The solver may only
fix `sut/router.py`. The treatment overlay is a pre-baked `graft/` note so
trials do not pay to regenerate a graph.

## Free models

`model_pin` must be `free-medium` (default in the sample goals), another
`free-*` alias, `dev-auto`, or `hermes-free`. Paid pins are refused.

`model_pin` is recorded on `compare.json` and exported as
`HERMES_EVAL_MODEL_PIN`. When the solver is `hermes`, the harness passes that
pin as `hermes chat -m`. Set `HERMES_EVAL_PROVIDER` (for example
`litellm-hermes`) so the pin hits LiteLLM instead of the default provider.
Product `hermes` allows `dev-auto`, which routes to the free groups before any
paid fallback. Override the sample goals' `free-medium` pin for that product:

```bash
HERMES_EVAL_SOLVER_BIN=hermes \
HERMES_EVAL_MODEL_PIN=dev-auto \
HERMES_EVAL_PROVIDER=litellm-hermes \
  make eval/ab GOAL=github.com/hermes/hermes/20260918-graft-mini-svc-ab
```

`max_wall_seconds` on the sample goals is 180. Keep the task on the one bug.

## How to read the verdict

| Field | Meaning |
| --- | --- |
| `verdict=pass` | Both arms succeed at ≥2/3 and treatment is not worse beyond the wall/token ratios |
| `efficiency=improves` | Treatment median wall and parsed tokens are ≤0.8× control |
| `tokens=unparsed` | Token gate skipped. Do not claim a token win |
| `adoption=inconclusive` | A solver path ends in `.sh` (mock). Not an adoption |
| `adoption=measured_pass` | Live solver, verdict pass. Still not a silent default |

Schema: `goals/_schema.md`. Going in: `templates/goal.md`. The filled pre-run
example is `goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab.md` —
show that file, do not recap it. Coming out beside the goal:
`goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab-result.md`. A green
check with no result file beside the goal is not done. Commit that result in a
later local commit, not with the goal or the fixture. Both commits may be in
one pull request. Squash or merge may combine them. Template:
`templates/result.md`. If the claim is that an agent used a tool, the check
starts that agent in the runtime under test. A config file, a throwaway
projector run, or a library script is not that agent.
