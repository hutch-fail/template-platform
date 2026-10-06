## Learned User Preferences

- Prefer skills that do one atomic piece of work, composed by orchestrators
  (e.g. `meta-dev` → `goal-author` / `goal-develop`|`goal-solve` / `goal-judge`)
  rather than monolithic skill bodies.
- This repository is the **templates, processes, scripts, and skills** for
  architecting, designing, and running goals (`harness/`, `goal*` / `meta-dev`
  skills, schema). A behavior change here is still eval work. Doing only the
  implementation that turns checks green is forbidden. If a goal already covers
  the claim, run it.
- Author WIP and standing goals in the evals git tree (this hub or a product’s
  synced/subtree `evals/`). Use `scope: active` for WIP that must not enter
  default CI select until Adopt; date-prefix product leaves
  `goals/github.com/<slug>/<repo>/YYYYMMDD-<kebab>.md`. Harness:
  `make eval/...` here or `make -C evals` from a host.
- Standing product claims land under that product’s tracked `evals/` (+
  `docs/goals/` when the project uses NNN-MM), then harvest to this hub.
- Meta (agent-eval / agent-improvement) work goes through `meta-dev` →
  `goal-author` → `goal-develop`|`goal-solve` → `goal-judge` (Cursor rule
  `.cursor/rules/meta-dev.mdc`); never weaken evals or adopt tools without a
  green judge verdict.
- The pre-run report is the goal markdown file, not a chat recap. The example is
  `goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab.md` (Cursor rule
  `.cursor/rules/goal-spec.mdc`). After the run, write `<goal>-result.md` beside
  the goal. Commit that result in a later local commit, not in the same
  `git commit` as the goal or the fixture. Both commits may be in one pull
  request. If the claim is that an agent used a tool, the check starts that
  agent in the runtime under test. A config file, a throwaway projector run, or
  a library script is not that agent.

- A check you ran by hand and saw pass must become an automated check in the
  same PR (or the result states why it cannot, with a reproducible command and a
  script-written proof artifact). End-to-end claims are graded by running the
  path from the documented starting state on a throwaway environment, not by
  `grep`ing the implementing files. See `PROCESS.md` “Manual verification
  becomes a test”; CI requires a `# Manual verification` section in results.

## Learned Workspace Facts

- Procedure homes (rules/skills/scripts/`AGENTS.md`) mirror claim scopes—see
  `PROCESS.md` “Procedure homes” and `docs/scoping.md` for claims. Org
  `live-verify.mdc` ships via `install-host-adapters.sh`; product stack paths
  stay in product `AGENTS.md`.
- Skills SoT is `skills/`; host editors use tracked relative adapters in
  `.cursor/skills/` and `.agents/skills/`. Host projects that sync/subtree this
  hub at `evals/` should run `evals/scripts/install-host-adapters.sh` once.
  Org-wide harvest/redistribute: `docs/syncing.md` (`make sync/list|harvest|pull|doctor`).
- Language / UI growth is open-closed: append
  `goals|fixtures/language/<id>/` + one wire in `scripts/eval-bars.sh`
  `run_*_bars`; consumers opt in via `evals/scope.yaml` `languages:`. See
  `docs/scoping.md` § Ratchet. Do not add per-product UI workflows that
  duplicate `eval/bars`.
- Goals/fixtures/runs live in the evals git tree (`EVALS_ROOT` /
  `HERMES_EVALS_ROOT` override). Products sync/subtree/mount this hub at
  `evals/`; do not use a home-directory process SoT.
- Dynamic agent-solver (TB2a): `make eval/solve` / skill **goal-solve** runs a
  goal’s `solver_bin` (coding-agent CLIs or a fixture mock `.sh`) in a fixture
  copy, then the same F2P/P2P shell checks; the harness does not call LLM
  provider APIs or require API keys. Soft trajectory/rubric LLM judges remain
  deferred.
