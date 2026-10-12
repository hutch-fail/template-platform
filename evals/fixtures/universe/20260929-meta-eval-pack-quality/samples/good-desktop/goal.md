---
schema: goal/v1
id: 20261003-sample-good-desktop-pack
title: Sample good desktop-launch pack for pack-quality selftest
fixture_dir: .
f2p_check: check.sh
solver: none
pack_quality: required
---

# Executive overview

This sample proves a desktop-launch eval pack must grade the in-session openbox
menu and Kasm DISPLAY launcher, not only a binary on PATH. It is the hold-out
good contrast for the launch-path lint.

# Decision

A pass lets us keep shipping the launch-path selftest as a trusted fixture.
A pass does not prove a live Kasm session.

# User outcome

Operators launch the guest GUI from the openbox in-session menu on the Kasm
DISPLAY. Reviewers can compare PATH-only packs against this shape.

# Scope

| Covered | Not covered |
| --- | --- |
| Selftest good desktop sample | Live Kasm click |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Launch path | Fixture asserts menu.xml or menu.d plus DISPLAY |

# Dataset

One synthetic good desktop pack held out from product goals. Train/test split
is N/A; the bad-desktop sample is the hold-out contrast case.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Launch path | program (check.sh) | File tokens for openbox and DISPLAY |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Does good-desktop pass and bad-desktop fail? | selftest exits 0 | Either wrong |

# Limitations

Does not exercise a live graphical session. Hold-out is the paired bad-desktop
sample.
