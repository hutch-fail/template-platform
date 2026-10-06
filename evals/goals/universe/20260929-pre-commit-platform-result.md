---
schema: result/v1
id: 20260929-pre-commit-platform-result
goal_id: 20260929-pre-commit-platform
status: pass
---

# Result

`make eval/assert-red GOAL=universe/20260929-pre-commit-platform` certified
red (missing `.pre-commit-config.yaml`). `make eval/verify` green after
`golden.patch` (platform + evals-pre-commit). Hub dogfood:
`.pre-commit-config.yaml` pins `hutch-fail/pre-commit` `id: platform` and
`scripts/pre-commit-evals.sh`; `make eval/bars` exits 0. Unit coverage in
`tests/unit/test_eval_bars.sh` for missing vs golden shape.

# Manual verification

None — kit redistribute from hub 518db3f; eval-ci and pre-commit bars are the covering automated checks.
