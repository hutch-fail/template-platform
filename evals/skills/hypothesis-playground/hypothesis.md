---
schema: hypothesis/v1
id: 20260918-hermes-playground-hypothesis-example
goal_rel: github.com/hermes/hermes/20260918-playground-hypothesis-example
title: Example — Graft notes still produce a working fix
fixture_dir: evals/fixtures/github.com/hermes/hermes/20260918-playground-mini-svc
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver_prompt: evals/fixtures/github.com/hermes/hermes/20260918-playground-mini-svc/solver-prompt.md
solver_bin: evals/fixtures/github.com/hermes/hermes/20260918-playground-mini-svc/solvers/mock-control.sh
control_solver_bin: evals/fixtures/github.com/hermes/hermes/20260918-playground-mini-svc/solvers/mock-control.sh
treatment_solver_bin: evals/fixtures/github.com/hermes/hermes/20260918-playground-mini-svc/solvers/mock-graft.sh
control_overlay: arms/control
treatment_overlay: arms/graft
trials: 1
model_pin: free-medium
max_wall_seconds: 180
max_wall_ratio: 1.2
max_token_ratio: 1.2
---

# Decision

A pass lets us say Graft notes still produced a working fix on this one bug. A pass does not install Graft.
