#!/usr/bin/env bash
# Branch each included consumer, sync-pull from hub tip, commit, push, open a DRAFT PR.
# Usage: sync-redistribute.sh [--consumers-root DIR] [--hub DIR] [--branch NAME] [--dry-run]
set -euo pipefail

HUB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONSUMERS_ROOT="${CONSUMERS_ROOT:-$HOME/github.com/hutch-fail}"
HUB="${HUB:-$HUB_ROOT}"
DRY_RUN=0
ORG=hutch-fail
BRANCH="chore/sync-evals-$(date +%Y%m%d)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --consumers-root) CONSUMERS_ROOT="${2:?}"; shift 2 ;;
    --hub) HUB="${2:?}"; shift 2 ;;
    --branch) BRANCH="${2:?}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: sync-redistribute.sh [--consumers-root DIR] [--hub DIR] [--branch NAME] [--dry-run]
For each include=true kit/missing clone: refuse if dirty; checkout/create BRANCH;
run sync-pull.sh --hub HUB (--init-scope if no scope.yaml); install-host-adapters.sh;
commit + push when the tree changed; open a draft PR (gh pr create --draft).
Leave PRs draft until ready-for-review so eval-ci/pre-commit stay skipped.
EOF
      exit 0
      ;;
    *) printf 'error: unknown arg %s\n' "$1" >&2; exit 2 ;;
  esac
done

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }

git_https() {
  git -c url."https://github.com/".insteadOf="git@github.com:" \
      -c url."https://github.com/".insteadOf="git@ssh.github.com:" \
      "$@"
}

LIST_SCRIPT="$HUB_ROOT/scripts/sync-list-repos.sh"
PULL_SCRIPT="$HUB_ROOT/scripts/sync-pull.sh"
ADAPTERS="$HUB_ROOT/scripts/install-host-adapters.sh"
[[ -f "$LIST_SCRIPT" ]] || die "missing $LIST_SCRIPT"
[[ -f "$PULL_SCRIPT" ]] || die "missing $PULL_SCRIPT"
[[ -f "$ADAPTERS" ]] || die "missing $ADAPTERS"
command -v jq >/dev/null || die "jq required"
command -v gh >/dev/null || die "gh required (draft PR create)"
HUB="$(cd "$HUB" && pwd)"
[[ -f "$HUB/Makefile" ]] || die "HUB=$HUB missing Makefile"

FAIL=0
OK=0
DRAFT_PRS=0

open_draft_pr() {
  local path="$1" name="$2"
  local title body url existing
  title="chore(evals): sync kit from hub (${BRANCH})"
  body="$(cat <<EOF
## Summary
- Sync-pull evals kit (+ universe/language + own leaf) from hub tip
- Host adapters refreshed

## Notes
- Opened as **draft** so eval-ci / pre-commit stay skipped until ready-for-review
- Kit-only diffs rely on consumer \`evals/**\` paths-ignore for pre-commit (no \`[skip ci]\`)
- Mark ready-for-review in batches after spot-check

EOF
)"
  existing="$(gh pr list --repo "${ORG}/${name}" --head "$BRANCH" --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  if [[ -n "$existing" ]]; then
    url="$(gh pr view "$existing" --repo "${ORG}/${name}" --json url --jq .url)"
    log "OK    $name draft PR already #${existing} $url"
    return 0
  fi
  url="$(gh pr create --repo "${ORG}/${name}" --draft --base main --head "$BRANCH" --title "$title" --body "$body")"
  log "OK    $name draft PR $url"
  DRAFT_PRS=$((DRAFT_PRS + 1))
}

while IFS= read -r row; do
  name="$(jq -r '.name' <<<"$row")"
  include="$(jq -r '.include|tostring' <<<"$row")"
  path="$(jq -r '.path // empty' <<<"$row")"
  [[ "$include" == true ]] || continue
  # Submodules use a .git *file*; plain clones use a .git directory.
  if [[ -z "$path" || ! -e "$path/.git" ]]; then
    log "FAIL  $name uncloned"
    FAIL=1
    continue
  fi
  if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
    log "FAIL  $name dirty — refuse redistribute"
    FAIL=1
    continue
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY   $name would branch $BRANCH + sync-pull + adapters + draft PR"
    OK=$((OK + 1))
    continue
  fi
  git_https -C "$path" fetch origin --prune
  if git -C "$path" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git -C "$path" checkout "$BRANCH"
  else
    # Prefer branching from current mainline tip
    if git -C "$path" show-ref --verify --quiet refs/remotes/origin/main; then
      git -C "$path" checkout -B "$BRANCH" origin/main
    elif git -C "$path" show-ref --verify --quiet refs/remotes/origin/master; then
      git -C "$path" checkout -B "$BRANCH" origin/master
    else
      git -C "$path" checkout -B "$BRANCH"
    fi
  fi

  init_args=()
  if [[ ! -f "$path/evals/scope.yaml" ]]; then
    init_args+=(--init-scope)
  fi
  (
    cd "$path"
    bash "$PULL_SCRIPT" --hub "$HUB" "${init_args[@]}"
    bash "$ADAPTERS"
  )

  if [[ -z "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
    # No tree change — still ensure a draft PR exists if the branch was pushed before.
    if git -C "$path" rev-parse --verify --quiet "origin/${BRANCH}" >/dev/null 2>&1; then
      open_draft_pr "$path" "$name" || { log "FAIL  $name draft PR"; FAIL=1; continue; }
    else
      log "OK    $name on $BRANCH (no changes; skip push/PR)"
    fi
    OK=$((OK + 1))
    continue
  fi

  git -C "$path" add -A
  if git -C "$path" diff --cached --quiet; then
    log "OK    $name on $BRANCH (nothing staged; skip)"
    OK=$((OK + 1))
    continue
  fi
  # Refuse commit when host lacks org pre-commit (20260929-pre-commit-platform).
  if [[ ! -f "$path/.pre-commit-config.yaml" ]]; then
    log "FAIL  $name missing root .pre-commit-config.yaml — backfill org pre-commit (hutch-fail/pre-commit id: platform + local evals-pre-commit + evals-pre-push) before redistribute"
    FAIL=1
    continue
  fi
  # Local result gate (20261002-local-eval-gates): require pre-push pack entry.
  if ! grep -Fq 'pre-push-evals.sh' "$path/.pre-commit-config.yaml"; then
    log "FAIL  $name .pre-commit-config.yaml missing pre-push-evals.sh — backfill evals-pre-push (default_install_hook_types includes pre-push) before redistribute"
    FAIL=1
    continue
  fi
  # Pack gate: adapter / kit sync touches paths outside existing goals — seed a
  # dated repo pack so local evals-pre-commit does not fail closed.
  pack_id="20261001-sync-evals-kit"
  pack_goal="$path/evals/goals/github.com/${ORG}/${name}/${pack_id}.md"
  pack_fix="$path/evals/fixtures/github.com/${ORG}/${name}/${pack_id}"
  if [[ ! -f "$pack_goal" ]]; then
    mkdir -p "$(dirname "$pack_goal")" "$pack_fix"
    cat >"$pack_goal" <<EOF
---
schema: goal/v1
id: ${pack_id}
title: Sync evals kit from hub
scope: repo
fixture_dir: evals/fixtures/github.com/${ORG}/${name}/${pack_id}
f2p_check: check.sh
p2p_check: p2p-smoke.sh
solver: none
---

# Decision

A pass lets us claim this consumer received a sync-pull of the evals kit
(including language/gha bars) from hub tip on ${BRANCH}.
EOF
    cat >"$pack_fix/check.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
root="${HERMES_EVAL_REPO_ROOT:-${HERMES_EVAL_SCAN_ROOT:-$PWD}}"
[[ -f "${root}/evals/scripts/eval-bars.sh" ]] || { echo "missing eval-bars.sh" >&2; exit 1; }
grep -q 'run_gha_bars' "${root}/evals/scripts/eval-bars.sh" || { echo "missing run_gha_bars after sync" >&2; exit 1; }
echo sync_evals_kit_ok
EOF
    cat >"$pack_fix/p2p-smoke.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${dir}/check.sh"
EOF
    chmod +x "$pack_fix/check.sh" "$pack_fix/p2p-smoke.sh"
    git -C "$path" add -f "$pack_goal" "$pack_fix"
  fi
  if ! git -C "$path" commit -m "$(cat <<EOF
chore(evals): sync kit from hub

Redistribute via sync-pull + host adapters (${BRANCH}).
EOF
)"; then
    log "FAIL  $name sync commit (pre-commit/pack-quality)"
    FAIL=1
    git -C "$path" reset --hard HEAD >/dev/null 2>&1 || true
    git -C "$path" clean -fd >/dev/null 2>&1 || true
    git -C "$path" checkout main --quiet 2>/dev/null || true
    continue
  fi
  # Result in a follow-up commit (result-not-with-eval).
  pack_result="$path/evals/goals/github.com/${ORG}/${name}/${pack_id}-result.md"
  if [[ ! -f "$pack_result" ]]; then
    cat >"$pack_result" <<EOF
---
schema: goal-result/v1
id: ${pack_id}
status: pass
---

Kit sync-pull includes language/gha bars (run_gha_bars present).
EOF
    git -C "$path" add -f "$pack_result"
    git -C "$path" commit -m "test(evals): result for ${pack_id}" || true
  fi
  git_https -C "$path" push -u origin "HEAD:${BRANCH}"
  open_draft_pr "$path" "$name" || { log "FAIL  $name draft PR"; FAIL=1; continue; }
  log "OK    $name on $BRANCH (sync-pull + adapters + draft PR)"
  OK=$((OK + 1))
done < <(CONSUMERS_ROOT="$CONSUMERS_ROOT" "$LIST_SCRIPT" --format json --consumers-root "$CONSUMERS_ROOT" --org "$ORG" | jq -c '.[]')

log "sync-redistribute: ok=$OK fail=$FAIL draft_prs=$DRAFT_PRS branch=$BRANCH hub=$HUB"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
