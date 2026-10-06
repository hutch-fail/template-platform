#!/usr/bin/env bash
# Shared eval bars entrypoint for local, pre-commit, and CI.
#
# Always runs applicable **universe** bars against HERMES_EVAL_SCAN_ROOT:
#   - no raw secrets.GH_APP_* in workflows
#   - org pre-commit (hutch-fail/pre-commit id: platform + evals-pre-commit + evals-pre-push)
#   - sync-secrets GITHUB_OWNER hard-pin (no parent-shell inherit)
# Append further org-wide CI/CD checks in run_universe_bars (universe growth rail).
#
# Additionally runs **language** family bars when changed paths (or force)
# indicate them:
#   - *.tf / *.tf.json     → opentofu (remote-backend, …)
#   - *.ts / *.tsx / tsconfig.json / package.json with typescript cues → typescript
#     (typecheck / test npm scripts when present)
#   - design/**, docs/design-system/**, docs/north-star/**, evals/ui/**,
#     scripts/ui-*, own-leaf ui-process|ui-jev|ui-visual|ui-semantic → ui
#     (presence + execute ui:docs|lint|process + optional ui:jev)
#   - ansible/**, */ansible/**, ansible.cfg, */ansible.cfg → ansible
#     (single-converge; not bare *.yml)
#   - .github/workflows/**, .github/actions/** → gha
#     (CI/CD / Actions hygiene; languages: gha or alias ci)
#
# Usage:
#   bash scripts/eval-bars.sh [path...]
#   make eval/bars
#   HERMES_EVAL_FORCE_FAMILIES=opentofu bash scripts/eval-bars.sh
#
# Env:
#   HERMES_EVAL_KIT / EVALS_KIT — evals hub (default: ./evals or parent of scripts/)
#   HERMES_EVAL_SCAN_ROOT — product root to scan (default: cwd)
#   HERMES_EVAL_FORCE_FAMILIES — comma list to add families even with no paths
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_kit() {
  local kit="${HERMES_EVAL_KIT:-${EVALS_KIT:-}}"
  if [[ -n "${kit}" ]]; then
    printf '%s\n' "$(cd "${kit}" && pwd)"
    return 0
  fi
  if [[ -f "${PWD}/evals/harness/goal.sh" ]]; then
    printf '%s\n' "$(cd "${PWD}/evals" && pwd)"
    return 0
  fi
  if [[ -f "${script_dir}/../harness/goal.sh" ]]; then
    printf '%s\n' "$(cd "${script_dir}/.." && pwd)"
    return 0
  fi
  printf 'error: cannot find evals kit (set HERMES_EVAL_KIT or run from a product with ./evals)\n' >&2
  return 1
}

is_tf_path() {
  local base
  base="$(basename "$1")"
  case "${base}" in
    *.tf|*.tf.json) return 0 ;;
  esac
  return 1
}

is_typescript_path() {
  local base
  base="$(basename "$1")"
  case "${base}" in
    *.ts|*.tsx|tsconfig.json|tsconfig.*.json) return 0 ;;
  esac
  return 1
}

# Ansible family path allowlist (org-wide). Bare *.yml is intentionally excluded.
is_ansible_path() {
  local p="$1" base
  base="$(basename "${p}")"
  case "${base}" in
    ansible.cfg) return 0 ;;
  esac
  case "${p}" in
    ansible/*|*/ansible/*) return 0 ;;
    ansible.cfg|*/ansible.cfg) return 0 ;;
    fixtures/language/ansible/*|*/fixtures/language/ansible/*|goals/language/ansible/*|*/goals/language/ansible/*) return 0 ;;
  esac
  return 1
}

# Kit / recipe paths that still cue the ansible family (skipped by is_kit_path otherwise).
is_ansible_kit_cue_path() {
  local p="$1"
  case "${p}" in
    evals/fixtures/language/ansible/*|*/evals/fixtures/language/ansible/*) return 0 ;;
    evals/goals/language/ansible/*|*/evals/goals/language/ansible/*) return 0 ;;
    fixtures/language/ansible/*|*/fixtures/language/ansible/*) return 0 ;;
    goals/language/ansible/*|*/goals/language/ansible/*) return 0 ;;
  esac
  return 1
}

# GHA / CI-CD family: product workflow and composite action trees only.
is_gha_path() {
  local p="$1"
  case "${p}" in
    .github/workflows/*|*/.github/workflows/*) return 0 ;;
    .github/actions/*|*/.github/actions/*) return 0 ;;
    fixtures/language/gha/*|*/fixtures/language/gha/*|goals/language/gha/*|*/goals/language/gha/*) return 0 ;;
  esac
  return 1
}

# Kit / recipe paths that still cue the gha family (skipped by is_kit_path otherwise).
is_gha_kit_cue_path() {
  local p="$1"
  case "${p}" in
    evals/fixtures/language/gha/*|*/evals/fixtures/language/gha/*) return 0 ;;
    evals/goals/language/gha/*|*/evals/goals/language/gha/*) return 0 ;;
    fixtures/language/gha/*|*/fixtures/language/gha/*) return 0 ;;
    goals/language/gha/*|*/goals/language/gha/*) return 0 ;;
  esac
  return 1
}

# UI family path allowlist (org-wide). src/** alone is intentionally excluded.
is_ui_path() {
  local p="$1"
  case "${p}" in
    design/*|*/design/*) return 0 ;;
    docs/design-system/*|*/docs/design-system/*) return 0 ;;
    docs/north-star/*|*/docs/north-star/*) return 0 ;;
    evals/ui/*|*/evals/ui/*) return 0 ;;
    scripts/ui-*|*/scripts/ui-*) return 0 ;;
    */ui-process/*|*ui-process/*) return 0 ;;
    */ui-jev/*|*ui-jev/*) return 0 ;;
    */ui-visual/*|*ui-visual/*) return 0 ;;
    */ui-semantic/*|*ui-semantic/*) return 0 ;;
    fixtures/language/ui/*|*/fixtures/language/ui/*|goals/language/ui/*|*/goals/language/ui/*) return 0 ;;
  esac
  return 1
}

# Skip kit / recipe paths (language fixtures ship *.tf; universe fixtures ship workflows).
is_kit_path() {
  case "$1" in
    evals/*|*/evals/*|fixtures/*|*/fixtures/*) return 0 ;;
  esac
  return 1
}

# Kit / recipe paths that still cue the ui family (skipped by is_kit_path otherwise).
is_ui_kit_cue_path() {
  local p="$1"
  case "${p}" in
    evals/fixtures/language/ui/*|*/evals/fixtures/language/ui/*) return 0 ;;
    evals/goals/language/ui/*|*/evals/goals/language/ui/*) return 0 ;;
    fixtures/language/ui/*|*/fixtures/language/ui/*) return 0 ;;
    goals/language/ui/*|*/goals/language/ui/*) return 0 ;;
    evals/fixtures/github.com/*/ui-process/*|*/evals/fixtures/github.com/*/ui-process/*) return 0 ;;
    evals/fixtures/github.com/*/ui-jev/*|*/evals/fixtures/github.com/*/ui-jev/*) return 0 ;;
    evals/fixtures/github.com/*/ui-visual/*|*/evals/fixtures/github.com/*/ui-visual/*) return 0 ;;
    evals/fixtures/github.com/*/ui-semantic/*|*/evals/fixtures/github.com/*/ui-semantic/*) return 0 ;;
    fixtures/github.com/*/ui-process/*|*/fixtures/github.com/*/ui-process/*) return 0 ;;
    fixtures/github.com/*/ui-jev/*|*/fixtures/github.com/*/ui-jev/*) return 0 ;;
    fixtures/github.com/*/ui-visual/*|*/fixtures/github.com/*/ui-visual/*) return 0 ;;
    fixtures/github.com/*/ui-semantic/*|*/fixtures/github.com/*/ui-semantic/*) return 0 ;;
    evals/ui/*|*/evals/ui/*) return 0 ;;
  esac
  return 1
}

resolve_manifest() {
  local scan_root="$1"
  if [[ -f "${scan_root}/evals/scope.yaml" ]]; then
    printf '%s\n' "${scan_root}/evals/scope.yaml"
  elif [[ -f "${scan_root}/scope.yaml" && -d "${scan_root}/harness" ]]; then
    printf '%s\n' "${scan_root}/scope.yaml"
  fi
}

# Families declared in consumer evals/scope.yaml languages: (select SoT).
# CI calls eval/bars with no path args — declaration is how UI/OpenTofu bars
# run automatically for new consumers that opt in via the manifest.
families_from_manifest() {
  local scan_root="$1" manifest lang
  manifest="$(resolve_manifest "${scan_root}")"
  [[ -n "${manifest}" && -f "${manifest}" ]] || return 0
  while IFS= read -r lang; do
    [[ -n "${lang}" ]] || continue
    case "${lang}" in
      opentofu|typescript|python|ui|ansible|gha) printf '%s\n' "${lang}" ;;
      ci) printf '%s\n' "gha" ;;
    esac
  done < <(
    # Prefer PyYAML when present; else list items under languages:.
    python3 - "${manifest}" <<'PY' 2>/dev/null || true
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding="utf-8")
try:
    import yaml  # type: ignore
    data = yaml.safe_load(text) or {}
    langs = data.get("languages") or []
    if isinstance(langs, str):
        langs = [langs]
    for lang in langs:
        if lang:
            print(str(lang).strip())
except Exception:
    in_langs = False
    for raw in text.splitlines():
        line = raw.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        if line.startswith("languages:"):
            in_langs = True
            continue
        if in_langs and line.lstrip().startswith("-"):
            print(line.lstrip()[1:].strip().strip("'\""))
        elif ":" in line and not line.startswith(" "):
            in_langs = False
PY
  )
}

# Print unique families that apply (one per line): universe (always), opentofu, typescript, ui, …
# Sources: FORCE_FAMILIES, path args (pre-commit), and scope.yaml languages (CI / default).
detect_families() {
  local arg fam scan_root
  declare -A seen=()
  # Universe bars always apply (global / recipe-wide policy).
  seen[universe]=1
  scan_root="$(cd "${HERMES_EVAL_SCAN_ROOT:-${PWD}}" && pwd)"

  if [[ -n "${HERMES_EVAL_FORCE_FAMILIES:-}" ]]; then
    IFS=',' read -r -a forced <<<"${HERMES_EVAL_FORCE_FAMILIES}"
    for fam in "${forced[@]}"; do
      fam="$(echo "${fam}" | tr -d '[:space:]')"
      [[ -n "${fam}" ]] || continue
      # Alias: ci → gha (workflow/SDLC language family).
      if [[ "${fam}" == "ci" ]]; then
        seen[gha]=1
        continue
      fi
      seen["${fam}"]=1
    done
  fi

  while IFS= read -r fam; do
    [[ -n "${fam}" ]] || continue
    seen["${fam}"]=1
  done < <(families_from_manifest "${scan_root}")

  for arg in "$@"; do
    if is_ui_kit_cue_path "${arg}"; then
      seen[ui]=1
    fi
    if is_ansible_kit_cue_path "${arg}"; then
      seen[ansible]=1
    fi
    if is_gha_kit_cue_path "${arg}"; then
      seen[gha]=1
    fi
    if is_kit_path "${arg}"; then
      continue
    fi
    if is_tf_path "${arg}"; then
      seen[opentofu]=1
    fi
    if is_typescript_path "${arg}"; then
      seen[typescript]=1
    fi
    if is_ui_path "${arg}"; then
      seen[ui]=1
    fi
    if is_ansible_path "${arg}"; then
      seen[ansible]=1
    fi
    if is_gha_path "${arg}"; then
      seen[gha]=1
    fi
  done

  for fam in "${!seen[@]}"; do
    printf '%s\n' "${fam}"
  done | sort -u
}

warn_if_manifest_omits() {
  local scan_root="$1" lang="$2"
  local manifest
  manifest="$(resolve_manifest "${scan_root}")"
  [[ -n "${manifest}" ]] || return 0
  if ! grep -qE "^[[:space:]]*-[[:space:]]*${lang}[[:space:]]*$|languages:.*${lang}" "${manifest}"; then
    printf 'warning: %s does not list languages: %s (%s bars still run on matching paths)\n' \
      "${manifest}" "${lang}" "${lang}" >&2
  fi
}

run_universe_bars() {
  local kit="$1" scan_root="$2"
  local check rc=0

  export HERMES_EVAL_SCAN_ROOT="${scan_root}"
  export HERMES_EVAL_REPO_ROOT="${scan_root}"

  # Universe CI/CD growth rail: append new always-on check.sh paths here.
  for check in \
    "${kit}/fixtures/universe/20260924-no-gha-app-actions-secrets/check.sh" \
    "${kit}/fixtures/universe/20260929-pre-commit-platform/check.sh" \
    "${kit}/fixtures/universe/20261002-local-eval-gates/check.sh" \
    "${kit}/fixtures/universe/20261004-sync-secrets-pin-github-owner/check.sh" \
    "${kit}/fixtures/universe/20260929-meta-eval-pack-quality/check.sh"; do
    if [[ ! -x "${check}" ]]; then
      printf 'error: missing universe check at %s\n' "${check}" >&2
      rc=1
      continue
    fi
    if ! bash "${check}"; then
      rc=1
    fi
  done
  return "${rc}"
}

run_opentofu_bars() {
  local kit="$1" scan_root="$2"
  local check="${kit}/fixtures/language/opentofu/20260924-remote-backend-locking/check.sh"
  if [[ ! -x "${check}" ]]; then
    printf 'error: missing OpenTofu remote-backend check at %s\n' "${check}" >&2
    return 1
  fi

  warn_if_manifest_omits "${scan_root}" "opentofu"

  export HERMES_EVAL_SCAN_ROOT="${scan_root}"
  export HERMES_EVAL_REPO_ROOT="${scan_root}"
  bash "${check}"
}

run_typescript_bars() {
  local kit="$1" scan_root="$2"
  local check="${kit}/fixtures/language/typescript/20260929-typescript-execute-scripts/check.sh"
  if [[ ! -x "${check}" ]]; then
    printf 'error: missing TypeScript execute check at %s\n' "${check}" >&2
    return 1
  fi

  warn_if_manifest_omits "${scan_root}" "typescript"

  export HERMES_EVAL_SCAN_ROOT="${scan_root}"
  export HERMES_EVAL_REPO_ROOT="${scan_root}"
  bash "${check}"
}

scope_lists_language() {
  local scan_root="$1" lang="$2" manifest
  manifest="$(resolve_manifest "${scan_root}")"
  [[ -n "${manifest}" && -f "${manifest}" ]] || return 1
  grep -qE "^[[:space:]]*-[[:space:]]*${lang}[[:space:]]*$|languages:.*${lang}" "${manifest}"
}

run_ui_bars() {
  local kit="$1" scan_root="$2"
  local check rc=0
  if [[ -f "${scan_root}/evals/scope.yaml" ]] && ! scope_lists_language "${scan_root}" "ui"; then
    printf 'ui_bars_skip reason=scope_languages_omit_ui root=%s\n' "${scan_root}"
    return 0
  fi
  warn_if_manifest_omits "${scan_root}" "ui"

  export HERMES_EVAL_SCAN_ROOT="${scan_root}"
  export HERMES_EVAL_REPO_ROOT="${scan_root}"

  for check in \
    "${kit}/fixtures/language/ui/20260928-ui-scope-manifest/check.sh" \
    "${kit}/fixtures/language/ui/20260928-ui-process-entrypoint/check.sh" \
    "${kit}/fixtures/language/ui/20260929-ui-execute-scripts/check.sh" \
    "${kit}/fixtures/language/ui/20260929-ui-jev-optional/check.sh"; do
    if [[ ! -x "${check}" ]]; then
      printf 'error: missing UI bar check at %s\n' "${check}" >&2
      rc=1
      continue
    fi
    if ! bash "${check}"; then
      rc=1
    fi
  done
  return "${rc}"
}

run_ansible_bars() {
  local kit="$1" scan_root="$2"
  local check="${kit}/fixtures/language/ansible/20260929-ansible-single-converge/check.sh"
  if [[ ! -x "${check}" ]]; then
    printf 'error: missing Ansible single-converge check at %s\n' "${check}" >&2
    return 1
  fi

  warn_if_manifest_omits "${scan_root}" "ansible"

  export HERMES_EVAL_SCAN_ROOT="${scan_root}"
  export HERMES_EVAL_REPO_ROOT="${scan_root}"
  bash "${check}"
}

run_gha_bars() {
  local kit="$1" scan_root="$2"
  local check rc=0
  warn_if_manifest_omits "${scan_root}" "gha"

  export HERMES_EVAL_SCAN_ROOT="${scan_root}"
  export HERMES_EVAL_REPO_ROOT="${scan_root}"

  for check in \
    "${kit}/fixtures/language/gha/20261001-unique-runner-determination/check.sh"; do
    if [[ ! -x "${check}" ]]; then
      printf 'error: missing gha bar check at %s\n' "${check}" >&2
      rc=1
      continue
    fi
    if ! bash "${check}"; then
      rc=1
    fi
  done
  return "${rc}"
}

kit="$(resolve_kit)"
scan_root="$(cd "${HERMES_EVAL_SCAN_ROOT:-${PWD}}" && pwd)"

mapfile -t families < <(detect_families "$@")

rc=0
for fam in "${families[@]}"; do
  case "${fam}" in
    universe)
      if ! run_universe_bars "${kit}" "${scan_root}"; then
        rc=1
      fi
      ;;
    opentofu)
      if ! run_opentofu_bars "${kit}" "${scan_root}"; then
        rc=1
      fi
      ;;
    typescript)
      if ! run_typescript_bars "${kit}" "${scan_root}"; then
        rc=1
      fi
      ;;
    ui)
      if ! run_ui_bars "${kit}" "${scan_root}"; then
        rc=1
      fi
      ;;
    ansible)
      if ! run_ansible_bars "${kit}" "${scan_root}"; then
        rc=1
      fi
      ;;
    gha)
      if ! run_gha_bars "${kit}" "${scan_root}"; then
        rc=1
      fi
      ;;
    *)
      printf 'error: unknown eval family %q (extend scripts/eval-bars.sh)\n' "${fam}" >&2
      rc=1
      ;;
  esac
done

exit "${rc}"
