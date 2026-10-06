---
schema: goal/v1
id: 20260929-sample-good-pack
title: Sample good pack for pack-quality selftest
fixture_dir: .
solver: none
pack_quality: required
---

# Executive overview

This sample proves a well-formed eval pack passes the deterministic pack-quality
lint. It names the decision, the user outcome, and how we grade success so an
executive can skim without reading the harness.

# Decision

A pass lets us keep shipping the pack-quality selftest as a trusted fixture.
A pass does not prove live product behavior outside this sample.

# User outcome

Authors see a concrete example of executive voice, holdout discipline, and
program grading. Reviewers can compare failing packs against this shape.

# Scope

| Covered | Not covered |
| --- | --- |
| Selftest good sample | Live API judges |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Lint accepts this file | pack_quality_lint.py exits 0 |

# Dataset

One synthetic good pack held out from product goals. Train/test split is N/A
for a single selftest artifact; the bad sample is the hold-out contrast case.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Lint accepts this file | program (pack_quality_lint.py) | Structural markdown checks |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Does good pass and bad fail? | selftest exits 0 | Either wrong |

# Limitations

Does not exercise Tier-2 Jev or Tier-3 LiteLLM. Hold-out is the paired bad sample.
