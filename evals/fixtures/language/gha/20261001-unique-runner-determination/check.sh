#!/usr/bin/env bash
# F2P: Blacksmith determine-runner must not share a bare concurrency group
# named exactly "runner-determination" (siblings cancel across workflows).
# Prefer runner-determination-${{ github.workflow }}-${{ github.job }}.
# Pass when no workflows or no bare group (thin callers / already unique).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_scan_root() {
  if [[ -n "${HERMES_EVAL_SCAN_ROOT:-}" && -d "${HERMES_EVAL_SCAN_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_SCAN_ROOT}" && pwd)"
    return 0
  fi
  if [[ -d "${here}/.github/workflows" ]]; then
    printf '%s\n' "${here}"
    return 0
  fi
  if [[ -n "${HERMES_EVAL_REPO_ROOT:-}" && -d "${HERMES_EVAL_REPO_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_REPO_ROOT}" && pwd)"
    return 0
  fi
  printf 'error: no scan root (set HERMES_EVAL_SCAN_ROOT)\n' >&2
  return 1
}

list_workflows() {
  local root="$1" wf
  wf="${root}/.github/workflows"
  [[ -d "${wf}" ]] || return 0
  find "${wf}" \( -name '*.yml' -o -name '*.yaml' \) -type f 2>/dev/null | sort
}

root="$(resolve_scan_root)"
fail=0
while IFS= read -r f; do
  [[ -n "${f}" ]] || continue
  if grep -nE '[[:space:]]group:[[:space:]]*runner-determination[[:space:]]*$' "${f}" >/dev/null 2>&1; then
    printf 'error: bare concurrency group runner-determination in %s\n' "${f#"${root}"/}" >&2
    printf '  use: group: runner-determination-${{ github.workflow }}-${{ github.job }}\n' >&2
    fail=1
  fi
done < <(list_workflows "${root}")

[[ "${fail}" -eq 0 ]] || exit 1
echo unique_runner_determination_ok
