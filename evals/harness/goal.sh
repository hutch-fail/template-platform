#!/usr/bin/env bash
# Hermes goal harness: goal/v1 assert-red / run / verify / solve / report.
# Goals/fixtures/runs live in this evals git tree (hub or product sync/subtree/
# mount). Override with EVALS_ROOT when needed. Host-runnable; no Incus required.
# Usage: evals/harness/goal.sh <parse|assert-red|run|verify|solve|list|select|doctor-scope|doctor-attach|report|help> [GOAL]
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'EOF'
Usage: evals/harness/goal.sh <command> [GOAL]

Commands:
  parse GOAL       Validate goal/v1 frontmatter and print id
  assert-red GOAL  Certify F2P fails on baseline fixture (exit 0 only if red)
  run GOAL         Run public F2P + P2P on a workspace (see --workspace)
  verify GOAL      Apply golden patch in a temp workspace; require F2P+P2P green
  solve GOAL       TB2a: run agent/mock solver then F2P+P2P (requires solver: agent)
  ab GOAL          Paired control/treatment trials; write compare.json
  list [GOAL]      Human-readable applicable goals (id, scope, path)
  select [GOAL]    Machine-readable absolute paths for CI (one per line)
  doctor-scope     Hint/validate product evals/scope.yaml (scoped; full doctor is #2)
  doctor-attach    Fail closed if git-tracked evals paths violate attachment:
  report GOAL      Print the latest run manifest for GOAL (if any)
  help             Show this help

GOAL may be an id (fixture-token-echo) or a path under evals/goals/.
For list/select, GOAL is optional and restricts output to that goal (and
allows scope: active for it).

Environment:
  EVALS_ROOT               Preferred goals/fixtures/runs root (default: this evals tree)
  HERMES_EVALS_ROOT        Alias for EVALS_ROOT (compat)
  HERMES_EVAL_RUNS         Override runs directory (default: <evals_root>/runs)
  HERMES_EVAL_RECIPE_ROOT  Override recipe root for list/select discovery
                           (default: this hub / vendored evals/)
  EVALS_INCLUDE_ACTIVE     Set to 1 to include scope: active goals in list/select
  HERMES_EVAL_SOLVER_BIN   Override solver binary (path or PATH name). For ab, both arms.
  HERMES_EVAL_MODEL_PIN    Override frontmatter model_pin (free-* / dev-auto / hermes-free)
  HERMES_EVAL_PROVIDER     Hermes --provider for live ab/solve (e.g. litellm-hermes)
EOF
}

harness_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_evals="$(cd "${harness_dir}/.." && pwd)"
# Product root when this hub lives at <project>/evals; otherwise the hub itself.
if [[ "$(basename "${repo_evals}")" == "evals" ]]; then
  repo_root="$(cd "${repo_evals}/.." && pwd)"
else
  repo_root="${repo_evals}"
fi

# Resolve goals/fixtures/runs root. Default: this evals git tree (hub or synced).
resolve_evals_dir() {
  local root
  root="${EVALS_ROOT:-${HERMES_EVALS_ROOT:-}}"
  if [[ -n "${root}" && -d "${root}/goals" ]]; then
    printf '%s\n' "${root}"
    return 0
  fi
  printf '%s\n' "$(cd "${repo_evals}" && pwd)"
}

evals_dir="$(resolve_evals_dir)"
runs_root="${HERMES_EVAL_RUNS:-${evals_dir}/runs}"
# shellcheck source=lib/solver.sh
source "${harness_dir}/lib/solver.sh"
# shellcheck source=lib/ab.sh
source "${harness_dir}/lib/ab.sh"
# shellcheck source=lib/scope.sh
source "${harness_dir}/lib/scope.sh"
# shellcheck source=lib/manifest.sh
source "${harness_dir}/lib/manifest.sh"
# shellcheck source=lib/attachment.sh
source "${harness_dir}/lib/attachment.sh"
# shellcheck source=lib/select.sh
source "${harness_dir}/lib/select.sh"
CLEANUP_DIRS=""

cleanup_workspaces() {
  local d
  for d in ${CLEANUP_DIRS}; do
    [[ -n "${d}" ]] || continue
    rm -rf "${d}"
  done
}
trap cleanup_workspaces EXIT

register_cleanup() {
  CLEANUP_DIRS="${CLEANUP_DIRS} $1"
}

goal_path_for() {
  local arg="$1" candidate found id
  if [[ -f "${arg}" ]]; then
    printf '%s\n' "$(cd "$(dirname "${arg}")" && pwd)/$(basename "${arg}")"
    return 0
  fi
  candidate="${evals_dir}/goals/${arg}"
  if [[ -f "${candidate}" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi
  candidate="${evals_dir}/goals/${arg}.md"
  if [[ -f "${candidate}" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi
  # Nested path under goals/ (e.g. universe/fixture-token-echo).
  candidate="${evals_dir}/goals/${arg}.md"
  if [[ -f "${candidate}" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi
  # Find by frontmatter id or basename under goals/ (and recipe fallback).
  _hermes_eval_find_goal_by_id() {
    local search_root="$1" want="$2" f base
    [[ -d "${search_root}/goals" ]] || return 1
    while IFS= read -r -d '' f; do
      base="$(basename "${f}" .md)"
      [[ "${base}" == *-result ]] && continue
      case "${base}" in
        _schema|README) continue ;;
      esac
      if [[ "${base}" == "${want}" ]]; then
        printf '%s\n' "${f}"
        return 0
      fi
      id="$(frontmatter_get "${f}" id 2>/dev/null || true)"
      if [[ "${id}" == "${want}" ]]; then
        printf '%s\n' "${f}"
        return 0
      fi
    done < <(find "${search_root}/goals" -type f -name '*.md' -print0 2>/dev/null)
    return 1
  }
  if found="$(_hermes_eval_find_goal_by_id "${evals_dir}" "${arg}")"; then
    printf '%s\n' "${found}"
    return 0
  fi
  if [[ "${evals_dir}" != "$(cd "${repo_evals}" && pwd)" ]]; then
    candidate="${repo_evals}/goals/${arg}"
    if [[ -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
    candidate="${repo_evals}/goals/${arg}.md"
    if [[ -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
    if found="$(_hermes_eval_find_goal_by_id "${repo_evals}" "${arg}")"; then
      printf '%s\n' "${found}"
      return 0
    fi
  fi
  die "goal not found: ${arg} (tried ${evals_dir}/goals/${arg}[.md] and nested id search)"
}

# Read a simple key: value from YAML frontmatter (first --- … --- block).
frontmatter_get() {
  local file="$1" key="$2"
  awk -v key="${key}" '
    BEGIN { in_fm=0 }
    /^---[[:space:]]*$/ {
      if (in_fm == 0) { in_fm=1; next }
      else exit
    }
    in_fm == 1 && $0 ~ ("^" key ":[[:space:]]*") {
      sub("^[^:]+:[[:space:]]*", "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      gsub(/^["'\'']|["'\'']$/, "")
      print
      exit
    }
  ' "${file}"
}

require_goal_v1() {
  local file="$1" schema id fixture solver bin prompt
  schema="$(frontmatter_get "${file}" schema)"
  id="$(frontmatter_get "${file}" id)"
  fixture="$(frontmatter_get "${file}" fixture_dir)"
  [[ "${schema}" == "goal/v1" ]] || die "${file}: schema must be goal/v1 (got '${schema}')"
  [[ -n "${id}" ]] || die "${file}: missing id"
  [[ -n "${fixture}" ]] || die "${file}: missing fixture_dir"
  if [[ ! -d "${repo_root}/${fixture}" ]]; then
    if [[ "${fixture}" == evals/* && -d "${repo_evals}/${fixture#evals/}" ]]; then
      :
    else
      die "${file}: fixture_dir not found: ${fixture}"
    fi
  fi

  solver="$(frontmatter_get "${file}" solver)"
  [[ -z "${solver}" || "${solver}" == "none" || "${solver}" == "agent" ]] \
    || die "${file}: solver must be none|agent (got '${solver}')"
  if [[ "${solver}" == "agent" ]]; then
    bin="$(frontmatter_get "${file}" solver_bin)"
    prompt="$(frontmatter_get "${file}" solver_prompt)"
    [[ -n "${bin}" ]] || die "${file}: solver: agent requires solver_bin"
    [[ -n "${prompt}" ]] || die "${file}: solver: agent requires solver_prompt"
    if [[ ! -f "${repo_root}/${prompt}" ]]; then
      if [[ "${prompt}" == evals/* && -f "${repo_evals}/${prompt#evals/}" ]]; then
        :
      else
        die "${file}: solver_prompt not found: ${prompt}"
      fi
    fi
  fi

  validate_goal_scope "${file}"
}

fixture_abs() {
  local file="$1" rel candidate
  rel="$(frontmatter_get "${file}" fixture_dir)"
  # Prefer SoT-relative: evals/fixtures/X → ${evals_dir}/fixtures/X
  if [[ "${rel}" == evals/* ]]; then
    candidate="${evals_dir}/${rel#evals/}"
    if [[ -d "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi
  candidate="${evals_dir}/${rel}"
  if [[ -d "${candidate}" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi
  # Repo-tracked fixtures (harness clone / unseeded host).
  candidate="${repo_root}/${rel}"
  if [[ -d "${candidate}" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi
  die "fixture_dir not found: ${rel} (tried under ${evals_dir} and ${repo_root})"
}

copy_fixture_workspace() {
  local src="$1" dest="$2"
  mkdir -p "${dest}"
  tar -C "${src}" -cf - . | tar -C "${dest}" -xf -
  find "${dest}" -type f -name '*.sh' -exec chmod +x {} \;
}

apply_golden_patch() {
  local ws="$1" patch_name="$2"
  local patch="${ws}/${patch_name}"
  [[ -f "${patch}" ]] || die "golden patch missing: ${patch}"
  (cd "${ws}" && patch -p1 --batch --silent < "${patch_name}") \
    || die "failed to apply ${patch_name}"
}

run_check() {
  local ws="$1" script="$2"
  [[ -x "${ws}/${script}" ]] || die "check not executable: ${ws}/${script}"
  (
    cd "${ws}"
    # Preserve an explicit override (e.g. language bars vs a consumer repo).
    export HERMES_EVAL_REPO_ROOT="${HERMES_EVAL_REPO_ROOT:-${repo_root}}"
    "./${script}"
  )
}

new_run_dir() {
  local goal_id="$1" stamp
  stamp="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%S)"
  printf '%s/%s/%s\n' "${runs_root}" "${goal_id}" "${stamp}-$$"
}

write_manifest() {
  local run_dir="$1"
  shift
  mkdir -p "${run_dir}"
  {
    printf '{\n'
    local first=1
    local kv key val
    for kv in "$@"; do
      key="${kv%%=*}"
      val="${kv#*=}"
      if [[ "${first}" -eq 1 ]]; then
        first=0
      else
        printf ',\n'
      fi
      val="${val//\\/\\\\}"
      val="${val//\"/\\\"}"
      printf '  "%s": "%s"' "${key}" "${val}"
    done
    printf '\n}\n'
  } > "${run_dir}/manifest.json"
  python3 "${harness_dir}/lib/write_result.py" \
    "${repo_evals}/templates/result.md" \
    "${run_dir}/manifest.json" \
    "${run_dir}/result.md"
}

cmd_parse() {
  local file id solver
  file="$(goal_path_for "$1")"
  require_goal_v1 "${file}"
  id="$(frontmatter_get "${file}" id)"
  solver="$(frontmatter_get "${file}" solver)"
  [[ -z "${solver}" ]] && solver="none"
  printf 'goal_id=%s\n' "${id}"
  printf 'path=%s\n' "${file}"
  printf 'fixture_dir=%s\n' "$(frontmatter_get "${file}" fixture_dir)"
  printf 'solver=%s\n' "${solver}"
  printf 'scope=%s\n' "${HERMES_EVAL_GOAL_SCOPE}"
}

cmd_assert_red() {
  local file id fixture f2p ws run_dir rc=0
  file="$(goal_path_for "$1")"
  require_goal_v1 "${file}"
  id="$(frontmatter_get "${file}" id)"
  fixture="$(fixture_abs "${file}")"
  f2p="$(frontmatter_get "${file}" f2p_check)"
  [[ -n "${f2p}" ]] || die "missing f2p_check"

  ws="$(mktemp -d "${TMPDIR:-/tmp}/hermes-eval-assert-red.XXXXXX")"
  run_dir="$(new_run_dir "${id}")"
  register_cleanup "${ws}"
  copy_fixture_workspace "${fixture}" "${ws}"

  set +e
  run_check "${ws}" "${f2p}"
  rc=$?
  set -e

  if [[ "${rc}" -eq 0 ]]; then
    write_manifest "${run_dir}" \
      "goal_id=${id}" \
      "command=assert-red" \
      "verdict=reject" \
      "reason=f2p_already_green" \
      "f2p_check=${f2p}" \
      "f2p_exit=0" \
      "wall_cost_usd="
    printf 'assert-red REJECT: F2P already green on baseline (%s)\n' "${f2p}" >&2
    printf 'manifest=%s/manifest.json\n' "${run_dir}"
    exit 1
  fi

  write_manifest "${run_dir}" \
    "goal_id=${id}" \
    "command=assert-red" \
    "verdict=certified_red" \
    "f2p_check=${f2p}" \
    "f2p_exit=${rc}" \
    "wall_cost_usd="
  printf 'assert-red OK: F2P is red on baseline (%s exit %s)\n' "${f2p}" "${rc}"
  printf 'manifest=%s/manifest.json\n' "${run_dir}"
}

cmd_run() {
  local file id fixture f2p p2p ws run_dir f2p_rc=0 p2p_rc=0 workspace=""
  file="$(goal_path_for "$1")"
  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --workspace)
        workspace="${2:-}"
        [[ -n "${workspace}" ]] || die "--workspace needs a path"
        shift 2
        ;;
      *)
        die "unknown run option: $1"
        ;;
    esac
  done

  require_goal_v1 "${file}"
  id="$(frontmatter_get "${file}" id)"
  fixture="$(fixture_abs "${file}")"
  f2p="$(frontmatter_get "${file}" f2p_check)"
  p2p="$(frontmatter_get "${file}" p2p_check)"
  [[ -n "${f2p}" && -n "${p2p}" ]] || die "missing f2p_check or p2p_check"

  run_dir="$(new_run_dir "${id}")"
  if [[ -n "${workspace}" ]]; then
    ws="${workspace}"
    [[ -d "${ws}" ]] || die "workspace not a directory: ${ws}"
  else
    ws="$(mktemp -d "${TMPDIR:-/tmp}/hermes-eval-run.XXXXXX")"
    register_cleanup "${ws}"
    copy_fixture_workspace "${fixture}" "${ws}"
  fi

  set +e
  run_check "${ws}" "${f2p}"
  f2p_rc=$?
  run_check "${ws}" "${p2p}"
  p2p_rc=$?
  set -e

  local verdict="fail"
  if [[ "${f2p_rc}" -eq 0 && "${p2p_rc}" -eq 0 ]]; then
    verdict="pass"
  fi
  write_manifest "${run_dir}" \
    "goal_id=${id}" \
    "command=run" \
    "verdict=${verdict}" \
    "f2p_check=${f2p}" \
    "f2p_exit=${f2p_rc}" \
    "p2p_check=${p2p}" \
    "p2p_exit=${p2p_rc}" \
    "wall_cost_usd="
  printf 'run %s: f2p_exit=%s p2p_exit=%s\n' "${verdict}" "${f2p_rc}" "${p2p_rc}"
  printf 'manifest=%s/manifest.json\n' "${run_dir}"
  [[ "${verdict}" == "pass" ]]
}

cmd_verify() {
  local file id fixture f2p p2p patch_name ws run_dir f2p_rc=0 p2p_rc=0
  file="$(goal_path_for "$1")"
  require_goal_v1 "${file}"
  id="$(frontmatter_get "${file}" id)"
  fixture="$(fixture_abs "${file}")"
  f2p="$(frontmatter_get "${file}" f2p_check)"
  p2p="$(frontmatter_get "${file}" p2p_check)"
  patch_name="$(frontmatter_get "${file}" golden_patch)"
  [[ -n "${f2p}" && -n "${p2p}" && -n "${patch_name}" ]] \
    || die "missing f2p_check, p2p_check, or golden_patch"

  ws="$(mktemp -d "${TMPDIR:-/tmp}/hermes-eval-verify.XXXXXX")"
  run_dir="$(new_run_dir "${id}")"
  register_cleanup "${ws}"
  copy_fixture_workspace "${fixture}" "${ws}"
  apply_golden_patch "${ws}" "${patch_name}"

  set +e
  run_check "${ws}" "${f2p}"
  f2p_rc=$?
  run_check "${ws}" "${p2p}"
  p2p_rc=$?
  set -e

  if [[ "${f2p_rc}" -ne 0 || "${p2p_rc}" -ne 0 ]]; then
    write_manifest "${run_dir}" \
      "goal_id=${id}" \
      "command=verify" \
      "verdict=fail" \
      "f2p_exit=${f2p_rc}" \
      "p2p_exit=${p2p_rc}" \
      "golden_patch=${patch_name}" \
      "wall_cost_usd="
    printf 'verify FAIL: f2p_exit=%s p2p_exit=%s\n' "${f2p_rc}" "${p2p_rc}" >&2
    printf 'manifest=%s/manifest.json\n' "${run_dir}"
    exit 1
  fi

  write_manifest "${run_dir}" \
    "goal_id=${id}" \
    "command=verify" \
    "verdict=pass" \
    "f2p_exit=0" \
    "p2p_exit=0" \
    "golden_patch=${patch_name}" \
    "wall_cost_usd="
  printf 'verify OK: F2P+P2P green after %s\n' "${patch_name}"
  printf 'manifest=%s/manifest.json\n' "${run_dir}"
}

cmd_solve() {
  local file id fixture f2p p2p solver bin_name prompt_rel max_wall
  local bin prompt_abs ws run_dir transcript f2p_rc=0 p2p_rc=0
  local solver_exit=1 wall_seconds=0 verdict="fail"
  local tin="" tout="" cost=""

  file="$(goal_path_for "$1")"
  require_goal_v1 "${file}"
  id="$(frontmatter_get "${file}" id)"
  solver="$(frontmatter_get "${file}" solver)"
  [[ "${solver}" == "agent" ]] || die "solve requires frontmatter solver: agent (got '${solver:-none}')"

  fixture="$(fixture_abs "${file}")"
  f2p="$(frontmatter_get "${file}" f2p_check)"
  p2p="$(frontmatter_get "${file}" p2p_check)"
  bin_name="$(frontmatter_get "${file}" solver_bin)"
  prompt_rel="$(frontmatter_get "${file}" solver_prompt)"
  max_wall="$(frontmatter_get "${file}" max_wall_seconds)"
  [[ -z "${max_wall}" ]] && max_wall=300
  [[ -n "${f2p}" && -n "${p2p}" ]] || die "missing f2p_check or p2p_check"

  bin="$(hermes_eval_resolve_solver_bin "${bin_name}")"
  prompt_abs="${repo_root}/${prompt_rel}"

  run_dir="$(new_run_dir "${id}")"
  ws="${run_dir}/workspace"
  transcript="${run_dir}/transcript.txt"
  mkdir -p "${ws}"
  copy_fixture_workspace "${fixture}" "${ws}"

  HERMES_EVAL_SOLVER_EXIT=1
  HERMES_EVAL_SOLVER_WALL=0
  hermes_eval_run_solver "${bin}" "${prompt_abs}" "${ws}" "${transcript}" "${max_wall}"
  solver_exit="${HERMES_EVAL_SOLVER_EXIT}"
  wall_seconds="${HERMES_EVAL_SOLVER_WALL}"
  tin="${HERMES_EVAL_TOKENS_IN:-}"
  tout="${HERMES_EVAL_TOKENS_OUT:-}"
  cost="${HERMES_EVAL_WALL_COST_USD:-}"

  set +e
  run_check "${ws}" "${f2p}"
  f2p_rc=$?
  run_check "${ws}" "${p2p}"
  p2p_rc=$?
  set -e

  if [[ "${f2p_rc}" -eq 0 && "${p2p_rc}" -eq 0 ]]; then
    verdict="pass"
  fi

  write_manifest "${run_dir}" \
    "goal_id=${id}" \
    "command=solve" \
    "verdict=${verdict}" \
    "solver=agent" \
    "solver_bin=${bin_name}" \
    "solver_exit=${solver_exit}" \
    "wall_seconds=${wall_seconds}" \
    "transcript=transcript.txt" \
    "f2p_check=${f2p}" \
    "f2p_exit=${f2p_rc}" \
    "p2p_check=${p2p}" \
    "p2p_exit=${p2p_rc}" \
    "tokens_in=${tin}" \
    "tokens_out=${tout}" \
    "wall_cost_usd=${cost}"

  printf 'solve %s: solver_exit=%s wall_seconds=%s f2p_exit=%s p2p_exit=%s\n' \
    "${verdict}" "${solver_exit}" "${wall_seconds}" "${f2p_rc}" "${p2p_rc}"
  printf 'manifest=%s/manifest.json\n' "${run_dir}"
  printf 'transcript=%s\n' "${transcript}"
  [[ "${verdict}" == "pass" ]]
}

hermes_eval_allow_model_pin() {
  local pin="$1"
  case "${pin}" in
    ""|free-*|dev-auto|hermes-free) ;;
    *)
      die "model_pin must be empty, free-*, dev-auto, or hermes-free (got '${pin}')"
      ;;
  esac
}

cmd_ab() {
  local file id fixture f2p p2p solver prompt_rel max_wall
  local trials model_pin max_wall_ratio max_token_ratio
  local control_overlay_rel treatment_overlay_rel
  local control_bin_name treatment_bin_name
  local control_overlay treatment_overlay
  local run_dir tsv trial arm ws transcript bin prompt_abs
  local solver_exit wall f2p_rc p2p_rc success tin tout cost
  local effective_control effective_treatment

  file="$(goal_path_for "$1")"
  require_goal_v1 "${file}"
  id="$(frontmatter_get "${file}" id)"
  solver="$(frontmatter_get "${file}" solver)"
  [[ "${solver}" == "agent" ]] || die "ab requires frontmatter solver: agent (got '${solver:-none}')"

  fixture="$(fixture_abs "${file}")"
  f2p="$(frontmatter_get "${file}" f2p_check)"
  p2p="$(frontmatter_get "${file}" p2p_check)"
  prompt_rel="$(frontmatter_get "${file}" solver_prompt)"
  max_wall="$(frontmatter_get "${file}" max_wall_seconds)"
  [[ -z "${max_wall}" ]] && max_wall=180
  trials="$(frontmatter_get "${file}" trials)"
  [[ -z "${trials}" ]] && trials=3
  case "${trials}" in
    ''|*[!0-9]*) die "trials must be a positive integer (got '${trials}')" ;;
  esac
  [[ "${trials}" -ge 1 ]] || die "trials must be >= 1"

  model_pin="${HERMES_EVAL_MODEL_PIN:-$(frontmatter_get "${file}" model_pin)}"
  hermes_eval_allow_model_pin "${model_pin}"
  export HERMES_EVAL_MODEL_PIN="${model_pin}"

  max_wall_ratio="$(frontmatter_get "${file}" max_wall_ratio)"
  [[ -z "${max_wall_ratio}" ]] && max_wall_ratio="1.2"
  max_token_ratio="$(frontmatter_get "${file}" max_token_ratio)"
  [[ -z "${max_token_ratio}" ]] && max_token_ratio="1.2"

  control_overlay_rel="$(frontmatter_get "${file}" control_overlay)"
  treatment_overlay_rel="$(frontmatter_get "${file}" treatment_overlay)"
  [[ -n "${control_overlay_rel}" && -n "${treatment_overlay_rel}" ]] \
    || die "ab requires control_overlay and treatment_overlay"
  [[ -d "${fixture}/${control_overlay_rel}" ]] \
    || die "control_overlay not found: ${control_overlay_rel}"
  [[ -d "${fixture}/${treatment_overlay_rel}" ]] \
    || die "treatment_overlay not found: ${treatment_overlay_rel}"
  control_overlay="${fixture}/${control_overlay_rel}"
  treatment_overlay="${fixture}/${treatment_overlay_rel}"

  control_bin_name="$(frontmatter_get "${file}" control_solver_bin)"
  [[ -z "${control_bin_name}" ]] && control_bin_name="$(frontmatter_get "${file}" solver_bin)"
  treatment_bin_name="$(frontmatter_get "${file}" treatment_solver_bin)"
  [[ -z "${treatment_bin_name}" ]] && treatment_bin_name="$(frontmatter_get "${file}" solver_bin)"
  [[ -n "${control_bin_name}" && -n "${treatment_bin_name}" ]] \
    || die "ab requires solver_bin or per-arm solver bins"
  [[ -n "${f2p}" && -n "${p2p}" && -n "${prompt_rel}" ]] \
    || die "ab requires f2p_check, p2p_check, and solver_prompt"
  prompt_abs="${repo_root}/${prompt_rel}"

  if [[ -n "${HERMES_EVAL_SOLVER_BIN:-}" ]]; then
    effective_control="${HERMES_EVAL_SOLVER_BIN}"
    effective_treatment="${HERMES_EVAL_SOLVER_BIN}"
  else
    effective_control="${control_bin_name}"
    effective_treatment="${treatment_bin_name}"
  fi

  run_dir="$(new_run_dir "${id}")"
  tsv="${run_dir}/trials.tsv"
  mkdir -p "${run_dir}"
  : >"${tsv}"

  trial=1
  while [[ "${trial}" -le "${trials}" ]]; do
    for arm in control treatment; do
      ws="${run_dir}/t${trial}-${arm}/workspace"
      transcript="${run_dir}/t${trial}-${arm}/transcript.txt"
      mkdir -p "${ws}"
      copy_fixture_workspace "${fixture}" "${ws}"
      if [[ "${arm}" == "control" ]]; then
        hermes_eval_apply_overlay "${ws}" "${control_overlay}"
        bin="$(hermes_eval_resolve_solver_bin "${control_bin_name}")"
      else
        hermes_eval_apply_overlay "${ws}" "${treatment_overlay}"
        bin="$(hermes_eval_resolve_solver_bin "${treatment_bin_name}")"
      fi

      HERMES_EVAL_SOLVER_EXIT=1
      HERMES_EVAL_SOLVER_WALL=0
      hermes_eval_run_solver "${bin}" "${prompt_abs}" "${ws}" "${transcript}" "${max_wall}"
      solver_exit="${HERMES_EVAL_SOLVER_EXIT}"
      wall="${HERMES_EVAL_SOLVER_WALL}"
      tin="${HERMES_EVAL_TOKENS_IN:-}"
      tout="${HERMES_EVAL_TOKENS_OUT:-}"
      cost="${HERMES_EVAL_WALL_COST_USD:-}"
      [[ -n "${tin}" ]] || tin="-"
      [[ -n "${tout}" ]] || tout="-"
      [[ -n "${cost}" ]] || cost="-"

      set +e
      run_check "${ws}" "${f2p}"
      f2p_rc=$?
      run_check "${ws}" "${p2p}"
      p2p_rc=$?
      set -e
      if [[ "${f2p_rc}" -eq 0 && "${p2p_rc}" -eq 0 ]]; then
        success=1
      else
        success=0
      fi
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${arm}" "${success}" "${wall}" "${tin}" "${tout}" "${cost}" >>"${tsv}"
      write_manifest "${run_dir}/t${trial}-${arm}" \
        "goal_id=${id}" \
        "command=ab-trial" \
        "arm=${arm}" \
        "trial=${trial}" \
        "solver_exit=${solver_exit}" \
        "wall_seconds=${wall}" \
        "f2p_exit=${f2p_rc}" \
        "p2p_exit=${p2p_rc}" \
        "tokens_in=${tin}" \
        "tokens_out=${tout}" \
        "wall_cost_usd=${cost}"
      printf 'ab trial %s %s: success=%s wall=%s f2p=%s p2p=%s\n' \
        "${trial}" "${arm}" "${success}" "${wall}" "${f2p_rc}" "${p2p_rc}"
    done
    trial=$((trial + 1))
  done

  hermes_eval_write_compare "${tsv}" "${run_dir}/compare.json" "${id}" "${trials}" \
    "${model_pin}" "${max_wall_ratio}" "${max_token_ratio}" \
    "${effective_control}" "${effective_treatment}"

  write_manifest "${run_dir}" \
    "goal_id=${id}" \
    "command=ab" \
    "verdict=${HERMES_EVAL_AB_VERDICT}" \
    "efficiency=${HERMES_EVAL_AB_EFFICIENCY}" \
    "adoption=${HERMES_EVAL_AB_ADOPTION}" \
    "reason=${HERMES_EVAL_AB_REASON}" \
    "trials=${trials}" \
    "model_pin=${model_pin}" \
    "compare=compare.json" \
    "wall_cost_usd="

  printf 'ab %s: efficiency=%s adoption=%s reason=%s\n' \
    "${HERMES_EVAL_AB_VERDICT}" "${HERMES_EVAL_AB_EFFICIENCY}" \
    "${HERMES_EVAL_AB_ADOPTION}" "${HERMES_EVAL_AB_REASON}"
  printf 'manifest=%s/manifest.json\n' "${run_dir}"
  printf 'compare=%s/compare.json\n' "${run_dir}"
  [[ "${HERMES_EVAL_AB_VERDICT}" == "pass" ]]
}

cmd_report() {
  local file id dir latest result
  file="$(goal_path_for "$1")"
  require_goal_v1 "${file}"
  id="$(frontmatter_get "${file}" id)"
  dir="${runs_root}/${id}"
  if [[ ! -d "${dir}" ]]; then
    die "no runs for ${id} under ${dir}"
  fi
  latest=""
  while IFS= read -r -d '' m; do
    latest="${m}"
  done < <(find "${dir}" -mindepth 2 -maxdepth 2 -name manifest.json -print0 | sort -z)
  [[ -n "${latest}" ]] || die "no manifests for ${id}"
  printf 'manifest=%s\n' "${latest}"
  result="${latest%/manifest.json}/result.md"
  if [[ -f "${result}" ]]; then
    printf 'result=%s\n' "${result}"
    cat "${result}"
    printf '\n'
  fi
  cat "${latest}"
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "${cmd}" in
    help|-h|--help) usage ;;
    parse)
      [[ $# -ge 1 ]] || die "parse requires GOAL"
      cmd_parse "$1"
      ;;
    assert-red)
      [[ $# -ge 1 ]] || die "assert-red requires GOAL"
      cmd_assert_red "$1"
      ;;
    run)
      [[ $# -ge 1 ]] || die "run requires GOAL"
      cmd_run "$@"
      ;;
    verify)
      [[ $# -ge 1 ]] || die "verify requires GOAL"
      cmd_verify "$1"
      ;;
    solve)
      [[ $# -ge 1 ]] || die "solve requires GOAL"
      cmd_solve "$1"
      ;;
    ab)
      [[ $# -ge 1 ]] || die "ab requires GOAL"
      cmd_ab "$1"
      ;;
    report)
      [[ $# -ge 1 ]] || die "report requires GOAL"
      cmd_report "$1"
      ;;
    list)
      cmd_list "${1:-}"
      ;;
    select)
      cmd_select "${1:-}"
      ;;
    doctor-scope)
      cmd_doctor_scope
      ;;
    doctor-attach)
      cmd_doctor_attach
      ;;
    *)
      usage >&2
      die "unknown command: ${cmd}"
      ;;
  esac
}

main "$@"
