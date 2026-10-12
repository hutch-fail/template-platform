# PROPOSAL — role-agnostic AGENTS closeout (DEF-115)

Append (or equivalent) to shared / role AGENTS instructions after CEO/board
accept. Do not hot-swap without that confirmation.

## Kick-the-tires closeout

If the task asks to **install, configure, hire, run, publish, demo, integrate,
converge, or verify**, `done` requires **one observed runtime proof** (command
exit, listen/probe, rendered asset, or equivalent) **or** an explicit
waiver/blocker naming owner + what was not run.

### Mandatory checklist before `done`

1. **Final state observed** — the PRD’s observable final state was checked, not
   only that files exist.
2. **Command run** — exact command(s) executed; paste exit code / key output or
   link a git-tracked log.
3. **Artifact visible** — evidence lives outside a transient workspace
   (committed + pushed reviewable PR, or durable work product attachment).
4. **Unverified items named** — every NOT RUN item has owner + waiver or keeps
   the issue `blocked` / `in_review`.

### Status discipline

- Delegated live proof ⇒ parent stays `blocked` by the child (or `in_review`
  with a real interaction/monitor), never `done` merely because a follow-up
  issue exists.
- Writing IaC, factory seats, or examples without run/converge/durable surface
  ⇒ `blocked` or `in_review`, **not** `done`.
- Structure-only greps, org-chart files, or npm build alone do **not** satisfy
  a live-behavior claim.
