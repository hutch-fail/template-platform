#!/usr/bin/env bash
# List hutch-fail org repos with evals class + local path.
# Usage: sync-list-repos.sh [--format json|tsv] [--consumers-root DIR] [--org ORG]
set -euo pipefail

FORMAT=tsv
ORG=hutch-fail
CONSUMERS_ROOT="${CONSUMERS_ROOT:-$HOME/github.com/hutch-fail}"
HUB_NAME=evals
SKIP_ALWAYS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) FORMAT="${2:?}"; shift 2 ;;
    --consumers-root) CONSUMERS_ROOT="${2:?}"; shift 2 ;;
    --org) ORG="${2:?}"; shift 2 ;;
    -h|--help)
      printf '%s\n' "Usage: $0 [--format json|tsv] [--consumers-root DIR] [--org ORG]"
      exit 0
      ;;
    *) printf 'error: unknown arg %s\n' "$1" >&2; exit 2 ;;
  esac
done

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
command -v gh >/dev/null || die "gh CLI required"
command -v jq >/dev/null || die "jq required"

resolve_local() {
  local name="$1"
  # Submodules use a .git *file*; plain clones use a .git directory.
  if [[ "$name" == ".github" ]]; then
    if [[ -e "$CONSUMERS_ROOT/dot-github/.git" ]]; then
      printf '%s\n' "$CONSUMERS_ROOT/dot-github"
      return
    fi
    if [[ -e "$CONSUMERS_ROOT/.github/.git" ]]; then
      printf '%s\n' "$CONSUMERS_ROOT/.github"
      return
    fi
    printf '\n'
    return
  fi
  if [[ -e "$CONSUMERS_ROOT/$name/.git" ]]; then
    printf '%s\n' "$CONSUMERS_ROOT/$name"
  else
    printf '\n'
  fi
}

classify_path() {
  local dir="$1"
  if [[ -z "$dir" || ! -d "$dir" ]]; then
    printf 'uncloned\n'
    return
  fi
  if [[ ! -d "$dir/evals" ]]; then
    printf 'missing\n'
    return
  fi
  if [[ -f "$dir/evals/Makefile" ]]; then
    printf 'kit\n'
    return
  fi
  if [[ -f "$dir/evals/scope.yaml" ]] \
    || [[ -d "$dir/evals/goals" ]] \
    || [[ -d "$dir/evals/fixtures" ]]; then
    printf 'pack-only\n'
    return
  fi
  printf 'missing\n'
}

is_skipped_name() {
  local name="$1"
  local s
  for s in "${SKIP_ALWAYS[@]}"; do
    [[ "$name" == "$s" ]] && return 0
  done
  return 1
}

mapfile -t REPOS < <(gh repo list "$ORG" --limit 200 --json name,isArchived \
  | jq -r '.[] | [.name, (if .isArchived then "true" else "false" end)] | @tsv')

rows=()
for line in "${REPOS[@]}"; do
  name="${line%%$'\t'*}"
  archived="${line#*$'\t'}"
  local_path="$(resolve_local "$name")"
  class=""
  skip_reason=""
  include="true"

  if [[ "$archived" == "true" ]]; then
    class=skipped
    skip_reason=archived
    include=false
  elif [[ "$name" == "$HUB_NAME" ]]; then
    class=hub
    skip_reason=hub
    include=false
  elif is_skipped_name "$name"; then
    class=skipped
    skip_reason=meter
    include=false
  else
    class="$(classify_path "$local_path")"
    skip_reason=
  fi

  rows+=("$(jq -nc \
    --arg name "$name" \
    --arg class "$class" \
    --arg path "$local_path" \
    --arg skip "$skip_reason" \
    --argjson archived "$([[ "$archived" == true ]] && echo true || echo false)" \
    --argjson include "$([[ "$include" == true ]] && echo true || echo false)" \
    '{name:$name,class:$class,path:$path,skip_reason:$skip,archived:$archived,include:$include}')")
done

if [[ "$FORMAT" == json ]]; then
  printf '%s\n' "${rows[@]}" | jq -s '.'
else
  # Use "-" for empty skip_reason so bash IFS tab-splitting does not shift fields.
  printf 'name\tclass\tinclude\tskip_reason\tpath\n'
  printf '%s\n' "${rows[@]}" | jq -r '
    [.name, .class, (.include|tostring), (if (.skip_reason|length)>0 then .skip_reason else "-" end), .path] | @tsv'
fi
