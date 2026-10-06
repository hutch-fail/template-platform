#!/usr/bin/env bash
# Every eval fixture (a directory with check.sh) needs a goal markdown whose
# fixture_dir points at it. *-result.md is not a goal.
#
# Hub-native: fixtures/ + goals/ at repo root.
# Host subtree: scripts live under evals/tests/unit; pack is evals/{fixtures,goals}.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

resolve_pack_roots() {
  if [[ -n "${EVALS_PACK_ROOT:-}" ]]; then
    ROOT="$(cd "${EVALS_PACK_ROOT}" && pwd)"
    FIXTURES_DIR="${ROOT}/evals/fixtures"
    GOALS_DIR="${ROOT}/evals/goals"
    PATH_PREFIX="evals/"
    return 0
  fi
  if [[ -d "${HUB_ROOT}/.git" ]]; then
    ROOT="${HUB_ROOT}"
    FIXTURES_DIR="${ROOT}/fixtures"
    GOALS_DIR="${ROOT}/goals"
    PATH_PREFIX=""
    return 0
  fi
  ROOT="$(cd "${HUB_ROOT}/.." && pwd)"
  FIXTURES_DIR="${HUB_ROOT}/fixtures"
  GOALS_DIR="${HUB_ROOT}/goals"
  PATH_PREFIX="evals/"
}

# evals/fixtures/X → fixtures/X
normalize_fixture_rel() {
  local r="$1"
  r="${r#./}"
  if [[ "${r}" == evals/* ]]; then
    r="${r#evals/}"
  fi
  if [[ "${r}" != fixtures/* ]]; then
    r="fixtures/${r}"
  fi
  printf '%s\n' "${r}"
}

fixture_dir_of() {
  local file="$1"
  awk '
    BEGIN { in_fm=0 }
    /^---[[:space:]]*$/ {
      if (in_fm == 0) { in_fm=1; next }
      else exit
    }
    in_fm == 1 && $0 ~ /^fixture_dir:[[:space:]]*/ {
      sub(/^fixture_dir:[[:space:]]*/, "")
      gsub(/^["'\'']|["'\'']$/, "")
      gsub(/[[:space:]]+$/, "")
      print
      exit
    }
  ' "${file}"
}

missing_eval_goals() {
  local fixtures="$1" goals="$2"
  [[ -d "${fixtures}" ]] || return 0

  local -a linked=()
  local goal rel want check found dir
  if [[ -d "${goals}" ]]; then
    while IFS= read -r -d '' goal; do
      case "${goal}" in
        */_schema.md|*/README.md|*-result.md) continue ;;
      esac
      rel="$(fixture_dir_of "${goal}")"
      [[ -n "${rel}" ]] || continue
      linked+=("$(normalize_fixture_rel "${rel}")")
    done < <(find "${goals}" -type f -name '*.md' -print0)
  fi

  while IFS= read -r -d '' check; do
    dir="$(dirname "${check}")"
    rel="fixtures/${dir#"${fixtures}"/}"
    found=0
    for want in "${linked[@]+"${linked[@]}"}"; do
      if [[ "${want}" == "${rel}" ]]; then
        found=1
        break
      fi
    done
    if [[ "${found}" -eq 0 ]]; then
      printf '%s\n' "${rel}"
    fi
  done < <(find "${fixtures}" -type f -name 'check.sh' -print0 | sort -z)
}

report_missing() {
  local fixtures="$1" goals="$2" prefix="$3"
  local missing rel
  missing="$(missing_eval_goals "${fixtures}" "${goals}")"
  [[ -n "${missing}" ]] || return 0
  while IFS= read -r rel; do
    [[ -n "${rel}" ]] || continue
    printf '✗ eval fixture has no goal: %s%s\n' "${prefix}" "${rel}" >&2
    printf '  next: add %sgoals/%s.md with fixture_dir: evals/%s\n' \
      "${prefix}" "${rel#fixtures/}" "${rel}" >&2
  done <<<"${missing}"
  return 1
}

self_check() {
  local tmp orphan
  tmp="$(mktemp -d)"
  trap 'rm -rf "'"${tmp}"'"' RETURN
  orphan="${tmp}/fixtures/example/orphan"
  mkdir -p "${orphan}" "${tmp}/goals"
  printf '#!/bin/sh\nexit 1\n' >"${orphan}/check.sh"
  printf '%s\n' '---' 'schema: goal/v1' 'fixture_dir: evals/fixtures/example/kept' '---' \
    >"${tmp}/goals/kept.md"
  mkdir -p "${tmp}/fixtures/example/kept"
  printf '#!/bin/sh\nexit 1\n' >"${tmp}/fixtures/example/kept/check.sh"
  if report_missing "${tmp}/fixtures" "${tmp}/goals" "" >/dev/null 2>&1; then
    printf '✗ assert_eval_has_goal self-check did not flag an orphan fixture\n' >&2
    exit 1
  fi
}

resolve_pack_roots
self_check

if ! report_missing "${FIXTURES_DIR}" "${GOALS_DIR}" "${PATH_PREFIX}"; then
  exit 1
fi

printf '✓ eval fixtures have a goal markdown\n'
