#!/usr/bin/env bash
# PRs must not modify an existing .optmem/main/ (Action-only). Adding main on
# bootstrap (missing on merge-base) is allowed. Shard paths may only be added.
set -euo pipefail

root=""
base=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) root="${2:?}"; shift 2 ;;
    --base) base="${2:?}"; shift 2 ;;
    *) printf 'usage: assert_optmem_pr_diff.sh [--root DIR] [--base REV]\n' >&2; exit 2 ;;
  esac
done

if [[ -z "${root}" ]]; then
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    root="$(git rev-parse --show-toplevel)"
  else
    printf 'assert_optmem_pr_diff: not a git repo; skip\n'
    exit 0
  fi
fi

if ! git -C "${root}" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

if [[ -z "${base}" ]]; then
  if [[ -n "${OPTMEM_DIFF_BASE:-}" ]]; then
    base="${OPTMEM_DIFF_BASE}"
  elif [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    base="origin/${GITHUB_BASE_REF}"
  elif git -C "${root}" rev-parse --verify origin/main >/dev/null 2>&1; then
    base="$(git -C "${root}" merge-base origin/main HEAD)"
  else
    printf 'assert_optmem_pr_diff: no base; skip\n'
    exit 0
  fi
fi

if ! git -C "${root}" rev-parse --verify "${base}^{commit}" >/dev/null 2>&1; then
  printf 'assert_optmem_pr_diff: base %s missing; skip\n' "${base}"
  exit 0
fi

mapfile -t changed < <(git -C "${root}" diff --name-only "${base}"...HEAD -- '.optmem' '.optmem/**' 2>/dev/null || true)
if [[ ${#changed[@]} -eq 0 ]]; then
  exit 0
fi

fail=0
base_has_main=0
if git -C "${root}" cat-file -e "${base}:.optmem/main/memory/config" 2>/dev/null \
  || git -C "${root}" ls-tree -d --name-only "${base}" .optmem/main >/dev/null 2>&1; then
  if git -C "${root}" ls-tree -r --name-only "${base}" .optmem/main 2>/dev/null | grep -q .; then
    base_has_main=1
  fi
fi

for p in "${changed[@]}"; do
  case "${p}" in
    .optmem/main|/*/.optmem/main|.optmem/main/*)
      if [[ "${base_has_main}" -eq 1 ]]; then
        printf 'error: PRs must not modify .optmem/main/ (%s); reconcile Action owns it\n' "${p}" >&2
        fail=1
      fi
      ;;
    .optmem/shards/*)
      status="$(git -C "${root}" diff --name-status "${base}"...HEAD -- "${p}" | awk '{print $1}')"
      if [[ "${status}" == "D" || "${status}" == M* ]]; then
        printf 'error: PRs may only add shard files, not modify/delete %s\n' "${p}" >&2
        fail=1
      fi
      ;;
  esac
done

exit "${fail}"
