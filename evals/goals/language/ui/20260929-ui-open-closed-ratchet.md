---
schema: goal/v1
id: 20260929-ui-open-closed-ratchet
title: Declared ui consumers enforce ui:lint via language bars without ui-design.yml
scope: language
languages: ui
fixture_dir: evals/fixtures/language/ui/20260929-ui-open-closed-ratchet
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

Write this before any run. Say what decision the result is allowed to support.

# Decision

A pass lets us say the hub open-closed ratchet is live: a consumer that
declares `languages: ui` and `package.json` `ui:lint` is enforced by
`language/ui` execute bars via `eval-bars` / eval-ci, and shared language gates
do **not** require a product `.github/workflows/ui-design.yml`.

A pass does not prove every UI consumer has redistributed, or that
select→verify runs every selected goal in CI (hub #8).

This authoring run must not pass on the unpatched baseline fixture.

# User outcome

Meter (and peers) collapse dual UI CI into one rail; authors extend by
appending hub language fixtures + `run_*_bars`, not new product workflows.

# Scope

| Covered | Not covered |
| --- | --- |
| Hub wire of execute/jev/typescript bars; eval-ci Node + TYPESAFE; temp consumer without ui-design.yml | Promoting Meter Jev IA into hub; fleet redistribute |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | Fixture `notes.txt` baseline; `check.sh` exits non-zero |
| The fix works | After `golden.patch` (`patched`) and hub implementation: wiring greps + live `ui:lint` marker + `eval-bars` ui family green without ui-design.yml |
| Nothing else breaks | `p2p-smoke.sh` stays green |

# Dataset

Notes baseline/golden. Live probe builds a temp product under `/tmp`.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Ratchet shape + live lint | Program (`check.sh`) | Hub files + temp consumer |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Baseline certified red? | assert-red OK | Already green |
| After implement + golden, verify green? | F2P+P2P pass | Wiring missing |

# Execution

1. `make eval/assert-red GOAL=20260929-ui-open-closed-ratchet` (certified red)
2. Implement execute bars + typescript bars + eval-ci Node/Jev
3. `make eval/verify GOAL=20260929-ui-open-closed-ratchet`

# Limitations

Does not redistribute to every consumer. Does not delete Meter `ui-design.yml`
(that is the product follow-up).

# Result file

After the run, write `20260929-ui-open-closed-ratchet-result.md` beside this
goal. Commit the result in a later local commit, not with this goal or its
fixture.
