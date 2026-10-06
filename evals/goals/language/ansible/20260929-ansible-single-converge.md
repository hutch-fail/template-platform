---
schema: goal/v1
id: 20260929-ansible-single-converge
title: Ansible playbooks root must expose only converge.yml
scope: language
languages: ansible
fixture_dir: evals/fixtures/language/ansible/20260929-ansible-single-converge
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

Write this before any run. Say what decision the result is allowed to support.

# Decision

A pass lets us say Ansible consumers that declare `languages: ansible` keep a
single converge entrypoint under `ansible/playbooks/` — `converge.yml` only,
no per-feature sibling playbooks (ROLE-CONTRACT). A pass against the fixture
does not prove every product CI gate runs this check, and does not prove live
guest converge.

# User outcome

Teams apply roles through one converge playbook; parallel follow-ons add role
entries there instead of forking per-feature playbooks.

# Scope

| Covered | Not covered |
| --- | --- |
| `ansible/playbooks/` has `converge.yml` and no other `*.yml`/`*.yaml` siblings | ansible-lint; requirements.yml pins; live guest converge |
| Skip kit/recipe trees (`evals/`, `.evals-hub/`, fixtures) | Per-role naming bars |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | Fixture ships `converge.yml` plus `feature.yml`; `check.sh` exits non-zero |
| The fix works | After `golden.patch`, only `converge.yml` remains and `check.sh` exits 0 |
| Nothing else breaks | `p2p-smoke.sh` stays green |

# Dataset

One fixture Ansible playbooks root. Product pre-commit / bars scan the consumer
tree the same way via `HERMES_EVAL_SCAN_ROOT`.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Single converge playbook | Program (`check.sh`) | Directly visible as sibling files |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Did the patch remove sibling playbooks? | F2P fails before patch; F2P+P2P pass after | Either check wrong |

# Execution

`make eval/assert-red` then `make eval/verify`. `eval/bars` runs this check
when the `ansible` family is selected.

# Limitations

Does not execute `ansible-playbook` or grade role contents inside converge.yml.

# Result file

After the run, write `20260929-ansible-single-converge-result.md` beside this goal.
Commit the result in a later local commit, not with this goal or its fixture.
