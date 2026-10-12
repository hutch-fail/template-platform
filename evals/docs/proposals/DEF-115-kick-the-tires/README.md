# DEF-115 proposal — company-wide kick-the-tires closeout (pending CEO/board)

**Status:** ACCEPTED by local-board (DEF-115 confirmation `9b3fe795…`) — landed in `paperclip-agentic-company` on branch `DEF-108-setup-game-dev-agent`.

**Why:** DEF-108 closed on structure-only checks while live behavior was requested.
Eval procedure for (a) lands in the `evals` hub without this approval. Items below
touch shared operating rules and must be reviewable before hot-swap.

## Contents

| File | Intended home after approval |
| --- | --- |
| `AGENTS-closeout-snippet.md` | Append to role-agnostic / CEO+PM+engineer `AGENTS.md` (factory under `paperclip-agentic-company/agents/`) |
| `skill-kick-the-tires/SKILL.md` | New skill `local/.../kick-the-tires` (or company skills tree) |
| `pull_request_template.md` | Org or product `.github/PULL_REQUEST_TEMPLATE.md` |

## Eval procedure already landed (no board gate)

- `PROCESS.md` — Kick-the-tires / structure-only disposition
- `scripts/grade-structure-only-disposition.sh`
- Universe pack `goals/universe/20261009-kick-the-tires-structure-only.md`
  (paths relative to the evals hub)

## Approval question

Accept landing the three artifacts above into company SoT (AGENTS + skill + PR
template), with SDET/Platform applying them in a follow-up reviewable PR after
accept?
