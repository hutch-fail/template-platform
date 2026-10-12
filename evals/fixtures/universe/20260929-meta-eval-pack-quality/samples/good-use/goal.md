---
schema: goal/v1
id: 20261007-sample-good-use-pack
title: Sample good kick-the-tires pack for pack-quality selftest
fixture_dir: .
f2p_check: check.sh
solver: none
pack_quality: required
---

# Executive overview

This sample proves a behavior claim must exercise the operator entrypoint and
re-enter once (idempotent kick-the-tires), not only grep that the symbol
exists. It is the hold-out good contrast for the use-path lint.

# Decision

A pass lets us keep shipping the use-path selftest as a trusted fixture.
A pass does not prove a live Incus guest.

# User outcome

Operators run ensure_invent_bind; invent receives seed skills and a second
ensure stays green (idempotent reconverge). Reviewers can compare wiring-only
packs against this shape.

# Scope

| Covered | Not covered |
| --- | --- |
| Selftest good use-path sample | Live Paperclip HTTP sync |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Kick the tires | Fixture calls ensure_invent_bind, asserts invent receives seed, re-ensures |

# Dataset

One synthetic good use-path pack held out from product goals. Train/test split
is N/A; the bad-use sample is the hold-out contrast case.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Kick the tires | program (check.sh) | Calls + observable + second pass |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Does lint accept exercise + re-entry? | selftest good-use exits 0 | Pack fails use-path |

# Limitations

Does not prove live guest systemd mounts. Hold-out is the paired bad-use
sample. Live Paperclip skills/sync is out of scope for this selftest.
