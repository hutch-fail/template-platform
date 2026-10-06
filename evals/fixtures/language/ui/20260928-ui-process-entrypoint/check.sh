#!/usr/bin/env bash
# F2P: UI consumers expose process-gate entrypoint + process JSON fixtures.
set -euo pipefail

root="${HERMES_EVAL_REPO_ROOT:-}"
if [[ -z "${root}" || ! -d "${root}" ]]; then
  printf 'HERMES_EVAL_REPO_ROOT unset or not a directory\n' >&2
  exit 1
fi

miss() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# Entrypoint: npm script ui:process and/or scripts/ui-process-check.*
has_script=0
if [[ -f "${root}/package.json" ]] && grep -qE '"ui:process"[[:space:]]*:' "${root}/package.json"; then
  has_script=1
fi
has_file=0
for cand in \
  "${root}/scripts/ui-process-check.mjs" \
  "${root}/scripts/ui-process-check.js" \
  "${root}/scripts/ui-process-check.ts"; do
  if [[ -f "${cand}" ]]; then
    has_file=1
    break
  fi
done
if [[ "${has_script}" -eq 0 && "${has_file}" -eq 0 ]]; then
  # Hub kit self-scan (pre-commit on language/ui paths): not a UI consumer.
  if [[ -f "${root}/scripts/eval-bars.sh" && -d "${root}/fixtures/language/ui" ]]; then
    printf 'ui_process_entrypoint_skip reason=hub_kit_self_scan root=%s\n' "${root}"
    exit 0
  fi
  miss "UI consumers need package.json scripts.ui:process or scripts/ui-process-check.*"
fi

# Process JSON fixtures — preferred own-leaf, legacy evals/ui overlay accepted.
json_count=0
while IFS= read -r -d '' f; do
  json_count=$((json_count + 1))
done < <(
  find "${root}/evals" \
    \( -path '*/fixtures/github.com/*/ui-process/fixtures/*.json' \
       -o -path '*/ui/process/fixtures/*.json' \) \
    -type f -print0 2>/dev/null || true
)

if [[ "${json_count}" -lt 1 ]]; then
  miss "no process JSON fixtures (want evals/fixtures/github.com/<org>/<repo>/ui-process/fixtures/*.json or legacy evals/ui/process/fixtures/*.json)"
fi

printf 'ui_process_entrypoint_ok entrypoint=%s fixtures=%s\n' \
  "$([[ ${has_script} -eq 1 ]] && echo npm:ui:process || echo scripts/ui-process-check)" \
  "${json_count}"
