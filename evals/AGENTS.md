## Memory

Your memory is OptMem (repository-scoped):
- The tool is `optmem/repo-memo` (hosts: `evals/optmem/repo-memo`)
- Canonical identity after merge: `.optmem/main/memory`
- PR inbox: `.optmem/shards/<YYYYMMDDTHHMMSSZ>-<branch>/memory`
- Upstream `memo` is unmodified; the wrapper only sets `MEMORY_DIR`

OptMem outlives every session, compaction, model and vendor change.
Without it you do not know what this repository already decided and tried.

Note shape, backfill recipe, and wake vs TREE: [`docs/optmem.md`](docs/optmem.md).
Checklist: [`templates/optmem-note.md`](templates/optmem-note.md).

### At startup: activating OptMem (mandatory)

Run `python3 optmem/repo-memo wake` before any other tool call, in every
session, and then do exactly what it prints, to the end of its output.

### While working: register memories (mandatory)

Call `python3 optmem/repo-memo note "<1 line, max 280 bytes>"` whenever you
learn something new, or something worth keeping happens. Do not register
redundant memories. If `note` asks a compression: do it before your next
action. Never edit `.optmem/main` on a pull request (the reconcile Action
owns it). Never edit files under `.optmem/**/memory` by hand.

### If you're a subagent: skip everything above

A subagent must never run memo. When you spawn one, write:
`You are a subagent. Don't run memo.`

## Learned User Preferences

- Prefer wrapping and pinning existing tools over reimplementing them when an
  upstream already owns the mechanism (`docs/prior-art.md`, Cursor rule
  `wrap-prior-art.mdc`). OptMem in **this hub** is the instance: do not edit
  `optmem/upstream/memo`. Product/downstream memory stores are out of scope
  for the evals kit universe bars.
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
  `grep`ing the implementing files. Operator-use / kick-the-tires claims
  (ensure, heal, seed, bind, …) must exercise the entrypoint in F2P — and
  re-enter when reconverge is in scope — not only wire-grep; Tier-1 use-path
  lint enforces this (`PROCESS.md` “Use path vs wiring path”). Host URL /
  portless / dashboard L0 claims must wire into `doctor` / `test/smoke` /
  `make up` (Tier-1 live-path); grepping a probe script for `curl` is not Done
  (`PROCESS.md` “Live path vs probe-script path”). See also
  `PROCESS.md` “Manual verification becomes a test”; CI requires a
  `# Manual verification` section in results.

## Learned Workspace Facts

- Procedure homes (rules/skills/scripts/`AGENTS.md`) mirror claim scopes—see
  `PROCESS.md` “Procedure homes” and `docs/scoping.md` for claims.   Org `live-verify.mdc` and `wrap-prior-art.mdc` ship via
  `install-host-adapters.sh`; product stack paths stay in product `AGENTS.md`.
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
