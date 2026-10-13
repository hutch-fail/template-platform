---
schema: goal/v1
id: 20261012-sample-jev-good-pack
title: Sample good pack for Jev pack-quality selftest
fixture_dir: .
f2p_check: check.sh
solver: none
pack_quality: required
---

# Executive overview

This sample shows a well-formed hermetic pack that should pass the Jev
holistic axes. User outcome may state the production *why*; Success criteria
grade a unit-test runner effect; Limitations own live proof as hold-out.

# Decision

A pass lets us treat this shape as a trusted Jev selftest fixture for pack
quality (hermetic + hold-out). A pass does not prove any live product outside
this sample.

# User outcome

Operators get correct prefer-path behavior in production when cost is
available. Authors compare failing packs against this shape when calibrating
the Jev judge.

# Scope

| Covered | Not covered |
| --- | --- |
| Jev selftest good sample (hermetic unit-test exercise) | Live product APIs |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Unit-test exercise | `check.sh` runs `node --test` (or equivalent) and asserts a prefer/effect marker |
| Wiring optional | Implementing module may also be grepped as an extra row |

# Dataset

One synthetic good pack held out from product goals. The paired `jev-bad-*`
samples are the hold-out contrast cases for axis failures.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Unit-test exercise | program (`check.sh`) | Observable effect from the test runner |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Does the unit-test exercise leave the marker? | check exits 0 | Marker missing |

# Limitations

Live guest / production spend reconciliation is hold-out — this pack grades
hermetic unit-test exercise only. A careful author could still game the check
by writing the marker without running the real tests — the fixture would need
a stronger oracle to catch that. Hold-out contrast is the paired `jev-bad-*`
samples.
