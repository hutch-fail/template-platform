#!/usr/bin/env bash
# Ensure CONSUMERS_ROOT is a local-only parent git repo with org children as
# submodules (membership = sync-list include=true + hub evals).
#
# Idempotent: init parent if needed; repair empty HEAD; register/absorb each
# module; refresh gitlinks; commit only when SHAs/modules/gitignore change.
#
# Usage:
#   sync-ensure-org-submodules.sh [--consumers-root DIR] [--org ORG]
#                                 [--list-json FILE] [--dry-run]
# Env: CONSUMERS_ROOT, ORG, ORG_SUBMODULE_LIST_JSON
#
# Operator: make -C evals sync/ensure-org-submodules
set -euo pipefail

HUB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONSUMERS_ROOT="${CONSUMERS_ROOT:-$HOME/github.com/hutch-fail}"
ORG="${ORG:-hutch-fail}"
DRY_RUN=0
LIST_JSON=""
COMMIT_MSG='chore(org): ensure submodule pins'
BOOTSTRAP_MSG='chore(org): bootstrap local parent'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --consumers-root) CONSUMERS_ROOT="${2:?}"; shift 2 ;;
    --org) ORG="${2:?}"; shift 2 ;;
    --list-json) LIST_JSON="${2:?}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: sync-ensure-org-submodules.sh [--consumers-root DIR] [--org ORG]
                                     [--list-json FILE] [--dry-run]
Make CONSUMERS_ROOT a local-only parent with org consumer (+ evals) submodules.
Membership comes from sync-list-repos (include=true) plus hub evals.
EOF
      exit 0
      ;;
    *) printf 'error: unknown arg %s\n' "$1" >&2; exit 2 ;;
  esac
done

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }

command -v jq >/dev/null || die "jq required"
command -v git >/dev/null || die "git required"

MEMBERSHIP_LIB="$HUB_ROOT/scripts/lib/org-submodule-membership.sh"
[[ -f "$MEMBERSHIP_LIB" ]] || die "missing $MEMBERSHIP_LIB"
# shellcheck source=lib/org-submodule-membership.sh
source "$MEMBERSHIP_LIB"

CONSUMERS_ROOT="$(cd "$CONSUMERS_ROOT" && pwd)"
[[ -d "$CONSUMERS_ROOT" ]] || die "consumers root not a directory: $CONSUMERS_ROOT"

membership_args=(--format json --consumers-root "$CONSUMERS_ROOT" --org "$ORG")
if [[ -n "$LIST_JSON" ]]; then
  membership_args+=(--list-json "$LIST_JSON")
fi
modules_json="$(org_submodule_membership "${membership_args[@]}")"
module_count="$(jq 'length' <<<"$modules_json")"
[[ "$module_count" -gt 0 ]] || die "no submodule membership rows (cloned include=true + evals)"

log "sync/ensure-org-submodules consumers_root=$CONSUMERS_ROOT modules=$module_count dry_run=$DRY_RUN"

parent_git_exists() { [[ -e "$CONSUMERS_ROOT/.git" ]]; }

parent_head_ok() {
  git -C "$CONSUMERS_ROOT" rev-parse --verify HEAD >/dev/null 2>&1
}

git_parent() {
  # Local-only parent: do not require global identity; keep commits deterministic.
  git -C "$CONSUMERS_ROOT" \
    -c user.email="${GIT_AUTHOR_EMAIL:-org-parent@localhost}" \
    -c user.name="${GIT_AUTHOR_NAME:-org-parent}" \
    "$@"
}

ensure_gitignore() {
  local gi="$CONSUMERS_ROOT/.gitignore"
  local needed=(
    'tmp-*'
    '.paperclip/'
    '.worktrees/'
    '*-wt-*'
    '.DS_Store'
  )
  if [[ ! -f "$gi" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "DRY   would write .gitignore"
      return
    fi
    {
      printf '%s\n' '# Local org parent — non-module junk (managed by sync/ensure-org-submodules)'
      printf '%s\n' "${needed[@]}"
    } >"$gi"
    log "OK    wrote .gitignore"
    return
  fi
  local line
  for line in "${needed[@]}"; do
    if ! grep -Fxq "$line" "$gi"; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        log "DRY   would append $line to .gitignore"
      else
        printf '%s\n' "$line" >>"$gi"
        log "OK    appended $line to .gitignore"
      fi
    fi
  done
}

module_url() {
  local abs="$1"
  local name="$2"
  local url=""
  if git -C "$abs" remote get-url origin >/dev/null 2>&1; then
    url="$(git -C "$abs" remote get-url origin)"
  fi
  if [[ -z "$url" ]]; then
    url="git@github.com:${ORG}/${name}.git"
  fi
  # Prefer SSH so guest worktrees can clone without HTTPS credentials
  # (ubuntu git config may rewrite https→ssh; do not rely on that alone).
  case "$url" in
    https://github.com/*|http://github.com/*)
      url="git@github.com:${url#*github.com/}"
      url="${url%.git}.git"
      ;;
  esac
  printf '%s\n' "$url"
}

register_module() {
  local name="$1"
  local rel="$2"
  local abs="$3"
  local url
  url="$(module_url "$abs" "$name")"

  if [[ ! -e "$abs/.git" ]]; then
    die "module $rel is not a git checkout ($abs)"
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY   register $rel url=$url"
    return
  fi

  git -C "$CONSUMERS_ROOT" config -f .gitmodules "submodule.${rel}.path" "$rel"
  git -C "$CONSUMERS_ROOT" config -f .gitmodules "submodule.${rel}.url" "$url"
  git -C "$CONSUMERS_ROOT" add -- .gitmodules

  # Stage as gitlink (160000) while nested .git dir still present, then absorb
  # when possible. Multi-worktree checkouts cannot relocate gitdir — keep the
  # nested .git directory; parent worktree + submodule update still works.
  if [[ -d "$abs/.git" ]]; then
    git -C "$CONSUMERS_ROOT" -c advice.addEmbeddedRepo=false add -- "$rel"
    mode="$(git -C "$CONSUMERS_ROOT" ls-files -s -- "$rel" | awk '{print $1}')"
    [[ "$mode" == "160000" ]] || die "expected gitlink 160000 for $rel, got ${mode:-none}"
    absorb_ok=0
    if git -C "$CONSUMERS_ROOT" submodule absorbgitdirs -- "$rel" 2>/dev/null; then
      absorb_ok=1
    fi
    if [[ "$absorb_ok" -eq 1 && -f "$abs/.git" ]]; then
      log "OK    absorbed $rel"
    elif [[ -d "$abs/.git" ]]; then
      # Multi-worktree, or odd paths (e.g. .github) where absorb is a no-op.
      wt_count="$(git -C "$abs" worktree list 2>/dev/null | wc -l | tr -d ' ')"
      log "WARN  absorbgitdirs skipped for $rel (worktrees=${wt_count:-?}; nested .git kept)"
    else
      die "absorbgitdirs left $rel without usable .git"
    fi
  elif [[ -f "$abs/.git" ]]; then
    # Already a submodule checkout — refresh gitlink to current child HEAD.
    git -C "$CONSUMERS_ROOT" add -- "$rel"
    log "OK    refreshed gitlink $rel"
  else
    die "module $rel has no .git after register"
  fi
}

# --- parent bootstrap -------------------------------------------------------
if ! parent_git_exists; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY   would git init -b main at $CONSUMERS_ROOT"
  else
    git -C "$CONSUMERS_ROOT" init -b main
    log "OK    git init -b main"
  fi
fi

ensure_gitignore

if ! parent_head_ok; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY   would bootstrap empty HEAD ($BOOTSTRAP_MSG)"
  else
    ensure_gitignore
    git -C "$CONSUMERS_ROOT" add -- .gitignore
    if [[ -n "$(git -C "$CONSUMERS_ROOT" status --porcelain)" ]]; then
      git_parent commit -m "$BOOTSTRAP_MSG"
    else
      git_parent commit --allow-empty -m "$BOOTSTRAP_MSG"
    fi
    parent_head_ok || die "failed to repair empty HEAD; refuse to continue"
    log "OK    repaired empty HEAD → $(git -C "$CONSUMERS_ROOT" rev-parse --short HEAD)"
  fi
fi

# --- register each module ---------------------------------------------------
while IFS= read -r row; do
  name="$(jq -r '.name' <<<"$row")"
  rel="$(jq -r '.rel' <<<"$row")"
  abs="$(jq -r '.path' <<<"$row")"
  register_module "$name" "$rel" "$abs"
done < <(jq -c '.[]' <<<"$modules_json")

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "sync/ensure-org-submodules: DRY-RUN complete"
  exit 0
fi

git -C "$CONSUMERS_ROOT" add -- .gitmodules .gitignore 2>/dev/null || true

if [[ -n "$(git -C "$CONSUMERS_ROOT" status --porcelain)" ]]; then
  git_parent commit -m "$COMMIT_MSG"
  log "OK    committed pin update → $(git -C "$CONSUMERS_ROOT" rev-parse --short HEAD)"
else
  log "OK    pins unchanged (no commit)"
fi

parent_head_ok || die "HEAD unresolvable after ensure"
[[ -f "$CONSUMERS_ROOT/.gitmodules" ]] || die "missing .gitmodules after ensure"
log "sync/ensure-org-submodules: OK HEAD=$(git -C "$CONSUMERS_ROOT" rev-parse --short HEAD)"
exit 0
