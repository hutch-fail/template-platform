#!/usr/bin/env bash
# Local git commit only. A result markdown must not share this commit with
# its goal or its fixture. Hub-native paths: goals/*-result.md.
# Host subtree: evals/goals/*-result.md (auto-detected).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

resolve_pack_roots() {
  if [[ -n "${EVALS_PACK_ROOT:-}" ]]; then
    ROOT="$(cd "${EVALS_PACK_ROOT}" && pwd)"
    GOALS_GLOB="evals/goals"
    return 0
  fi
  if [[ -d "${HUB_ROOT}/.git" ]]; then
    ROOT="${HUB_ROOT}"
    GOALS_GLOB="goals"
    return 0
  fi
  ROOT="$(cd "${HUB_ROOT}/.." && pwd)"
  GOALS_GLOB="evals/goals"
}

fixture_dir_of_text() {
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
  '
}

fixture_dir_for() {
  local root="$1" goal="$2" text
  text=""
  if git -C "${root}" cat-file -e ":${goal}" 2>/dev/null; then
    text="$(git -C "${root}" show ":${goal}")"
  elif [[ -f "${root}/${goal}" ]]; then
    text="$(cat "${root}/${goal}")"
  elif git -C "${root}" cat-file -e "HEAD:${goal}" 2>/dev/null; then
    text="$(git -C "${root}" show "HEAD:${goal}")"
  fi
  printf '%s\n' "${text}" | fixture_dir_of_text
}

# Map fixture_dir frontmatter to a path relative to ROOT (git paths).
fixture_git_path() {
  local rel="$1"
  if [[ "${GOALS_GLOB}" == "goals" ]]; then
    # Hub-native: strip evals/ so evals/fixtures/X → fixtures/X
    if [[ "${rel}" == evals/* ]]; then
      printf '%s\n' "${rel#evals/}"
    else
      printf '%s\n' "${rel}"
    fi
  else
    # Host: keep or add evals/ prefix
    if [[ "${rel}" == evals/* ]]; then
      printf '%s\n' "${rel}"
    else
      printf 'evals/%s\n' "${rel}"
    fi
  fi
}

check_result_commit() {
  local root="$1"
  local staged result goal fixture hit fail staged_path
  local -a paths=()
  fail=0
  staged="$(mktemp)"
  git -C "${root}" diff --cached --name-only --diff-filter=ACMR >"${staged}"
  paths=()
  while IFS= read -r staged_path || [[ -n "${staged_path}" ]]; do
    [[ -n "${staged_path}" ]] || continue
    paths+=("${staged_path}")
  done <"${staged}"
  rm -f "${staged}"

  for result in "${paths[@]+"${paths[@]}"}"; do
    case "${result}" in
      ${GOALS_GLOB}/*-result.md) ;;
      *) continue ;;
    esac
    goal="${result%-result.md}.md"
    hit=""
    for staged_path in "${paths[@]+"${paths[@]}"}"; do
      if [[ "${staged_path}" == "${goal}" ]]; then
        hit="${staged_path}"
        break
      fi
    done
    if [[ -n "${hit}" ]]; then
      printf '✗ result and its goal are in the same commit\n' >&2
      printf '  result: %s\n' "${result}" >&2
      printf '  goal:   %s\n' "${goal}" >&2
      printf '  next: commit the goal and fixture first, then the result alone\n' >&2
      fail=1
    fi
    fixture="$(fixture_dir_for "${root}" "${goal}")"
    if [[ -z "${fixture}" ]]; then
      continue
    fi
    fixture="$(fixture_git_path "${fixture}")"
    hit=""
    for staged_path in "${paths[@]+"${paths[@]}"}"; do
      case "${staged_path}" in
        "${fixture}"|"${fixture}"/*) hit="${staged_path}" ;;
      esac
    done
    if [[ -n "${hit}" ]]; then
      printf '✗ result and its eval fixture are in the same commit\n' >&2
      printf '  result:  %s\n' "${result}" >&2
      printf '  fixture: %s\n' "${fixture}" >&2
      printf '  next: commit the goal and fixture first, then the result alone\n' >&2
      fail=1
    fi
  done

  [[ "${fail}" -eq 0 ]]
}

self_check() {
  (
  unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE
  tmp="$(mktemp -d)"
  git -C "${tmp}" init -q
  mkdir -p "${tmp}/goals/example" "${tmp}/fixtures/example"
  printf '%s\n' '---' 'schema: goal/v1' 'fixture_dir: evals/fixtures/example' '---' \
    >"${tmp}/goals/example/probe.md"
  printf '%s\n' '# Result' >"${tmp}/goals/example/probe-result.md"
  printf '#!/bin/sh\nexit 1\n' >"${tmp}/fixtures/example/check.sh"
  # Temporarily force hub-native globs for self-check
  GOALS_GLOB="goals"
  git -C "${tmp}" add \
    goals/example/probe.md \
    goals/example/probe-result.md \
    fixtures/example/check.sh
  if check_result_commit "${tmp}" >/dev/null 2>&1; then
    printf '✗ result-commit self-check did not flag a mixed commit\n' >&2
    rm -rf "${tmp}"
    exit 1
  fi
  git -C "${tmp}" rm -q --cached -r goals fixtures >/dev/null
  git -C "${tmp}" add goals/example/probe-result.md
  if ! check_result_commit "${tmp}" >/dev/null 2>&1; then
    printf '✗ result-commit self-check flagged a result-only commit\n' >&2
    rm -rf "${tmp}"
    exit 1
  fi
  rm -rf "${tmp}"
  )
}

resolve_pack_roots
self_check

if ! git -C "${ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf '✗ not a git work tree: %s\n' "${ROOT}" >&2
  exit 1
fi

if ! check_result_commit "${ROOT}"; then
  exit 1
fi

printf '✓ result markdown is not committed with its goal or fixture\n'
