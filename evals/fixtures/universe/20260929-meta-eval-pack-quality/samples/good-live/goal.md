---
schema: goal/v1
id: 20261008-sample-good-live-pack
title: Sample good live-path pack (smoke wiring) for pack-quality selftest
fixture_dir: .
f2p_check: check.sh
solver: none
pack_quality: required
---

# Executive overview

This sample proves a Host URL claim must grade doctor/test-smoke wiring that
invokes the probe — not only grep that probe-demo.sh mentions curl. It is the
hold-out good contrast for the live-path lint.

# Decision

A pass lets us keep shipping the live-path selftest as a trusted fixture.
A pass does not exercise a real Incus instance in this synthetic sample.

# User outcome

Operators open https://demo.localhost/dashboard after make up; test/smoke
runs probe-demo.sh and curl health returns 200. Reviewers compare wiring-only
packs against this shape.

# Scope

| Covered | Not covered |
| --- | --- |
| Selftest good live-path sample | Real Incus guest runtime |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Smoke wiring | F2P asserts test-smoke.sh invokes probe-demo.sh for demo.localhost |

# Dataset

One synthetic good live-path pack held out from product goals. Train/test split
is N/A; the bad-live sample is the hold-out contrast case.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Smoke wiring | program (check.sh) | test-smoke arm + probe |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Does lint accept smoke exercise cues? | selftest good-live exits 0 | Pack fails live-path |

# Limitations

Synthetic selftest only. Hold-out contrast is the paired bad-live sample.
TypeSafe and LiteLLM keys are unused here.
