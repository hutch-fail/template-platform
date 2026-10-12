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

This sample shows a well-formed eval pack that should pass the Jev holistic
pack-quality axes. It states what a green result allows, grades operator use
by running an entrypoint (not only grepping wiring), and names a concrete
way a careful author could still game the checks.

# Decision

A pass lets us treat this shape as a trusted Jev selftest fixture for pack
quality. A pass does not prove any live product outside this sample.

# User outcome

Operators run a one-shot `check.sh` that exercises the sample entrypoint and
asserts an observable effect. Authors can compare failing packs against this
shape when calibrating the Jev judge.

# Scope

| Covered | Not covered |
| --- | --- |
| Jev selftest good sample | Live product APIs |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Entrypoint effect | `check.sh` runs and asserts the sample marker file exists after invoke |

# Dataset

One synthetic good pack held out from product goals. The paired `jev-bad-*`
samples are the hold-out contrast cases for axis failures.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Entrypoint effect | program (`check.sh`) | Observable effect, not vibe |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Does the entrypoint leave the marker? | check exits 0 | Marker missing |

# Limitations

Does not prove a live guest or production service. A careful author could still
game the check by writing the marker without running the real entrypoint — the
fixture would need a stronger oracle to catch that. Hold-out is the paired
`jev-bad-*` samples.
