#!/usr/bin/env bash
# F2P / product bar: when typescript family selected, run typecheck / test npm
# scripts when present; skip if absent. Require node_modules when any run.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_scan_root() {
  if [[ -n "${HERMES_EVAL_SCAN_ROOT:-}" && -d "${HERMES_EVAL_SCAN_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_SCAN_ROOT}" && pwd)"
    return 0
  fi
  if [[ -f "${here}/package.json" ]]; then
    printf '%s\n' "${here}"
    return 0
  fi
  if [[ -n "${HERMES_EVAL_REPO_ROOT:-}" && -d "${HERMES_EVAL_REPO_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_REPO_ROOT}" && pwd)"
    return 0
  fi
  printf 'error: no scan root (set HERMES_EVAL_SCAN_ROOT or place package.json under the fixture)\n' >&2
  return 1
}

pkg_has_script() {
  local root="$1" name="$2"
  [[ -f "${root}/package.json" ]] || return 1
  python3 - "${root}/package.json" "${name}" <<'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception:
    sys.exit(1)
scripts = data.get("scripts") or {}
sys.exit(0 if name in scripts else 1)
PY
}

root="$(resolve_scan_root)"
pkg="${root}/package.json"

if [[ ! -f "${pkg}" ]]; then
  printf 'typescript_execute_skip reason=no_package_json root=%s\n' "${root}"
  exit 0
fi

wanted=(typecheck test)
to_run=()
for s in "${wanted[@]}"; do
  if pkg_has_script "${root}" "${s}"; then
    to_run+=("${s}")
  fi
done

if [[ "${#to_run[@]}" -eq 0 ]]; then
  printf 'typescript_execute_skip reason=no_typecheck_or_test_scripts root=%s\n' "${root}"
  exit 0
fi

if [[ ! -d "${root}/node_modules" ]]; then
  printf 'error: %s declares %s but node_modules is missing — run npm ci in the product root before eval/bars\n' \
    "${pkg}" "${to_run[*]}" >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  printf 'error: npm not on PATH — cannot run %s\n' "${to_run[*]}" >&2
  exit 1
fi

rc=0
for s in "${to_run[@]}"; do
  printf 'typescript_execute: npm run %s (cwd=%s)\n' "${s}" "${root}" >&2
  if ! (cd "${root}" && npm run "${s}" --silent); then
    printf 'error: npm run %s failed under %s\n' "${s}" "${root}" >&2
    rc=1
  fi
done

if [[ "${rc}" -eq 0 ]]; then
  printf 'typescript_execute_ok scripts=%s root=%s\n' "${to_run[*]}" "${root}"
fi
exit "${rc}"
