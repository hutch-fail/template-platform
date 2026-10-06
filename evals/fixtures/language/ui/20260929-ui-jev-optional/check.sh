#!/usr/bin/env bash
# F2P / product bar: if package.json has ui:jev, require TYPESAFE_API_KEY and run.
# If no ui:jev script, skip (exit 0).
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

if [[ ! -f "${pkg}" ]] || ! pkg_has_script "${root}" "ui:jev"; then
  printf 'ui_jev_optional_skip reason=no_ui_jev_script root=%s\n' "${root}"
  exit 0
fi

if [[ -z "${TYPESAFE_API_KEY:-}" ]]; then
  # CI / explicit bars: fail closed. Local pre-commit historically only ran
  # deterministic ui:lint — skip Jev when the key is absent so laptops can
  # commit; eval-ci still fails closed when ui:jev is declared.
  if [[ "${PRE_COMMIT:-}" == "1" || "${HERMES_EVAL_SKIP_JEV:-}" == "1" ]]; then
    printf 'ui_jev_optional_skip reason=no_TYPESAFE_API_KEY_pre_commit root=%s\n' "${root}" >&2
    exit 0
  fi
  printf 'error: package.json has ui:jev but TYPESAFE_API_KEY is unset — fail closed (pass secret into eval-ci / local env)\n' >&2
  exit 1
fi

if [[ ! -d "${root}/node_modules" ]]; then
  printf 'error: ui:jev present but node_modules missing — run npm ci before eval/bars\n' >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  printf 'error: npm not on PATH — cannot run ui:jev\n' >&2
  exit 1
fi

printf 'ui_jev: npm run ui:jev (cwd=%s)\n' "${root}" >&2
(cd "${root}" && npm run ui:jev --silent)
printf 'ui_jev_optional_ok root=%s\n' "${root}"
