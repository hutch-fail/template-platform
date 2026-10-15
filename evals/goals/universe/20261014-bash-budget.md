---
schema: goal/v1
id: 20261014-bash-budget
title: Bash budget for GHA YAML and eval check.sh
scope: universe
fixture_dir: evals/fixtures/universe/20261014-bash-budget
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
pack_quality: required
---

# Executive overview

We will stop eval packs and GitHub Actions YAML from growing into unmaintainable
inline bash. A green result means changed workflow `run: |` blocks and eval
`check.sh` files stay within a consecutive-line budget (~12) and YAML files do
not dedicate most of their lines to inline script. The grader is a small Python
lint invoked by a thin shell wrapper. Historic fat files are not rewritten in
this pack; enforcement is PR-scoped via `HERMES_EVAL_CHANGED_PATHS`.

# Decision

A pass lets us believe that new or edited GHA YAML and eval shell on a PR cannot
silently grow past the bash budget without CI failing closed. A pass does not
let us believe every historic `check.sh` or workflow is thin, or that composite
actions are mandatory everywhere.

# User outcome

Authors who paste a long script into `run: |` or grow a fixture `check.sh` past
~12 consecutive content lines get a CI error that names the file and says to
extract a helper — without needing a local TypeSafe re-judge or a full-tree
rewrite.

# Scope

| Covered | Not covered |
| --- | --- |
| `.github/workflows|actions/**/*.yml` `run: \|` / `run: >` blocks | One-liner `run: cmd` |
| Eval `check.sh` / `p2p-smoke.sh` consecutive content lines | Product app shell outside evals fixtures |
| PR-scoped via `HERMES_EVAL_CHANGED_PATHS`; fixture selftest always | Rewriting historic hub workflows in this pack |
| YAML file bash-body percentage (default 35%) | Shell file percentage (not meaningful) |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Selftest | `samples/good-*` pass; `samples/bad-*` fail under defaults |
| Assert-red | Fixture baseline fat `sample.yml` fails check.sh |
| Golden | After `golden.patch`, check.sh exits 0 |
| PR skip | No changed paths → skip live scan after selftest (not tree-fail) |
| How-to-pass | Fail stderr names path, threshold, and extract-helper guidance |

# Dataset

Train: fixture `samples/good-*` / `bad-*` plus baseline/golden `sample.yml`.
Hold-out: real hub `.github/workflows/eval-ci.yml` (still over budget) is not
modified here; Limitations own that gap until a follow-up PR edits it.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Selftest / assert-red / golden | program (`check.sh` → `bash_budget_lint.py`) | Deterministic line counts |
| PR-scoped skip | program | Env contract |

# Acceptance gates

| Question | Pass | Fail |
| --- | --- | --- |
| Assert-red then verify? | Certified red on fat baseline; green after golden | Already green, or still red after patch |
| Unrelated PR tree-scanned? | No — skip without `HERMES_EVAL_CHANGED_PATHS` | Full-tree fail on historic fat files |
| Fail readable? | stderr says extract helper / thin wrapper | Opaque exit 1 only |

# Execution

One authoring pass on `feat/bash-budget-gha-yml` from `origin/main`. No API keys.

# Limitations

Does not slim existing hub workflows (e.g. `eval-ci.yml` max block ~25) in this
change — that is hold-out until those paths are edited. Shell percentage is out
of scope (a `.sh` file is mostly bash by definition). A careful human can split
a fat block with blank lines to reset the consecutive counter; that easy-to-get-
wrong mode is why YAML also has a file-level bash percentage cap.

# Result file

After the run, write `20261014-bash-budget-result.md` beside this goal. Commit
the result in a later local commit, not with this goal or its fixture.
