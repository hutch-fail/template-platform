---
name: goal
description: >-
  Run the goal harness (assert-red, verify, solve, run, report). Trigger on
  "run goal", "assert-red", "eval verify", F2P/P2P, or proving an
  agent-improvement claim. Host-runnable via make eval/*; no Incus required
  for TB1/TB2a harness commands.
---

# goal

Thin shim over this hub’s eval CLI. This repository owns the methodology
(templates, harness, skills); any coding agent or human uses the same
entrypoints from the hub root or via `make -C evals` when this tree is a
subtree at `<project>/evals`.

Goals/fixtures/runs live in this evals git tree (override with `EVALS_ROOT` /
`HERMES_EVALS_ROOT`). From a product workspace, start at `evals/PROCESS.md`.
Date-prefix product leaves under `goals/github.com/<slug>/<repo>/YYYYMMDD-<kebab>.md`.

Durable product packs live in the **target repo’s** tracked `evals/` (often
this hub as a sync/subtree) when that claim should travel with the app.

## Commands (from hub root)

```bash
make eval/parse GOAL=fixture-token-echo
make eval/assert-red GOAL=fixture-token-echo   # F2P must be red on baseline
make eval/verify GOAL=fixture-token-echo       # golden patch → F2P+P2P green
make eval/solve GOAL=fixture-token-echo-agent  # TB2a agent/mock solver → F2P+P2P
make eval/ab GOAL=github.com/hermes/hermes/20260918-playground-mini-svc
make eval/run GOAL=fixture-token-echo          # public F2P+P2P (baseline fails F2P)
make eval/report GOAL=fixture-token-echo
```

From a host project with this hub at `./evals`:

```bash
make -C evals eval/assert-red GOAL=fixture-token-echo
```

Product-scoped process goal (HockeyMind example):

```bash
make eval/assert-red GOAL=github.com/hockeymind/hockeymind/20260916-studio-chat-channel-discipline
```

Equivalent CLI:

```bash
bash harness/goal.sh assert-red fixture-token-echo
bash harness/goal.sh verify fixture-token-echo
bash harness/goal.sh solve fixture-token-echo-agent
```

From a product workspace with this hub at `./evals`, run
`make -C evals …` or `bash evals/harness/goal.sh …`.

## Related

- Orchestrator: **meta-dev**
- Author / develop / judge: **goal-author**, **goal-develop**, **goal-judge**, **goal-solve**
- Docs: `PROCESS.md`, `README.md`, `goals/_schema.md`
- Commit rules (local `git commit` only): a fixture with `check.sh` needs a
  goal (`eval-has-goal`). A result file is a later local commit, not the same
  commit as that goal or fixture (`result-not-with-eval`). Both commits may be
  in one pull request. Squash or merge may combine them.
