#!/usr/bin/env bash
# Sync hub kit into a consumer's evals/ (bootstrap or refresh).
# Run from the consumer repository root:
#   bash /path/to/evals/scripts/sync-pull.sh [--hub DIR] [--init-scope] [--attachment MODE]
# Or: make -C evals sync/pull HUB=../evals  (once kit exists)
#
# Redistributes: kit + goals|fixtures/universe/ + goals|fixtures/language/
# + this repo's own github.com/<org>/<repo>/ leaf (preserve then overlay from hub).
# Does NOT copy other products' github.com packs. Omits runs/ and .github/.
# Preserves evals/scope.yaml.
# --attachment ephemeral|kit|full installs persist gitignore (default full).
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }

CONSUMER_ROOT="$(pwd)"
HUB=""
INIT_SCOPE=0
DRY_RUN=0
ATTACHMENT_CLI=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hub) HUB="${2:?}"; shift 2 ;;
    --init-scope) INIT_SCOPE=1; shift ;;
    --attachment) ATTACHMENT_CLI="${2:?}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: sync-pull.sh [--hub DIR] [--init-scope] [--attachment ephemeral|kit|full] [--dry-run]
Run from the consumer repo root. Syncs hub → ./evals/:
  kit + universe/language (+ fixtures) + own github.com/<org>/<repo>/ leaf only.
Preserves existing evals/scope.yaml and consumer-owned own leaf, then overlays
that leaf from hub when present. Omits runs/, .github/, and other products'
github.com packs. --attachment installs the persist gitignore (default: full).
EOF
      exit 0
      ;;
    *) die "unknown arg $1" ;;
  esac
done

if [[ -z "$HUB" ]]; then
  # Submodules use a .git *file*; plain clones use a .git directory.
  if [[ -e "$CONSUMER_ROOT/../evals/.git" ]]; then
    HUB="$(cd "$CONSUMER_ROOT/../evals" && pwd)"
  else
    die "pass --hub /path/to/evals hub checkout"
  fi
fi
HUB="$(cd "$HUB" && pwd)"
[[ -f "$HUB/Makefile" ]] || die "HUB=$HUB does not look like the evals hub (no Makefile)"
[[ -f "$HUB/harness/goal.sh" ]] || die "HUB=$HUB missing harness/goal.sh"
command -v rsync >/dev/null || die "rsync required"

ATTACH_LIB=""
if [[ -f "$HUB/harness/lib/attachment.sh" ]]; then
  ATTACH_LIB="$HUB/harness/lib/attachment.sh"
elif [[ -f "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/harness/lib/attachment.sh" ]]; then
  ATTACH_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/harness/lib/attachment.sh"
fi
if [[ -n "$ATTACH_LIB" ]]; then
  # shellcheck source=../harness/lib/attachment.sh
  source "$ATTACH_LIB"
fi

ATTACHMENT="full"
if declare -F eval_attachment_normalize >/dev/null 2>&1; then
  if [[ -n "$ATTACHMENT_CLI" ]]; then
    ATTACHMENT="$(eval_attachment_normalize "$ATTACHMENT_CLI")"
  elif [[ -f "$CONSUMER_ROOT/evals/scope.yaml" ]]; then
    ATTACHMENT="$(eval_attachment_from_scope "$CONSUMER_ROOT/evals/scope.yaml")"
  else
    ATTACHMENT="full"
  fi
elif [[ -n "$ATTACHMENT_CLI" ]]; then
  die "missing harness/lib/attachment.sh (required for --attachment)"
fi

DEST="$CONSUMER_ROOT/evals"
SCOPE_BACKUP=""
OWN_GOALS_BACKUP=""
OWN_FIX_BACKUP=""
tmpdir=""
cleanup() {
  if [[ -n "$SCOPE_BACKUP" && -f "$SCOPE_BACKUP" ]]; then
    mkdir -p "$DEST"
    cp -a "$SCOPE_BACKUP" "$DEST/scope.yaml"
  fi
  [[ -n "$tmpdir" && -d "$tmpdir" ]] && rm -rf "$tmpdir"
}
trap cleanup EXIT

infer_repo_slug() {
  local url
  url="$(git -C "$CONSUMER_ROOT" remote get-url origin 2>/dev/null || true)"
  if [[ "$url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    printf 'github.com/%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return
  fi
  local base
  base="$(basename "$CONSUMER_ROOT")"
  if [[ "$base" == "dot-github" ]]; then
    printf 'github.com/hutch-fail/.github\n'
    return
  fi
  printf 'github.com/hutch-fail/%s\n' "$base"
}

slug="$(infer_repo_slug)"
# slug is github.com/<org>/<repo> — leaf under goals|fixtures
own_rel="${slug}"

tmpdir="$(mktemp -d)"

if [[ -f "$DEST/scope.yaml" ]]; then
  SCOPE_BACKUP="$tmpdir/scope.yaml"
  cp -a "$DEST/scope.yaml" "$SCOPE_BACKUP"
  log "preserved existing evals/scope.yaml"
fi

if [[ -d "$DEST/goals/${own_rel}" ]]; then
  OWN_GOALS_BACKUP="$tmpdir/own-goals"
  mkdir -p "$OWN_GOALS_BACKUP"
  cp -a "$DEST/goals/${own_rel}/." "$OWN_GOALS_BACKUP/"
  log "preserved consumer own goals leaf ${own_rel}"
fi
if [[ -d "$DEST/fixtures/${own_rel}" ]]; then
  OWN_FIX_BACKUP="$tmpdir/own-fixtures"
  mkdir -p "$OWN_FIX_BACKUP"
  cp -a "$DEST/fixtures/${own_rel}/." "$OWN_FIX_BACKUP/"
  log "preserved consumer own fixtures leaf ${own_rel}"
fi

RSYNC_FLAGS=(-a --delete --exclude 'runs/' --exclude '.github/' --exclude '.git/' \
  --exclude 'goals/github.com/' --exclude 'fixtures/github.com/')
if [[ "$DRY_RUN" -eq 1 ]]; then
  RSYNC_FLAGS+=(--dry-run --itemize-changes)
fi

mkdir -p "$DEST"
log "rsync $HUB/ → $DEST/ (kit + universe/language; omit foreign github.com packs)"
rsync "${RSYNC_FLAGS[@]}" "$HUB/" "$DEST/"

restore_own_leaf() {
  local kind="$1" backup="$2"
  local dest_leaf="$DEST/${kind}/${own_rel}"
  if [[ -n "$backup" && -d "$backup" ]]; then
    mkdir -p "$dest_leaf"
    cp -a "$backup/." "$dest_leaf/"
  fi
}

if [[ "$DRY_RUN" -eq 0 ]]; then
  # Drop stale foreign packs left from earlier full-tree pulls, then restore own leaf.
  if [[ -d "$DEST/goals/github.com" ]]; then
    rm -rf "$DEST/goals/github.com"
    log "removed stale goals/github.com (will restore own leaf only)"
  fi
  if [[ -d "$DEST/fixtures/github.com" ]]; then
    rm -rf "$DEST/fixtures/github.com"
    log "removed stale fixtures/github.com (will restore own leaf only)"
  fi

  restore_own_leaf goals "$OWN_GOALS_BACKUP"
  restore_own_leaf fixtures "$OWN_FIX_BACKUP"

  # Overlay own leaf from hub when present (harvested updates)
  if [[ -d "$HUB/goals/${own_rel}" ]]; then
    mkdir -p "$DEST/goals/${own_rel}"
    rsync -a "$HUB/goals/${own_rel}/" "$DEST/goals/${own_rel}/"
    log "overlaid own goals leaf from hub: ${own_rel}"
  fi
  if [[ -d "$HUB/fixtures/${own_rel}" ]]; then
    mkdir -p "$DEST/fixtures/${own_rel}"
    rsync -a "$HUB/fixtures/${own_rel}/" "$DEST/fixtures/${own_rel}/"
    log "overlaid own fixtures leaf from hub: ${own_rel}"
  fi
fi

# Restore scope after rsync --delete
if [[ -n "$SCOPE_BACKUP" && -f "$SCOPE_BACKUP" ]]; then
  cp -a "$SCOPE_BACKUP" "$DEST/scope.yaml"
  SCOPE_BACKUP=""  # avoid double restore in trap
fi

if [[ ! -f "$DEST/scope.yaml" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY: would write minimal scope.yaml for $slug"
  else
    {
      cat <<EOF
schema: evals-scope/v1
repo: $slug
languages: []
opt_out: []
EOF
      if [[ -n "$ATTACHMENT_CLI" ]]; then
        printf 'attachment: %s\n' "$ATTACHMENT"
      fi
    } >"$DEST/scope.yaml"
    log "wrote minimal evals/scope.yaml ($slug)"
  fi
elif [[ "$INIT_SCOPE" -eq 1 ]]; then
  log "scope.yaml already present — left unchanged (--init-scope)"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "✓ sync-pull dry-run done → $DEST"
  exit 0
fi
[[ -f "$DEST/Makefile" ]] || die "sync incomplete: no evals/Makefile"
[[ -f "$DEST/scope.yaml" ]] || die "sync incomplete: no evals/scope.yaml"

if [[ "$DRY_RUN" -eq 0 ]]; then
  if declare -F eval_attachment_install_gitignore >/dev/null 2>&1; then
    eval_attachment_install_gitignore "$CONSUMER_ROOT" "$ATTACHMENT" "$HUB/templates"
    log "attachment=${ATTACHMENT} persist gitignore applied"
  fi
fi

log "✓ sync-pull done → $DEST (own leaf ${own_rel} only under github.com/; attachment=${ATTACHMENT})"
