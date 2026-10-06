---
schema: goal/v1
id: 20260929-typescript-execute-scripts
title: TypeScript consumers run typecheck / test via language bars
scope: language
languages: typescript
fixture_dir: evals/fixtures/language/typescript/20260929-typescript-execute-scripts
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

Write this before any run. Say what decision the result is allowed to support.

# Decision

A pass lets us say `languages: typescript` consumers that declare `typecheck`
and/or `test` in `package.json` have those scripts executed by `make eval/bars`
(fail closed). Missing scripts are skipped. Missing `node_modules` fails with
an `npm ci` hint.

A pass does not prove coverage thresholds or UI lint.

# User outcome

Typecheck/vitest leave product-only UI workflows; they ride the shared
typescript language family when declared.

# Scope

| Covered | Not covered |
| --- | --- |
| Execute `typecheck` / `test` when present | ESLint; UI `ui:*` scripts |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | Fixture `typecheck` exits 1; `check.sh` exits non-zero |
| The fix works | After `golden.patch`, scripts exit 0 |
| Nothing else breaks | `p2p-smoke.sh` stays green |

# Dataset

Minimal `package.json` + empty `node_modules/` under the fixture.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Script execute | Program (`check.sh`) | npm exit codes |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Broken typecheck fail-closed? | F2P red | Already green |
| Golden fixes typecheck? | F2P+P2P green | Still red |

# Execution

`make eval/assert-red GOAL=20260929-typescript-execute-scripts` then wire
`run_typescript_bars`, then `make eval/verify`.

# Limitations

Does not install packages. Does not run UI bars.

# Result file

After the run, write `20260929-typescript-execute-scripts-result.md` beside
this goal. Commit the result in a later local commit, not with this goal or
its fixture.
