---
schema: goal/v1
id: 20261007-sample-bad-use-pack
title: Sample bad wiring-only use-path pack
fixture_dir: .
f2p_check: check.sh
solver: none
pack_quality: required
---

# Executive overview

This sample claims operators run ensure_invent_bind so invent receives seed
skills, but the fixture only greps that the symbol exists in reconcile.py.
The use-path lint must reject wiring-only greps as kick-the-tires.

# Decision

A pass must not let us treat grep -Fq ensure_invent_bind as proof the feature
works. A pass does not prove a live Incus guest.

# User outcome

Operators should run ensure_invent_bind; invent receives seed and desiredSkills
mirror stays honest. This pack wrongly treats a wiring grep as that outcome.

# Scope

| Covered | Not covered |
| --- | --- |
| Selftest bad use-path sample | Live guest |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Wiring | grep finds ensure_invent_bind in reconcile.py |

# Dataset

One synthetic bad use-path pack held out from product goals. Train/test split
is N/A; the good-use sample is the hold-out contrast case.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Wiring | program (check.sh) | grep only — this is the failure mode |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Does lint reject wiring-only behavior claims? | selftest records use-path error | Pack passes |

# Limitations

Does not prove a live guest. Hold-out is the paired good-use sample. This pack
is the failing wiring-only contrast (no kick-the-tires exercise).
