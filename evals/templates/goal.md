---
schema: goal/v1
id: YYYYMMDD-short-name
title: One line a person can read
fixture_dir: evals/fixtures/github.com/<slug>/<repo>/YYYYMMDD-short-name
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
# Optional: pack_quality: required  # opt into universe pack-quality ratchet early
# Optional scope keys: see goals/_schema.md (scope / languages / repos)
---

# Executive overview

Write 3–6 sentences a non-author can skim: what we will accomplish, why it
matters, and vaguely how (criteria + grader class). This is the pre-run report.
Do not write a code changelog here.

Write the rest before any run. Say what decision the result is allowed to support.

# Decision

What a pass lets us do. What a pass does not let us do. Prefer ≥2 sentences.

# User outcome

What should be better for the person using the system. Prefer ≥2 sentences.

Prefer that each meaningful bullet either shows up as a Success criteria row
(observable) or is called out under Limitations / Scope “Not covered.” Prose
alone is easy to treat as proven when it is not. Wiggle room is fine for
aspirational color — just do not lean on it when closing “works for the user.”

# Scope

| Covered | Not covered |
| --- | --- |
| The cases this test includes | The cases this test leaves out |

# Success criteria

One row per thing we can observe. Do not combine two requirements on one row.

A row that claims an end-to-end outcome (“`make up` works from a fresh clone”)
must be graded by a check that **executes** that path from the documented
starting state, not only by `grep`s of the files that implement it
(`PROCESS.md` “Manual verification becomes a test”).

| Criterion | What we look at |
| --- | --- |
|  |  |

When this pack turns a mode **on** for one environment (Boat, Access, etc.),
consider whether the claim also needs the mode **off** (or different) elsewhere.
A second row or a Limitations line is usually enough; skip when out of scope.

# Dataset

Where the cases come from, how many, and which cases we hold back (hold-out /
train|test). If there is no split yet, say so under Limitations.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
|  | A program check, a person, or a model | What evidence that grader can actually see |

Prefer the cheapest grader that works: program → person → Jev → LiteLLM last.
Use a program check when the outcome is directly visible. Use a person or a model only when a program cannot tell.

If the claim is that an agent used a tool, the check starts that agent and reads what it did. Name each agent on its own row. A config file, a projector writing into a throwaway directory, or a library script is not that agent. One agent does not stand in for the others. Inside Hermes, those agents are the ones in the Incus guest.

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
|  |  |  |

Set these limits before looking at results.

# Execution

How many tries, which model, time limit, and whether a failed try is repeated.

# Limitations

What a pass would still leave unproven. Name hold-out gaps here when Dataset
cannot yet declare a train/test split.

If a manual or live run is how you close an outcome, name which automated check
now repeats it (or why none can) — the result must carry a `# Manual
verification` section. If live V&V is how you close an outcome the static bar
does not cover, prefer
naming that gap here and matching live proof to the outcome (listen/HTML vs
config/mode vs interactive) — see `PROCESS.md` “Live proof levels (soft).”

# Result file

After the run, write `<same-folder>/<same-name>-result.md` beside this goal. The filled example is `evals/goals/github.com/hermes/hermes/20260918-graft-mini-svc-ab-result.md`. Copy `evals/templates/result.md`. A green check with no result file beside the goal is not done. The copy under `evals/runs/` is not that file. Commit the result in a later local commit, not with this goal or its fixture. Both commits may be in one pull request. Squash or merge may combine them.
