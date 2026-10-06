---
schema: goal/v1
id: 20260928-ui-process-entrypoint
title: UI consumers expose process-gate entrypoint and process fixtures
scope: language
languages: ui
fixture_dir: evals/fixtures/language/ui/20260928-ui-process-entrypoint
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

Write this before any run. Say what decision the result is allowed to support.

# Decision

A pass lets us say UI language consumers expose a process-gate entrypoint
(`npm run ui:process` and/or `scripts/ui-process-check.*`) and ship process
JSON fixtures under the documented contract. A pass does not prove Jev,
visual, or System-2 bars, and does not move Meter-specific calibration into
the hub.

# User outcome

Any `languages: ui` consumer has a runnable process safeguard entrypoint and
fixture directory that `eval/bars` can enforce.

# Scope

| Covered | Not covered |
| --- | --- |
| Entrypoint + process JSON path contract | TypeSafe Jev keys; visual/System-2 runners; Meter-only IA |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Entrypoint | `package.json` `scripts.ui:process` or `scripts/ui-process-check.*` |
| Process fixtures | ≥1 `*.json` under own-leaf `ui-process/fixtures/` or legacy `evals/ui/process/fixtures/` |

# Dataset

`HERMES_EVAL_REPO_ROOT` is the product under test. Preferred fixture home:

```text
evals/fixtures/github.com/<org>/<repo>/ui-process/fixtures/*.json
```

Legacy overlay `evals/ui/process/fixtures/` still passes during crawl.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| All success criteria | A program check | Path + file presence |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Entrypoint present? | npm script and/or check script | Neither |
| Process JSON present? | ≥1 fixture | None |

# Execution

assert-red / verify with `HERMES_EVAL_REPO_ROOT` pointing at the consumer.
No agent solver. `eval/bars` runs this check when the `ui` family is selected.

# Limitations

Does not execute `npm run ui:process` or grade fixture semantics.

# Result file

After the run, write `20260928-ui-process-entrypoint-result.md` beside this goal.
Commit the result in a later local commit, not with this goal or its fixture.
