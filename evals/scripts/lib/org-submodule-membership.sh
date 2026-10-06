#!/usr/bin/env bash
# Org submodule membership: sync-list include=true rows + always hub evals.
# Maps .github → path sync-list resolves (dot-github or .github).
# Skips archived/uncloned/tmp-* and empty paths.
#
# Usage:
#   org-submodule-membership.sh [--format tsv|json] [--consumers-root DIR] [--org ORG]
#                               [--list-json FILE]
# Env:
#   CONSUMERS_ROOT, ORG, ORG_SUBMODULE_LIST_JSON (inline JSON array, test hook)
#
# TSV columns: name<TAB>rel_path<TAB>abs_path
# JSON: [{name,rel,path}, ...]
set -euo pipefail

ORG_SUBMODULE_MEMBERSHIP_LIB=1

_org_sm_die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Resolve hub scripts dir whether this file is sourced or executed.
_org_sm_scripts_dir() {
  local src="${BASH_SOURCE[0]:-$0}"
  cd "$(dirname "$src")/.." && pwd
}

org_submodule_membership() {
  local format=tsv
  local consumers_root="${CONSUMERS_ROOT:-$HOME/github.com/hutch-fail}"
  local org="${ORG:-hutch-fail}"
  local list_json_file=""
  local hub_name=evals

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format) format="${2:?}"; shift 2 ;;
      --consumers-root) consumers_root="${2:?}"; shift 2 ;;
      --org) org="${2:?}"; shift 2 ;;
      --list-json) list_json_file="${2:?}"; shift 2 ;;
      -h|--help)
        printf '%s\n' "Usage: org-submodule-membership.sh [--format tsv|json] [--consumers-root DIR] [--org ORG] [--list-json FILE]"
        return 0
        ;;
      *) _org_sm_die "unknown arg $1" ;;
    esac
  done

  command -v jq >/dev/null || _org_sm_die "jq required"

  local raw
  if [[ -n "${ORG_SUBMODULE_LIST_JSON:-}" ]]; then
    raw="$ORG_SUBMODULE_LIST_JSON"
  elif [[ -n "$list_json_file" ]]; then
    [[ -f "$list_json_file" ]] || _org_sm_die "list-json not found: $list_json_file"
    raw="$(cat "$list_json_file")"
  else
    local list_script
    list_script="$(_org_sm_scripts_dir)/sync-list-repos.sh"
    [[ -f "$list_script" ]] || _org_sm_die "missing $list_script"
    raw="$(CONSUMERS_ROOT="$consumers_root" bash "$list_script" \
      --format json --consumers-root "$consumers_root" --org "$org")"
  fi

  # include=true OR hub evals; require non-empty path; drop tmp-* basenames.
  local selected
  selected="$(jq -c --arg hub "$hub_name" --arg root "$consumers_root" '
    def rel:
      (.path // "") as $p
      | if ($p | startswith($root + "/")) then $p[$root|length+1:]
        elif ($p == $root) then "."
        else empty end;
    [.[]
      | select((.include == true) or (.name == $hub))
      | select((.path // "") | length > 0)
      | . + {rel: rel}
      | select(.rel != null and .rel != "" and .rel != ".")
      | select(.rel | test("^tmp-") | not)
      | {name, rel, path}
    ]
  ' <<<"$raw")"

  if [[ "$format" == json ]]; then
    printf '%s\n' "$selected"
  else
    printf 'name\trel\tpath\n'
    jq -r '.[] | [.name, .rel, .path] | @tsv' <<<"$selected"
  fi
}

# Execute when run as a script (not when sourced).
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
  org_submodule_membership "$@"
fi
