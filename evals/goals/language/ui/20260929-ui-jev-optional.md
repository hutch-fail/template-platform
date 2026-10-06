---
schema: goal/v1
id: 20260929-ui-jev-optional
title: Optional ui:jev runs only when script exists; key fail-closed
scope: language
languages: ui
fixture_dir: evals/fixtures/language/ui/20260929-ui-jev-optional
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

Write this before any run. Say what decision the result is allowed to support.

# Decision

A pass lets us say: when `package.json` has `ui:jev`, language bars require
`TYPESAFE_API_KEY` and run the script (fail closed). When `ui:jev` is absent,
the bar skips. A pass does not prove TypeSafe calibration quality.

# User outcome

Jev rides eval-ci when products opt into the script + secret — products without
Jev are not forced.

# Scope

| Covered | Not covered |
| --- | --- |
| Skip if no `ui:jev`; fail if script + missing key; run when both present | Fixture semantics inside Meter Jev JSON |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | Fixture has failing `ui:jev`; `check.sh` exits non-zero (with key if set) |
| The fix works | After `golden.patch`, no `ui:jev` → skip / exit 0 |
| Nothing else breaks | `p2p-smoke.sh` stays green |

# Dataset

Minimal `package.json` with `ui:jev` on baseline; golden removes the script.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Optional Jev gate | Program (`check.sh`) | script presence + env + npm |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| F2P red on baseline? | Non-zero | Already green |
| Skip path after golden? | Exit 0 without key | Still requires Jev |

# Execution

`make eval/assert-red GOAL=20260929-ui-jev-optional` then wire `run_ui_bars`,
then `make eval/verify`.

# Limitations

Does not mint keys. Does not grade Jev fixture content.

# Result file

After the run, write `20260929-ui-jev-optional-result.md` beside this goal.
Commit the result in a later local commit, not with this goal or its fixture.
