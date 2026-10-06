#!/usr/bin/env bash
# F2P: product (or hub) root must ship org pre-commit shape.
# Fail-closed when .pre-commit-config.yaml is missing, lacks id: platform from
# hutch-fail/pre-commit, or lacks a local entry that runs pre-commit-evals.sh.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_scan_root() {
  if [[ -n "${HERMES_EVAL_SCAN_ROOT:-}" && -d "${HERMES_EVAL_SCAN_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_SCAN_ROOT}" && pwd)"
    return 0
  fi
  # Fixture / local run: config lives beside check.sh when SCAN_ROOT unset.
  printf '%s\n' "${here}"
}

root="$(resolve_scan_root)"
cfg="${root}/.pre-commit-config.yaml"

if [[ ! -f "${cfg}" ]]; then
  printf 'error: missing %s — backfill org pre-commit (hutch-fail/pre-commit id: platform + local evals-pre-commit)\n' \
    "${cfg}" >&2
  exit 1
fi

fail=0

if ! grep -Eq 'hutch-fail/pre-commit|github\.com/hutch-fail/pre-commit' "${cfg}"; then
  printf 'error: %s must pin hutch-fail/pre-commit\n' "${cfg}" >&2
  fail=1
fi

if ! grep -Eq '^[[:space:]]*-[[:space:]]*id:[[:space:]]*platform[[:space:]]*$' "${cfg}"; then
  printf 'error: %s must enable hooks id: platform\n' "${cfg}" >&2
  fail=1
fi

if ! grep -Fq 'pre-commit-evals.sh' "${cfg}"; then
  printf 'error: %s must include a local hook entry running pre-commit-evals.sh\n' "${cfg}" >&2
  fail=1
fi

exit "${fail}"
