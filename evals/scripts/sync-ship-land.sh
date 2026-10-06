#!/usr/bin/env bash
# Orchestrate org redistribute: reset → redistribute (draft PRs) → land checklist.
# sync-redistribute commits/pushes and opens draft PRs; agent marks ready-for-review
# in batches, then land-pr-until-green (soft-require) → squash-merge.
# Usage: sync-ship-land.sh [--consumers-root DIR] [--hub DIR] [--skip-reset] [--skip-redistribute]
set -euo pipefail

HUB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONSUMERS_ROOT="${CONSUMERS_ROOT:-$HOME/github.com/hutch-fail}"
HUB="${HUB:-$HUB_ROOT}"
SKIP_RESET=0
SKIP_REDIST=0
ORG=hutch-fail

while [[ $# -gt 0 ]]; do
  case "$1" in
    --consumers-root) CONSUMERS_ROOT="${2:?}"; shift 2 ;;
    --hub) HUB="${2:?}"; shift 2 ;;
    --skip-reset) SKIP_RESET=1; shift ;;
    --skip-redistribute) SKIP_REDIST=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: sync-ship-land.sh [--consumers-root DIR] [--hub DIR] [--skip-reset] [--skip-redistribute]
Runs sync-reset-to-main then sync-redistribute (unless skipped). Redistribute
opens draft PRs. Then prints per-repo paths for ready-for-review (batch) →
land-pr-until-green (RFV) → squash-merge → checkout origin/main → sync/doctor.
EOF
      exit 0
      ;;
    *) printf 'error: unknown arg %s\n' "$1" >&2; exit 2 ;;
  esac
done

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }

RESET="$HUB_ROOT/scripts/sync-reset-to-main.sh"
REDIST="$HUB_ROOT/scripts/sync-redistribute.sh"
LIST="$HUB_ROOT/scripts/sync-list-repos.sh"
DOCTOR="$HUB_ROOT/scripts/sync-doctor.sh"
[[ -f "$RESET" ]] || die "missing $RESET"
[[ -f "$REDIST" ]] || die "missing $REDIST"
[[ -f "$LIST" ]] || die "missing $LIST"
command -v jq >/dev/null || die "jq required"

HUB="$(cd "$HUB" && pwd)"

if [[ "$SKIP_RESET" -eq 0 ]]; then
  log "==> sync-reset-to-main"
  CONSUMERS_ROOT="$CONSUMERS_ROOT" bash "$RESET" --consumers-root "$CONSUMERS_ROOT"
else
  log "==> skip reset"
fi

if [[ "$SKIP_REDIST" -eq 0 ]]; then
  log "==> sync-redistribute (hub=$HUB)"
  CONSUMERS_ROOT="$CONSUMERS_ROOT" bash "$REDIST" --consumers-root "$CONSUMERS_ROOT" --hub "$HUB"
else
  log "==> skip redistribute"
fi

log ""
log "==> Per included repo: ready-for-review (batch) → land-pr-until-green (max 5, RFV) → squash-merge → origin/main"
log "    Drafts skip eval-ci/pre-commit; kit-only relies on evals/** paths-ignore for pre-commit"
log "    Soft-require skill: land-pr-until-green (resolve via ~/.claude/skills)"
log "    Local VERIFY hint: make -C evals eval/select"
log ""

while IFS= read -r row; do
  name="$(jq -r '.name' <<<"$row")"
  include="$(jq -r '.include|tostring' <<<"$row")"
  path="$(jq -r '.path // empty' <<<"$row")"
  [[ "$include" == true ]] || continue
  br="$(git -C "$path" branch --show-current 2>/dev/null || echo '?')"
  dirty="$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  printf 'REPO  %-28s path=%s branch=%s dirty_files=%s\n' "$name" "$path" "$br" "$dirty"
done < <(CONSUMERS_ROOT="$CONSUMERS_ROOT" "$LIST" --format json --consumers-root "$CONSUMERS_ROOT" --org "$ORG" | jq -c '.[]')

log ""
log "After all merges: CONSUMERS_ROOT=$CONSUMERS_ROOT make -C $HUB_ROOT sync/doctor"
log "sync-ship-land: mechanical reset/redistribute (draft PRs) done; agent must ready+land each REPO line"
exit 0
