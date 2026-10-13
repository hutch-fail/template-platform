---
schema: goal/v1
id: 20261005-wrap-prior-art
title: Org wrap-prior-art rule ships via host adapters
scope: universe
fixture_dir: evals/fixtures/universe/20261005-wrap-prior-art
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
pack_quality: required
---

# Executive overview

When an upstream already owns a mechanism, this kit should pin it unmodified
and wrap it rather than rewrite it. This pack’s F2P entrypoint certifies the
hub ships `.cursor/rules/wrap-prior-art.mdc`, lists it in
`scripts/install-host-adapters.sh`, and names it in PROCESS / docs. A pass
lets us redistribute that procedure file set. A pass does not prove every
laptop re-ran adapters or that agents obey the rule in chat.

# Decision

A pass lets us say the hub tree contains the wrap-don't-rewrite procedure
files and the F2P/P2P entrypoints stay green. A pass does not prove the hub
OptMem store itself — that is hub-only
`github.com/hutch-fail/evals/20261005-optmem-repo-memory`. This authoring run
must not pass while the fixture baseline still omits the rule and adapter
entry.

# User outcome

Operators run `check.sh` / `p2p-smoke.sh`. Each entrypoint asserts the
wrap-prior-art rule and adapter listing, then writes an observable marker file
(`.wrap-prior-art-ok` / `.wrap-prior-art-p2p-ok`). That marker is the graded
effect. This pack does not claim agents follow the rule in sessions.

# Scope

| Covered | Not covered |
| --- | --- |
| Rule file, adapter list, PROCESS pointer, docs/prior-art.md on live hub | Product OptMem rollout; relicensing OptMem; agent session obedience |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Baseline red | `check.sh` exit non-zero; no `.wrap-prior-art-ok` marker |
| Patched baseline green | After `golden.patch`, `check.sh` exit 0 and `.wrap-prior-art-ok` exists |
| Live hub | `p2p-smoke.sh` exit 0 and `.wrap-prior-art-p2p-ok` exists |

# Dataset

One fixture baseline that omits the rule. Live hub files after the change. No
train/test split — Limitations owns the single-case gap.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Baseline | program (`check.sh`) | Exit + marker after invoke |
| Live | program (`p2p-smoke.sh`) | Exit + marker after invoke |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Assert-red then verify? | Certified red; verify green after golden | Either wrong |

# Execution

One local `assert-red` / `verify` cycle. No agent solver.

# Limitations

Does not prove agents wrap upstreams in sessions, that personal Cursor rules
were removed on laptops, or that product OptMem stores follow the rule.
A careful author could game the marker without a real rule file if the
entrypoint were weakened — the fixture oracle still requires the rule +
adapter listing before writing the marker. Hold-out is fixture vs live hub
only (single-case; no train|test split). Agent session use-path is out of
scope.

# Result file

After the run, write `20261005-wrap-prior-art-result.md` beside this goal.
Commit the result in a later local commit, not with this goal or its fixture.
