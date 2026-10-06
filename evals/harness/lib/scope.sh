# Scope frontmatter + path validation for evals/harness (sourced by goal.sh).
# Normative rules: docs/scoping.md / goals/_schema.md.

# Legacy flat smoke basenames (no .md) still map to universe if a flat copy appears.
_hermes_eval_legacy_universe_ids() {
  printf '%s\n' \
    'fixture-token-echo' \
    'fixture-token-echo-agent' \
    'hub-kit-smoke'
}

# True if path is under the recipe/product goals tree (${repo_evals}/goals).
_hermes_eval_under_recipe_goals() {
  local file="$1" recipe_goals file_abs
  recipe_goals="$(cd "${repo_evals}/goals" && pwd)"
  file_abs="$(cd "$(dirname "${file}")" && pwd)/$(basename "${file}")"
  case "${file_abs}" in
    "${recipe_goals}"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Print path under goals/ (including .md), or empty if not under a goals/ tree.
_hermes_eval_goals_relpath() {
  local file="$1" file_abs
  file_abs="$(cd "$(dirname "${file}")" && pwd)/$(basename "${file}")"
  if [[ "${file_abs}" == */goals/* ]]; then
    printf '%s\n' "${file_abs##*/goals/}"
    return 0
  fi
  printf '\n'
  return 1
}

# Split languages: value into newline-separated tokens (comma or space).
_hermes_eval_split_languages() {
  local raw="$1"
  printf '%s\n' "${raw}" | tr ', ' '\n\n' | sed '/^$/d'
}

# Infer scope from path into HERMES_EVAL_INFERRED_SCOPE / HERMES_EVAL_INFERRED_LANG.
# Dies when scope cannot be inferred. Must not run in a command substitution
# (side-effect globals would be lost).
_hermes_eval_infer_scope() {
  local file="$1" rel base lang
  HERMES_EVAL_INFERRED_LANG=""
  HERMES_EVAL_INFERRED_SCOPE=""
  rel="$(_hermes_eval_goals_relpath "${file}" || true)"
  [[ -n "${rel}" ]] || die "${file}: not under a goals/ tree; cannot infer scope"

  case "${rel}" in
    universe/*)
      HERMES_EVAL_INFERRED_SCOPE='universe'
      return 0
      ;;
    language/*/*)
      lang="${rel#language/}"
      lang="${lang%%/*}"
      [[ -n "${lang}" ]] || die "${file}: language path missing <lang> segment"
      HERMES_EVAL_INFERRED_LANG="${lang}"
      HERMES_EVAL_INFERRED_SCOPE='language'
      return 0
      ;;
    github.com/*/*)
      HERMES_EVAL_INFERRED_SCOPE='repo'
      return 0
      ;;
  esac

  base="${rel%.md}"
  if [[ "${base}" != */* ]]; then
    if _hermes_eval_legacy_universe_ids | grep -Fxq "${base}"; then
      HERMES_EVAL_INFERRED_SCOPE='universe'
      return 0
    fi
  fi

  if ! _hermes_eval_under_recipe_goals "${file}"; then
    HERMES_EVAL_INFERRED_SCOPE='active'
    return 0
  fi

  die "${file}: cannot infer scope from path '${rel}' (set scope: explicitly)"
}

# Path class for an explicit scope check. Prints: universe|language|repo|flat-universe|other
_hermes_eval_path_class() {
  local file="$1" rel base
  rel="$(_hermes_eval_goals_relpath "${file}" || true)"
  [[ -n "${rel}" ]] || {
    printf '%s\n' 'other'
    return 0
  }
  case "${rel}" in
    universe/*)
      printf '%s\n' 'universe'
      return 0
      ;;
    language/*/*)
      printf '%s\n' 'language'
      return 0
      ;;
    github.com/*/*)
      printf '%s\n' 'repo'
      return 0
      ;;
  esac
  base="${rel%.md}"
  if [[ "${base}" != */* ]] && _hermes_eval_legacy_universe_ids | grep -Fxq "${base}"; then
    printf '%s\n' 'flat-universe'
    return 0
  fi
  printf '%s\n' 'other'
}

_hermes_eval_path_lang() {
  local file="$1" rel lang
  rel="$(_hermes_eval_goals_relpath "${file}" || true)"
  case "${rel}" in
    language/*/*)
      lang="${rel#language/}"
      printf '%s\n' "${lang%%/*}"
      ;;
  esac
}

_hermes_eval_path_repo_id() {
  local file="$1" rel stem
  rel="$(_hermes_eval_goals_relpath "${file}" || true)"
  case "${rel}" in
    github.com/*/*)
      stem="${rel%.md}"
      # Canonical: github.com/<org>/<repo>/… → github.com/<org>/<repo>
      # Legacy flat: github.com/<org>/<name>.md → github.com/<org>/<name>
      awk -F/ '{
        if (NF >= 4) { print $1"/"$2"/"$3 }
        else { print $0 }
      }' <<<"${stem}"
      ;;
  esac
}

# Validate scope keys against path. Sets HERMES_EVAL_GOAL_SCOPE. Dies on error.
validate_goal_scope() {
  local file="$1"
  local scope languages repos path_class path_lang path_repo lang_ok entry

  scope="$(frontmatter_get "${file}" scope)"
  languages="$(frontmatter_get "${file}" languages)"
  repos="$(frontmatter_get "${file}" repos)"
  HERMES_EVAL_INFERRED_LANG=""

  if [[ -z "${scope}" ]]; then
    _hermes_eval_infer_scope "${file}"
    scope="${HERMES_EVAL_INFERRED_SCOPE}"
  else
    case "${scope}" in
      universe|language|repo|active) ;;
      *)
        die "${file}: unknown scope '${scope}' (want universe|language|repo|active)"
        ;;
    esac
  fi

  path_class="$(_hermes_eval_path_class "${file}")"

  case "${scope}" in
    universe)
      case "${path_class}" in
        universe|flat-universe) ;;
        *)
          die "${file}: scope: universe requires goals/universe/… or legacy flat smoke (path class '${path_class}')"
          ;;
      esac
      ;;
    language)
      [[ "${path_class}" == "language" ]] \
        || die "${file}: scope: language requires goals/language/<lang>/… (path class '${path_class}')"
      path_lang="$(_hermes_eval_path_lang "${file}")"
      if [[ -z "${languages}" ]]; then
        if [[ -n "${HERMES_EVAL_INFERRED_LANG}" ]]; then
          languages="${HERMES_EVAL_INFERRED_LANG}"
        else
          die "${file}: scope: language requires languages:"
        fi
      fi
      lang_ok=0
      while IFS= read -r entry; do
        [[ -z "${entry}" ]] && continue
        if [[ "${entry}" == "${path_lang}" ]]; then
          lang_ok=1
          break
        fi
      done < <(_hermes_eval_split_languages "${languages}")
      [[ "${lang_ok}" -eq 1 ]] \
        || die "${file}: languages must include path lang '${path_lang}' (got '${languages}')"
      ;;
    repo)
      [[ "${path_class}" == "repo" ]] \
        || die "${file}: scope: repo requires goals/github.com/<org>/<repo>/… (path class '${path_class}')"
      if [[ -n "${repos}" ]]; then
        path_repo="$(_hermes_eval_path_repo_id "${file}")"
        lang_ok=0
        while IFS= read -r entry; do
          [[ -z "${entry}" ]] && continue
          if [[ "${entry}" == "${path_repo}" ]]; then
            lang_ok=1
            break
          fi
        done < <(_hermes_eval_split_languages "${repos}")
        [[ "${lang_ok}" -eq 1 ]] \
          || die "${file}: repos must include path identity '${path_repo}' (got '${repos}')"
      fi
      ;;
    active)
      # WIP lifecycle marker inside evals git; list/select skip unless
      # EVALS_INCLUDE_ACTIVE=1 or the goal is named explicitly.
      ;;
  esac

  if [[ -n "${languages}" && "${scope}" != "language" ]]; then
    # Inferred language may have filled languages only for language scope.
    die "${file}: languages: is only valid when scope: language (resolved '${scope}')"
  fi

  HERMES_EVAL_GOAL_SCOPE="${scope}"
}
