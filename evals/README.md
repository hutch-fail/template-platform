# Goal methodology (evals hub)

This repository owns the **templates, harness, Make API, process docs, and
skills** for architecting, designing, and running goals. Org consumers refresh
`evals/` primarily via **file sync** (`make sync/pull` / `scripts/sync-pull.sh`);
git subtree and volume mounts remain valid local options.

| Distribution | How it appears | Day-to-day |
| --- | --- | --- |
| **File sync (org primary)** | `scripts/sync-pull.sh` → `<repo>/evals/` | Harvest → hub PR → redistribute ([`docs/syncing.md`](docs/syncing.md)) |
| **Git subtree** | `<repo>/evals/` vendored from this hub | Self-contained clones; `make -C evals eval/…` |
| **Volume / bind mount** | Same path layout mounted from a shared host tree | Local convenience; required for `attachment: ephemeral` OSS trees |

`evals/scope.yaml` `attachment:` (`ephemeral` \| `kit` \| `full`) is the persist
policy: what the consumer **git remote** may contain. Local `./evals` can still
hold kit + own packs. See [`docs/consuming.md`](docs/consuming.md).

This is a **breaking consumer contract** (semantic-release major): default
`full` keeps prior org remotes, but `kit` / `ephemeral` change what may be
committed, and `eval/doctor-attach` fails closed on leaks.

After sync/subtree/mount, run [`scripts/install-host-adapters.sh`](scripts/install-host-adapters.sh)
from the **host project root** so `.cursor/skills` and `.agents/skills` point
into `evals/skills/`. Details: [`docs/consuming.md`](docs/consuming.md),
[`docs/syncing.md`](docs/syncing.md).

## Pre-run report

The specification written before a run **is** the goal file. Copy
[`templates/goal.md`](templates/goal.md) and keep those headings. After the run,
write `<goal>-result.md` beside the goal. A green check with no result file
beside the goal is not done. Commit the result in a **later** local commit, not
with the goal or fixture. Both commits may be in one pull request.

Filled examples (methodology seed):

- Goal: [`goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab.md`](goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab.md)
- Result: [`goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab-result.md`](goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab-result.md)

If the claim is that an agent used a tool, the check starts that agent in the
runtime under test. A config file, throwaway projector run, or library script is
not that agent.

## Three homes for eval material

| Home | What lives there | Commit? |
| --- | --- | --- |
| **This hub (kit + seed)** | `harness/`, `skills/`, schema, smoke goals/fixtures, docs, Make API | Yes — in this repo; consumers vendor via subtree/mount |
| **WIP (`scope: active`)** | Feature-branch packs under this evals git tree; skipped by default select until Adopt | Yes — in git; not standing CI until promoted |
| **Product packs** | Durable claim packs under `evals/goals/github.com/…` | On the **hub** for `ephemeral`/`kit` consumers; also in the product remote when `attachment: full` |

## Product goal paths (required)

```text
goals/github.com/<org>/<repo>/YYYYMMDD-<kebab>.md
fixtures/github.com/<org>/<repo>/YYYYMMDD-<kebab>/
```

Frontmatter `id` is flat and date-prefixed (no `/`). `GOAL=` may be an id
(resolved under `goals/`, including nested paths) or a path under `goals/`
without `.md`. Universe smoke lives under `goals/universe/` (e.g.
`GOAL=fixture-token-echo`). Do not add new product-scoped goals at the flat
`goals/` root.

## Scoping (universe / repo / language / active-dev)

Which goals apply where is defined in [`docs/scoping.md`](docs/scoping.md):
frontmatter `scope:`, path homes, consumer `evals/scope.yaml` (languages +
documented opt-outs), and dual CI hooks (hub reusable workflows + thin Make
stubs under [`templates/github-workflows/`](templates/github-workflows/)).
Schema keys are in [`goals/_schema.md`](goals/_schema.md).

## Invoking the harness

**Hub root (this repo):**

```bash
make eval/assert-red GOAL=fixture-token-echo
make eval/verify GOAL=fixture-token-echo
make eval/solve GOAL=fixture-token-echo-agent
```

**Host with this hub at `./evals`:**

```bash
make -C evals eval/assert-red GOAL=fixture-token-echo
# or:
EVALS_ROOT="$PWD/evals" bash evals/harness/goal.sh assert-red fixture-token-echo
```

`EVALS_ROOT` (preferred) / `HERMES_EVALS_ROOT` select the goals/fixtures/runs
tree (default: this evals git tree — hub or product sync/subtree/mount).
`HERMES_EVAL_REPO_ROOT` is set by the harness to the repository that contains
the hub (subtree parent when the hub directory is named `evals`).

Operator pointer: [`docs/evals.md`](docs/evals.md). Hypothesis loop:
[`docs/hypothesis-playground.md`](docs/hypothesis-playground.md).

## Layout

```text
evals/   (this repo, or <project>/evals after subtree)
├── README.md PROCESS.md AGENTS.md Makefile
├── harness/                 # goal.sh + solver helpers
├── skills/                  # goal*, meta-dev, build-eval, hillclimb, …
├── .cursor/skills → skills/ # hub-as-repo adapters
├── .agents/skills → skills/
├── docs/
├── templates/
├── goals/  fixtures/  runs/
├── tests/unit/
└── scripts/install-host-adapters.sh
```

## Meta-dev loop

| Skill | Role |
| --- | --- |
| **meta-dev** | Orchestrator: author → develop\|solve → judge |
| **goal-author** | Write goals + fixtures; `assert-red` until certified |
| **goal-develop** | Implement in scope only; never weaken evals |
| **goal-solve** | TB2a: `assert-red` then solve (`solver: agent`) |
| **goal-judge** | Static verify / solve / run / report; fail closed; result + proof |
| **build-eval** | Design packs (executive voice → assert-red) |
| **hillclimb** | Optimize with train/test; result + proof snippets |
| **goal** | Low-level harness CLI shim |

Cursor rule: `.cursor/rules/meta-dev.mdc`. Agent prefs: [`AGENTS.md`](AGENTS.md).
Pack-quality ratchet: [`docs/meta-eval-quality.md`](docs/meta-eval-quality.md).

## TB1 smoke / TB2a

```bash
make eval/parse GOAL=fixture-token-echo
make eval/assert-red GOAL=fixture-token-echo
make eval/verify GOAL=fixture-token-echo
make eval/solve GOAL=fixture-token-echo-agent   # TB2a mock solver
```

- **F2P:** must fail on baseline (`assert-red`); must pass after the allowed change.
- **P2P:** must stay green on baseline and after the change.
- Never weaken, delete, skip, or xfail checks to force green.

## Gates

Local pre-commit: `eval-has-goal`, `result-not-with-eval`, `pr-has-eval-pack`.
PR job: [`.github/workflows/eval-pack.yml`](.github/workflows/eval-pack.yml).
Host-consumer hook snippet: [`docs/evals.md`](docs/evals.md).
Scoping and reusable CI design: [`docs/scoping.md`](docs/scoping.md).

## Releases

This hub’s versions are cut by a thin
[`.github/workflows/release.yml`](.github/workflows/release.yml) that calls
[`hutch-fail/actions`](https://github.com/hutch-fail/actions) reusable
semantic-release (org-wide Actions home). GitHub Release + notes, PR/issue
comments, `released` label; **no** in-repo `CHANGELOG.md`. Stub copy:
[`templates/github-workflows/release.yml`](templates/github-workflows/release.yml).
Prefer `@vX.Y.Z` once tags exist (same idea for eval `hub_ref` pins).

## Schema

See [`goals/_schema.md`](goals/_schema.md). Full agent-facing process copy:
[`PROCESS.md`](PROCESS.md).
