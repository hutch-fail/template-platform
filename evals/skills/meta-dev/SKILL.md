---
name: meta-dev
description: >-
  Orchestrate meta (agent-eval / agent-improvement) work: goal-author →
  goal-develop or goal-solve → goal-judge. Trigger on "meta-dev", "run the meta
  loop", or proving an agent-improvement claim end-to-end. Refuse to skip
  assert-red.
---

# meta-dev

End-to-end meta development. Load and run children **in order**. Do not skip
**goal-author** assert-red.

Skills live under `skills/` in this hub (editor adapters:
`.cursor/skills/`, `.agents/skills/`). Host projects that subtree this hub
at `evals/` should run `evals/scripts/install-host-adapters.sh` once.

This hub is the recipe for **goal methodology** (templates, processes, harness,
skills). A change to hub behavior is eval work. Do not call methodology or
skill edits exempt. Doing only the implementation that turns checks green is
forbidden. Research is **goal-author**, before the goal file exists. If a goal
already covers the claim, run it (`make eval/verify` or `make eval/assert-red`)
instead of a side check as the only proof.

Durable product claims land in the **target repo’s** tracked `evals/` with
dated paths `goals/github.com/<slug>/<repo>/YYYYMMDD-<kebab>.md`. WIP uses
`scope: active` on a feature branch in that same tree. Product workspaces:
read `evals/PROCESS.md`. See `README.md`.

A diff that changes behavior outside the pack needs a fixture, a pre-run goal,
and, before merge, a `<goal>-result.md`. Local pre-commit `pr-has-eval-pack`
checks the fixture and the goal. Hub PR `eval-ci` (via `eval-ci-pr.yml` →
reusable `eval-ci.yml`) checks all three. `eval-has-goal` and
`result-not-with-eval` stay local commit checks.

## Chain

1. **goal-author** (optionally via **build-eval**) — goals + fixtures with an
   executive overview; `make eval/assert-red` until certified red; preflight the
   universe pack-quality ratchet when keys allow
2. Implement path (pick one):
   - **goal-develop** — human/agent implements within scope; never weaken evals
   - **goal-solve** — when goal has `solver: agent`: `make eval/solve` (TB2a)
   - **hillclimb** — when optimizing performance/cost: one patch per round,
     train/test split, revert on flat/regression
3. **goal-judge** — `make eval/verify` and/or `solve` / `run` / `report`; fail
   closed; always land the plain-language `<goal>-result.md` with **proof
   snippets** from harness output (soft LLM product rubrics stay deferred)

A fixture with `check.sh` needs a goal (`fixture_dir`; local pre-commit `eval-has-goal`).
After the run, write `<goal>-result.md` beside the goal in a later local commit, not
with the goal or the fixture (local pre-commit `result-not-with-eval`). Both commits
may be in one pull request. Squash or merge may combine them.

Low-level CLI: **goal**. Cursor rule: `.cursor/rules/meta-dev.mdc`. Docs:
`README.md`.

## Status between phases

After each phase, one line: phase name, goal id, pass/fail (or certified-red),
manifest path if any.

## Stop conditions

- assert-red never certifies → stop; do not develop/solve
- judge non-pass → stop; report failure evidence; do not claim success
- Human cancels or budget exhausted → stop with phase status

## Forbidden

- Skipping author or assert-red
- Doing only the implementation that turns checks green
- Ad-hoc meta edits outside this chain
- Installing Graft (or similar) as default without a green judge verdict
- Treating process-only evals as the ship bar for a product claim that should be
  tracked in the app repo
