#!/usr/bin/env bash
# Turn a hypothesis/v1 file into a goal/v1 under the process SoT.
# Usage: evals/harness/hypothesis-to-goal.sh [--assert-red] [--seed] HYPOTHESIS.md
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

harness_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_evals="$(cd "${harness_dir}/.." && pwd)"
if [[ "$(basename "${repo_evals}")" == "evals" ]]; then
  repo_root="$(cd "${repo_evals}/.." && pwd)"
else
  repo_root="${repo_evals}"
fi

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

usage() {
  cat <<'EOF'
Usage: evals/harness/hypothesis-to-goal.sh [--assert-red] [--seed] HYPOTHESIS.md

Writes goals/<goal_rel>.md under EVALS_ROOT / HERMES_EVALS_ROOT (default: this evals tree).
--seed also copies that goal into this hub's goals/ (recipe seed).
--assert-red runs the harness against the new goal (fixture must exist in the hub).
EOF
}

assert_red=0
seed=0
src=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --assert-red) assert_red=1; shift ;;
    --seed) seed=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) die "unknown option: $1" ;;
    *)
      [[ -z "${src}" ]] || die "unexpected extra arg: $1"
      src="$1"
      shift
      ;;
  esac
done

[[ -n "${src}" && -f "${src}" ]] || die "hypothesis file required"
schema="$(frontmatter_get "${src}" schema)"
[[ "${schema}" == "hypothesis/v1" ]] || die "schema must be hypothesis/v1 (got '${schema}')"

id="$(frontmatter_get "${src}" id)"
goal_rel="$(frontmatter_get "${src}" goal_rel)"
title="$(frontmatter_get "${src}" title)"
fixture="$(frontmatter_get "${src}" fixture_dir)"
f2p="$(frontmatter_get "${src}" f2p_check)"
p2p="$(frontmatter_get "${src}" p2p_check)"
golden="$(frontmatter_get "${src}" golden_patch)"
prompt="$(frontmatter_get "${src}" solver_prompt)"
solver_bin="$(frontmatter_get "${src}" solver_bin)"
control_bin="$(frontmatter_get "${src}" control_solver_bin)"
treatment_bin="$(frontmatter_get "${src}" treatment_solver_bin)"
control_overlay="$(frontmatter_get "${src}" control_overlay)"
treatment_overlay="$(frontmatter_get "${src}" treatment_overlay)"
trials="$(frontmatter_get "${src}" trials)"
model_pin="$(frontmatter_get "${src}" model_pin)"
max_wall="$(frontmatter_get "${src}" max_wall_seconds)"
max_wall_ratio="$(frontmatter_get "${src}" max_wall_ratio)"
max_token_ratio="$(frontmatter_get "${src}" max_token_ratio)"

[[ -n "${id}" ]] || die "missing id"
printf '%s\n' "${id}" | grep -Eq '^[0-9]{8}-[A-Za-z0-9-]+$' \
  || die "id must be YYYYMMDD-kebab with no slashes"
[[ -n "${goal_rel}" ]] || die "missing goal_rel"
case "${goal_rel}" in
  *..*) die "goal_rel must not contain .." ;;
  github.com/*) ;;
  *) die "goal_rel must start with github.com/" ;;
esac
[[ -n "${fixture}" && -n "${f2p}" && -n "${p2p}" && -n "${golden}" ]] \
  || die "missing fixture_dir, f2p_check, p2p_check, or golden_patch"
[[ -n "${prompt}" && -n "${control_overlay}" && -n "${treatment_overlay}" ]] \
  || die "missing solver_prompt or overlays"
[[ -n "${solver_bin}" || ( -n "${control_bin}" && -n "${treatment_bin}" ) ]] \
  || die "missing solver_bin or both arm solver bins"
if [[ -z "${control_bin}" ]]; then
  control_bin="${solver_bin}"
fi
if [[ -z "${treatment_bin}" ]]; then
  treatment_bin="${solver_bin}"
fi
if [[ -z "${solver_bin}" ]]; then
  solver_bin="${control_bin}"
fi
if [[ -z "${trials}" ]]; then
  trials=3
fi
if [[ -z "${model_pin}" ]]; then
  model_pin="free-medium"
fi
if [[ -z "${max_wall}" ]]; then
  max_wall=180
fi
if [[ -z "${max_wall_ratio}" ]]; then
  max_wall_ratio="1.2"
fi
if [[ -z "${max_token_ratio}" ]]; then
  max_token_ratio="1.2"
fi
if [[ -z "${title}" ]]; then
  title="${id}"
fi

sot="${EVALS_ROOT:-${HERMES_EVALS_ROOT:-}}"
if [[ -z "${sot}" ]]; then
  sot="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
out="${sot}/goals/${goal_rel}.md"
mkdir -p "$(dirname "${out}")"

body_tmp="$(mktemp)"
awk '
  BEGIN { in_fm=0; done=0 }
  /^---[[:space:]]*$/ {
    if (done) { print; next }
    if (in_fm == 0) { in_fm=1; next }
    done=1
    next
  }
  done { print }
' "${src}" >"${body_tmp}"

{
  cat <<EOF
---
schema: goal/v1
id: ${id}
title: ${title}
fixture_dir: ${fixture}
f2p_check: ${f2p}
p2p_check: ${p2p}
golden_patch: ${golden}
solver: agent
solver_bin: ${solver_bin}
solver_prompt: ${prompt}
max_wall_seconds: ${max_wall}
trials: ${trials}
model_pin: ${model_pin}
max_wall_ratio: ${max_wall_ratio}
max_token_ratio: ${max_token_ratio}
control_overlay: ${control_overlay}
treatment_overlay: ${treatment_overlay}
control_solver_bin: ${control_bin}
treatment_solver_bin: ${treatment_bin}
---

# Decision

EOF
  if grep -q '^# Decision' "${body_tmp}"; then
    awk 'BEGIN { on=0 } /^# Decision/ { on=1; next } /^# / { if (on) exit } on { print }' "${body_tmp}"
  else
    cat "${body_tmp}"
  fi
  cat <<EOF

# User outcome

The person using the system still gets a correct result when the treatment is on.

# Scope

Covered: the fixture for this goal, ${trials} tries, model \`${model_pin}\`. Not covered: anything outside that fixture.

# Success criteria

| Criterion | What we look at |
| --- | --- |
| The change works | \`${f2p}\` goes from fail to pass |
| Nothing else breaks | \`${p2p}\` stays passing |
| Speed | Clock time, Graft at most ${max_wall_ratio} times the other side |
| Tokens | Printed token counts, Graft at most ${max_token_ratio} times the other side |

# Dataset

The fixture at \`${fixture}\`. Same case each try. No held-out cases.

# Grading

Program checks grade the fix. A clock grades time. The run log grades tokens only when it prints counts. No second model grades the writing.

# Acceptance gates

| Question | Pass | Fail |
| --- | --- | --- |
| Did the fix work? | Each side passes at least 2 of 3 tries. The treatment passes at least as often. | Either side passes only once, or the treatment passes less often. |
| Was the treatment slower? | At most ${max_wall_ratio} times as long. | Longer than that. |
| Did the treatment use more tokens? | If counted, at most ${max_token_ratio} times as many. | If counted, more than that. |

# Execution

Control \`${control_overlay}\` versus treatment \`${treatment_overlay}\`. ${trials} tries. Each try stops after ${max_wall} seconds. Failed tries are not repeated.

# Limitations

A pass does not install the treatment. A mock solver cannot support an install decision. Missing token counts leave cost unproven.
EOF
  printf '\n'
} >"${out}"
rm -f "${body_tmp}"

if [[ "${seed}" -eq 1 ]]; then
  if [[ "$(basename "${repo_evals}")" == "evals" && -d "${repo_root}/evals" ]]; then
    seed_out="${repo_root}/evals/goals/${goal_rel}.md"
  else
    seed_out="${repo_evals}/goals/${goal_rel}.md"
  fi
  mkdir -p "$(dirname "${seed_out}")"
  cp "${out}" "${seed_out}"
  printf 'seed=%s\n' "${seed_out}"
fi

printf 'goal=%s\n' "${out}"
printf 'GOAL=%s\n' "${goal_rel}"

if [[ "${assert_red}" -eq 1 ]]; then
  EVALS_ROOT="${sot}" HERMES_EVALS_ROOT="${sot}" bash "${harness_dir}/goal.sh" assert-red "${goal_rel}"
fi
