---
schema: goal/v1
id: 20261001-live-verify-org-rule
title: Org live-verify rule ships via host adapters
scope: universe
fixture_dir: evals/fixtures/universe/20261001-live-verify-org-rule
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

# Executive overview

Org agents should treat “works” / “done” as a live-system claim, ask before
disruptive probes when a stack may be in use, and keep product-specific paths
out of the shared rule. This pack certifies that
`.cursor/rules/live-verify.mdc` exists with that contract and that
`scripts/install-host-adapters.sh` lists it next to `meta-dev.mdc` /
`goal-spec.mdc`, with a short procedure-homes pointer in PROCESS.md.

# Decision

A pass lets us say the hub redistributes an org-generic live-verify procedure
through host adapters. A pass does not prove every laptop already re-ran
`install-host-adapters.sh`, nor that product `AGENTS.md` files document stack
green paths.

This authoring run must not pass while the fixture baseline still omits the
rule and adapter entry. The check does not read `origin/main` alone.

# User outcome

Agents working in any consumer of this kit get the same live-verify bar without
copying personal `~/.cursor` rules, and they ask before disruptive live checks.

# Scope

| Covered | Not covered |
| --- | --- |
| Fixture baseline rule + adapter list; live `.cursor/rules/live-verify.mdc`, `scripts/install-host-adapters.sh`, `PROCESS.md` Procedure homes | Re-running adapters on every laptop; product Incus/volumes recipes; retiring personal `live-verify-not-weasel.mdc` |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Baseline red | Unpatched fixture lacks `live-verify.mdc` and adapter listing |
| Patched baseline green | After golden, rule has `alwaysApply`, ask-before, real evidence; adapter lists `live-verify.mdc`; no product hosts |
| Live rule present | Hub `.cursor/rules/live-verify.mdc` matches the contract |
| Live adapter wired | `scripts/install-host-adapters.sh` lists `live-verify.mdc` |
| Procedure homes | `PROCESS.md` has a Procedure homes subsection |

# Dataset

One fixture baseline that omits the rule and adapter entry. Live hub files after
the change. No train|test split and no held-out repository — this is a
single-case kit presence bar.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Baseline criteria | `check.sh` | Files under fixture `baseline/` |
| Live criteria | `p2p-smoke.sh` | Grep on `HERMES_EVAL_REPO_ROOT` |

No second model. The check does not start an agent.

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Assert-red then verify? | Certified red; verify green after golden | Either wrong |
| Live rule org-generic? | No Incus/volumes/Colima in the rule | Product paths in universe rule |
| Adapter lists rule? | `live-verify.mdc` in the rule loop | Only meta-dev/goal-spec |

# Execution

One local `assert-red` / `verify` cycle. No agent solver.

# Limitations

No hold-out set beyond the fixture baseline vs live hub contrast. A pass does
not prove personal `~/.cursor/rules/live-verify-not-weasel.mdc` was removed on
any machine. A pass does not prove product repos already document host-plane
green paths in `AGENTS.md`.

# Result file

After the run, write `20261001-live-verify-org-rule-result.md` beside this goal.
Commit the result in a later local commit, not with this goal or its fixture.
Both commits may be in one pull request.
