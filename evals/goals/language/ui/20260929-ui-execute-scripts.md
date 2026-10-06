---
schema: goal/v1
id: 20260929-ui-execute-scripts
title: UI consumers run ui:docs / ui:lint / ui:process via language bars
scope: language
languages: ui
fixture_dir: evals/fixtures/language/ui/20260929-ui-execute-scripts
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

Write this before any run. Say what decision the result is allowed to support.

# Decision

A pass lets us say `languages: ui` consumers that declare `ui:docs`, `ui:lint`,
and/or `ui:process` in `package.json` have those scripts executed by
`make eval/bars` (fail closed on non-zero). Missing scripts are skipped.
Missing `node_modules` fails with an `npm ci` hint.

A pass does not prove Jev, visual, or Meter-only IA calibration.

# User outcome

Deterministic UI process/lint gates ride the shared eval rail — no second
product `ui-design.yml` required for those scripts.

# Scope

| Covered | Not covered |
| --- | --- |
| Execute `ui:docs` / `ui:lint` / `ui:process` when present | `ui:jev` (sibling bar); `ui:visual`; typecheck |
| `node_modules` / `npm ci` fail-closed hint | Installing dependencies inside the bar |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | Fixture `ui:lint` exits 1; `check.sh` exits non-zero |
| The fix works | After `golden.patch`, scripts exit 0; `check.sh` exits 0 |
| Nothing else breaks | `p2p-smoke.sh` stays green |

# Dataset

Minimal `package.json` + empty `node_modules/` under the fixture. Product
`eval/bars` uses `HERMES_EVAL_SCAN_ROOT`.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Script execute | Program (`check.sh`) | npm exit codes |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Did broken lint fail closed? | F2P red on baseline | Already green |
| Did golden make lint pass? | F2P+P2P green after patch | Still red |

# Execution

`make eval/assert-red GOAL=20260929-ui-execute-scripts` then wire
`run_ui_bars`, then `make eval/verify`.

# Limitations

Does not install npm packages. Does not run visual or Jev.

# Result file

After the run, write `20260929-ui-execute-scripts-result.md` beside this goal.
Commit the result in a later local commit, not with this goal or its fixture.
