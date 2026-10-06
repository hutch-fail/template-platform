---
schema: goal/v1
id: 20260924-no-gha-app-actions-secrets
title: Workflows must not use raw GitHub App Actions secrets
scope: universe
fixture_dir: evals/fixtures/universe/20260924-no-gha-app-actions-secrets
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

Write this before any run. Say what decision the result is allowed to support.

# Decision

A pass lets us say every recipe consumer’s top-level `.github/workflows`
does not reference `secrets.GH_APP_ID` / `secrets.GH_APP_PRIVATE_KEY` and does
not declare those names under workflow_call or job `secrets:` mappings. App
credentials may come from `op://…/GH_APP_*`, `steps.op.outputs.GH_APP_*`, or a
1Password PEM document ref (post-#34 pattern).

A pass does not prove live 1Password ACLs, migrate every caller in one PR, or
implement full select→verify for all universe goals ([#8](https://github.com/hutch-fail/evals/issues/8)).

This authoring run must not pass while the fixture baseline still uses raw
`secrets.GH_APP_*`.

# User outcome

Product repos cannot keep shipping raw GitHub App id/PEM as Actions secrets;
`make eval/bars` (local, pre-commit, and eval-ci) always runs the same check.

# Scope

| Covered | Not covered |
| --- | --- |
| `${HERMES_EVAL_SCAN_ROOT}/.github/workflows/*.{yml,yaml}` | Nested fixtures under `fixtures/` / `evals/` |
| Forbid `secrets.GH_APP_*` refs + named `secrets:` declarations | Org secret inventory; Connect Server auth |
| Allow `op://` + `steps.op.outputs.*` load pattern | Full select→verify matrix |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | Fixture `sample-ci.yml` uses raw App secrets; `check.sh` exits non-zero |
| The fix works | After `golden.patch`, OP load + mint from outputs; `check.sh` exits 0 |
| Nothing else breaks | `p2p-smoke.sh` stays green |

# Dataset

One fixture workflow root. Product pre-commit and eval-ci scan the caller tree
the same way (`HERMES_EVAL_SCAN_ROOT`).

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| No raw App secrets | Program (`check.sh`) | Directly visible in workflow YAML |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Did the patch remove raw App secrets? | F2P fails before patch; F2P+P2P pass after | Either check wrong |

# Execution

`make eval/assert-red` then wire shared `eval/bars` (universe always-on), then
`make eval/verify`.

# Limitations

Does not prove the org SA can read the vault in Actions. Does not scan workflows
outside the scan root’s top-level `.github/workflows`.

# Result file

After the run, write `20260924-no-gha-app-actions-secrets-result.md` beside this goal.
Commit the result in a later local commit, not with this goal or its fixture.
Both commits may be in one pull request. Squash or merge may combine them.
