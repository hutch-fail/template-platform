#!/usr/bin/env bash
# Universe bar: three-tier eval pack-quality ratchet.
# Tier1 deterministic (always). Tier2 meta/calibrate (TYPESAFE key-gated).
# Tier3 LiteLLM pack rubric (EVAL_LLM_* / OPENAI_* + EVAL_LLM_MODEL).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_kit() {
  local cand
  if [[ -n "${HERMES_EVAL_KIT:-}" && -d "${HERMES_EVAL_KIT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_KIT}" && pwd)"
    return 0
  fi
  if [[ -n "${EVALS_KIT:-}" && -d "${EVALS_KIT}" ]]; then
    printf '%s\n' "$(cd "${EVALS_KIT}" && pwd)"
    return 0
  fi
  for cand in \
    "${HERMES_EVAL_REPO_ROOT:-}" \
    "${HERMES_EVAL_REPO_ROOT:-}/evals" \
    "${HERMES_EVAL_RECIPE_ROOT:-}" \
    "${here}/../../.." \
    "${here}/../../../evals"; do
    [[ -n "${cand}" && -d "${cand}" ]] || continue
    if [[ -f "${cand}/harness/lib/pack_quality_lint.py" ]]; then
      printf '%s\n' "$(cd "${cand}" && pwd)"
      return 0
    fi
  done
  printf 'error: cannot resolve evals kit (set HERMES_EVAL_KIT)\n' >&2
  return 1
}

kit="$(resolve_kit)"
lint_py="${kit}/harness/lib/pack_quality_lint.py"
judge_py="${kit}/harness/lib/llm_pack_quality_judge.py"
samples="${here}/samples"

resolve_scan_root() {
  if [[ -n "${HERMES_EVAL_SCAN_ROOT:-}" && -d "${HERMES_EVAL_SCAN_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_SCAN_ROOT}" && pwd)"
    return 0
  fi
  printf '%s\n' "${here}"
}

root="$(resolve_scan_root)"
rc=0

if [[ ! -f "${lint_py}" ]]; then
  printf 'error: missing pack_quality_lint.py at %s\n' "${lint_py}" >&2
  exit 1
fi

# --- Tier 1a: selftest good/bad samples (always) ---
if ! python3 "${lint_py}" --scan-root "${here}" --selftest "${samples}" --selftest-only; then
  rc=1
fi

# --- Tier 1b: lint packs under scan root ---
mode="opt-in"
if [[ -f "${root}/PACK_QUALITY_FIXTURE" ]]; then
  mode="all"
fi

if ! python3 "${lint_py}" --scan-root "${root}" --mode "${mode}"; then
  rc=1
fi

# --- Tier 2: Jev meta/calibrate (key-gated) ---
ensure_meta_python() {
  local req="${kit}/meta/requirements.txt"
  local venv="${kit}/meta/.venv"
  [[ -f "${req}" ]] || {
    printf 'error: missing %s\n' "${req}" >&2
    return 1
  }
  if [[ ! -x "${venv}/bin/python" ]]; then
    python3 -m venv "${venv}"
  fi
  # Quiet install into kit-local venv (no global site-packages).
  "${venv}/bin/pip" install -q --disable-pip-version-check --no-input -r "${req}"
}

run_tier2() {
  local fixture_mode=0
  [[ -f "${root}/PACK_QUALITY_FIXTURE" ]] && fixture_mode=1

  if [[ -n "${TYPESAFE_API_KEY:-}" ]]; then
    printf 'meta_eval_tier2: make meta/calibrate (kit=%s)\n' "${kit}" >&2
    if ! ensure_meta_python; then
      return 1
    fi
    if ! make -C "${kit}" meta/calibrate; then
      printf 'error: meta/calibrate failed — Tier2 fail closed\n' >&2
      return 1
    fi
    printf 'meta_eval_tier2_ok\n'
    return 0
  fi
  if [[ "${PRE_COMMIT:-}" == "1" || "${HERMES_EVAL_SKIP_JEV:-}" == "1" || "${fixture_mode}" -eq 1 ]]; then
    printf 'meta_eval_tier2_skip reason=no_TYPESAFE_API_KEY root=%s\n' "${root}" >&2
    return 0
  fi
  printf 'error: TYPESAFE_API_KEY unset — Tier2 meta/calibrate fail closed (set PRE_COMMIT=1 to skip locally)\n' >&2
  return 1
}

if ! run_tier2; then
  rc=1
fi

# --- Tier 3: LiteLLM pack-quality judge (key + model gated) ---
ensure_llm_python() {
  local req="${kit}/harness/requirements-llm.txt"
  local venv="${kit}/harness/.venv-llm"
  [[ -f "${req}" ]] || {
    printf 'error: missing %s\n' "${req}" >&2
    return 1
  }
  if [[ ! -x "${venv}/bin/python" ]]; then
    python3 -m venv "${venv}"
  fi
  "${venv}/bin/pip" install -q --disable-pip-version-check --no-input -r "${req}"
  printf '%s\n' "${venv}/bin/python"
}

run_tier3() {
  local key model judged=0 fixture_mode=0 llm_py
  key="${EVAL_LLM_API_KEY:-${OPENAI_API_KEY:-}}"
  model="${EVAL_LLM_MODEL:-}"
  [[ -f "${root}/PACK_QUALITY_FIXTURE" ]] && fixture_mode=1

  # EVAL_LLM_MODEL is the opt-in: unset → skip (CI green until secrets exist).
  # When model is set, key is required (fail closed) unless PRE_COMMIT/fixture skip.
  if [[ -z "${model}" ]]; then
    printf 'meta_eval_tier3_skip reason=no_EVAL_LLM_MODEL root=%s\n' "${root}" >&2
    return 0
  fi
  if [[ -z "${key}" ]]; then
    if [[ "${PRE_COMMIT:-}" == "1" || "${HERMES_EVAL_SKIP_LLM_PACK:-}" == "1" || "${fixture_mode}" -eq 1 ]]; then
      printf 'meta_eval_tier3_skip reason=no_EVAL_LLM_key root=%s\n' "${root}" >&2
      return 0
    fi
    printf 'error: EVAL_LLM_MODEL set but EVAL_LLM_API_KEY/OPENAI_API_KEY unset — Tier3 fail closed\n' >&2
    return 1
  fi
  if [[ ! -f "${judge_py}" ]]; then
    printf 'error: missing llm_pack_quality_judge.py at %s\n' "${judge_py}" >&2
    return 1
  fi
  llm_py="$(ensure_llm_python)" || return 1

  list_tier3_goals() {
    local g
    if [[ -n "${BASE_REF:-}" ]]; then
      local repo="${GITHUB_WORKSPACE:-${kit}}"
      git -C "${repo}" diff --name-only "origin/${BASE_REF}...HEAD" -- \
        'goals/**/*.md' 'evals/goals/**/*.md' 2>/dev/null \
        | while IFS= read -r g; do
            [[ -z "${g}" ]] && continue
            case "${g}" in
              *-result.md) continue ;;
            esac
            if [[ -f "${repo}/${g}" ]]; then
              printf '%s\n' "${repo}/${g}"
            elif [[ -f "${root}/${g}" ]]; then
              printf '%s\n' "${root}/${g}"
            fi
          done
      return 0
    fi
    find "${root}/goals" "${root}/evals/goals" -name '*.md' ! -name '*-result.md' 2>/dev/null || true
  }

  local goal
  while IFS= read -r goal; do
    [[ -z "${goal}" || ! -f "${goal}" ]] && continue
    if ! grep -qE '^# Executive overview[[:space:]]*$|^pack_quality:[[:space:]]*(required|ratchet)' "${goal}" 2>/dev/null; then
      continue
    fi
    case "${goal}" in
      */samples/*) continue ;;
    esac
    judged=1
    printf 'meta_eval_tier3: judging %s\n' "${goal}" >&2
    if ! "${llm_py}" "${judge_py}" "${goal}"; then
      return 1
    fi
  done < <(list_tier3_goals)

  if [[ "${judged}" -eq 0 && -f "${samples}/good/goal.md" ]]; then
    printf 'meta_eval_tier3: judging sample good\n' >&2
    if ! "${llm_py}" "${judge_py}" "${samples}/good/goal.md"; then
      return 1
    fi
  fi
  printf 'meta_eval_tier3_ok\n'
  return 0
}

if ! run_tier3; then
  rc=1
fi

if [[ "${rc}" -eq 0 ]]; then
  printf 'meta_eval_pack_quality_ok root=%s mode=%s\n' "${root}" "${mode}"
fi
exit "${rc}"
