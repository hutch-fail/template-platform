---
schema: goal/v1
id: 20260929-ansible-scope-manifest
title: Ansible consumers declare ansible in evals/scope.yaml
scope: language
languages: ansible
fixture_dir: evals/fixtures/language/ansible/20260929-ansible-scope-manifest
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

Write this before any run. Say what decision the result is allowed to support.

# Decision

A pass lets us say Ansible language consumers declare `evals/scope.yaml`
(`evals-scope/v1`) with `languages` including `ansible`, so language-scoped
bars can select against them. A pass against machine-layers does not prove
other consumers or a mandatory select gate.

This authoring run must not pass while the consumer under test lacks that
manifest entry.

# User outcome

Ansible product repos are discoverable as language consumers via the shared
manifest.

# Scope

| Covered | Not covered |
| --- | --- |
| Product `evals/scope.yaml` (or hub-root `scope.yaml`) lists `ansible` | Doctor/secrets; other languages; mandatory CI select |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Manifest present | `evals/scope.yaml` under the product root (or `scope.yaml` when the root is the evals kit) |
| Schema | `schema: evals-scope/v1` |
| Language | `languages` includes `ansible` |

# Dataset

`HERMES_EVAL_REPO_ROOT` is the product under test (machine-layers for the
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
| `ansible` listed? | Present in languages | Absent |

# Execution

assert-red / verify with `HERMES_EVAL_REPO_ROOT` pointing at the consumer.
No agent solver.

# Limitations

Does not prove universe migration, live guest converge, or ansible-lint hooks.

# Result file

After the run, write `20260929-ansible-scope-manifest-result.md` beside this goal.
Commit the result in a later local commit, not with this goal or its fixture.
