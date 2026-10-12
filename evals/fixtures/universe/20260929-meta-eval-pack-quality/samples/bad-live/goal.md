---
schema: goal/v1
id: 20261008-sample-bad-live-pack
title: Sample bad live-path pack (probe-script grep only)
fixture_dir: .
f2p_check: check.sh
solver: none
pack_quality: required
---

# Executive overview

This sample claims operators get https://demo.localhost/dashboard working, but
the fixture only greps that probe-demo.sh mentions curl. The live-path lint
must reject probe-script greps as tire-kick for Host URL claims.

# Decision

A pass must not let us treat grep of a probe script as proof the Host works.
A pass does not exercise a real Incus instance.

# User outcome

Operators should open https://demo.localhost/dashboard and see HTTP 200 after
make up. This pack wrongly treats a probe-script curl grep as that outcome.

# Scope

| Covered | Not covered |
| --- | --- |
| Selftest bad live-path sample | Real Incus guest |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Wiring | grep finds curl and demo.localhost in probe-demo.sh |

# Dataset

One synthetic bad live-path pack held out from product goals. Train/test split
is N/A; the good-live sample is the hold-out contrast case.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Wiring | program (check.sh) | grep only — this is the failure mode |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Does lint reject probe-script-only URL claims? | selftest records live-path error | Pack passes |

# Limitations

Synthetic selftest only. Hold-out contrast is the paired good-live sample.
This pack is the failing probe-script-grep contrast (no doctor or smoke arm).
