# A/B compare helpers for evals/harness (sourced by goal.sh).
# Bash 3.2-safe: no associative arrays. Trial rows are TSV.

# Args: overlay dir (may be empty). Copies files onto workspace.
hermes_eval_apply_overlay() {
  local ws="$1" overlay="$2" any
  [[ -n "${overlay}" && -d "${overlay}" ]] || return 0
  any="$(find "${overlay}" -mindepth 1 -print 2>/dev/null | head -n 1 || true)"
  [[ -n "${any}" ]] || return 0
  tar -C "${overlay}" -cf - . | tar -C "${ws}" -xf -
}

# Read solver transcript. Sets HERMES_EVAL_TOKENS_IN/OUT and WALL_COST_USD (empty if absent).
hermes_eval_parse_usage() {
  local transcript="$1" line tin="" tout="" cost=""
  HERMES_EVAL_TOKENS_IN=""
  HERMES_EVAL_TOKENS_OUT=""
  HERMES_EVAL_WALL_COST_USD=""
  [[ -f "${transcript}" ]] || return 0

  line="$(grep -E '^tokens_in=[0-9]+$' "${transcript}" | tail -n 1 || true)"
  tin="${line#tokens_in=}"
  line="$(grep -E '^tokens_out=[0-9]+$' "${transcript}" | tail -n 1 || true)"
  tout="${line#tokens_out=}"
  line="$(grep -E '^wall_cost_usd=[0-9.]+$' "${transcript}" | tail -n 1 || true)"
  cost="${line#wall_cost_usd=}"

  if [[ -z "${tin}" ]]; then
    line="$(grep -Eo '"input_tokens"[[:space:]]*:[[:space:]]*[0-9]+' "${transcript}" | tail -n 1 || true)"
    tin="$(printf '%s\n' "${line}" | grep -Eo '[0-9]+$' || true)"
  fi
  if [[ -z "${tin}" ]]; then
    line="$(grep -Eo '"prompt_tokens"[[:space:]]*:[[:space:]]*[0-9]+' "${transcript}" | tail -n 1 || true)"
    tin="$(printf '%s\n' "${line}" | grep -Eo '[0-9]+$' || true)"
  fi
  if [[ -z "${tout}" ]]; then
    line="$(grep -Eo '"output_tokens"[[:space:]]*:[[:space:]]*[0-9]+' "${transcript}" | tail -n 1 || true)"
    tout="$(printf '%s\n' "${line}" | grep -Eo '[0-9]+$' || true)"
  fi
  if [[ -z "${tout}" ]]; then
    line="$(grep -Eo '"completion_tokens"[[:space:]]*:[[:space:]]*[0-9]+' "${transcript}" | tail -n 1 || true)"
    tout="$(printf '%s\n' "${line}" | grep -Eo '[0-9]+$' || true)"
  fi

  # hermes chat -Q prints session_id but not token counts. The session row
  # stores the agent-turn totals (not the later title-generation call).
  if [[ -z "${tin}" || -z "${tout}" ]]; then
    local sid db counted
    sid="$(grep -E '^session_id: [A-Za-z0-9_]+$' "${transcript}" | tail -n 1 || true)"
    sid="${sid#session_id: }"
    db="${HERMES_EVAL_STATE_DB:-${HOME}/.hermes/state.db}"
    if [[ -n "${sid}" && -f "${db}" ]]; then
      counted="$(python3 -c '
import sqlite3, sys
db, sid = sys.argv[1], sys.argv[2]
row = sqlite3.connect(db).execute(
    "SELECT input_tokens, output_tokens FROM sessions WHERE id = ?",
    (sid,),
).fetchone()
if row and row[0] is not None and row[1] is not None:
    print("%d %d" % (int(row[0]), int(row[1])))
' "${db}" "${sid}" 2>/dev/null || true)"
      if [[ -n "${counted}" ]]; then
        tin="${counted%% *}"
        tout="${counted#* }"
      fi
    fi
  fi

  HERMES_EVAL_TOKENS_IN="${tin}"
  HERMES_EVAL_TOKENS_OUT="${tout}"
  HERMES_EVAL_WALL_COST_USD="${cost}"
}

# Monotonic-ish clock in nanoseconds (GNU date) or seconds*1e9 (macOS).
hermes_eval_now_ns() {
  local raw
  raw="$(date +%s%N 2>/dev/null || true)"
  if printf '%s' "${raw}" | grep -Eq '^[0-9]{16,}$'; then
    printf '%s\n' "${raw}"
    return 0
  fi
  printf '%s000000000\n' "$(date +%s)"
}

# Args: trials.tsv compare.json goal_id trials model_pin max_wall_ratio max_token_ratio
#        control_solver treatment_solver
# Sets HERMES_EVAL_AB_VERDICT, HERMES_EVAL_AB_EFFICIENCY, HERMES_EVAL_AB_ADOPTION, HERMES_EVAL_AB_REASON
hermes_eval_write_compare() {
  local tsv="$1" out="$2" goal_id="$3" trials="$4" model_pin="$5"
  local max_wall="$6" max_token="$7" control_solver="$8" treatment_solver="$9"
  [[ -f "${tsv}" ]] || die "missing trial rows: ${tsv}"
  awk -F '\t' \
    -v goal_id="${goal_id}" \
    -v trials="${trials}" \
    -v model_pin="${model_pin}" \
    -v max_wall="${max_wall}" \
    -v max_token="${max_token}" \
    -v control_solver="${control_solver}" \
    -v treatment_solver="${treatment_solver}" \
    -v out="${out}" '
    function sort_insert(n, arr,   i, j, key) {
      for (i = 2; i <= n; i++) {
        key = arr[i]
        j = i - 1
        while (j >= 1 && arr[j] > key) {
          arr[j + 1] = arr[j]
          j--
        }
        arr[j + 1] = key
      }
    }
    function median(n, arr,   mid) {
      if (n <= 0) return 0
      sort_insert(n, arr)
      if (n % 2 == 1) return arr[(n + 1) / 2]
      mid = n / 2
      return (arr[mid] + arr[mid + 1]) / 2
    }
    function ratio(num, den) {
      if (den <= 0) {
        if (num <= 0) return 1
        return 999
      }
      return num / den
    }
    function json_escape(s) {
      gsub(/\\/, "\\\\", s)
      gsub(/"/, "\\\"", s)
      return s
    }
    {
      arm = $1
      ok = $2 + 0
      wall = $3 + 0
      tin = $4
      tout = $5
      if (arm == "control") {
        cn++
        cok += ok
        cwall[cn] = wall
        if (tin ~ /^[0-9]+$/ && tout ~ /^[0-9]+$/) {
          ctok_n++
          ctok[ctok_n] = tin + tout
        }
      } else if (arm == "treatment") {
        tn++
        tok += ok
        twall[tn] = wall
        if (tin ~ /^[0-9]+$/ && tout ~ /^[0-9]+$/) {
          ttok_n++
          ttok[ttok_n] = tin + tout
        }
      }
    }
    END {
      if (cn < 1 || tn < 1) {
        print "error: compare needs control and treatment rows" > "/dev/stderr"
        exit 2
      }
      c_rate = cok / cn
      t_rate = tok / tn
      c_med_w = median(cn, cwall)
      t_med_w = median(tn, twall)
      w_ratio = ratio(t_med_w, c_med_w)
      tokens = "unparsed"
      c_med_t = ""
      t_med_t = ""
      t_ratio = ""
      if (ctok_n == cn && ttok_n == tn) {
        tokens = "parsed"
        c_med_t = median(ctok_n, ctok)
        t_med_t = median(ttok_n, ttok)
        t_ratio = ratio(t_med_t + 0, c_med_t + 0)
      }
      quality = (c_rate >= (2 / 3) && t_rate >= (2 / 3) && tok >= cok)
      verdict = "pass"
      reason = "non_degrade"
      if (!quality) {
        verdict = "fail"
        reason = "quality"
      } else if ((w_ratio + 0) > (max_wall + 0)) {
        verdict = "fail"
        reason = "speed_degrade"
      } else if (tokens == "parsed" && (t_ratio + 0) > (max_token + 0)) {
        verdict = "fail"
        reason = "token_degrade"
      }
      efficiency = "non_degrade"
      if (verdict == "pass") {
        wall_better = (w_ratio + 0) <= 0.8
        token_better = (tokens == "parsed" && (t_ratio + 0) <= 0.8)
        if (wall_better && token_better) efficiency = "improves"
        else if (wall_better) efficiency = "wall_improves"
        reason = efficiency
      } else {
        efficiency = "degrades"
      }
      mock = (control_solver ~ /\.sh$/ || treatment_solver ~ /\.sh$/)
      if (mock) adoption = "inconclusive"
      else if (verdict != "pass") adoption = "reject"
      else adoption = "measured_pass"

      printf "{\n" > out
      printf "  \"goal_id\": \"%s\",\n", json_escape(goal_id) > out
      printf "  \"command\": \"ab\",\n" > out
      printf "  \"verdict\": \"%s\",\n", verdict > out
      printf "  \"efficiency\": \"%s\",\n", efficiency > out
      printf "  \"adoption\": \"%s\",\n", adoption > out
      printf "  \"reason\": \"%s\",\n", reason > out
      printf "  \"trials\": \"%s\",\n", trials > out
      printf "  \"model_pin\": \"%s\",\n", json_escape(model_pin) > out
      printf "  \"control_success\": \"%d\",\n", cok > out
      printf "  \"treatment_success\": \"%d\",\n", tok > out
      printf "  \"control_success_rate\": \"%.3f\",\n", c_rate > out
      printf "  \"treatment_success_rate\": \"%.3f\",\n", t_rate > out
      printf "  \"control_median_wall\": \"%.3f\",\n", c_med_w > out
      printf "  \"treatment_median_wall\": \"%.3f\",\n", t_med_w > out
      printf "  \"wall_ratio\": \"%.3f\",\n", w_ratio > out
      printf "  \"max_wall_ratio\": \"%s\",\n", max_wall > out
      if (tokens == "parsed") {
        printf "  \"control_median_tokens\": \"%.0f\",\n", c_med_t > out
        printf "  \"treatment_median_tokens\": \"%.0f\",\n", t_med_t > out
        printf "  \"token_ratio\": \"%.3f\",\n", t_ratio > out
      } else {
        printf "  \"control_median_tokens\": \"\",\n" > out
        printf "  \"treatment_median_tokens\": \"\",\n" > out
        printf "  \"token_ratio\": \"\",\n" > out
      }
      printf "  \"max_token_ratio\": \"%s\",\n", max_token > out
      printf "  \"tokens\": \"%s\"\n", tokens > out
      printf "}\n" > out
      printf "%s %s %s %s\n", verdict, efficiency, adoption, reason
    }
  ' "${tsv}" > "${out}.status"
  # awk writes compare.json itself; status line is the last printf to stdout.
  # The function redirected the JSON to `out` and the summary to stdout, which we captured.
  local status verdict efficiency adoption reason
  status="$(cat "${out}.status")"
  rm -f "${out}.status"
  [[ -f "${out}" ]] || die "compare.json was not written"
  # shellcheck disable=SC2086
  set -- ${status}
  verdict="${1:-}"
  efficiency="${2:-}"
  adoption="${3:-}"
  reason="${4:-}"
  [[ -n "${verdict}" ]] || die "compare status empty"
  HERMES_EVAL_AB_VERDICT="${verdict}"
  HERMES_EVAL_AB_EFFICIENCY="${efficiency}"
  HERMES_EVAL_AB_ADOPTION="${adoption}"
  HERMES_EVAL_AB_REASON="${reason}"
}
