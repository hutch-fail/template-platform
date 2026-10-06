# Process evals

This file ships inside the shared `evals` hub (org **file sync** primary; git
**subtree** or volume **mount** also fine). It is the agent-facing process guide.

| Path in a product workspace | What it is | Commit to the product repo? |
| --- | --- | --- |
| `evals/` (sync / subtree / mount) | Shared harness, skills, templates, methodology + (when `attachment: full`) product claim packs | **Depends on `attachment:`** — `ephemeral`: never; `kit`: kit + universe/language + `scope.yaml` only; `full`: also own `evals/goals|fixtures/github.com/<org>/<repo>/`. Packs for `ephemeral`/`kit` are harvested to the hub ([`docs/syncing.md`](docs/syncing.md), [`docs/consuming.md`](docs/consuming.md)) |

This hub owns `make eval/…`, `harness/`, and `skills/`. From a host project:

```bash
make -C evals eval/assert-red GOAL=…
# after sync/subtree/mount, once:
bash evals/scripts/install-host-adapters.sh
```

## Pre-run report

The pre-run report **is** the goal file, not a recap. Copy
`evals/templates/goal.md` (lead with `# Executive overview`) and keep the same
headings. After the run, write `<goal>-result.md` beside the goal with plain
language outcome and **proof snippets** from harness output. A green check with
no result file is not done. Commit the result in a later local commit, not with
the goal or fixture. Both commits may be in one pull request. Squash or merge
may combine them.

Process skills: **build-eval** (design packs), **hillclimb** (optimize with
train/test discipline). Universe pack-quality ratchet:
[`docs/meta-eval-quality.md`](docs/meta-eval-quality.md).

If the claim is that an agent used a tool, the check starts that agent in the
runtime under test. A config file, a throwaway projector run, or a library
script is not that agent.

## Where to put a new product goal

Mirror the GitHub org/repo leaf you are editing:

```text
goals/github.com/<org>/<repo>/YYYYMMDD-<kebab>.md
fixtures/github.com/<org>/<repo>/YYYYMMDD-<kebab>/
```

**Date-prefix required** (`YYYYMMDD-`). Do not invent flat names at
`goals/<name>.md` for product work (smoke goals like `fixture-token-echo` are
the exception).

### Example

```text
evals/
├── PROCESS.md
├── goals/github.com/<org>/<repo>/YYYYMMDD-<kebab>.md
└── fixtures/github.com/<org>/<repo>/YYYYMMDD-<kebab>/
    ├── check.sh
    └── p2p-smoke.sh
```

```yaml
id: YYYYMMDD-<org>-<repo>-<kebab>
fixture_dir: evals/fixtures/github.com/<org>/<repo>/YYYYMMDD-<kebab>
```

```bash
make -C evals eval/assert-red GOAL=github.com/<org>/<repo>/YYYYMMDD-<kebab>
```

### Other org examples

| Workspace | Goal path under `evals/goals/` |
| --- | --- |
| HockeyMind | `github.com/hockeymind/hockeymind/YYYYMMDD-…` |
| Hermes | `github.com/hermes/hermes/YYYYMMDD-…` |
| Function-Health app | `github.com/function-health/applications/<app>/YYYYMMDD-…` |

## Distribution

- **Sync / subtree (primary):** vendor this hub into `<product>/evals/`. Product PRs
  carry harness/skill updates (when pulled) and, for `attachment: full`, product goals.
- **Volume mount / `attachment: ephemeral`:** local `evals/` must not be committed;
  durable packs still live on the hub own-leaf.
- **`attachment: kit`:** commit the kit; keep `github.com/**` packs gitignored and
  harvested to the hub.
- **WIP / active:** author on a feature branch under this same `evals/` git tree
  (`scope: active` stays out of default CI select until Adopt).

See [`docs/consuming.md`](docs/consuming.md).

## Harness commands

```bash
# hub root
make eval/assert-red GOAL=github.com/<org>/<repo>/YYYYMMDD-<kebab>
make eval/report GOAL=github.com/<org>/<repo>/YYYYMMDD-<kebab>

# host
make -C evals eval/assert-red GOAL=github.com/<org>/<repo>/YYYYMMDD-<kebab>
EVALS_ROOT=/path/to/evals bash evals/harness/goal.sh assert-red …
```

Author from `evals/templates/goal.md` before the run. Never weaken checks to
force green.

## Outcome vs check (soft)

Harness green means the **written criteria** passed — not every sentence under
User outcome. Prefer that meaningful outcome bullets either map to a Success
criteria row (observable) or sit honestly under Limitations / Scope “Not
covered.” Ambient README hope (“local login form works”) without either is easy
to misread as proven.

When a pack asserts one environment enables a mode (e.g. Boat trusted-header
SSO), consider whether the opposite mode matters for the claim (e.g. local
without that mode). A sibling criterion or an explicit Limitations line is
usually enough; not every dual-mode needs a second pack.

### Live proof levels (soft)

Ad-hoc live curls in a PR test plan are outside harness judge. When you do live
V&V, prefer matching the level to the outcome you care about — not only the
cheapest green:

| Level | Roughly | Example |
| --- | --- | --- |
| L0 | Process listens / document GET | `curl` → HTTP 200 HTML |
| L1 | Product mode / config shape | API or inspect shows auth mode, feature flags |
| L2 | Interactive path | Signup/login or equivalent happy path |

“UI loads” for an auth-gated surface often wants at least L1. L0 alone is fine
when the claim is truly “something answers on that Host.” Avoid treating L0 as
Done for outcomes that need a mode or session unless Limitations says so.

## Manual verification becomes a test

A check you ran by hand and saw pass is proof that an automated check can
exist. Do not leave it as prose in a PR description or result file.

1. **Every manual pass gets an automated check.** If you verified something by
   hand (ran a command, curled an endpoint, ran `make up` on a box, clicked
   through), the PR carries a check that asserts the same observable. If it
   truly cannot be automated, the result says why under `# Manual verification`
   and gives the exact command plus where its proof artifact lives.
2. **Say which tier you have.** *Hermetic*: runs anywhere (CI, `make test`)
   against stubs or a sandbox; it proves wiring, ordering, defaults and error
   messages, not the real world. *Live*: needs the real environment; it must
   produce a **proof artifact written by a script** (command, exit code, commit
   SHAs, timestamps), not text typed into a result file.
3. **End-to-end claims need an end-to-end check.** A claim like "`make up`
   works from a fresh clone" is graded by a check that executes that path from
   the documented starting state (fresh clone → copy the example config →
   run). `grep`s of the files that implement it may be extra rows, never the
   only grader. If only a static check ran, the result must not present the
   headline claim as proven; name the gap under Limitations.
4. **Verify on a throwaway environment, not your long-lived one.** Long-lived
   instances carry cached images, hand tweaks and "already installed" stamps
   that hide first-run failures (an idempotent step that says "skip" never
   re-runs the code you changed).
5. **A bug found by a manual run gets a regression test** in the fix PR: it
   fails before the fix and passes after, and the PR says so.

Enforced in CI: `assert_pr_has_eval_pack.sh --mode ci` rejects any result file
added or changed in the PR that lacks a non-empty `# Manual verification`
section (use `None — <why>` when nothing was run by hand). Existing results
are not rewritten.

## Procedure homes

Claims homes are normative in [`docs/scoping.md`](docs/scoping.md). Procedures
(rules, skills, scripts, product `AGENTS.md`) follow the same scopes—do not
fork the claims table:

| Scope | Procedures home |
| --- | --- |
| Org-wide (`universe`) | Hub `.cursor/rules/`, `skills/`, kit scripts; consumers get them via sync/subtree/mount + `evals/scripts/install-host-adapters.sh` |
| Tag / language | Hub language skills/docs + `eval/bars`; product opts in via `evals/scope.yaml` `languages:` |
| Repo | Product-root `AGENTS.md` + Makefile/scripts (call hub kit; keep product paths out of universe rules) |
| Active (WIP) | Stay on the feature branch with the pack until Adopt; then promote into the product or hub home above |

Example org procedure: `.cursor/rules/live-verify.mdc` (real-system evidence;
ask before disruptive live checks). Product-specific green paths belong in that
repo’s `AGENTS.md`.

## Skills

Use hub skills: `goal-author` → `goal-develop`|`goal-solve` → `goal-judge`,
orchestrator `meta-dev`, CLI shim `goal`. Host projects: run
`evals/scripts/install-host-adapters.sh` so editors discover them.
