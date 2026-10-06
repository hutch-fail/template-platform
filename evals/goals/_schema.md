# schema: goal/v1

Flat `key: value` lines inside the first `---` block (nested YAML is docs-only
unless noted).

## Path layout

The shared `evals` recipe (harness + templates) is distributed by **git
subtree** or **volume mount**. Goals may live in:

| Home | Path shape | Commit? |
| --- | --- | --- |
| Override root | `EVALS_ROOT` / `HERMES_EVALS_ROOT` → another evals checkout | Optional |
| Shared recipe smoke / seed | Recipe `evals/goals` + `fixtures` (incl. `fixture-token-echo*`) | Yes — in canonical `evals` |
| Product packs | Product repo `evals/goals/github.com/<org>/<repo>/` | Yes — with the product |

### Product / process goals (required layout)

**Date-prefix every new goal** (`YYYYMMDD-`) so the tree sorts chronologically:

```text
goals/github.com/<org>/<repo>/YYYYMMDD-<kebab>.md
fixtures/github.com/<org>/<repo>/YYYYMMDD-<kebab>/
```

| Example workspace | Goal file |
| --- | --- |
| platform-github | `goals/github.com/hutch-fail/platform-github/20260921-manage-evals-repo.md` |
| HockeyMind | `goals/github.com/hockeymind/hockeymind/20260916-studio-chat-channel-discipline.md` |
| Function-Health app | `goals/github.com/function-health/applications/<app>/20260916-<kebab>.md` |
| Hermes | `goals/github.com/hermes/hermes/20260916-<kebab>.md` |

Invoke with the path under `goals/` (no `.md`):

```bash
HERMES_EVALS_ROOT="$PWD/evals" bash evals/harness/goal.sh assert-red \
  github.com/hutch-fail/platform-github/20260921-manage-evals-repo
```

Frontmatter `id` must be **flat** (no `/`; used as `runs/<id>/`) and should
**also** start with `YYYYMMDD-`, e.g.
`20260921-platform-github-manage-evals-repo`.

Agents in a product repo with a vendored `evals/`: open `evals/PROCESS.md`.
Start at `PROCESS.md` in this evals tree.

Every goal body is a specification written before the run. The filled example
is [`20260918-graft-mini-svc-ab.md`](github.com/hermes/hermes/20260918-graft-mini-svc-ab.md).
Show that file when asked for the pre-run report. Do not recap it. Copy
[`evals/templates/goal.md`](../templates/goal.md) and keep the same headings,
including `Set before the run.` above the Acceptance gates table, and a Result
file section. After the run, write `<goal>-result.md` beside the goal. The
example is
[`20260918-graft-mini-svc-ab-result.md`](github.com/hermes/hermes/20260918-graft-mini-svc-ab-result.md).
A green check with no result file beside the goal is not done. Do not commit
that result in the same local `git commit` as the goal or the fixture. Both
commits may be in one pull request. Squash or merge may combine them. The
pre-commit hooks are local only. A fixture with `check.sh` must be the
`fixture_dir` of a goal markdown. `*-result.md` is not that goal. If the claim is
that an agent used a tool, the check starts that agent inside the Incus guest.
A config file, a throwaway projector run, or a library script is not that
agent. One agent does not stand in for the others. Every harness command writes
a decision report from [`evals/templates/result.md`](../templates/result.md)
to `result.md` next to `manifest.json`. `make eval/report` prints that report.
The opening states the recommendation: Adopt, Hold, or Inconclusive.

### Legacy / smoke

Flat goals under `evals/goals/*.md` are **legacy-only** (historical smoke).
Universe smoke now lives under `evals/goals/universe/`. Do **not** add new
product-scoped goals at the flat root. The Hermes repo keeps a
seed copy; `make up` copies into the host SoT once (no overwrite of existing
files) and refreshes recipe-owned `PROCESS.md` + `_schema.md`.

Promote durable product claims into the app’s tracked `evals/` rather than
leaving them only in the process SoT.

### Scoping (enforced)

Normative design: [`docs/scoping.md`](../docs/scoping.md). Keys below are
validated by `harness/lib/scope.sh` via `require_goal_v1` on `parse`,
`assert-red`, and other harness verbs.

| Key | Values | Meaning |
| --- | --- | --- |
| `scope` | `universe` \| `language` \| `repo` \| `active` | Who the goal binds; if omitted, infer from path |
| `languages` | e.g. `typescript` | Required when `scope: language`; matched to consumer `evals/scope.yaml` |
| `repos` | e.g. `github.com/org/repo` | Optional; path usually encodes repo identity |

Path homes (in addition to today’s `github.com/<org>/<repo>/`):

```text
goals/universe/YYYYMMDD-<kebab>.md
goals/language/<lang>/YYYYMMDD-<kebab>.md
```

Legacy flat smoke was treated as proto-`universe` until migrated under
`goals/universe/` (#9). `scope: active`
belongs only in the process SoT — not under product `evals/goals/`. Unknown
`scope` values and path/frontmatter mismatches fail closed.

Consumer opt-out / language list: product-owned `evals/scope.yaml`
(`evals-scope/v1`). See scoping design for selection rules and CI hooks.

## Required (all goals)

| Key | Required | Meaning |
| --- | --- | --- |
| `schema` | yes | Must be `goal/v1` |
| `id` | yes | Stable goal id under `evals/runs/<id>/`; **date-prefixed**, no `/` |
| `title` | no | Human title |
| `fixture_dir` | yes | Repo-relative path to fixture workspace |
| `f2p_check` | yes | Executable under fixture that must be red on baseline |
| `p2p_check` | yes | Executable under fixture that must stay green |
| `golden_patch` | yes for `verify` | Unified diff applied with `patch -p1` in a temp copy |

Capability judges may read the Hermes tree via harness-exported
`HERMES_EVAL_REPO_ROOT`.

## Agent solver (TB2a — `make eval/solve`)

| Key | Default | Meaning |
| --- | --- | --- |
| `solver` | `none` | `none` = static TB1 only; `agent` = run solve path |
| `solver_bin` | required if `agent` | `claude` \| `cursor-agent` \| `codex` \| `hermes`, or a repo-relative `.sh` path (e.g. mock) |
| `solver_prompt` | required if `agent` | Repo-relative markdown/text fed to the CLI |
| `max_wall_seconds` | `300` | Kill solver if exceeded |

Override binary at runtime: `HERMES_EVAL_SOLVER_BIN=/path/to/bin`.

Hard success after solve remains static F2P + P2P. Soft LLM rubrics are out of
scope for TB2a.

## A/B arms (`make eval/ab`)

Flat keys. Both arms copy the fixture, apply an overlay directory, run the
solver, then score the same F2P + P2P checks. `HERMES_EVAL_SOLVER_BIN` overrides
**both** arms (fair live comparison). `HERMES_EVAL_MODEL_PIN` overrides
`model_pin`.

| Key | Default | Meaning |
| --- | --- | --- |
| `trials` | `3` | Repetitions per arm |
| `model_pin` | empty | `free-*`, `dev-auto`, or `hermes-free` only (recorded, exported as `HERMES_EVAL_MODEL_PIN`, passed to `hermes chat -m`). Paid pins are refused. `HERMES_EVAL_PROVIDER` selects the Hermes provider (for example `litellm-hermes`) |
| `max_wall_seconds` | `180` on `ab` (`300` on `solve`) | Kill each solver if exceeded |
| `max_wall_ratio` | `1.2` | Fail if treatment median wall / control median wall exceeds this |
| `max_token_ratio` | `1.2` | Same for parsed `tokens_in+tokens_out`. Unparsed tokens do not fail the run |
| `control_overlay` | required for `ab` | Dir under the fixture copied onto the control workspace |
| `treatment_overlay` | required for `ab` | Dir under the fixture copied onto the treatment workspace |
| `control_solver_bin` | `solver_bin` | Control solver |
| `treatment_solver_bin` | `solver_bin` | Treatment solver |

`compare.json` fields include `verdict` (`pass`/`fail`), `efficiency`
(`improves` / `wall_improves` / `non_degrade` / `degrades`), `adoption`
(`inconclusive` when either solver path ends in `.sh`; otherwise `reject` or
`measured_pass`), `reason`, median wall, and token medians when both arms
have counts. Counts come from `tokens_in=` / `tokens_out=` lines, a usage JSON
object, or the Hermes session row named by `session_id:` in the transcript.
Unparsed tokens do not fail the run and are not a token win.

Quality gate: each arm’s F2P+P2P success rate ≥ 2/3 **and** treatment successes
≥ control successes. Speed/token gates run only after quality holds. A mock
`.sh` pass is **not** an adoption verdict.

## Docs-only

Nested `budgets:` / `success:` remain documentation unless a flat key above
covers the same concern (`max_wall_seconds` is enforced on solve).
