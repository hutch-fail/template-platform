---
schema: goal/v1
id: 20261004-sync-secrets-pin-github-owner
title: sync-secrets must hard-pin GITHUB_OWNER (no parent-shell inherit)
scope: universe
fixture_dir: evals/fixtures/universe/20261004-sync-secrets-pin-github-owner
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

# Executive overview

A parent-shell `GITHUB_OWNER` once caused dest `make sync-secrets` to write
Cloudflare credentials into the wrong GitHub org. This always-on universe bar
fails closed when a consumer ships `scripts/sync-secrets.sh` but still lets
`GITHUB_OWNER` inherit via `: "${GITHUB_OWNER:=…}"`.

# Decision

A pass lets us say every recipe consumer with `scripts/sync-secrets.sh`
assigns `GITHUB_OWNER` as a literal after dotenv load. A pass does not prove
live GitHub secret values, probe Cloudflare, or migrate credentials.

This authoring run must not pass while the fixture still inherits
`GITHUB_OWNER` from the environment.

# User outcome

Operators cannot accidentally push dest Cloudflare tokens into another org’s
Actions environment because a leftover `GITHUB_OWNER` was exported in the shell.

# Scope

| Covered | Not covered |
| --- | --- |
| Consumers that ship `scripts/sync-secrets.sh` | Repos without that script (skip / pass) |
| Literal `GITHUB_OWNER="org"` (or equivalent) in `scripts/lib/env.sh` or `sync-secrets.sh` | Live `gh secret list` inventory |
| Optional: `gh secret set --repo` built from that pin | Token permission probes |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | Fixture `scripts/lib/env.sh` uses `: "${GITHUB_OWNER:=hutch-fail}"`; `check.sh` exits non-zero |
| The fix works | After `golden.patch`, literal `GITHUB_OWNER="coachmind-ca"`; `check.sh` exits 0 |
| Skip-if-absent | Scan root without `scripts/sync-secrets.sh` exits 0 |
| Nothing else breaks | `p2p-smoke.sh` stays green |

# Dataset

One fixture tree with `scripts/sync-secrets.sh` + `scripts/lib/env.sh`. No
hold-out / train|test split — the bar is a deterministic source grep. Product
pre-commit and eval-ci scan `HERMES_EVAL_SCAN_ROOT` the same way.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Hard pin present | Program (`check.sh`) | Visible in shell source |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Did the patch stop inheriting GITHUB_OWNER? | F2P fails before patch; F2P+P2P pass after | Either check wrong |

# Execution

`make eval/assert-red` then wire shared `eval/bars` (`run_universe_bars`), then
`make eval/verify`.

# Limitations

Does not inspect GitHub. Does not forbid extra `:=` defaults if a later literal
assignment wins. Standing law — keep after the Cloudflare account move.

# Result file

After the run, write `20261004-sync-secrets-pin-github-owner-result.md` beside this goal.
Commit the result in a later local commit, not with this goal or its fixture.
Both commits may be in one pull request. Squash or merge may combine them.
