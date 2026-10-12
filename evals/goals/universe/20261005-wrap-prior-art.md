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
and wrap it rather than rewrite it. This pack certifies that
`.cursor/rules/wrap-prior-art.mdc` exists with that contract, that
`scripts/install-host-adapters.sh` lists it, and that PROCESS.md / docs name
the rule. A pass lets us redistribute the procedure with the hub. A pass does
not prove every laptop re-ran adapters.

# Decision

A pass lets us say the hub ships an org-generic wrap-don't-rewrite procedure
through host adapters. A pass does not prove the hub OptMem store itself —
that is hub-only `github.com/hutch-fail/evals/20261005-optmem-repo-memory`.
This authoring run must not pass while the fixture baseline still omits the
rule and adapter entry.

# User outcome

Authors and agents default to wrapping named upstreams (checksummed pins)
instead of cloning their engines. OptMem in this hub is the worked example;
product memories remain each product’s concern.

# Scope

| Covered | Not covered |
| --- | --- |
| Rule file, adapter list, PROCESS pointer, docs/prior-art.md on live hub | Product OptMem rollout; relicensing OptMem |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Baseline red | Fixture lacks wrap-prior-art.mdc and adapter listing |
| Patched baseline green | Golden adds alwaysApply rule and adapter name |
| Live hub | Rule, adapters, PROCESS, docs/prior-art.md |

# Dataset

One fixture baseline that omits the rule. Live hub files after the change. No
train/test split — Limitations owns the single-case gap.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Baseline | `check.sh` | Files under fixture `baseline/` |
| Live | `p2p-smoke.sh` | Grep on `HERMES_EVAL_REPO_ROOT` |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Assert-red then verify? | Certified red; verify green after golden | Either wrong |

# Execution

One local `assert-red` / `verify` cycle. No agent solver.

# Limitations

Hold-out is fixture vs live hub only. Does not prove personal Cursor rules
were removed on laptops.

# Result file

After the run, write `20261005-wrap-prior-art-result.md` beside this goal.
Commit the result in a later local commit, not with this goal or its fixture.
