---
name: evals-org-redistribute
description: >-
  Org-wide evals reset → sync-pull → draft PRs → ready-for-review → land →
  main. Trigger on "redistribute evals", "org sync-pull", sync/reset-main,
  sync/redistribute, or sync/ship-land. Fail closed on dirty trees.
---

# evals-org-redistribute

Reset every included hutch-fail consumer to `origin/main`, refresh `evals/`
from the hub tip via `sync-pull` (kit + universe/language + **own leaf only**),
open one **draft** PR per repo (`gh pr create --draft`), then batch
**ready-for-review**, land with **land-pr-until-green** (RFV), squash-merge,
return each clone to `origin/main`, and run `sync/doctor`.

## When to use

- Org-wide kit redistribute after a hub merge
- User asks for `make sync/reset-main`, `sync/redistribute`, or `sync/ship-land`
- Repairing consumers after a bad pull that copied foreign `github.com/**` packs

## Preconditions

1. Hub change (especially `sync-pull` own-leaf preserve) is on **`origin/main`**
2. `CONSUMERS_ROOT` points at org checkouts (default `~/github.com/hutch-fail`)
3. Working trees for included clones are **clean** (fail closed otherwise)

Skip: hub (`evals`), archived, `*-wt-*` worktrees. Include `service-meter`
when product UI fixtures are under its own leaf (`ui-*`, not `evals/ui/`).

## Env

| Var | Default | Role |
| --- | --- | --- |
| `CONSUMERS_ROOT` | `$HOME/github.com/hutch-fail` | Org clone root |
| `HUB` | this hub checkout | Source for sync-pull |

## Make / scripts

From the hub:

```bash
make sync/list CONSUMERS_ROOT=…
make sync/reset-main CONSUMERS_ROOT=…
make sync/redistribute CONSUMERS_ROOT=… HUB=…   # after hub is on main
make sync/ship-land CONSUMERS_ROOT=… HUB=…     # reset+redistribute + checklist
make sync/doctor CONSUMERS_ROOT=…
```

Scripts: `scripts/sync-reset-to-main.sh`, `sync-redistribute.sh`,
`sync-ship-land.sh`, `sync-pull.sh`, `sync-doctor.sh`.

`sync-redistribute` commits, pushes, and opens **draft** PRs. Drafts skip
eval-ci and pre-commit until marked ready.

## Draft PRs + kit-only CI

1. Redistribute opens draft PRs — do **not** mark ready until spot-checked.
2. Batch **ready-for-review** (not all 16 at once if avoidable) so CI does not
   storm.
3. **Kit-only** syncs (`evals/**` only) rely on consumer pre-commit
   `paths-ignore` for `evals/**` — eval-ci still runs; do **not** use
   `[skip ci]` (that would skip eval-ci too).
4. Docs/markdown-only PRs skip eval-ci via caller `paths-ignore`.

## Agent loop (after mechanical redistribute)

For each `include=true` path from `sync/list` with a draft PR:

1. Confirm the draft diff is only the intended sync (kit + own leaf)
2. Mark **ready for review** (batch) when ready for CI
3. **land-pr-until-green** — max 5 rounds; RFV on CI fail; local VERIFY e.g.
   `make -C evals eval/select`
4. Squash-merge when land-ready
5. `git fetch && git checkout main && git reset --hard origin/main`

Then `make sync/doctor`.

Soft-require personal skills via `~/.claude/skills/land-pr-until-green`
(resolve-script.sh pattern). Commit/push/PR create is handled by
`sync-redistribute` (draft); shipit is optional if you need a manual PR.

## Consumer PR expectations

- Hub kit refresh + own leaf overlay only (no foreign packs)
- Root `.pre-commit-config.yaml` **required** before redistribute will commit
  (`20260929-pre-commit-platform`): `hutch-fail/pre-commit` `id: platform` +
  local `evals-pre-commit` → `evals/scripts/pre-commit-evals.sh`; also
  `evals-pre-push` → `evals/scripts/pre-push-evals.sh`
  (`20261002-local-eval-gates`, `default_install_hook_types` includes `pre-push`)
- Eval CI: single `eval-ci.yml` caller pinning
  `hutch-fail/evals/.github/workflows/eval-ci.yml@<sha>` (not separate
  pack/select). Prefer the hub template under
  `templates/github-workflows/eval-ci.yml`. Pass `OP_SERVICE_ACCOUNT_TOKEN`
  (or `secrets: inherit`) so the reusable can load App credentials from
  1Password and checkout private `hutch-fail/evals`.
- `languages: opentofu` in `scope.yaml` only if the repo has `*.tf`
- Eval pack (fixture + goal; result in a later commit) so `eval-ci` pack step
  passes

## Forbidden

- Hard-reset over dirty trees
- Touching archived / worktrees; wiping product-owned own leaves
- Redistributing from a hub tip that still rsyncs all of `github.com/**`
- Marking every draft ready in one burst without need
- Claiming success without `sync/doctor` OK after merges

## Related

- Docs: `docs/syncing.md`
- Goal: `goals/github.com/hutch-fail/evals/20260924-sync-pull-own-leaf.md`
- Skills: **land-pr-until-green**, **meta-dev**
