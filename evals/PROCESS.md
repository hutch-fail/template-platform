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
[`docs/meta-eval-quality.md`](docs/meta-eval-quality.md). Bash budget for GHA
YAML + eval `check.sh` (≤~12 consecutive content lines; YAML ≤35% inline bash):
[`docs/evals.md`](docs/evals.md) § Bash budget (`20261014-bash-budget`).

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

### Launch path vs install path

`command -v`, `dpkg-query`, and a vendor XDG `.desktop` file prove **install**,
not **launch**, on a Kasm/openbox guest. The in-session SoT is openbox
`~/.config/openbox/menu.d/*.xml` (merged into `menu.xml`) plus a wrapper that
sets `DISPLAY` / sources `~/.config/desktop/env`. Packs that claim an operator
starts a GUI from the guest session are L2 interactive path: fixture and live
probe must grade that menu/launcher. A vendor CLI installer that also ships a
Desktop IDE needs either a `*-desktop` sibling pack with those criteria or an
explicit Limitations line (CLI-only / Desktop IDE out of scope). Tier-1
pack-quality lint enforces this on desktop-launch claims
(`docs/meta-eval-quality.md`).

### Use path vs wiring path

`grep -Fq 'ensure_…'` / “module exists” prove **wiring**, not **use**. If User
outcome or Success criteria claim operators run an entrypoint (ensure, heal,
reconcile, bootstrap, seed, mirror, bind) — or that invent/skills **receive**
seed / survive — the fixture must **kick the tires**: call that entrypoint (or
run the documented `./scripts/…` / `make up|ensure|bootstrap`), then assert an
observable. Greps of implementing files may be extra rows, never the only
grader for a behavior claim.

When the fixture already exercises an ensure/seed/heal-class entrypoint, also
grade **reconverge**: a second call / idempotent pass (the day-2 `make ensure`
loop). Cold-start-only packs must say so under Limitations (`single-shot only`
/ `reconverge out of scope`). Tier-1 pack-quality lint enforces use-path on
behavior claims (`docs/meta-eval-quality.md`); selftest samples are
`samples/good-use` and `samples/bad-use`.

For **lib / prefer-path** claims (pure logic, cost resolution, adapters), a
hermetic **unit-test exercise** counts as kick-the-tires: the fixture runs the
CI-backed runner (`node --test`, `pytest`, `npm test`, `bash tests/unit/…`,
etc.) and asserts an effect. User outcome may still state the production *why*
when Limitations own live proof as hold-out. That is **not** a substitute for
ensure/heal reconverge on operator entrypoint claims.

### Live path vs probe-script path

`grep -Fq 'curl'` inside `scripts/probe-….sh` proves **wiring**, not that
operators get a working Host. If User outcome or Success criteria claim a
portless URL (`*.localhost`), `/dashboard`, or “curl health → 200”, the L0
tire-kick is the product **doctor / `test/smoke` / `make up`** path — not a
one-off `HERMES_EVAL_LIVE_*` eval pack.

Hermetic F2P must assert that smoke (or doctor) **invokes** the probe when the
feature is enabled. Done for the operator URL claim requires actually running
that smoke (`make test/smoke` or `make up`) and recording a **live-proof**
artifact (smoke log / HTTP codes) under Manual verification. Grepping that the
probe script mentions `curl` may be an extra row, never the only grader.

Escape hatch: Limitations `live-path out of scope` / `hermetic wiring only` —
then the Result must **not** recommend PASS/Adopt for the Host URL claim.
Tier-1 pack-quality lint enforces live-path (`samples/good-live` /
`samples/bad-live`).

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

## Kick-the-tires / structure-only disposition

When a task asks to install, configure, hire, run, publish, demo, integrate,
converge, or verify — **structure alone is not done**.

### Before build (fail-closed)

1. **PM** defines an **observable final state** in the PRD/acceptance criteria:
   what a reviewer can see or run (command exit, listen port, rendered asset,
   PR URL), not only which files should exist.
2. **SDET** maps the highest-risk claim to a fail-closed gate (unit/integration
   check and/or F2P/P2P goal under the product’s tracked `evals/`) and certifies
   that gate **red** on the unbuilt/broken baseline before implementation lanes
   start.
3. **Acceptance surface** is explicit for UI/UX work:
   desktop/remote-desktop apps need an in-session launch path (menu item,
   launcher, or `.desktop` entry as appropriate), and web apps need the
   expected product navigation/link surface such as the Meter link when that is
   part of the operator workflow. `command -v`, package install, or a listening
   port is not enough for a UI outcome unless the PRD explicitly scopes UI
   launch/navigation out.
4. Implementation may proceed only after that red certification (or an explicit
   board/PM waiver naming what remains unproven).

### Universal regression (structure-only close)

If an agent writes IaC, factory seats, examples, or docs but never **runs**,
**converges**, or **surfaces** them as a durable artifact outside a transient
workspace, disposition must be `blocked` or `in_review` — **not** `done`.

Grade synthetic closeouts with (from the evals hub root):

```bash
bash scripts/grade-structure-only-disposition.sh \
  fixtures/universe/20261009-kick-the-tires-structure-only/cases/structure-only-done.json
```

Expected: non-zero exit (reject `done`). Universe pack:
`goals/universe/20261009-kick-the-tires-structure-only.md`.
From a host checkout: prefix with `evals/` or `make -C evals`.

Game-dev instance of this bar:
`goals/github.com/hutch-fail/game-dev-agent-process.md` (probe + durable PR
evidence + waivers).

### Closeout checklist (eval procedure)

| Required | Signal |
| --- | --- |
| Observable final state named before build | PRD / acceptance criteria |
| Highest-risk claim has certified-red gate | `make -C evals eval/assert-red GOAL=…` |
| UI launch/navigation surface covered | desktop menu/launcher or web Meter link acceptance criterion/eval, or explicit waiver |
| Live/runtime proof or explicit waiver | command log, screenshot, artifact path, or board waiver |
| Durable surface | committed/pushed reviewable PR (or child-repo PR) — not workspace-only |
| Structure-only ⇒ not done | grader rejects `done` without run/converge/surface |

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
   headline claim as proven; name the gap under Limitations. Host URL / health
   L0 claims follow **Live path vs probe-script path**: wire into
   doctor/`test/smoke`, then run smoke for Done — do not invent parallel live
   evals as the primary bar.
4. **Verify on a throwaway environment, not your long-lived one.** Long-lived
   instances carry cached images, hand tweaks and "already installed" stamps
   that hide first-run failures (an idempotent step that says "skip" never
   re-runs the code you changed).
5. **A bug found by a manual run gets a regression test** in the fix PR: it
   fails before the fix and passes after, and the PR says so.

Enforced in CI: `assert_pr_has_eval_pack.sh --mode ci` rejects any result file
*added* in the PR that lacks a non-empty `# Manual verification` section (use
`None — <why>` when nothing was run by hand). Existing results are not
rewritten; modifying them (for example hub sync) does not re-apply the section gate.

### UI/UX PR screenshots

When a pull request touches UI/UX surfaces (non-test `*.tsx` / `*.jsx`,
stylesheets, `design/**`, design-system / north-star docs, or `ui-*` process
fixtures), the **PR description** must include before and after screenshots or
clips (markdown/`<img>` / GitHub attachment URLs) so reviewers can see the
visual delta. Escape hatch on the same PR body:

`UI before/after: n/a — <short reason>`

(for copy-only, non-visual refactors, etc.). Enforced in CI by
`assert_pr_has_eval_pack.sh` when `EVALS_PR_BODY` is set (eval-ci / eval-pack
gate); unset locally skips the screenshot gate. A listening port or hermetic
unit green is not a substitute for showing the UI change.

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

Example org procedures: `.cursor/rules/live-verify.mdc` (real-system evidence;
ask before disruptive live checks); `.cursor/rules/wrap-prior-art.mdc` (pin and
wrap named upstreams; do not rewrite their source). Product-specific green paths
belong in that repo’s `AGENTS.md`. See [`docs/prior-art.md`](docs/prior-art.md).

## Skills

Use hub skills: `goal-author` → `goal-develop`|`goal-solve` → `goal-judge`,
orchestrator `meta-dev`, CLI shim `goal`. Host projects: run
`evals/scripts/install-host-adapters.sh` so editors discover them.
