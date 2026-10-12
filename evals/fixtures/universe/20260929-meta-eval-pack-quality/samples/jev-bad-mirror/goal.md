---
schema: goal/v1
id: 20261012-sample-jev-bad-mirror
title: Sample bad wiring-only pack for Jev mirror_prod axis
fixture_dir: .
f2p_check: check.sh
solver: none
pack_quality: required
---

# Executive overview

This sample claims operators run a reconcile entrypoint so a feature actually
applies, but Success criteria only grep that a symbol exists in a file. Jev
`mirror_prod` must fail this shape.

# Decision

A pass must not let us treat a wiring grep as proof the feature works. A pass
does not prove a live environment.

# User outcome

Operators should run reconcile so the feature applies and stays honest. This
pack wrongly treats a wiring grep as that outcome.

# Scope

| Covered | Not covered |
| --- | --- |
| Jev selftest bad mirror_prod | Live guest |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Wiring | grep finds `reconcile_feature` in reconcile.py |

# Dataset

One synthetic bad pack held out from product goals. The good Jev sample is the
hold-out contrast case.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Wiring | program (`check.sh`) | grep only — intentional failure mode |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Does Jev reject wiring-only behavior claims? | mirror_prod false | Pack passes all axes |

# Limitations

Does not prove a live guest. Hold-out is the paired jev-good sample. This pack
is the failing wiring-only contrast (no kick-the-tires exercise).
