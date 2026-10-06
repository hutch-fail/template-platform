---
name: goal-develop
description: >-
  Implement only within a certified-red goal's allowed scope. Trigger after
  goal-author / assert-red, or on "develop against goal". Never weaken evals.
---

# goal-develop

Implement the change the goal requires. Preconditions: a goal id and a recent
**assert-red** certification (manifest `verdict=certified_red`).

## Steps

1. Load `goals/<id>.md` (or `evals/goals/<id>.md` from a host) and the latest
   assert-red manifest under `runs/<id>/` (skill **goal** →
   `make eval/report GOAL=<id>` if needed).
2. Respect allowed / forbidden paths from the goal body and frontmatter. Prefer
   smallest diff that could turn F2P green without touching eval definitions.
3. Implement. Re-run fast local checks if the goal names them.
4. Do **not** call `verify` yourself unless the human asked — prefer handing off
   to **goal-judge**.
5. Stop when: ready for judge, or budget/scope exhausted (say what is unfinished).

## Forbidden

- Editing `goals/**` / `evals/goals/**`, fixture `check.sh` / `p2p-smoke.sh`, or
  golden patches to force green
- Skipping assert-red / developing against an uncertified goal
- Expanding scope past the goal without human approval

## Related

- Prior: **goal-author**
- Next: **goal-judge**
- CLI: **goal**
- Orchestrator: **meta-dev**
