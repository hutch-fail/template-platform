---
schema: goal/v1
id: 20261015-ui-pr-before-after-screenshots
title: UI/UX-touching PRs require before/after screenshots in the description
scope: language
languages: ui
fixture_dir: evals/fixtures/language/ui/20261015-ui-pr-before-after-screenshots
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

# Executive overview

Fail-closed CI gate: when a pull request touches UI/UX paths, the PR
description must include before/after screenshots (or an explicit n/a waiver).
Hermetic wiring + pack-gate self-test; live GitHub PR bodies are hold-out.

# Decision

A pass lets us say the hub pack gate enforces UI before/after evidence in CI
via `EVALS_PR_BODY` when UI/UX paths change. A pass does not prove every
consumer redistributed the hub pin, or that a human reviewed the screenshots.

# User outcome

Reviewers of UI/UX PRs always get a visual before/after (or a documented
waiver) in the PR description instead of inventing ad-hoc screenshot asks.

# Scope

| Covered | Not covered |
| --- | --- |
| PROCESS cue; assert_pr helpers; eval-ci / pack-gate `EVALS_PR_BODY`; self-test | Playwright; live Host URL SPA boot; fleet redistribute |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| PROCESS | Documents UI/UX PR screenshots + n/a waiver |
| Pack gate | `path_is_ui_ux` / `pr_body_has_ui_screenshots` / `ui_screenshot_gate_problem` |
| CI wire | `EVALS_PR_BODY` in eval-ci.yml and eval-pack-gate.yml; thin prepare scripts |
| Self-test | `assert_pr_has_eval_pack.sh` with no args exits 0 |

# Dataset

Hub checkout under `HERMES_EVAL_REPO_ROOT` / kit resolve. No train/test split.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Wiring + self-test | Program (`check.sh`) | Hermetic, no API keys |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Offline fixture | `check.sh` exit 0 | Missing PROCESS / helpers / EVALS_PR_BODY / self-test |
| Live PR body claimed? | Not claimed here | Treating green wiring as live screenshot proof |

# Execution

`make eval/verify GOAL=20261015-ui-pr-before-after-screenshots` from the hub.

# Limitations

Does not fetch a real GitHub PR body. Does not redistribute to product repos
(next evals sync / hub pin bump).

# Result file

After the run, write `20261015-ui-pr-before-after-screenshots-result.md` beside
this goal. Commit the result in a later local commit, not with this goal or its
fixture.
