# Agent solver helpers for evals/harness (sourced by goal.sh).
# No Incus; no provider API keys — only PATH CLIs or script paths.

# Resolve solver binary. Args: solver_bin value from frontmatter.
# Prints absolute path to executable. Honors HERMES_EVAL_SOLVER_BIN.
hermes_eval_resolve_solver_bin() {
  local name="${1:-}"
  local override="${HERMES_EVAL_SOLVER_BIN:-}"
  local candidate

  if [[ -n "${override}" ]]; then
    if [[ -x "${override}" ]]; then
      printf '%s\n' "${override}"
      return 0
    fi
    if command -v "${override}" >/dev/null 2>&1; then
      command -v "${override}"
      return 0
    fi
    die "HERMES_EVAL_SOLVER_BIN not executable: ${override}"
  fi

  [[ -n "${name}" ]] || die "solver_bin is empty"

  if [[ "${name}" == /* ]]; then
    [[ -x "${name}" ]] || die "solver_bin not executable: ${name}"
    printf '%s\n' "${name}"
    return 0
  fi

  if [[ "${name}" == */* || "${name}" == *.sh ]]; then
    candidate="${repo_root}/${name}"
    [[ -x "${candidate}" ]] || die "solver_bin not executable: ${candidate}"
    printf '%s\n' "${candidate}"
    return 0
  fi

  case "${name}" in
    claude|cursor-agent|codex|hermes) ;;
    *)
      die "unknown solver_bin '${name}' (want claude|cursor-agent|codex|hermes or a .sh path)"
      ;;
  esac

  if command -v "${name}" >/dev/null 2>&1; then
    command -v "${name}"
    return 0
  fi
  die "solver_bin '${name}' not found on PATH"
}

# Run solver in workspace.
# Sets HERMES_EVAL_SOLVER_EXIT, HERMES_EVAL_SOLVER_WALL (seconds, 3 decimals when
# the clock supports it), and token fields via hermes_eval_parse_usage when sourced.
# Args: bin, prompt_file, workspace, transcript, max_wall_seconds
hermes_eval_run_solver() {
  local bin="$1"
  local prompt_file="$2"
  local ws="$3"
  local transcript="$4"
  local max_wall="${5:-300}"
  local base prompt_text status=0 elapsed=0
  local start end timeout_bin=""
  local -a cmd

  HERMES_EVAL_TOKENS_IN=""
  HERMES_EVAL_TOKENS_OUT=""
  HERMES_EVAL_WALL_COST_USD=""

  [[ -f "${prompt_file}" ]] || die "solver_prompt missing: ${prompt_file}"
  [[ -d "${ws}" ]] || die "solver workspace missing: ${ws}"
  mkdir -p "$(dirname -- "${transcript}")"

  prompt_text="$(cat "${prompt_file}")"
  base="$(basename -- "${bin}")"

  if command -v timeout >/dev/null 2>&1; then
    timeout_bin="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    timeout_bin="gtimeout"
  fi

  case "${base}" in
    claude)
      cmd=("${bin}" -p "${prompt_text}" --permission-mode bypassPermissions)
      ;;
    cursor-agent)
      cmd=("${bin}" -p "${prompt_text}" --force)
      ;;
    codex)
      cmd=("${bin}" exec --full-auto "${prompt_text}")
      ;;
    hermes)
      cmd=("${bin}" chat --oneshot -Q --query-file "${prompt_file}" --yolo --max-turns 12)
      if [[ -n "${HERMES_EVAL_MODEL_PIN:-}" ]]; then
        cmd+=(-m "${HERMES_EVAL_MODEL_PIN}")
      fi
      if [[ -n "${HERMES_EVAL_PROVIDER:-}" ]]; then
        cmd+=(--provider "${HERMES_EVAL_PROVIDER}")
      fi
      ;;
    *)
      cmd=("${bin}" "${prompt_file}")
      ;;
  esac

  if declare -F hermes_eval_now_ns >/dev/null 2>&1; then
    start="$(hermes_eval_now_ns)"
  else
    start="$(date +%s)000000000"
  fi
  set +e
  (
    cd "${ws}"
    if [[ -n "${HERMES_EVAL_MODEL_PIN:-}" ]]; then
      export HERMES_EVAL_MODEL_PIN
    fi
    if [[ -n "${timeout_bin}" ]]; then
      "${timeout_bin}" "${max_wall}" "${cmd[@]}"
    else
      "${cmd[@]}"
    fi
  ) >"${transcript}" 2>&1
  status=$?
  set -e

  if declare -F hermes_eval_now_ns >/dev/null 2>&1; then
    end="$(hermes_eval_now_ns)"
  else
    end="$(date +%s)000000000"
  fi
  elapsed="$(awk -v s="${start}" -v e="${end}" 'BEGIN { printf "%.3f", (e - s) / 1000000000 }')"
  if [[ -z "${timeout_bin}" ]]; then
    if awk -v elapsed="${elapsed}" -v max="${max_wall}" 'BEGIN { exit !(elapsed > max) }'; then
      printf '\nsolver wall exceeded (no timeout binary): %ss > %ss\n' \
        "${elapsed}" "${max_wall}" >>"${transcript}"
      status=124
    fi
  fi

  HERMES_EVAL_SOLVER_EXIT="${status}"
  HERMES_EVAL_SOLVER_WALL="${elapsed}"
  if declare -F hermes_eval_parse_usage >/dev/null 2>&1; then
    hermes_eval_parse_usage "${transcript}"
    if [[ -n "${HERMES_EVAL_TOKENS_IN}" && -n "${HERMES_EVAL_TOKENS_OUT}" ]]; then
      if ! grep -qE '^tokens_in=[0-9]+$' "${transcript}"; then
        printf 'tokens_in=%s\ntokens_out=%s\n' \
          "${HERMES_EVAL_TOKENS_IN}" "${HERMES_EVAL_TOKENS_OUT}" >>"${transcript}"
      fi
    fi
  fi
  return 0
}
