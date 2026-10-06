#!/usr/bin/env bash
# CI helper for eval-ci.yml: run make eval/bars against the caller workspace.
# Usage: ci-eval-bars.sh <kit_dir> [scan_root]
#   kit_dir: hub Makefile root (GITHUB_WORKSPACE when evals_path is ".", else .evals-hub)
#   scan_root: product root to scan (default: GITHUB_WORKSPACE or cwd)
#
# When GITHUB_BASE_REF / BASE_REF is set (pull_request), pass changed paths into
# eval-bars so language families (including gha) match pre-commit path detect.
#
# Thin Actions step — all bar logic lives in scripts/eval-bars.sh (shellcheckable).
set -euo pipefail

kit="${1:-.}"
scan_root="${2:-${GITHUB_WORKSPACE:-${PWD}}}"

[[ -d "${kit}" ]] || {
  printf 'error: kit_dir not a directory: %s\n' "${kit}" >&2
  exit 1
}
[[ -d "${scan_root}" ]] || {
  printf 'error: scan_root not a directory: %s\n' "${scan_root}" >&2
  exit 1
}

scan_root="$(cd "${scan_root}" && pwd)"
kit="$(cd "${kit}" && pwd)"

export HERMES_EVAL_KIT="${kit}"
export HERMES_EVAL_SCAN_ROOT="${scan_root}"
export HERMES_EVAL_REPO_ROOT="${scan_root}"

# Collect PR changed paths for path-detect (gha / ui / opentofu / …).
paths=()
base_ref="${BASE_REF:-${GITHUB_BASE_REF:-}}"
if [[ -n "${base_ref}" ]] && git -C "${scan_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "${scan_root}" fetch --no-tags --depth=1 origin "${base_ref}:refs/remotes/origin/${base_ref}" 2>/dev/null || true
  range=""
  if git -C "${scan_root}" rev-parse --verify "origin/${base_ref}" >/dev/null 2>&1; then
    range="origin/${base_ref}...HEAD"
  elif git -C "${scan_root}" rev-parse --verify "${base_ref}" >/dev/null 2>&1; then
    range="${base_ref}...HEAD"
  fi
  if [[ -n "${range}" ]]; then
    while IFS= read -r p; do
      [[ -n "${p}" ]] || continue
      paths+=("${p}")
    done < <(git -C "${scan_root}" diff --name-only "${range}" 2>/dev/null || true)
  fi
fi

if [[ -f "${kit}/Makefile" ]] && grep -Eq '^[[:space:]]*eval/bars:' "${kit}/Makefile"; then
  if [[ "${#paths[@]}" -gt 0 ]]; then
    # Make does not forward arbitrary path args; call the script directly.
    bash "${kit}/scripts/eval-bars.sh" "${paths[@]}"
    exit $?
  fi
  make --no-print-directory -C "${kit}" eval/bars
  exit $?
fi

# Fallback when Makefile target missing (older pin) — still prefer Make.
if [[ "${#paths[@]}" -gt 0 ]]; then
  bash "${kit}/scripts/eval-bars.sh" "${paths[@]}"
else
  bash "${kit}/scripts/eval-bars.sh"
fi
