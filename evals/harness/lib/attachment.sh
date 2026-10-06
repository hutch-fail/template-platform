#!/usr/bin/env bash
# Consumer attachment persist policy (open-closed dispatcher).
# Modes: ephemeral | kit | full (default). See docs/scoping.md.
# Sourced by sync-pull, sync-harvest, and harness doctor-attach.

if ! declare -F die >/dev/null 2>&1; then
  die() { printf 'error: %s\n' "$*" >&2; exit 1; }
fi

eval_attachment_normalize() {
  local v="${1:-}"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  v="${v,,}"
  if [[ -z "${v}" ]]; then
    printf 'full\n'
    return 0
  fi
  case "${v}" in
    ephemeral | kit | full)
      printf '%s\n' "${v}"
      ;;
    *)
      printf 'error: unknown attachment: %s (want ephemeral|kit|full; see docs/scoping.md)\n' "${v}" >&2
      return 1
      ;;
  esac
}

eval_attachment_from_scope() {
  local manifest="${1:-}"
  if [[ -z "${manifest}" || ! -f "${manifest}" ]]; then
    printf 'full\n'
    return 0
  fi
  local raw="" mode
  raw="$(awk -F: '
    /^[[:space:]]*attachment:[[:space:]]*/ {
      val=$0
      sub(/^[[:space:]]*attachment:[[:space:]]*/, "", val)
      gsub(/["'\'' ]/, "", val)
      print val
      exit
    }
  ' "${manifest}")"
  if ! mode="$(eval_attachment_normalize "${raw}")"; then
    return 1
  fi
  printf '%s\n' "${mode}"
}

eval_attachment_tracked_evals_paths() {
  local consumer="${1:?}"
  git -C "${consumer}" ls-files -- 'evals' 'evals/**' 2>/dev/null || true
}

eval_attachment_gitignore_fragment() {
  local templates="${1:?}" mode="${2:?}"
  case "${mode}" in
    ephemeral)
      printf '%s\n' "${templates}/evals-gitignore-ephemeral"
      ;;
    kit)
      printf '%s\n' "${templates}/evals-gitignore-kit"
      ;;
    full)
      return 0
      ;;
    *)
      printf 'error: unknown attachment: %s\n' "${mode}" >&2
      return 1
      ;;
  esac
}

eval_attachment_install_gitignore() {
  local consumer="${1:?}" mode="${2:?}" templates="${3:?}"
  mode="$(eval_attachment_normalize "${mode}")"
  local frag gi
  frag="$(eval_attachment_gitignore_fragment "${templates}" "${mode}")"
  [[ -n "${frag}" ]] || return 0
  [[ -f "${frag}" ]] || die "missing gitignore template ${frag}"
  gi="${consumer}/.gitignore"
  if [[ -f "${gi}" ]] && grep -qF '# BEGIN evals-attachment' "${gi}"; then
    local tmp
    tmp="$(mktemp)"
    awk '
      /# BEGIN evals-attachment/ {skip=1; next}
      /# END evals-attachment/ {skip=0; next}
      skip==0 {print}
    ' "${gi}" >"${tmp}"
    mv "${tmp}" "${gi}"
  fi
  {
    printf '\n# BEGIN evals-attachment\n'
    cat "${frag}"
    printf '# END evals-attachment\n'
  } >>"${gi}"
}

eval_attachment_assert_persist_policy() {
  local consumer="${1:?}" mode="${2:?}" own_rel="${3:-}"
  mode="$(eval_attachment_normalize "${mode}")"
  [[ -d "${consumer}/.git" || -f "${consumer}/.git" ]] \
    || die "doctor-attach: ${consumer} is not a git checkout"
  local tracked
  tracked="$(eval_attachment_tracked_evals_paths "${consumer}")"
  case "${mode}" in
    ephemeral)
      if [[ -n "${tracked}" ]]; then
        printf 'error: attachment=ephemeral forbids tracked evals/ paths:\n%s\n' "${tracked}" >&2
        return 1
      fi
      ;;
    kit)
      if printf '%s\n' "${tracked}" | grep -qE '^evals/(goals|fixtures)/github\.com/'; then
        printf 'error: attachment=kit forbids tracked github.com packs:\n%s\n' \
          "$(printf '%s\n' "${tracked}" | grep -E '^evals/(goals|fixtures)/github\.com/' || true)" >&2
        return 1
      fi
      ;;
    full)
      if [[ -z "${own_rel}" ]]; then
        return 0
      fi
      local line rel
      while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        case "${line}" in
          evals/goals/github.com/* | evals/fixtures/github.com/*)
            rel="${line#evals/goals/}"
            rel="${rel#evals/fixtures/}"
            # rel is github.com/org/repo/...
            local leaf
            leaf="$(printf '%s\n' "${rel}" | awk -F/ '{print $1"/"$2"/"$3}')"
            if [[ "${leaf}" != "${own_rel}" ]]; then
              printf 'error: attachment=full forbids foreign tracked pack %s (own=%s)\n' \
                "${line}" "${own_rel}" >&2
              return 1
            fi
            ;;
        esac
      done <<<"${tracked}"
      ;;
  esac
  return 0
}

eval_attachment_refuse_foreign_leaves() {
  local consumer="${1:?}" own_rel="${2:?}"
  local evals="${consumer}/evals"
  local kind leaf org repo got
  for kind in goals fixtures; do
    local base="${evals}/${kind}/github.com"
    [[ -d "${base}" ]] || continue
    while IFS= read -r -d '' leaf; do
      org="$(basename "$(dirname "${leaf}")")"
      repo="$(basename "${leaf}")"
      got="github.com/${org}/${repo}"
      if [[ "${got}" != "${own_rel}" ]]; then
        printf 'error: foreign %s leaf %s (own=%s)\n' "${kind}" "${got}" "${own_rel}" >&2
        return 1
      fi
    done < <(find "${base}" -mindepth 2 -maxdepth 2 -type d -print0 2>/dev/null)
  done
  return 0
}

eval_attachment_harvest_own_leaf() {
  local consumer="${1:?}" hub_dest="${2:?}" own_rel="${3:?}"
  local evals="${consumer}/evals"
  local kind src dest
  for kind in goals fixtures; do
    src="${evals}/${kind}/${own_rel}"
    [[ -d "${src}" ]] || continue
    dest="${hub_dest}/${kind}/${own_rel}"
    mkdir -p "${dest}"
    cp -a "${src}/." "${dest}/"
  done
  return 0
}
