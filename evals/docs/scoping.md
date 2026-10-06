# Eval scoping: universe / repo / language / active-dev

Design for [issue #3](https://github.com/hutch-fail/evals/issues/3).
**Status:** accepted design. Frontmatter/path validation is enforced
([#5](https://github.com/hutch-fail/evals/issues/5)); `make eval/list` /
`make eval/select` are implemented ([#6](https://github.com/hutch-fail/evals/issues/6));
shared `evals/scope.yaml` reader + `eval/doctor-scope` are implemented
([#7](https://github.com/hutch-fail/evals/issues/7)); reusable pack/select
workflows + host stubs are implemented
([#8](https://github.com/hutch-fail/evals/issues/8)); universe smoke lives under
`goals/universe/` and an OpenTofu language seed is in-tree
([#9](https://github.com/hutch-fail/evals/issues/9)).
This document is normative for authorship and placement.

Related: Make / secrets / doctor conventions in
[issue #2](https://github.com/hutch-fail/evals/issues/2) (Actions stay thin;
Make is the interface).

## Problem

Path homes (`goals/github.com/<org>/<repo>/…`, flat smoke seeds, process SoT)
encode “where the file lives” but not these operator intents:

| Intent | Meaning |
| --- | --- |
| **Universe** | Applies to every consumer of the shared `evals` recipe |
| **Repo-global** | Standing bar for one product repository |
| **Language** | Applies to consumers that declare language X |
| **Active-dev** | Current branch / process experiment only |

Without an explicit mechanism, agents and humans duplicate goals, put standing
bars in the wrong tree, or treat process experiments as product law.

## Decisions

1. **Declaration:** frontmatter `scope:` on each goal, validated against path
   layout, plus a product-owned `evals/scope.yaml` (when present) for consumer
   identity, languages, and opt-outs.
2. **Override:** universe and language bars are **default-on**. Consumers may
   **documentedly opt out** per goal id (or path) with a required `reason`.
   CI must print opt-outs in the job summary when the select gate exists.
3. **Language binding (v1):** no repo heuristics. Language goals declare
   `languages:`; the consumer lists languages in `scope.yaml`. Empty / missing
   `languages` ⇒ language bars do **not** apply; universe bars still do.
4. **CI hooks:** both cross-repo reusable workflows (`workflow_call` in this
   hub) **and** thin host stubs that only call `make -C evals …`.

## Approaches considered

| Approach | Why not / why |
| --- | --- |
| Path-only | Already partially true; cannot express language or opt-out |
| Registry-only YAML | Drifts from goal files; agents edit two places |
| **Frontmatter + path validation + consumer manifest** | Chosen: scope travels with the goal; path refuses misplacement; opt-out stays product-owned |

## Four scopes

| Scope | Meaning | Canonical home | Frontmatter | Path rule |
| --- | --- | --- | --- | --- |
| `universe` | Every recipe consumer | Hub `goals/universe/…` | `scope: universe` | Recipe goals only — not product-only trees |
| `language` | Consumers that list that language | Hub `goals/language/<lang>/…` | `scope: language` + `languages: […]` | Path `<lang>` must match frontmatter |
| `repo` | Standing bar for one product | `goals/github.com/<org>/<repo>/…` | `scope: repo` (`repos:` optional if path encodes identity) | Path org/repo must match consumer `repo` |
| `active` | WIP experiment | Same evals git tree (hub or product leaf) | `scope: active` | Allowed under `evals/goals/`; default select skips unless `EVALS_INCLUDE_ACTIVE=1` |

### Ownership and inheritance

| Scope | Owned by | How consumers see it |
| --- | --- | --- |
| Universe / language | This hub (recipe PR) | Via `sync/pull` / subtree / mount of `evals/` |
| Repo | Product repo (commits under `evals/goals/github.com/…`) | Must be **harvested to hub** for org SoT ([`syncing.md`](syncing.md)); then redistribute |
| Active | Authored in evals git on a branch; not standing CI until Adopt | Same sync/subtree/mount as the rest of `evals/` |

`evals/scope.yaml` is product-owned and **never** harvested onto the hub.

Subtree note: GitHub Actions only loads workflows from the **repository root**
`.github/workflows/`. Files under `evals/.github/` are ignored. Hosts must
either call hub reusable workflows with `uses: hutch-fail/evals/...@pin` or
copy stubs into the host root `.github/workflows/`. Prefer `uses:` + pin for
shared policy; local Make for day-to-day.

### Promotion

```text
active  →  repo  →  (optional) language | universe
```

1. **active → repo:** green result with Adopt (or equivalent), move goal +
   fixture into `goals/github.com/<org>/<repo>/`, set `scope: repo`, commit
   in the product.
2. **repo → language | universe:** only via PR on **this hub**. Product
   commits do not promote a bar to shared recipe scope.

## Ratchet: detect → language bars → optional repo

Open-closed growth for shared gates (OpenTofu prior art; UI/TypeScript follow
the same shape):

```text
detect (scope.yaml languages: + path cues)
  → universe bars (always)
  → language bars for each declared id  (hub goals|fixtures/language/<id>/)
  → optional repo goals                 (goals|fixtures/github.com/<org>/<repo>/)
```

| Layer | Closed for modification | Open for extension |
| --- | --- | --- |
| Dispatcher | One `scripts/eval-bars.sh` + one `eval-ci` rail | Append `run_<id>_bars` case + call |
| Language family | Shared presence/execute checks under `language/<id>/` | New dated goal + fixture; wire in `run_*_bars` |
| Product | Declares `languages:` in `evals/scope.yaml` | Own-leaf fixtures + `npm`/`make` scripts the bars invoke |

**Promotion `repo → language`** is a hub PR only (see Promotion above). Product
scripts (`ui:lint`, `typecheck`, …) are the executable extension points —
language bars call them when present; they do **not** invent a second product
workflow (anti-pattern: per-repo `ui-design.yml` duplicating `eval/bars`).

Authors: add `fixtures/language/<id>/YYYYMMDD-…/check.sh`, matching goal under
`goals/language/<id>/`, then one line in the matching `run_*_bars` function.

## Consumer manifest (`evals/scope.yaml`)

Product-owned file beside the vendored kit (survives subtree merges like
product goals). Schema `evals-scope/v1`:

```yaml
schema: evals-scope/v1
repo: github.com/hutch-fail/platform-github
languages:
  - typescript
opt_out:
  - id: 20260921-universe-require-doctor
    reason: "Not an IaC consumer yet"
```

| Field | Required | Meaning |
| --- | --- | --- |
| `schema` | yes | `evals-scope/v1` |
| `repo` | recommended | `github.com/<org>/<repo>` identity for `scope: repo` matching |
| `attachment` | no | Persist mode: `ephemeral` \| `kit` \| `full` (default **`full`**). Unknown values fail closed. See Attachment persist modes below. |
| `languages` | no | List of language ids (registry below); empty ⇒ no language bars |
| `opt_out` | no | List of `{ id \| path, reason }` |

### Language id registry

Supported `languages:` ids (declaration is SoT for `make eval/select`):

| Id | Meaning | Hub home |
| --- | --- | --- |
| `opentofu` | OpenTofu / Terraform language bars | `goals/language/opentofu/` |
| `typescript` | TypeScript execute bars (`typecheck` / `test` when present) | `goals/language/typescript/` |
| `python` | Python language bars (id reserved; no bars yet) | `goals/language/python/` when present |
| `ui` | Design-system UX bars (presence + `ui:*` / optional Jev execute) | `goals/language/ui/` |
| `ansible` | Ansible playbook language bars (single-converge) | `goals/language/ansible/` |

`make eval/select` is **declaration-only**: a language goal applies only when the
consumer lists that id. `make eval/bars` runs families from the same
`languages:` list (so declared UI consumers get design bars in CI with no path
args), plus path-detect (e.g. `*.tf` → `opentofu`, design-system / `scripts/ui-*`
→ `ui`, `ansible/**` / `ansible.cfg` → `ansible`, `.github/workflows/**` /
`.github/actions/**` → `gha`). Path-detect **warns** when
paths imply a family the manifest omits — that warning does not change
`eval/select`.

**Defaults when the file is missing:** infer `repo` from `git remote` /
`HERMES_EVAL_REPO_ROOT` when possible; `languages: []`; `opt_out: []`;
`attachment: full`. Universe goals still apply.

## Attachment persist modes

Closed dispatcher: [`harness/lib/attachment.sh`](../harness/lib/attachment.sh).
New modes are additional cases (gitignore template + harvest/doctor behavior),
not a rewrite of `sync-pull`.

| Mode | Consumer git remote | Local tree | Packs |
| --- | --- | --- | --- |
| `ephemeral` | No `evals/` paths | Mount or ignored `sync-pull` | Hub own-leaf; overlay locally |
| `kit` | Kit + universe/language + `scope.yaml` | Own leaf present, gitignored | Hub own-leaf |
| `full` | Kit + universe/language + own leaf | Same | Harvest own-leaf (never foreign) |

`make eval/doctor-attach` fails closed when tracked paths violate the mode
(and when `kit`/`ephemeral` working trees contain a foreign `github.com/` leaf).
`sync-pull --attachment …` writes `attachment:` only when initializing a new
`scope.yaml` **and** the flag is passed; existing manifests are preserved.

Operator detail: [`consuming.md`](consuming.md).

## Frontmatter (enforced)

Flat keys on `goal/v1` (see [`goals/_schema.md`](../goals/_schema.md)).
Validated by `harness/lib/scope.sh` on every `require_goal_v1` call (`parse`,
`assert-red`, …).

| Key | Values | Notes |
| --- | --- | --- |
| `scope` | `universe` \| `language` \| `repo` \| `active` | If omitted, infer from path (below) |
| `languages` | space- or comma-separated, or docs-only list | Required when `scope: language` |
| `repos` | optional | Override/extra identities when path is not enough |

### Path inference (when `scope` omitted)

| Path under `goals/` | Inferred scope |
| --- | --- |
| `universe/…` | `universe` |
| `language/<lang>/…` | `language` (languages = `[<lang>]`) |
| `github.com/<org>/<repo>/…` | `repo` |
| File outside the product/hub recipe `goals/` tree | `active` |

Unknown `scope` values and path/frontmatter mismatches fail closed.

(Historical: flat `fixture-token-echo*` / `hub-kit-smoke` at the goals root were
proto-universe until #9; they now live under `goals/universe/` with the same
ids. Do not add new goals at the flat root. The harness still treats those
legacy basenames as universe if a flat copy appears.)

## Examples

### Universe

```text
goals/universe/fixture-token-echo.md
goals/universe/hub-kit-smoke.md
goals/universe/20260924-no-gha-app-actions-secrets.md
goals/universe/20260929-pre-commit-platform.md
goals/universe/20261002-local-eval-gates.md
goals/universe/20261004-sync-secrets-pin-github-owner.md
fixtures/token-echo/
fixtures/hub-kit-smoke/
fixtures/universe/20260924-no-gha-app-actions-secrets/
fixtures/universe/20260929-pre-commit-platform/
fixtures/universe/20261002-local-eval-gates/
fixtures/universe/20261004-sync-secrets-pin-github-owner/
```

```yaml
---
schema: goal/v1
id: fixture-token-echo
title: Fixture echo emits FIXTURE_OK
scope: universe
fixture_dir: evals/fixtures/token-echo
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---
```

`GOAL=fixture-token-echo` still resolves by id. Do not add new product goals at
the flat `goals/` root.

Universe policy bars (always-on via `make eval/bars` / `scripts/eval-bars.sh`
in local, pre-commit, and eval-ci):

```yaml
---
schema: goal/v1
id: 20260924-no-gha-app-actions-secrets
title: Workflows must not use raw GitHub App Actions secrets
scope: universe
fixture_dir: evals/fixtures/universe/20260924-no-gha-app-actions-secrets
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---
```

```yaml
---
schema: goal/v1
id: 20260929-pre-commit-platform
title: Recipe consumers must include org pre-commit (platform + evals-pre-commit)
scope: universe
fixture_dir: evals/fixtures/universe/20260929-pre-commit-platform
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---
```

### Universe vs `language/gha` CI/CD growth rails

**Universe** — must-apply-to-all onboarding law (no second opt-in). DX:

1. New repo opts into evals → next PR runs universe bars.
2. Missing org pre-commit fails closed (`20260929-pre-commit-platform`).
   Missing local pre-push pack / schema gates fail closed
   (`20261002-local-eval-gates`).
3. Author the next always-on guideline as `goals/universe/YYYYMMDD-…` +
   fixture; append its `check.sh` in `run_universe_bars`; hub PR →
   `sync/redistribute`.
4. Existing and new consumers fail on the next PR until they backfill config.

**`language/gha`** — path-targeted CI/CD / GitHub Actions / SDLC hygiene
(same shape as OpenTofu / UI / Ansible). Fires when `.github/workflows/**` or
`.github/actions/**` change, or when the consumer lists `languages: [gha]`
(alias `ci` → `gha`). Author as `goals/language/gha/YYYYMMDD-…` + wire in
`run_gha_bars`. Keep true always-on law on universe; do not dump every
workflow guideline into universe just to avoid a language id.

### Language

```text
goals/language/opentofu/20260922-opentofu-scope-manifest.md
fixtures/language/opentofu/20260922-opentofu-scope-manifest/
goals/language/opentofu/20260924-remote-backend-locking.md
fixtures/language/opentofu/20260924-remote-backend-locking/
```

Host pre-commit gate: see [`docs/evals.md`](evals.md)
(`scripts/pre-commit-evals.sh` → `scripts/eval-bars.sh` / `make eval/bars`).
One generic entry: **universe** bars always run; language families map from
changed paths (e.g. `*.tf` → OpenTofu remote-backend; `*.ts` → typescript
typecheck/test when scripts exist; design-system / `scripts/ui-*` → UI
presence + execute/`ui:jev` bars; `.github/workflows/**` → `gha` hygiene).

```yaml
---
schema: goal/v1
id: 20260922-opentofu-scope-manifest
title: OpenTofu consumers declare opentofu in evals/scope.yaml
scope: language
languages: opentofu
fixture_dir: evals/fixtures/language/opentofu/20260922-opentofu-scope-manifest
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---
```

Applies only when the consumer manifest lists `opentofu`.

### Repo-global (today’s layout)

```text
goals/github.com/hutch-fail/platform-github/20260921-manage-evals-repo.md
```

```yaml
---
schema: goal/v1
id: 20260921-platform-github-manage-evals-repo
title: OpenTofu manages the evals GitHub repository
scope: repo
fixture_dir: evals/fixtures/github.com/hutch-fail/platform-github/20260921-manage-evals-repo
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---
```

### Active-dev (WIP in evals git)

```text
# same evals tree; feature branch; skipped by default select
goals/github.com/example/product/20260921-try-graft-overlay.md
```

```yaml
---
schema: goal/v1
id: 20260921-try-graft-overlay
title: Scratch A/B for graft overlay
scope: active
fixture_dir: evals/fixtures/github.com/example/scratch/20260921-try-graft-overlay
f2p_check: check.sh
p2p_check: p2p-smoke.sh
solver: agent
# …
---
```

Product CI must not select `scope: active` by default.

## Harness discovery

Make surface (no substantive logic in Actions YAML — issue #2):

| Target | Role |
| --- | --- |
| `make eval/list` | Human-readable applicable goals (`id`, `scope`, path) |
| `make eval/select` | Machine-readable absolute paths for CI (one per line) |
| `make eval/doctor-scope` | Hint when `scope.yaml` is missing; fail closed when invalid |
| `make eval/doctor-attach` | Fail closed when git-tracked `evals/` paths violate `attachment:` |
| Existing `eval/assert-red`, `verify`, … | Unchanged per-goal verbs |

Implemented in `harness/lib/select.sh` via `harness/goal.sh list|select`.
Consumer manifest parsing lives in `harness/lib/manifest.sh` (`load_scope_manifest`)
and is shared by list/select and `doctor-scope`. Soft-defaults when
`evals/scope.yaml` is missing (infer `repo` from git remote when possible;
empty `languages` / `opt_out`). Set `EVALS_INCLUDE_ACTIVE=1` to include
`scope: active`, or pass `GOAL=` to restrict to one goal (and allow active for
that id). Opt-outs print to stderr as `opt_out id=… reason=…`.

`make eval/doctor-scope` (or `harness/goal.sh doctor-scope`):

- **Missing** file: prints an actionable create hint (schema example) and still
  exits 0 with `doctor-scope: ready` (defaults remain valid for select).
- **Present + invalid**: exits non-zero with a field-named error pointing at
  this document.
- **Present + valid**: exits 0 with `doctor-scope: ready` only.

Consumer `make doctor` (issue #2) should call `make -C evals eval/doctor-scope`
when that surface lands. This hub does not ship the full secrets/env doctor.

**Selection algorithm:**

1. Load goals from the recipe root and, if present, the process SoT. Skip
   `*-result.md`, `_schema.md`, `README.md`.
2. Resolve `scope` (frontmatter or path inference).
3. Include when:
   - `universe` and not in `opt_out`
   - `language` and intersection(goal languages, manifest languages) non-empty
     and not in `opt_out`
   - `repo` and goal org/repo matches `manifest.repo` (or inferred) and not
     in `opt_out`
   - `active` only if `EVALS_INCLUDE_ACTIVE=1` or the caller passed an
     explicit `GOAL=` (never default product CI)
4. Fail closed on unknown `scope` or path/frontmatter mismatch.

## CI: reusable workflows + host stubs

### Hub (this repository)

| Workflow | Role |
| --- | --- |
| [`.github/workflows/eval-ci.yml`](../.github/workflows/eval-ci.yml) | Preferred reusable: select then pack in one job |
| [`.github/workflows/eval-ci-pr.yml`](../.github/workflows/eval-ci-pr.yml) | Hub PR caller (draft skip, docs paths-ignore) |
| [`.github/workflows/eval-pack-gate.yml`](../.github/workflows/eval-pack-gate.yml) | **Deprecated** pack-only callable (Wave 2 migration) |
| [`.github/workflows/eval-select.yml`](../.github/workflows/eval-select.yml) | **Deprecated** select-only callable (Wave 2 migration) |

Reusable workflows live in **this** repo’s root `.github/workflows/` so other
repos can call `uses: hutch-fail/evals/.github/workflows/<file>@<pin>`.
Select discovery uses [`scripts/ci-eval-select.sh`](../scripts/ci-eval-select.sh).

### Host stubs

Copy-paste YAML under [`templates/github-workflows/`](../templates/github-workflows/):

| Stub | Role |
| --- | --- |
| `eval-ci.yml` | Preferred host PR → `uses: …/eval-ci.yml@PIN` |
| `eval-pack.yml` | **Deprecated** → pack-gate only |
| `eval-select.yml` | **Deprecated** → select only |
| `evals-make-select.yml` | Thin Make-only alternate (`make -C evals eval/select`) |
| `release.yml` | Host `main` → `uses: hutch-fail/actions/…/semantic-release.yml@PIN` |

Host root example (pin a commit/tag). Pass `OP_SERVICE_ACCOUNT_TOKEN` so the
reusable can load App credentials from 1Password and checkout private
`hutch-fail/evals` at `hub_ref` — explicit mapping or `secrets: inherit`:

```yaml
name: eval ci
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    paths-ignore:
      - '**/*.md'
      - 'docs/**'
jobs:
  eval-ci:
    if: github.event.pull_request.draft == false && github.event.pull_request.user.login != 'dependabot[bot]' && github.event.pull_request.user.login != 'renovate[bot]'
    uses: hutch-fail/evals/.github/workflows/eval-ci.yml@<pin>
    with:
      evals_path: evals
      hub_ref: <pin>
    secrets:
      OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
```

Thin stubs may instead call Make directly (see `evals-make-select.yml`).

### Policy evolution

- **Today:** hub default PR is **eval-ci** (select then pack) via
  `eval-ci-pr.yml` → `eval-ci.yml`. Separate pack/select callables remain until
  Wave 2 consumers migrate. Do **not** treat empty select output as a required
  verify matrix on the hub PR.
- **Wave 2 secrets:** callers that already pin `eval-ci` without
  `OP_SERVICE_ACCOUNT_TOKEN` (or `secrets: inherit`) need a follow-up — org
  1Password service account with access to item `hutch-fail-platform-github`.
- **Follow-up:** optional second gate — applicable universe/language goals
  must be green or explicitly opted out. That gate is not enabled in this hub’s
  default PR workflow.
## Non-goals

- Soft LLM rubric judges
- Scraping public repos to detect language
- Replacing product-specific goal authorship
- Implementing harness filters or mandatory universe CI in the design PR

## Follow-up implementation slices

1. Schema enforcement — [#5](https://github.com/hutch-fail/evals/issues/5) (done in harness)
2. Harness `eval/list` + `eval/select` — [#6](https://github.com/hutch-fail/evals/issues/6) (done)
3. Manifest reader + doctor hint — [#7](https://github.com/hutch-fail/evals/issues/7) (done)
4. Reusable workflows + host stubs — [#8](https://github.com/hutch-fail/evals/issues/8) (done)
5. Universe migration + language seed — [#9](https://github.com/hutch-fail/evals/issues/9) (done)

## Meta-dev

This design document alone does not change harness or CI behavior, so it
does not require an eval pack. Any follow-up that changes gates or discovery
goes through **meta-dev** (certified-red goal → develop/solve → judge).
