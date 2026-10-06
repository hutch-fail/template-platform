#!/usr/bin/env bash
# Harvest consumer packs (+ optional kit deltas) into this hub working tree.
# Run from hub root or via make sync/harvest.
#
# Packs: goals/github.com/** and fixtures/github.com/** (never scope.yaml).
# Own-repo leaf (matching consumer name) always wins on conflict.
# Shared leaves: copy consumer-only files; report content conflicts when both
# sides exist and differ (does not overwrite unless --prefer-consumer).
# Kit deltas: files under kit paths that exist only on consumer → copy;
# differing kit files → conflict report (hub wins unless --prefer-consumer).
set -euo pipefail

HUB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONSUMERS_ROOT="${CONSUMERS_ROOT:-$HOME/github.com/hutch-fail}"
ORG=hutch-fail
DRY_RUN=0
PREFER_CONSUMER=0
KIT=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --consumers-root) CONSUMERS_ROOT="${2:?}"; shift 2 ;;
    --org) ORG="${2:?}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --prefer-consumer) PREFER_CONSUMER=1; shift ;;
    --no-kit) KIT=0; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: sync-harvest.sh [--consumers-root DIR] [--dry-run] [--prefer-consumer] [--no-kit]
Harvest packs (and kit-only consumer files) into the hub tree.
EOF
      exit 0
      ;;
    *) printf 'error: unknown arg %s\n' "$1" >&2; exit 2 ;;
  esac
done

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }

if [[ -f "$HUB_ROOT/harness/lib/attachment.sh" ]]; then
  # shellcheck source=../harness/lib/attachment.sh
  source "$HUB_ROOT/harness/lib/attachment.sh"
fi
run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'DRY: %s\n' "$*"
  else
    "$@"
  fi
}

LIST_SCRIPT="$HUB_ROOT/scripts/sync-list-repos.sh"
[[ -x "$LIST_SCRIPT" ]] || die "missing $LIST_SCRIPT"

KIT_PATHS=(
  Makefile AGENTS.md PROCESS.md README.md .gitignore .pre-commit-config.yaml
  harness skills scripts templates tests docs .agents .cursor
)

conflicts=0
copied=0
skipped=0

copy_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  run cp -a "$src" "$dest"
  copied=$((copied + 1))
}

# Copy tree files from src_root → dest_root for relative paths under rel.
# mode: own | shared
harvest_tree() {
  local src_root="$1" dest_root="$2" rel="$3" consumer="$4" mode="$5"
  local src="$src_root/$rel"
  [[ -d "$src" ]] || return 0
  while IFS= read -r -d '' f; do
    local rel_file="${f#"$src_root"/}"
    # Never harvest bytecode / junk
    case "$rel_file" in
      *__pycache__*|*.pyc|*/.DS_Store) continue ;;
    esac
    local dest="$dest_root/$rel_file"
    if [[ ! -e "$dest" ]]; then
      log "COPY  $consumer → hub  $rel_file"
      copy_file "$f" "$dest"
    elif cmp -s "$f" "$dest"; then
      skipped=$((skipped + 1))
    else
      if [[ "$mode" == own ]] || [[ "$PREFER_CONSUMER" -eq 1 ]]; then
        log "OVERWRITE ($mode) $consumer → hub  $rel_file"
        copy_file "$f" "$dest"
      else
        log "CONFLICT  $rel_file  (hub keeps; consumer=$consumer)"
        conflicts=$((conflicts + 1))
      fi
    fi
  done < <(find "$src" -type f -print0)
}

harvest_consumer() {
  local name="$1" path="$2" class="$3"
  [[ "$class" == kit || "$class" == pack-only ]] || return 0
  local evals="$path/evals"
  [[ -d "$evals" ]] || return 0

  log "=== harvest $name ($class) ==="

  local att="full"
  if declare -F eval_attachment_from_scope >/dev/null 2>&1; then
    att="$(eval_attachment_from_scope "$evals/scope.yaml")"
  fi
  local own_rel="github.com/${ORG}/${name}"
  if [[ "$name" == ".github" || "$name" == "dot-github" ]]; then
    own_rel="github.com/${ORG}/.github"
  fi

  if [[ "$att" == "kit" || "$att" == "ephemeral" ]]; then
    eval_attachment_refuse_foreign_leaves "$path" "$own_rel" \
      || die "harvest $name: foreign github.com leaf in $att tree"
    eval_attachment_harvest_own_leaf "$path" "$HUB_ROOT" "$own_rel"
    log "harvested own leaf $own_rel ($att; skipped foreign github.com walk)"
  else
  # Product packs under github.com/
  if [[ -d "$evals/goals/github.com" ]]; then
    while IFS= read -r -d '' leaf; do
      local org repo rel mode
      org="$(basename "$(dirname "$leaf")")"
      repo="$(basename "$leaf")"
      rel="goals/github.com/$org/$repo"
      if [[ "$org" == "$ORG" && "$repo" == "$name" ]]; then
        mode=own
      else
        mode=shared
      fi
      harvest_tree "$evals" "$HUB_ROOT" "$rel" "$name" "$mode"
    done < <(find "$evals/goals/github.com" -mindepth 2 -maxdepth 2 -type d -print0)
  fi
  if [[ -d "$evals/fixtures/github.com" ]]; then
    while IFS= read -r -d '' leaf; do
      local org repo rel mode
      org="$(basename "$(dirname "$leaf")")"
      repo="$(basename "$leaf")"
      rel="fixtures/github.com/$org/$repo"
      if [[ "$org" == "$ORG" && "$repo" == "$name" ]]; then
        mode=own
      else
        mode=shared
      fi
      harvest_tree "$evals" "$HUB_ROOT" "$rel" "$name" "$mode"
    done < <(find "$evals/fixtures/github.com" -mindepth 2 -maxdepth 2 -type d -print0)
  fi
  fi

  # Kit deltas: consumer-only files under kit paths (hub wins on content conflict)
  if [[ "$KIT" -eq 1 && "$class" == kit ]]; then
    local kp
    for kp in "${KIT_PATHS[@]}"; do
      local src="$evals/$kp"
      [[ -e "$src" ]] || continue
      if [[ -d "$src" ]]; then
        while IFS= read -r -d '' f; do
          local rel_file="${f#"$evals"/}"
          # Never harvest hub-only CI under .github into kit sync from consumers
          [[ "$rel_file" == .github/* ]] && continue
          local dest="$HUB_ROOT/$rel_file"
          if [[ ! -e "$dest" ]]; then
            log "KIT+  $name → hub  $rel_file"
            copy_file "$f" "$dest"
          elif ! cmp -s "$f" "$dest"; then
            if [[ "$PREFER_CONSUMER" -eq 1 ]]; then
              log "KIT~  overwrite $rel_file from $name"
              copy_file "$f" "$dest"
            else
              log "KIT-CONFLICT  $rel_file  (hub keeps; consumer=$name)"
              conflicts=$((conflicts + 1))
            fi
          fi
        done < <(find "$src" -type f -print0)
      elif [[ -f "$src" ]]; then
        local dest="$HUB_ROOT/$kp"
        if [[ ! -e "$dest" ]]; then
          log "KIT+  $name → hub  $kp"
          copy_file "$src" "$dest"
        elif ! cmp -s "$src" "$dest"; then
          if [[ "$PREFER_CONSUMER" -eq 1 ]]; then
            log "KIT~  overwrite $kp from $name"
            copy_file "$src" "$dest"
          else
            log "KIT-CONFLICT  $kp  (hub keeps; consumer=$name)"
            conflicts=$((conflicts + 1))
          fi
        fi
      fi
    done
  fi
}

mapfile -t ENTRIES < <(
  CONSUMERS_ROOT="$CONSUMERS_ROOT" "$LIST_SCRIPT" --format json --consumers-root "$CONSUMERS_ROOT" --org "$ORG" \
    | jq -r '.[] | select(.include==true) | [.name,.path,.class] | @tsv'
)

for entry in "${ENTRIES[@]}"; do
  name="${entry%%$'\t'*}"
  rest="${entry#*$'\t'}"
  path="${rest%%$'\t'*}"
  class="${rest#*$'\t'}"
  if [[ -z "$path" || ! -d "$path" ]]; then
    log "SKIP uncloned $name"
    continue
  fi
  harvest_consumer "$name" "$path" "$class"
done

log ""
log "harvest summary: copied=$copied identical_skipped≈$skipped conflicts=$conflicts dry_run=$DRY_RUN"
if [[ "$conflicts" -gt 0 ]]; then
  log "note: conflicts left hub content in place (re-run with --prefer-consumer to take consumer)"
  exit 0
fi
exit 0
