---
schema: goal-result/v1
id: 20261001-unique-runner-determination
status: pass
---

# Manual verification

- Ran `HERMES_EVAL_SCAN_ROOT=fixtures/language/gha/20261001-unique-runner-determination bash fixtures/language/gha/20261001-unique-runner-determination/check.sh` → fails on bare group.
- After copying samples/good workflow into fixture `.github/workflows` → `unique_runner_determination_ok`.
- `detect_families .github/workflows/x.yml` selects `gha`; `HERMES_EVAL_FORCE_FAMILIES=ci` selects `gha`.

Deterministic language/gha seed bar wired in `run_gha_bars`.

# Manual verification

None — kit redistribute from hub 518db3f; eval-ci and pre-commit bars are the covering automated checks.
