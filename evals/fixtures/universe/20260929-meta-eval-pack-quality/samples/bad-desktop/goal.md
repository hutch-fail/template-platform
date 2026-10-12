---
schema: goal/v1
id: 20261003-sample-bad-desktop-pack
title: Sample bad PATH-only desktop-launch pack
fixture_dir: .
f2p_check: check.sh
solver: none
pack_quality: required
---

# Executive overview

This sample claims operators launch a guest GUI from the openbox in-session
menu on the Kasm DISPLAY, but the fixture only greps a binary on PATH. The
launch-path lint must reject it.

# Decision

A pass must not let us treat command -v as proof of in-session launch.
A pass does not prove a live Kasm session.

# User outcome

Operators should start the app from the openbox in-session menu on the Kasm
DISPLAY. This pack wrongly treats PATH as that outcome.

# Scope

| Covered | Not covered |
| --- | --- |
| Selftest bad desktop sample | Live Kasm click |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Installed | command -v the binary |

# Dataset

One synthetic bad desktop pack held out from product goals. Train/test split
is N/A; the good-desktop sample is the hold-out contrast case.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Installed | program (check.sh) | PATH only — this is the failure mode |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Does lint reject PATH-only GUI claims? | selftest records launch-path error | Pack passes |

# Limitations

Does not prove a live graphical session. Hold-out is the paired good-desktop
sample. This pack is the failing PATH-only contrast.
