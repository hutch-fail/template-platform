#!/usr/bin/env bash
# Universe bar: three-tier eval pack-quality ratchet.
# Tier1 deterministic (always).
# Tier2 Jev holistic judge on changed goals (TYPESAFE key-gated) +
#   path-triggered labeled-sample selftest when judge/samples change.
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
jev_py="${kit}/harness/lib/jev_pack_quality_judge.py"
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

# True when changed paths touch the Jev judge, jev-* samples, or this Tier2 wiring.
jev_selftest_paths_changed() {
  local line
  if [[ "${HERMES_EVAL_JEV_SELFTEST:-}" == "1" ]]; then
    return 0
  fi
  if [[ -z "${HERMES_EVAL_CHANGED_PATHS+x}" ]]; then
    return 1
  fi
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -n "${line}" ]] || continue
    case "${line}" in
      *harness/lib/jev_pack_quality_judge.py) return 0 ;;
      *20260929-meta-eval-pack-quality/check.sh) return 0 ;;
      *samples/jev-*) return 0 ;;
      *samples/README-jev.md) return 0 ;;
    esac
  done <<<"${HERMES_EVAL_CHANGED_PATHS}"
  return 1
}

# Hermetic probe for unit contracts (no Tier1/2/3 side effects).
if [[ "${HERMES_EVAL_PROBE_JEV_SELFTEST_GATE:-}" == "1" ]]; then
  if jev_selftest_paths_changed; then
    printf 'jev_selftest_gate=run\n'
  else
    printf 'jev_selftest_gate=skip\n'
  fi
  exit 0
fi

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

lint_paths=()
if [[ "${mode}" != "all" && -n "${HERMES_EVAL_CHANGED_PATHS+x}" ]]; then
  while IFS= read -r gp; do
    [[ -n "${gp}" ]] || continue
    lint_paths+=("${gp}")
  done < <(
    python3 "${kit}/harness/lib/pack_quality_select.py" --scan-root "${root}" \
      --changed-paths "${HERMES_EVAL_CHANGED_PATHS}" 2>/dev/null || true
  )
fi

if [[ "${#lint_paths[@]}" -gt 0 ]]; then
  if ! python3 "${lint_py}" --scan-root "${root}" --mode "${mode}" "${lint_paths[@]}"; then
    rc=1
  fi
elif [[ "${mode}" == "all" || -z "${HERMES_EVAL_CHANGED_PATHS+x}" ]]; then
  if ! python3 "${lint_py}" --scan-root "${root}" --mode "${mode}"; then
    rc=1
  fi
else
  printf 'pack_quality_skip reason=no_changed_goals root=%s\n' "${root}" >&2
fi

# --- Tier 2: Jev pack-quality on changed goals (key-gated) ---
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
  "${venv}/bin/pip" install -q --disable-pip-version-check --no-input -r "${req}"
  printf '%s\n' "${venv}/bin/python"
}

run_tier2() {
  local fixture_mode=0 meta_py judged=0 tier2_rc=0 goal select_py select_args
  local want_selftest=0
  [[ -f "${root}/PACK_QUALITY_FIXTURE" ]] && fixture_mode=1

  if [[ ! -f "${jev_py}" ]]; then
    printf 'error: missing jev_pack_quality_judge.py at %s\n' "${jev_py}" >&2
    return 1
  fi

  # Sample selftest: only when judge/samples/wiring change, fixture mode, or force.
  if [[ "${fixture_mode}" -eq 1 ]] || jev_selftest_paths_changed; then
    want_selftest=1
  fi

  if [[ -z "${TYPESAFE_API_KEY:-}" ]]; then
    if [[ "${PRE_COMMIT:-}" == "1" || "${HERMES_EVAL_SKIP_JEV:-}" == "1" || "${fixture_mode}" -eq 1 ]]; then
      printf 'meta_eval_tier2_skip reason=no_TYPESAFE_API_KEY root=%s\n' "${root}" >&2
      return 0
    fi
    printf 'error: TYPESAFE_API_KEY unset — Tier2 Jev pack-quality fail closed (set PRE_COMMIT=1 to skip locally)\n' >&2
    return 1
  fi

  meta_py="$(ensure_meta_python)" || return 1

  if [[ "${want_selftest}" -eq 1 ]]; then
    printf 'meta_eval_tier2_selftest: jev samples (kit=%s)\n' "${kit}" >&2
    if ! "${meta_py}" "${jev_py}" --selftest "${samples}"; then
      printf 'error: Jev pack-quality sample selftest failed — Tier2 fail closed\n' >&2
      return 1
    fi
    printf 'meta_eval_tier2_selftest_ok\n'
  else
    printf 'meta_eval_tier2_selftest_skip reason=unchanged_judge_or_samples\n' >&2
  fi

  select_py="${kit}/harness/lib/pack_quality_select.py"
  if [[ ! -f "${select_py}" ]]; then
    printf 'error: missing pack_quality_select.py — Tier2 cannot select goals\n' >&2
    return 1
  fi
  select_args=(--scan-root "${root}")
  if [[ "${fixture_mode}" -eq 1 ]]; then
    # Fixture mode: selftest above is enough; do not tree-scan all goals via Jev.
    printf 'meta_eval_tier2_ok reason=fixture_selftest_only\n'
    return 0
  elif [[ -n "${HERMES_EVAL_CHANGED_PATHS+x}" ]]; then
    select_args+=(--changed-paths "${HERMES_EVAL_CHANGED_PATHS}")
  elif [[ "${HERMES_EVAL_JEV_JUDGE_ALL:-}" == "1" ]]; then
    select_args+=(--judge-all)
  else
    printf 'meta_eval_tier2_skip reason=no_changed_goals root=%s\n' "${root}" >&2
    return 0
  fi

  while IFS= read -r goal; do
    [[ -z "${goal}" || ! -f "${goal}" ]] && continue
    if ! grep -qE '^# Executive overview[[:space:]]*$|^pack_quality:[[:space:]]*(required|ratchet)' "${goal}" 2>/dev/null; then
      continue
    fi
    case "${goal}" in
      */samples/*) continue ;;
    esac
    judged=1
    printf 'meta_eval_tier2: judging %s\n' "${goal}" >&2
    if ! "${meta_py}" "${jev_py}" "${goal}"; then
      tier2_rc=1
    fi
  done < <(python3 "${select_py}" "${select_args[@]}" 2>/dev/null || true)

  if [[ "${judged}" -eq 0 ]]; then
    printf 'meta_eval_tier2_skip reason=no_changed_goals root=%s\n' "${root}" >&2
    return 0
  fi
  if [[ "${tier2_rc}" -ne 0 ]]; then
    return 1
  fi
  printf 'meta_eval_tier2_ok\n'
  return 0
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

  local select_py="${kit}/harness/lib/pack_quality_select.py"
  if [[ ! -f "${select_py}" ]]; then
    printf 'error: missing pack_quality_select.py — Tier3 cannot select goals\n' >&2
    return 1
  fi
  local select_args=(--scan-root "${root}")
  if [[ "${fixture_mode}" -eq 1 ]]; then
    select_args+=(--fixture-mode)
  elif [[ -n "${HERMES_EVAL_CHANGED_PATHS+x}" ]]; then
    select_args+=(--changed-paths "${HERMES_EVAL_CHANGED_PATHS}")
  elif [[ "${HERMES_EVAL_LLM_JUDGE_ALL:-}" == "1" ]]; then
    select_args+=(--judge-all)
  else
    printf 'meta_eval_tier3_skip reason=no_changed_goals root=%s\n' "${root}" >&2
    return 0
  fi

  local goal tier3_rc=0
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
      tier3_rc=1
    fi
  done < <(python3 "${select_py}" "${select_args[@]}" 2>/dev/null || true)

  if [[ "${judged}" -eq 0 ]]; then
    if [[ "${fixture_mode}" -eq 1 && -f "${samples}/good/goal.md" ]]; then
      printf 'meta_eval_tier3: judging sample good\n' >&2
      if ! "${llm_py}" "${judge_py}" "${samples}/good/goal.md"; then
        return 1
      fi
    else
      printf 'meta_eval_tier3_skip reason=no_changed_goals root=%s\n' "${root}" >&2
      return 0
    fi
  fi
  if [[ "${tier3_rc}" -ne 0 ]]; then
    return 1
  fi
  printf 'meta_eval_tier3_ok\n'
  return 0
}

if ! run_tier3; then
  rc=1
fi

# --- PR-scope + readable-fail contracts (no live LLM) ---
run_pr_scope_contracts() {
  local select_py="${kit}/harness/lib/pack_quality_select.py"
  local bars="${kit}/scripts/eval-bars.sh"
  local tmp planted_new planted_old listed err
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/pack-quality-pr-scope.XXXXXX")"
  planted_old="${tmp}/goals/universe/historic.md"
  planted_new="${tmp}/goals/universe/pr-new.md"
  mkdir -p "${tmp}/goals/universe"
  printf '%s\n' '# Executive overview' 'A planted historic pack.' >"${planted_old}"
  printf '%s\n' '# Executive overview' 'A planted PR-new pack.' >"${planted_new}"

  if [[ ! -f "${select_py}" ]]; then
    printf 'error: missing pack_quality_select.py — Tier3 still tree-scans historic goals\n' >&2
    rm -rf "${tmp}"
    return 1
  fi

  listed="$(
    python3 "${select_py}" --scan-root "${tmp}" --changed-paths 'goals/universe/pr-new.md' \
      2>/dev/null || true
  )"
  if printf '%s\n' "${listed}" | grep -q 'historic.md'; then
    printf 'error: selector listed historic.md under HERMES_EVAL_CHANGED_PATHS=pr-new.md\n' >&2
    rm -rf "${tmp}"
    return 1
  fi
  if ! printf '%s\n' "${listed}" | grep -q 'pr-new.md'; then
    printf 'error: selector omitted pr-new.md from changed paths\n listed=%s\n' "${listed}" >&2
    rm -rf "${tmp}"
    return 1
  fi

  listed="$(
    python3 "${select_py}" --scan-root "${tmp}" --changed-paths '' 2>/dev/null || true
  )"
  if printf '%s\n' "${listed}" | grep -qE 'historic.md|pr-new.md'; then
    printf 'error: empty changed-paths must not tree-scan goals (got %s)\n' "${listed}" >&2
    rm -rf "${tmp}"
    return 1
  fi
  rm -rf "${tmp}"

  err="$(
    python3 "${judge_py}" --format-fail --path 'goals/universe/example.md' \
      --axis adversarial_warning 2>&1 || true
  )"
  if ! printf '%s\n' "${err}" | grep -q 'error: pack-quality LLM fail path=goals/universe/example.md'; then
    printf 'error: --format-fail must name the file\n got=%s\n' "${err}" >&2
    return 1
  fi
  if ! printf '%s\n' "${err}" | grep -q 'axis adversarial_warning: FAIL'; then
    printf 'error: --format-fail must name the axis\n got=%s\n' "${err}" >&2
    return 1
  fi
  if ! printf '%s\n' "${err}" | grep -q 'what this means:'; then
    printf 'error: --format-fail must print what this means\n got=%s\n' "${err}" >&2
    return 1
  fi
  if ! printf '%s\n' "${err}" | grep -q 'how to pass:'; then
    printf 'error: --format-fail must print how to pass\n got=%s\n' "${err}" >&2
    return 1
  fi
  if ! printf '%s\n' "${err}" | grep -qi 'slogan'; then
    printf 'error: adversarial_warning how-to-pass must say a slogan is not enough\n got=%s\n' "${err}" >&2
    return 1
  fi

  if [[ ! -f "${bars}" ]] || ! grep -q 'export HERMES_EVAL_CHANGED_PATHS' "${bars}"; then
    printf 'error: eval-bars.sh must export HERMES_EVAL_CHANGED_PATHS from path argv\n' >&2
    return 1
  fi
  if [[ ! -f "${bars}" ]] || ! grep -q 'HERMES_EVAL_DUMP_CHANGED_PATHS' "${bars}"; then
    printf 'error: eval-bars.sh must support HERMES_EVAL_DUMP_CHANGED_PATHS probe\n' >&2
    return 1
  fi
  listed="$(
    HERMES_EVAL_DUMP_CHANGED_PATHS=1 HERMES_EVAL_SCAN_ROOT="${root}" \
      bash "${bars}" 'goals/universe/pr-new.md' 2>/dev/null || true
  )"
  if ! printf '%s\n' "${listed}" | grep -qx 'goals/universe/pr-new.md'; then
    printf 'error: eval-bars dump must echo argv paths, got=%s\n' "${listed}" >&2
    return 1
  fi

  if [[ ! -f "${jev_py}" ]]; then
    printf 'error: missing jev_pack_quality_judge.py\n' >&2
    return 1
  fi
  # Live make invoke only (ignore this assertion / comments).
  if awk '
    /make/ && /meta\/calibrate/ && !/grep/ && !/awk/ && !/printf/ && !/^[[:space:]]*#/ {
      exit 0
    }
    END { exit 1 }
  ' "${here}/check.sh"; then
    printf 'error: Tier2 must not invoke meta/calibrate (toy criterion quiz)\n' >&2
    return 1
  fi
  if ! grep -q 'jev_pack_quality_judge' "${here}/check.sh"; then
    printf 'error: Tier2 must wire jev_pack_quality_judge\n' >&2
    return 1
  fi

  # Path-gate: product goal alone → skip selftest; judge path → run.
  listed="$(
    HERMES_EVAL_PROBE_JEV_SELFTEST_GATE=1 \
      HERMES_EVAL_CHANGED_PATHS='goals/universe/pr-new.md' \
      bash "${here}/check.sh" 2>/dev/null || true
  )"
  if ! printf '%s\n' "${listed}" | grep -qx 'jev_selftest_gate=skip'; then
    printf 'error: product-only changed paths must skip Jev selftest gate, got=%s\n' "${listed}" >&2
    return 1
  fi
  listed="$(
    HERMES_EVAL_PROBE_JEV_SELFTEST_GATE=1 \
      HERMES_EVAL_CHANGED_PATHS='harness/lib/jev_pack_quality_judge.py' \
      bash "${here}/check.sh" 2>/dev/null || true
  )"
  if ! printf '%s\n' "${listed}" | grep -qx 'jev_selftest_gate=run'; then
    printf 'error: judge path change must run Jev selftest gate, got=%s\n' "${listed}" >&2
    return 1
  fi
  listed="$(
    HERMES_EVAL_PROBE_JEV_SELFTEST_GATE=1 \
      HERMES_EVAL_CHANGED_PATHS='fixtures/universe/20260929-meta-eval-pack-quality/samples/jev-good/goal.md' \
      bash "${here}/check.sh" 2>/dev/null || true
  )"
  if ! printf '%s\n' "${listed}" | grep -qx 'jev_selftest_gate=run'; then
    printf 'error: jev sample change must run Jev selftest gate, got=%s\n' "${listed}" >&2
    return 1
  fi

  err="$(
    python3 "${jev_py}" --format-fail --path 'goals/universe/example.md' \
      --axis mirror_prod 2>&1 || true
  )"
  if ! printf '%s\n' "${err}" | grep -q 'error: pack-quality Jev fail path=goals/universe/example.md'; then
    printf 'error: Jev --format-fail must name the file\n got=%s\n' "${err}" >&2
    return 1
  fi
  if ! printf '%s\n' "${err}" | grep -q 'axis mirror_prod: FAIL'; then
    printf 'error: Jev --format-fail must name the axis\n got=%s\n' "${err}" >&2
    return 1
  fi

  [[ -f "${samples}/jev-good/goal.md" && -f "${samples}/jev-good/expected.yaml" ]] \
    || {
      printf 'error: missing samples/jev-good/{goal.md,expected.yaml}\n' >&2
      return 1
    }
  [[ -f "${samples}/jev-bad-mirror/expected.yaml" ]] \
    || {
      printf 'error: missing samples/jev-bad-mirror/expected.yaml\n' >&2
      return 1
    }

  printf 'pack_quality_pr_scope_contract_ok\n'
  return 0
}

if ! run_pr_scope_contracts; then
  rc=1
fi

if [[ "${rc}" -eq 0 ]]; then
  printf 'meta_eval_pack_quality_ok root=%s mode=%s\n' "${root}" "${mode}"
fi
exit "${rc}"
