---
name: goal-author
description: >-
  Author or update goals and fixtures; certify F2P red via assert-red.
  Trigger on "author a goal", "write F2P eval", "certify red", or before
  goal-develop. Does not implement the product fix.
---

# goal-author

Create or revise a **goal/v1** (or product NNN-MM pack when working in a repo
that owns persistent evals). This hub supplies the templates, schema, and harness;
stop when `assert-red` (or the product’s equivalent) certifies F2P is red on
baseline.

Prefer skill **build-eval** for the interview → samples → cheapest grader →
executive overview → assert-red loop. Refuse a goal that is only frontmatter +
empty tables. Lead with `# Executive overview` (see `templates/goal.md`).
Preflight the universe pack-quality ratchet (`docs/meta-eval-quality.md`) when
keys allow.

Do **not** implement the product change here — that is **goal-develop**.

If your workspace is a product repo, read **`evals/PROCESS.md`** first.

## Where to write

Copy `templates/goal.md` (or `evals/templates/goal.md` from a host project)
and write the specification before the run. The filled example is
`goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab.md`.
Match that body. If asked to show the pre-run report, show the goal file.
Do not recap it. After the run, write `<goal>-result.md` beside the goal.
The example is
`goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab-result.md`.
A green check with no result file beside the goal is not done.
Commit the goal and the fixture first. Commit the result alone. These are
local `git commit` hooks, not a pull-request or merge check. Both commits may
be in one pull request. Squash or merge may combine them. Pre-commit
`eval-has-goal` requires a goal whose `fixture_dir` matches each fixture that
has `check.sh`. Pre-commit `result-not-with-eval` rejects a result staged with
that goal or fixture. `*-result.md` is not a goal.
The harness also fills `templates/result.md`
into `runs/<id>/<stamp>/result.md` on every command. The report leads with
Adopt, Hold, or Inconclusive. `make eval/report` prints it.

If the claim is that an agent used a tool, the check starts that agent (in the
runtime where the claim is made — e.g. an Incus guest when that is the SUT)
and reads what it did. Name each agent on its own row. A config file, a
projector writing into a throwaway directory, or a library script is not that
agent. One agent does not stand in for the others.

| Kind | Location | Commit? |
| --- | --- | --- |
| WIP (`scope: active`) | Same evals git tree on a feature branch | Yes (branch) |
| Hub methodology smoke | This hub’s tracked `goals/` + `fixtures/` | Yes (hub) |
| Durable product claim | Target repo’s tracked `evals/` (+ `docs/goals/` if NNN-MM) | Yes (product) |

## Where to put the pack

Mirror the guest/project mount. **Date-prefix** the filename and the frontmatter `id`:

```text
goals/github.com/<slug>/<repo>/YYYYMMDD-<kebab>.md
fixtures/github.com/<slug>/<repo>/YYYYMMDD-<kebab>/
```

HockeyMind example:

```text
evals/goals/github.com/hockeymind/hockeymind/20260916-studio-chat-channel-discipline.md
evals/fixtures/github.com/hockeymind/hockeymind/20260916-studio-chat-channel-discipline/
```

```yaml
id: 20260916-hockeymind-studio-chat-channel-discipline
fixture_dir: evals/fixtures/github.com/hockeymind/hockeymind/20260916-studio-chat-channel-discipline
```

Do **not** put new product-scoped goals at `goals/<name>.md` (flat root is for
legacy smoke only).

## Steps (hub harness / process SoT)

1. Resolve `<slug>/<repo>` from the project path (or `PROCESS.md` table).
2. Create the dated goal + fixture dirs above; frontmatter per `_schema.md`.
3. Ensure F2P check fails on the committed baseline (ordinary failure, not xfail).
4. From the hub root (or `make -C evals` from a host):

```bash
make eval/parse GOAL=github.com/<slug>/<repo>/YYYYMMDD-<kebab>
make eval/assert-red GOAL=github.com/<slug>/<repo>/YYYYMMDD-<kebab>
```

5. If assert-red **rejects** (already green or flaky): revise the eval; do not
   weaken checks. Re-run until `assert-red` prints certified red.
6. Hand off: goal id + path to latest `assert-red` manifest under `runs/`.
7. If the claim should persist with the product: promote into that repo’s tracked
   `evals/` (follow that project’s naming/docs) before closeout.

## Outcome vs check (prefer, not rigid)

Before assert-red, skim User outcome against Success criteria and Limitations:

- Prefer each **meaningful** outcome bullet maps to an observable criterion **or**
  sits under Limitations / Scope “Not covered.”
- Ambient claims (“login form works locally”) without either tend to produce
  false greens (e.g. HTML 200 while auth mode is wrong).
- Aspirational color in User outcome is fine; avoid treating it as Done unless
  something checks it or Limitations owns the gap.

When a criterion asserts a mode is **enabled** in one environment (Boat Access,
trusted headers, etc.), consider whether the product claim also needs the
opposite (local / unset → mode off). Prefer a sibling row or an honest
Limitations line — not a second pack for every dual-mode. Skip when the goal’s
Decision already excludes that plane.

Live PR curls are outside harness judge. When they close an uncovered outcome,
prefer a proof level that matches the claim (listen/HTML vs config/mode vs
interactive) — see `PROCESS.md` “Live proof levels (soft).”

## Forbidden

- Editing product code to make F2P pass
- Deleting/skipping/xfailing checks to force green
- Skipping assert-red before develop
- Flat undated goal names for product work
- Leaving durable product bars only as local uncommitted scratch when the claim belongs
  in the app repo
- Committing `<goal>-result.md` in the same local commit as the goal or the fixture. A pull request may contain both commits. Squash or merge may combine them.

## Related

- CLI shim: skill **goal**
- Next: **goal-develop** → **goal-judge**
- Orchestrator: **meta-dev**
- Docs: `PROCESS.md`, `README.md`
