---
schema: goal/v1
id: 20261009-kick-the-tires-structure-only
title: Structure-only IaC/examples cannot close done (kick-the-tires procedure)
scope: universe
fixture_dir: evals/fixtures/universe/20261009-kick-the-tires-structure-only
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
pack_quality: required
---

# Executive overview

A future task must not close `done` on factory/IaC/examples alone when the ask
was live behavior (the DEF-108 failure). This pack certifies that the evals hub
documents a kick-the-tires procedure (PM observable final state before build;
SDET fail-closed/certified-red gate) and ships a disposition grader that rejects
`done` for structure-only closeouts.

# Decision

A pass lets us claim the shared eval procedure and universal regression grader
are present in the hub. A pass does not prove every company AGENTS.md or PR
template already mirrors the rule (those land only after CEO/board approval of
the DEF-115 proposal pack).

This authoring run must not pass while the fixture baseline still omits the
PROCESS section or while the baseline grader always allows `done`.

# User outcome

Operators running this pack’s `check.sh` / `p2p-smoke.sh` exercise the hub
disposition grader: structure-only closeouts get `blocked`/`in_review`, not
`done`, and PROCESS documents the kick-the-tires gate. The grader entrypoint
is the observable effect — not that every company AGENTS.md already calls it.

# Scope

| Covered | Not covered |
| --- | --- |
| Hub `PROCESS.md` kick-the-tires section; `scripts/grade-structure-only-disposition.sh`; fixture cases | Hot-swapping company AGENTS/skills/PR templates without CEO/board sign-off |
| Universal structure-only disposition regression | Product-specific probe commands (see game-dev-agent-process) |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Baseline red | Unpatched fixture: `check.sh` fails (PROCESS section missing; baseline grader allows `done`) |
| Patched baseline green | After golden, `check.sh` runs grader — rejects structure-only-done |
| Live PROCESS | Hub `PROCESS.md` documents observable final state + fail-closed + blocked/in_review |
| Live grader | `p2p-smoke.sh` runs hub `grade-structure-only-disposition.sh` — rejects `done`, allows `blocked` |

# Dataset

One synthetic structure-only-done case and one structure-only-blocked case.
No train|test split.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Baseline criteria | `check.sh` | Fixture `baseline/` files + grader exit |
| Live criteria | `p2p-smoke.sh` | Grep/run against `HERMES_EVAL_REPO_ROOT` |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Is F2P red on baseline? | `make eval/assert-red GOAL=universe/20261009-kick-the-tires-structure-only` | already green |
| Does golden verify green? | `make eval/verify GOAL=universe/20261009-kick-the-tires-structure-only` | f2p/p2p fail |

# Execution

One local `assert-red` / `verify` cycle. No agent solver.

# Limitations

A pass does not install company-wide AGENTS closeout rules, the reusable
kick-the-tires skill, or PR template sections — those are proposed under
`evals/docs/proposals/DEF-115-kick-the-tires/` pending CEO/board confirmation.

**Adversarial / gaming risk:** a careful author can still get a false green by
adding a PROCESS section heading (or copying fixture prose) while leaving the
live hub `scripts/grade-structure-only-disposition.sh` allowing `done`, or by
only grepping fixture copies under `evals/fixtures/` without running the hub
grader against real disposition text. There is no oracle that the company
AGENTS/PR templates actually invoke this grader on closeout.

**Holdout:** Dataset ships only two synthetic cases (structure-only-done and
structure-only-blocked) with no train|test split; green does not claim
generalization to unseen company wording or product-specific probe packs.

# Result file

After the run, write `20261009-kick-the-tires-structure-only-result.md` beside
this goal. Commit that result in a later local commit, not with this goal or
its fixture.
