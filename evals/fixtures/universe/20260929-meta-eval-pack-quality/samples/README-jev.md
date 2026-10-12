# Jev pack-quality samples

Labeled thin goals for the Tier-2 TypeSafe (`jev_pack_quality_judge.py`) selftest.

## Role

- **While changing the judge or these samples:** run
  `make meta/pack-judge-selftest` (needs `TYPESAFE_API_KEY`).
- **Consumer product PRs:** selftest is skipped unless the PR touches the
  judge, these `jev-*` dirs, or the pack-quality Tier2 wiring.
- **Docs:** examples of packs that should pass/fail the six holistic axes —
  not domain quizzes and not the everyday CI bar for unrelated PRs.

## Axes (shared with Tier-3 LiteLLM)

`mirror_prod` · `headroom` · `low_ambiguity` · `adversarial_warning` ·
`holdout` · `executive_readable`

Meta-check wording stays abstract. Sample product fiction must not leak into
Noul instructions.

## Layout

```text
jev-good/goal.md + expected.yaml     # all axes true
jev-bad-<axis>/goal.md + expected.yaml
```

When you change an axis definition, update the matching sample and expected
labels, then re-run the selftest.
