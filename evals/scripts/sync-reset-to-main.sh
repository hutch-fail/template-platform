#!/usr/bin/env bash
# Reset every included local clone under CONSUMERS_ROOT to origin/main.
# Fail closed on dirty trees (never hard-reset over uncommitted work).
# Usage: sync-reset-to-main.sh [--consumers-root DIR] [--exclude NAME]… [--dry-run]
# Env: SYNC_EXCLUDE=name1,name2 (passed through to sync-list-repos).
set -euo pipefail

HUB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONSUMERS_ROOT="${CONSUMERS_ROOT:-$HOME/github.com/hutch-fail}"
DRY_RUN=0
ORG=hutch-fail
LIST_EXCLUDE_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --consumers-root) CONSUMERS_ROOT="${2:?}"; shift 2 ;;
    --exclude)
      LIST_EXCLUDE_ARGS+=(--exclude "${2:?}")
      shift 2
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      printf '%s\n' "Usage: $0 [--consumers-root DIR] [--exclude NAME]… [--dry-run]" \
        "Env: SYNC_EXCLUDE=name1,name2"
      exit 0
      ;;
    *) printf 'error: unknown arg %s\n' "$1" >&2; exit 2 ;;
  esac
done

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }

# Prefer HTTPS when SSH publickey fails (same pattern as shipit).
git_https() {
  git -c url."https://github.com/".insteadOf="git@github.com:" \
      -c url."https://github.com/".insteadOf="git@ssh.github.com:" \
      "$@"
}

LIST_SCRIPT="$HUB_ROOT/scripts/sync-list-repos.sh"
[[ -x "$LIST_SCRIPT" || -f "$LIST_SCRIPT" ]] || die "missing $LIST_SCRIPT"
command -v jq >/dev/null || die "jq required"

FAIL=0
SKIPPED=0
OK=0

while IFS= read -r row; do
  name="$(jq -r '.name' <<<"$row")"
  include="$(jq -r '.include|tostring' <<<"$row")"
  path="$(jq -r '.path // empty' <<<"$row")"
  [[ "$include" == true ]] || continue
  # Submodules use a .git *file*; plain clones use a .git directory.
  if [[ -z "$path" || ! -e "$path/.git" ]]; then
    log "FAIL  $name uncloned or not a git repo"
    FAIL=1
    continue
  fi
  if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
    log "FAIL  $name dirty working tree — refuse reset"
    FAIL=1
    continue
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY   $name would fetch + checkout main + reset --hard origin/main"
    OK=$((OK + 1))
    continue
  fi
  git_https -C "$path" fetch origin --prune
  if git -C "$path" show-ref --verify --quiet refs/remotes/origin/main; then
    branch=main
  elif git -C "$path" show-ref --verify --quiet refs/remotes/origin/master; then
    branch=master
  else
    log "FAIL  $name no origin/main or origin/master"
    FAIL=1
    continue
  fi
  git -C "$path" checkout "$branch"
  git -C "$path" reset --hard "origin/$branch"
  log "OK    $name → origin/$branch ($(git -C "$path" rev-parse --short HEAD))"
  OK=$((OK + 1))
done < <(CONSUMERS_ROOT="$CONSUMERS_ROOT" SYNC_EXCLUDE="${SYNC_EXCLUDE:-}" \
  "$LIST_SCRIPT" --format json --consumers-root "$CONSUMERS_ROOT" --org "$ORG" \
  "${LIST_EXCLUDE_ARGS[@]}" | jq -c '.[]')

log "sync-reset-to-main: ok=$OK fail=$FAIL dry_run=$DRY_RUN"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
