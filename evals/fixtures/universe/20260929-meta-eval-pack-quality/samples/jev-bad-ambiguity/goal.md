---
schema: goal/v1
id: 20261012-sample-jev-bad-ambiguity
title: Sample bad vibe-graded pack for Jev low_ambiguity axis
fixture_dir: .
f2p_check: check.sh
solver: none
pack_quality: required
---

# Executive overview

This sample grades an observable entrypoint effect (so mirror_prod can pass)
but leaves Grading as vibe-only — two reviewers would not agree on pass/fail.
Jev `low_ambiguity` must fail this shape.

# Decision

A pass must not let us ship packs graded only by feel. A pass does not prove
product quality outside this sample.

# User outcome

Operators run `check.sh`, which invokes the sample entrypoint and leaves a
marker file. Reviewers should know exactly what green means; this pack leaves
that vague in Grading.

# Scope

| Covered | Not covered |
| --- | --- |
| Jev selftest bad low_ambiguity | Live product |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Entrypoint effect | `check.sh` runs the entrypoint and the marker file exists afterward |

# Dataset

One synthetic bad pack held out from product goals. The good Jev sample is the
hold-out contrast case.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Entrypoint effect | vibes | intentional ambiguity — no named program/person/model |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Does it feel right? | Seems fine | Unclear |

# Limitations

A careful author gaming soft language is the point of this sample. Hold-out is
the paired jev-good sample. No program grader is named on purpose so
`low_ambiguity` fails while the Success criteria still describe an entrypoint
effect.
