---
schema: goal/v1
id: 20260928-ui-scope-manifest
title: UI consumers declare ui in evals/scope.yaml
scope: language
languages: ui
fixture_dir: evals/fixtures/language/ui/20260928-ui-scope-manifest
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

Write this before any run. Say what decision the result is allowed to support.

# Decision

A pass lets us say UI language consumers declare `evals/scope.yaml`
(`evals-scope/v1`) with `languages` including `ui`, so design-system language
bars can select against them. A pass against one consumer does not prove other
consumers or a mandatory select gate.

This authoring run must not pass while the consumer under test lacks that
manifest entry.

# User outcome

UI / design-system product repos are discoverable as language consumers via the
shared manifest.

# Scope

| Covered | Not covered |
| --- | --- |
| Product `evals/scope.yaml` (or hub-root `scope.yaml`) lists `ui` | Jev/visual/System-2 promotion; mandatory CI select |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Manifest present | `evals/scope.yaml` under the product root (or `scope.yaml` when the root is the evals kit) |
| Schema | `schema: evals-scope/v1` |
| Language | `languages` includes `ui` |

# Dataset

`HERMES_EVAL_REPO_ROOT` is the product under test (service-meter for the
fail→pass demo). Synthetic roots may be used in unit smoke.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| All success criteria | A program check | File + YAML field presence |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Manifest found? | Path exists | Missing |
| Schema ok? | `evals-scope/v1` | Wrong/missing |
| `ui` listed? | Present in languages | Absent |

# Execution

assert-red / verify with `HERMES_EVAL_REPO_ROOT` pointing at the consumer.
No agent solver.

# Limitations

Does not prove Jev/visual promotion or live npm UI gates.

# Result file

After the run, write `20260928-ui-scope-manifest-result.md` beside this goal.
Commit the result in a later local commit, not with this goal or its fixture.
