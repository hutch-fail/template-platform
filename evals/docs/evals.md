# Eval harness (this hub)

SoT and operator docs live under [`README.md`](../README.md).

## CI/CD onboarding (executive DX)

1. Developer starts a **new repository**.
2. The repo **opts into evals** (kit + host adapters so `eval/bars` runs on
   PRs — sync/pull / `install-host-adapters`).
3. On the **next PR**, universe bars fail closed if org **pre-commit** is
   missing (`20260929-pre-commit-platform`: `hutch-fail/pre-commit` `id: platform`
   + local `evals-pre-commit`) or if the local **pre-push** pack gate is missing
   (`20261002-local-eval-gates`: `evals-pre-push` → `pre-push-evals.sh`).
   Backfill the canonical config → green.
4. **Always-on CI onboarding law** stays **universe** (`goals/universe/` +
   `run_universe_bars`) so every recipe consumer fails closed after
   redistribute with no second opt-in (pre-commit platform, no raw
   `GH_APP_*` Actions secrets, pack-quality).
5. **Workflow / SDLC hygiene** that should fire when CI files change lives
   under **`language/gha`** (`goals/language/gha/` + `run_gha_bars`). Path
   detect (`.github/workflows/**`, `.github/actions/**`) or
   `languages: [gha]` (alias `ci` → `gha`). Hub PR → `sync/redistribute` →
   consumers pick up the bar; the product PR lands the config. Keep true
   must-apply-to-all law on universe; do not dump every GHA guideline into
   always-on universe.

`install-host-adapters` places the thin eval-ci host stub so PRs can run
bars after opt-in; keep that stub when syncing.

Public API: `make eval/assert-red`, `make eval/verify`, `make eval/solve`,
`make eval/ab`, `make eval/parse`, `make eval/run`, `make eval/report`
(`GOAL=…`). From a host project with this tree at `./evals`, use
`make -C evals eval/…`. CLI skill: `goal`. Hypothesis drafts:
`docs/hypothesis-playground.md`. Consumer install: `docs/consuming.md`.

Goals/fixtures/runs live in this evals git tree. Override with `EVALS_ROOT` / `HERMES_EVALS_ROOT` when pointing the harness at another checkout. This hub keeps the harness, skills, and goals/fixtures for CI and sync to products.


New process goals live under `goals/github.com/<slug>/` (mirrors typical guest
mounts such as `/home/ubuntu/github.com/<slug>/`).

Meta loop (author → develop|solve → judge): skills `meta-dev`, `goal-author`,
`goal-develop`, `goal-solve`, `goal-judge`, plus process skills `build-eval` and
`hillclimb`; Cursor rule `.cursor/rules/meta-dev.mdc`. Pack-quality ratchet:
[`meta-eval-quality.md`](meta-eval-quality.md).

A fixture with `check.sh` needs a goal whose `fixture_dir` points at it
(local pre-commit `eval-has-goal`). Commit `<goal>-result.md` in a later local
commit, after the goal and fixture (local pre-commit `result-not-with-eval`).
Both commits may be in one pull request. Squash or merge may combine them.
`eval-has-goal` and `result-not-with-eval` are not a pull-request or merge
check. A behavior-changing diff must also carry the pack. Local pre-commit
`pr-has-eval-pack` (`tests/unit/assert_pr_has_eval_pack.sh`) requires a fixture
check and a pre-run goal already on the branch. It does not require
`<goal>-result.md` in that commit. The pull-request job
`.github/workflows/eval-ci-pr.yml` (reusable `eval-ci.yml`) requires the
fixture, the goal, and the result before merge. `tests/unit/` and `runs/` do
not count. If a goal already covers the change, run it. Doing only the
implementation that turns checks green is forbidden. See [`README.md`](../README.md).
Dependabot (`dependabot[bot]`) and Renovate (`renovate[bot]`) skip eval-ci —
version bumps are not behavior PRs; use `make sync-dependabot` (with an eval
pack) for policy YAML. The pack gate (`pr-has-eval-pack`) also skips when every
changed path outside `evals/` is a **dependency bump only**: known lockfiles
(`poetry.lock`, `package-lock.json`, …) or pin-only edits in
`.github/workflows/*` and `.github/actions/**` (`uses: …@`, `hub_ref:`, `rev:`).
Workflow logic changes still need an eval pack; pin bumps may still run
`language/gha` bars when those paths change.

## Host consumer (subtree / mount at `evals/`)

After adding this hub at `<project>/evals`, run
`evals/scripts/install-host-adapters.sh` once so project-root
`.cursor/skills` and `.agents/skills` point into `evals/skills/`.

Host pre-commit snippet (paths relative to the **product** repo root):

```yaml
- id: eval-has-goal
  name: eval fixtures require a goal markdown
  entry: bash evals/tests/unit/assert_eval_has_goal.sh
  language: system
  pass_filenames: false
  files: ^evals/(fixtures|goals)/
- id: result-not-with-eval
  name: result markdown is not in the same local commit as its goal or fixture
  entry: bash evals/tests/unit/assert_result_commit.sh
  language: system
  pass_filenames: false
  files: ^evals/(fixtures|goals)/
- id: pr-has-eval-pack
  name: behavior changes include an eval fixture and a pre-run goal
  entry: bash evals/tests/unit/assert_pr_has_eval_pack.sh
  language: system
  pass_filenames: false
  files: ^(?!evals/)
```

Generic evals pre-commit / pre-push (add **after** the `hutch-fail/pre-commit`
`platform` hook). `evals-pre-commit` runs the soft pack gate under
`PRE_COMMIT=1` (fixture + pre-run goal), parses staged goal markdown
(`schema: goal/v1` via `assert_goals_schema` / `goal.sh parse`), then the
shared bars dispatcher (`scripts/eval-bars.sh` / `make eval/bars`).
`evals-pre-push` runs the CI-mode pack gate (requires `<goal>-result.md`)
so two-commit authorship still works locally while a push without a result
fails before eval-ci:

```yaml
default_install_hook_types: [pre-commit, pre-push]
# …
- repo: local
  hooks:
    - id: evals-pre-commit
      name: evals — apply scoped bars for changed paths
      entry: bash evals/scripts/pre-commit-evals.sh
      language: system
      pass_filenames: true
    - id: evals-pre-push
      name: evals — CI-mode pack gate before push
      entry: bash evals/scripts/pre-push-evals.sh
      language: system
      pass_filenames: false
      stages: [pre-push]
```

Install both hook types once:

```bash
pre-commit install --hook-types pre-commit --hook-types pre-push
```

Hosts that already use `evals-pre-commit` pick up soft pack + schema parse on
the next `sync/pull`. They must add the `evals-pre-push` entry (universe bar
`20261002-local-eval-gates`) and reinstall pre-push hooks. The dedicated
`pr-has-eval-pack` snippet above remains valid (hub / specialized consumers).

Shared entrypoint (local / pre-commit / CI):

```bash
make eval/bars                          # or: bash scripts/eval-bars.sh
HERMES_EVAL_SCAN_ROOT=/path/to/product make eval/bars
```

Behavior today:

| Trigger | Family | Bars run |
| --- | --- | --- |
| (always) | `universe` | No raw `secrets.GH_APP_ID` / `GH_APP_PRIVATE_KEY` (`20260924-no-gha-app-actions-secrets`); org pre-commit platform + evals-pre-commit (`20260929-pre-commit-platform`); local schema parse + pre-push pack (`20261002-local-eval-gates`); `sync-secrets` must hard-pin `GITHUB_OWNER` (`20261004-sync-secrets-pin-github-owner`); pack-quality ratchet Tier1–3 (`20260929-meta-eval-pack-quality` — see [`meta-eval-quality.md`](meta-eval-quality.md)) |
| `*.tf` / `*.tf.json` | `opentofu` | Remote-backend language bar (`20260924-remote-backend-locking`) |
| `*.ts` / `*.tsx` / `tsconfig.json` or `languages: typescript` | `typescript` | Run `npm run typecheck` / `npm test` when those scripts exist (skip if absent) |
| `design/**`, `docs/design-system/**`, `docs/north-star/**`, `evals/ui/**`, `scripts/ui-*`, own-leaf `ui-process` / `ui-jev` / `ui-visual` / `ui-semantic`, or `languages: ui` | `ui` | Scope-manifest + process-entrypoint; execute `ui:docs` / `ui:lint` / `ui:process` when present; optional `ui:jev` when script + `TYPESAFE_API_KEY` exist |
| `ansible/**`, `*/ansible/**`, `ansible.cfg`, `*/ansible.cfg` | `ansible` | Single-converge playbook bar (`20260929-ansible-single-converge`) |
| `.github/workflows/**`, `.github/actions/**`, or `languages: gha` (alias `ci`) | `gha` | CI/CD / GitHub Actions hygiene (seed: unique `runner-determination` concurrency — `20261001-unique-runner-determination`) |

Language ids for `evals/scope.yaml` / select: `opentofu`, `typescript`,
`python`, `ui`, `ansible`, `gha` — see [`scoping.md`](scoping.md) registry
(ratchet: detect → language bars → optional repo). `eval/select` is
declaration-only. `eval/bars` selects language families from (1) `languages:`
in the consumer manifest (so CI / `make eval/bars` with no path args still
runs declared UI/OpenTofu/TypeScript/Ansible/`gha` bars), (2) changed path
args (pre-commit and `ci-eval-bars` PR diffs), and (3)
`HERMES_EVAL_FORCE_FAMILIES` (`ci` aliases to `gha`). Path-detect still
**warns** when paths imply `ui` / `opentofu` / `ansible` / `gha` but the
manifest omits that id. Do **not** treat `src/**` alone as org-wide `ui`
(too broad). Do **not** treat bare `*.yml` as org-wide `ansible`.

New UI/UX consumers: declare `languages: [ui]` (add `typescript` when
typecheck/vitest should ride the same rail), keep process fixtures under
own-leaf `ui-process/` (or legacy `evals/ui/`), expose `npm run ui:process`
(and usually `ui:docs` / `ui:lint`). Shared bars run those scripts via
`eval-ci` / `make eval/bars` — **do not** add a second product workflow such
as `ui-design.yml`. When `ui:jev` exists, CI must pass secret
`TYPESAFE_API_KEY` into eval-ci; missing key fails closed outside pre-commit.
Local `PRE_COMMIT=1` skips Jev when the key is unset (deterministic ui:lint
stays on pre-commit). Missing `node_modules` with declared `ui:*` /
`typecheck` scripts fails with an `npm ci` hint (laptop / pre-commit).

Universe bars always run against `HERMES_EVAL_SCAN_ROOT` (default cwd).
**Growth rails:**
- **Universe** — must-apply-to-all onboarding (`goals/universe/` +
  `run_universe_bars`).
- **`language/gha`** — workflow/SDLC hygiene when CI files change
  (`goals/language/gha/` + `run_gha_bars`). Seed bars are deterministic;
  later packs may be Jev-, LLM-, or manual-verification-shaped under the
  same family. Redistribute after hub merge so consumers fail closed on the
  next workflow-touching PR.

Rule A for remote-backend: fail `backend "local"` and missing backend; pass any
non-local backend type (including partial `backend "s3" {}`).

When these scripts run from a product repo, they detect the hub at `evals/`
automatically (see script headers).

## Scoping and CI selection

Design and frontmatter rules: [`scoping.md`](scoping.md). `scope` /
`languages` / `repos` are enforced by `harness/lib/scope.sh` on parse and
other harness verbs ([#5](https://github.com/hutch-fail/evals/issues/5)).

Discovery:

```bash
make eval/list                 # human-readable applicable goals
make eval/select               # absolute paths for CI
make eval/doctor-scope         # hint/validate evals/scope.yaml
EVALS_INCLUDE_ACTIVE=1 make eval/select
GOAL=fixture-token-echo make eval/select
```

Implemented in `harness/lib/select.sh` + `harness/lib/manifest.sh`
([#6](https://github.com/hutch-fail/evals/issues/6),
[#7](https://github.com/hutch-fail/evals/issues/7)).
Shared reader soft-defaults when `evals/scope.yaml` is missing; invalid
manifests fail closed. `eval/doctor-scope` prints a create hint when missing
and `doctor-scope: ready` when OK.
- **Eval CI (today):** one reusable [`eval-ci.yml`](../.github/workflows/eval-ci.yml)
  job runs select, then shared bars (`scripts/ci-eval-bars.sh` →
  `make eval/bars`), then pack. Consumers pass `OP_SERVICE_ACCOUNT_TOKEN` so
  `1password/load-secrets-action` can load App credentials from item
  `hutch-fail-platform-github` and checkout this private hub at `hub_ref`. Hub
  PR caller: [`eval-ci-pr.yml`](../.github/workflows/eval-ci-pr.yml). Host stub:
  [`templates/github-workflows/eval-ci.yml`](../templates/github-workflows/eval-ci.yml).
- **Bars (not full select→verify):** `make eval/bars` always runs applicable
  universe checks with `HERMES_EVAL_SCAN_ROOT` set to the caller workspace.
  Language families run when `languages:` in the consumer manifest, matching
  paths, or `HERMES_EVAL_FORCE_FAMILIES` select them.
  This is **not** full select→verify for every selected goal
  ([#8](https://github.com/hutch-fail/evals/issues/8)).
- **Deprecated callables:** [`eval-pack-gate.yml`](../.github/workflows/eval-pack-gate.yml)
  and [`eval-select.yml`](../.github/workflows/eval-select.yml) remain for Wave 2
  consumer migration; new callers must pin `eval-ci.yml`. Actions stay thin —
  Make/scripts only ([issue #2](https://github.com/hutch-fail/evals/issues/2)).

Do **not** enable a required select/verify gate beyond pack assert and shared
`eval/bars` in the hub’s default PR workflow. A later policy may require
applicable universe/language goals to be green or opted out; that remains
separate ([#8](https://github.com/hutch-fail/evals/issues/8)).
