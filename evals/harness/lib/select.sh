# Scope discovery + selection for evals/harness (sourced by goal.sh).
# Normative rules: docs/scoping.md (Harness discovery).
# Consumer manifest: harness/lib/manifest.sh (load_scope_manifest).

# Print absolute goal paths under a goals/ directory (one per line).
_hermes_eval_scan_goals_dir() {
  local goals_dir="$1" f base
  [[ -d "${goals_dir}" ]] || return 0
  while IFS= read -r -d '' f; do
    base="$(basename "${f}")"
    case "${base}" in
      *-result.md|_schema.md|README.md) continue ;;
    esac
    [[ "${base}" == *.md ]] || continue
    printf '%s\n' "$(cd "$(dirname "${f}")" && pwd)/$(basename "${f}")"
  done < <(find "${goals_dir}" -type f -name '*.md' -print0 2>/dev/null | sort -z)
}

# Discover goal files from recipe + process SoT.
# Dedupes by goal id (prefer recipe over process SoT), then by realpath.
discover_goal_files() {
  local recipe process_dir f real id seen_paths seen_ids
  recipe="$(_hermes_eval_recipe_root)"
  process_dir="$(cd "${evals_dir}" && pwd)"
  seen_paths=""
  seen_ids=""

  _hermes_eval_emit_if_new() {
    local f="$1" real id
    real="$(cd "$(dirname "${f}")" && pwd)/$(basename "${f}")"
    case $'\n'"${seen_paths}"$'\n' in
      *$'\n'"${real}"$'\n'*) return 0 ;;
    esac
    id="$(frontmatter_get "${real}" id 2>/dev/null || true)"
    if [[ -n "${id}" ]]; then
      case $'\n'"${seen_ids}"$'\n' in
        *$'\n'"${id}"$'\n'*) return 0 ;;
      esac
      seen_ids="${seen_ids}${id}"$'\n'
    fi
    seen_paths="${seen_paths}${real}"$'\n'
    printf '%s\n' "${real}"
  }

  while IFS= read -r f; do
    [[ -n "${f}" ]] || continue
    _hermes_eval_emit_if_new "${f}"
  done < <(_hermes_eval_scan_goals_dir "${recipe}/goals" | sort)

  if [[ "${process_dir}" != "${recipe}" ]]; then
    while IFS= read -r f; do
      [[ -n "${f}" ]] || continue
      _hermes_eval_emit_if_new "${f}"
    done < <(_hermes_eval_scan_goals_dir "${process_dir}/goals" | sort)
  fi
}

_hermes_eval_goal_languages() {
  local file="$1" scope="$2" languages
  languages="$(frontmatter_get "${file}" languages)"
  if [[ "${scope}" == "language" && -z "${languages}" ]]; then
    languages="$(_hermes_eval_path_lang "${file}")"
  fi
  printf '%s\n' "${languages}"
}

_hermes_eval_languages_intersect() {
  local goal_langs="$1" entry man
  while IFS= read -r entry; do
    [[ -z "${entry}" ]] && continue
    while IFS= read -r man; do
      [[ -z "${man}" ]] && continue
      if [[ "${entry}" == "${man}" ]]; then
        return 0
      fi
    done <<<"${HERMES_EVAL_MANIFEST_LANGUAGES}"
  done < <(_hermes_eval_split_languages "${goal_langs}")
  return 1
}

# Look up opt_out reason for id or path. Prints reason and returns 0 if opted out.
_hermes_eval_opt_out_reason() {
  local id="$1" file="$2" rel key reason i=0
  local -a keys=() reasons=()
  rel="$(_hermes_eval_goals_relpath "${file}" || true)"
  while IFS= read -r key; do
    [[ -z "${key}" ]] && continue
    keys+=("${key}")
  done <<<"${HERMES_EVAL_OPT_OUT_KEYS}"
  while IFS= read -r reason; do
    [[ -z "${reason}" && ${#reasons[@]} -ge ${#keys[@]} ]] && continue
    reasons+=("${reason}")
  done <<<"${HERMES_EVAL_OPT_OUT_REASONS}"

  for i in "${!keys[@]}"; do
    key="${keys[$i]}"
    reason="${reasons[$i]:-}"
    if [[ "${key}" == "${id}" ]]; then
      printf '%s\n' "${reason}"
      return 0
    fi
    if [[ -n "${rel}" && ( "${key}" == "${rel}" || "${key}" == "goals/${rel}" ) ]]; then
      printf '%s\n' "${reason}"
      return 0
    fi
    if [[ "${key}" == "${file}" || "${file}" == */"${key}" ]]; then
      printf '%s\n' "${reason}"
      return 0
    fi
  done
  return 1
}

_hermes_eval_matches_goal_arg() {
  local file="$1" arg="$2" id base
  [[ -z "${arg}" ]] && return 0
  id="$(frontmatter_get "${file}" id)"
  base="$(basename "${file}" .md)"
  [[ "${id}" == "${arg}" ]] && return 0
  [[ "${base}" == "${arg}" ]] && return 0
  [[ "${file}" == "${arg}" ]] && return 0
  [[ "${file}" == */"${arg}" ]] && return 0
  [[ "${file}" == */"${arg}.md" ]] && return 0
  [[ "${arg}" == */* && "${file}" == */"${arg}.md" ]] && return 0
  return 1
}

# Decide if a validated goal is applicable.
# Sets HERMES_EVAL_SKIP_KIND (opt_out|scope|active|"") and HERMES_EVAL_SKIP_REASON.
goal_applicable() {
  local file="$1" scope="$2" goal_arg="${3:-}"
  local id languages path_repo reason
  HERMES_EVAL_SKIP_KIND=""
  HERMES_EVAL_SKIP_REASON=""

  id="$(frontmatter_get "${file}" id)"
  if ! _hermes_eval_matches_goal_arg "${file}" "${goal_arg}"; then
    HERMES_EVAL_SKIP_KIND="filter"
    return 1
  fi

  if reason="$(_hermes_eval_opt_out_reason "${id}" "${file}")"; then
    HERMES_EVAL_SKIP_KIND="opt_out"
    HERMES_EVAL_SKIP_REASON="${reason}"
    return 1
  fi

  case "${scope}" in
    universe)
      return 0
      ;;
    language)
      languages="$(_hermes_eval_goal_languages "${file}" "${scope}")"
      if [[ -z "${HERMES_EVAL_MANIFEST_LANGUAGES//[$'\n']/}" ]]; then
        HERMES_EVAL_SKIP_KIND="scope"
        return 1
      fi
      if _hermes_eval_languages_intersect "${languages}"; then
        return 0
      fi
      HERMES_EVAL_SKIP_KIND="scope"
      return 1
      ;;
    repo)
      path_repo="$(_hermes_eval_path_repo_id "${file}")"
      if [[ -z "${HERMES_EVAL_MANIFEST_REPO}" ]]; then
        HERMES_EVAL_SKIP_KIND="scope"
        return 1
      fi
      if [[ "${path_repo}" == "${HERMES_EVAL_MANIFEST_REPO}" ]]; then
        return 0
      fi
      # Optional repos: frontmatter may list extra identities
      languages="$(frontmatter_get "${file}" repos)"
      if [[ -n "${languages}" ]]; then
        while IFS= read -r reason; do
          [[ -z "${reason}" ]] && continue
          if [[ "${reason}" == "${HERMES_EVAL_MANIFEST_REPO}" ]]; then
            return 0
          fi
        done < <(_hermes_eval_split_languages "${languages}")
      fi
      HERMES_EVAL_SKIP_KIND="scope"
      return 1
      ;;
    active)
      if [[ "${EVALS_INCLUDE_ACTIVE:-}" == "1" ]]; then
        return 0
      fi
      if [[ -n "${goal_arg}" ]] && _hermes_eval_matches_goal_arg "${file}" "${goal_arg}"; then
        return 0
      fi
      HERMES_EVAL_SKIP_KIND="active"
      return 1
      ;;
    *)
      HERMES_EVAL_SKIP_KIND="scope"
      return 1
      ;;
  esac
}

# Validate + filter. Prints selected rows on stdout.
# Opt-outs and malformed goals go to stderr. Returns non-zero if any malformed.
_hermes_eval_run_select_mode() {
  local mode="$1" goal_arg="${2:-}"
  local file scope id rel err_file malformed=0 matched=0
  local -a selected_paths=() selected_ids=() selected_scopes=() selected_rels=()

  load_scope_manifest
  err_file="$(mktemp)"

  while IFS= read -r file; do
    [[ -n "${file}" ]] || continue
    set +e
    scope="$(
      require_goal_v1 "${file}" 2>"${err_file}"
      printf '%s\n' "${HERMES_EVAL_GOAL_SCOPE}"
    )"
    local vrc=$?
    set -e
    if [[ "${vrc}" -ne 0 ]]; then
      printf 'error: malformed goal %s: %s\n' "${file}" "$(tr '\n' ' ' <"${err_file}")" >&2
      malformed=1
      continue
    fi
    if ! goal_applicable "${file}" "${scope}" "${goal_arg}"; then
      if [[ "${HERMES_EVAL_SKIP_KIND}" == "opt_out" ]]; then
        id="$(frontmatter_get "${file}" id)"
        printf 'opt_out id=%s reason=%s\n' "${id}" "${HERMES_EVAL_SKIP_REASON}" >&2
      fi
      continue
    fi
    matched=1
    id="$(frontmatter_get "${file}" id)"
    rel="$(_hermes_eval_goals_relpath "${file}" || true)"
    selected_paths+=("${file}")
    selected_ids+=("${id}")
    selected_scopes+=("${scope}")
    selected_rels+=("${rel:-${file}}")
  done < <(discover_goal_files)

  rm -f "${err_file}"

  if [[ -n "${goal_arg}" && "${matched}" -eq 0 ]]; then
    local found=0
    while IFS= read -r file; do
      if _hermes_eval_matches_goal_arg "${file}" "${goal_arg}"; then
        found=1
        break
      fi
    done < <(discover_goal_files)
    if [[ "${found}" -eq 0 ]]; then
      die "goal not found for select/list: ${goal_arg}"
    fi
  fi

  local i
  if [[ "${mode}" == "list" ]]; then
    for i in "${!selected_paths[@]}"; do
      printf '%s\t%s\t%s\n' "${selected_ids[$i]}" "${selected_scopes[$i]}" "${selected_rels[$i]}"
    done | sort -k1,1
  else
    for i in "${!selected_paths[@]}"; do
      printf '%s\n' "${selected_paths[$i]}"
    done | sort
  fi

  [[ "${malformed}" -eq 0 ]]
}

cmd_list() {
  _hermes_eval_run_select_mode list "${1:-}"
}

cmd_select() {
  _hermes_eval_run_select_mode select "${1:-}"
}
