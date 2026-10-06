#!/usr/bin/env bash
# Contract tests for the hub harness (host-only; no Incus).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0
cli="${ROOT}/harness/goal.sh"
goal="fixture-token-echo"
runs="${ROOT}/runs"

require() {
  local path="$1"
  if [[ ! -e "${ROOT}/${path}" ]]; then
    printf '✗ missing %s\n' "${path}" >&2
    fail=1
  fi
}

require README.md
require PROCESS.md
require goals/_schema.md
require goals/universe/fixture-token-echo.md
require goals/universe/fixture-token-echo-agent.md
require goals/github.com/hermes/README.md
require goals/github.com/function-health/local-pr-review-via-kodus.md
require fixtures/token-echo/sut.sh
require fixtures/token-echo/check.sh
require fixtures/token-echo/p2p-smoke.sh
require fixtures/token-echo/golden.patch
require fixtures/token-echo/mock-solver.sh
require fixtures/token-echo/solver-prompt.md
require fixtures/github.com/function-health/local-pr-review-via-kodus/check.sh
require fixtures/github.com/function-health/local-pr-review-via-kodus/p2p-smoke.sh
require fixtures/github.com/function-health/local-pr-review-via-kodus/expected-findings.json
require harness/goal.sh
require harness/lib/solver.sh
require harness/lib/scope.sh
require harness/lib/select.sh
require templates/goal.md
require templates/result.md
require harness/lib/write_result.py
require harness/hypothesis-to-goal.sh
require docs/hypothesis-playground.md
require docs/evals.md
require skills/hypothesis-playground/SKILL.md
require skills/hypothesis-playground/hypothesis.md
require skills/goal/SKILL.md
require skills/goal-solve/SKILL.md
require Makefile
require AGENTS.md

if ! grep -qE '^eval/list:' "${ROOT}/Makefile"; then
  printf '✗ Makefile must define eval/list\n' >&2
  fail=1
fi
if ! grep -qE '^eval/select:' "${ROOT}/Makefile"; then
  printf '✗ Makefile must define eval/select\n' >&2
  fail=1
fi
if ! grep -qE 'list\|select|cmd_list|cmd_select' "${cli}"; then
  printf '✗ goal.sh must expose list/select commands\n' >&2
  fail=1
fi

if [[ ! -x "${cli}" ]]; then
  printf '✗ harness/goal.sh must be executable\n' >&2
  fail=1
fi
if [[ ! -x "${ROOT}/fixtures/token-echo/mock-solver.sh" ]]; then
  printf '✗ mock-solver.sh must be executable\n' >&2
  fail=1
fi

if ! grep -q 'HERMES_EVAL_REPO_ROOT' "${cli}"; then
  printf '✗ goal.sh must export HERMES_EVAL_REPO_ROOT for capability judges\n' >&2
  fail=1
fi
if ! grep -qE 'EVALS_ROOT|HERMES_EVALS_ROOT|resolve_evals_dir' "${cli}"; then
  printf '✗ goal.sh must resolve EVALS_ROOT / HERMES_EVALS_ROOT\n' >&2
  fail=1
fi

if ! grep -qE 'github.com/<slug>|github.com/<org>' "${ROOT}/README.md"; then
  printf '✗ README.md must document github.com/<org>/<repo> mirror layout\n' >&2
  fail=1
fi
if ! grep -qE 'EVALS_ROOT|this evals|sync/subtree' "${ROOT}/README.md"; then
  printf '✗ README.md must document EVALS_ROOT / evals git tree as goals home\n' >&2
  fail=1
fi
if grep -qE '~/.hermes/evals' "${ROOT}/README.md"; then
  printf '✗ README.md must not document ~/.hermes/evals as SoT\n' >&2
  fail=1
fi
if grep -qE '~/.hermes/evals' "${cli}"; then
  printf '✗ goal.sh must not default to ~/.hermes/evals\n' >&2
  fail=1
fi

if ! grep -q 'runs/' "${ROOT}/.gitignore"; then
  printf '✗ .gitignore must ignore runs/\n' >&2
  fail=1
fi

for target in eval/parse eval/assert-red eval/run eval/verify eval/solve eval/ab eval/report; do
  if ! grep -Eq "^${target}:" "${ROOT}/Makefile"; then
    printf '✗ Makefile missing %s\n' "${target}" >&2
    fail=1
  fi
done

if ! grep -q 'make eval/assert-red' <<<"$(make -C "${ROOT}" help)"; then
  printf '✗ make help must list eval/assert-red\n' >&2
  fail=1
fi
if ! grep -q 'make eval/solve' <<<"$(make -C "${ROOT}" help)"; then
  printf '✗ make help must list eval/solve\n' >&2
  fail=1
fi
if ! grep -q 'make eval/ab' <<<"$(make -C "${ROOT}" help)"; then
  printf '✗ make help must list eval/ab\n' >&2
  fail=1
fi

if grep -Eq 'incus|ensure_incus|guest_as_user|INSTANCE_NAME' "${cli}"; then
  printf '✗ harness/goal.sh must not depend on Incus/guest helpers\n' >&2
  fail=1
fi
if grep -Eq 'incus|ensure_incus|guest_as_user|INSTANCE_NAME' "${ROOT}/harness/lib/solver.sh"; then
  printf '✗ harness/lib/solver.sh must not depend on Incus/guest helpers\n' >&2
  fail=1
fi

export HERMES_EVAL_RUNS="${runs}/unit-test-$$"
# Pin SoT to this hub so an alternate tree cannot shadow CI.
export HERMES_EVALS_ROOT="${ROOT}"
export EVALS_ROOT="${ROOT}"
mkdir -p "${HERMES_EVAL_RUNS}"
cleanup() { rm -rf "${HERMES_EVAL_RUNS}" "${HERMES_EVAL_RUNS}-alt"; }
trap cleanup EXIT

alt_sot="${HERMES_EVAL_RUNS}-alt"
mkdir -p "${alt_sot}/goals" "${alt_sot}/fixtures"
cp -R "${ROOT}/goals/." "${alt_sot}/goals/"
cp -R "${ROOT}/fixtures/." "${alt_sot}/fixtures/"
alt_parse="$(HERMES_EVALS_ROOT="${alt_sot}" bash "${cli}" parse "${goal}")"
if ! printf '%s\n' "${alt_parse}" | grep -q "goal_id=${goal}"; then
  printf '✗ parse under HERMES_EVALS_ROOT must find %s\n' "${goal}" >&2
  fail=1
fi
if ! HERMES_EVALS_ROOT="${alt_sot}" bash "${cli}" assert-red "${goal}" >/dev/null; then
  printf '✗ assert-red under HERMES_EVALS_ROOT must succeed\n' >&2
  fail=1
fi

parse_out="$(bash "${cli}" parse "${goal}")"
if ! printf '%s\n' "${parse_out}" | grep -q "goal_id=${goal}"; then
  printf '✗ parse must print goal_id=%s\n' "${goal}" >&2
  fail=1
fi

if ! bash "${cli}" assert-red "${goal}" >/dev/null; then
  printf '✗ assert-red must succeed (F2P red on baseline)\n' >&2
  fail=1
fi

if bash "${cli}" run "${goal}" >/dev/null 2>&1; then
  printf '✗ run on baseline must fail F2P\n' >&2
  fail=1
fi

if ! bash "${cli}" verify "${goal}" >/dev/null; then
  printf '✗ verify must succeed after golden.patch\n' >&2
  fail=1
fi

report_out="$(bash "${cli}" report "${goal}")"
if ! printf '%s\n' "${report_out}" | grep -q '"verdict": "pass"'; then
  printf '✗ report must show a pass verdict after verify\n' >&2
  fail=1
fi
if ! printf '%s\n' "${report_out}" | grep -q '# Result'; then
  printf '✗ report must include the result template\n' >&2
  fail=1
fi

agent_goal="fixture-token-echo-agent"
if ! bash "${cli}" assert-red "${agent_goal}" >/dev/null; then
  printf '✗ assert-red must succeed for %s\n' "${agent_goal}" >&2
  fail=1
fi
if ! bash "${cli}" solve "${agent_goal}" >/dev/null; then
  printf '✗ solve with mock-solver must pass for %s\n' "${agent_goal}" >&2
  fail=1
fi
agent_report="$(bash "${cli}" report "${agent_goal}")"
if ! printf '%s\n' "${agent_report}" | grep -q '"command": "solve"'; then
  printf '✗ agent report must be a solve manifest\n' >&2
  fail=1
fi
if ! printf '%s\n' "${agent_report}" | grep -q '"verdict": "pass"'; then
  printf '✗ agent solve report must show pass\n' >&2
  fail=1
fi

fh_goal="github.com/function-health/local-pr-review-via-kodus"
fh_id="function-health-local-pr-review-via-kodus"
parse_fh="$(bash "${cli}" parse "${fh_goal}")"
if ! printf '%s\n' "${parse_fh}" | grep -q "goal_id=${fh_id}"; then
  printf '✗ parse must print goal_id=%s for %s\n' "${fh_id}" "${fh_goal}" >&2
  fail=1
fi
if ! bash "${cli}" assert-red "${fh_goal}" >/dev/null; then
  printf '✗ assert-red must succeed for %s (deliverables absent)\n' "${fh_goal}" >&2
  fail=1
fi
fh_ws="$(mktemp -d "${TMPDIR:-/tmp}/evals-fh-p2p.XXXXXX")"
tar -C "${ROOT}/fixtures/github.com/function-health/local-pr-review-via-kodus" -cf - . \
  | tar -C "${fh_ws}" -xf -
chmod +x "${fh_ws}"/*.sh
if ! (cd "${fh_ws}" && ./p2p-smoke.sh >/dev/null); then
  printf '✗ FH p2p-smoke must pass on baseline fixture\n' >&2
  fail=1
fi
rm -rf "${fh_ws}"

if bash "${ROOT}/fixtures/token-echo/check.sh" >/dev/null 2>&1; then
  printf '✗ committed sut.sh must remain broken (F2P baseline)\n' >&2
  fail=1
fi

mini_goal="github.com/hermes/hermes/20260918-playground-mini-svc"
graft_goal="github.com/hermes/hermes/20260918-graft-mini-svc-ab"
mini_fix="${ROOT}/fixtures/github.com/hermes/hermes/20260918-playground-mini-svc"
if ! bash "${cli}" assert-red "${mini_goal}" >/dev/null; then
  printf '✗ assert-red must succeed for playground mini-svc\n' >&2
  fail=1
fi
if ! bash "${cli}" verify "${mini_goal}" >/dev/null; then
  printf '✗ verify must succeed for playground mini-svc\n' >&2
  fail=1
fi
if ! bash "${cli}" ab "${mini_goal}" >/dev/null; then
  printf '✗ eval/ab mock arms must pass for playground mini-svc\n' >&2
  fail=1
fi
mini_report="$(bash "${cli}" report "${mini_goal}")"
if ! printf '%s\n' "${mini_report}" | grep -q '"command": "ab"'; then
  printf '✗ mini-svc report must be an ab manifest\n' >&2
  fail=1
fi
if ! printf '%s\n' "${mini_report}" | grep -q '"adoption": "inconclusive"'; then
  printf '✗ mock ab must stay adoption=inconclusive\n' >&2
  fail=1
fi
if ! bash "${cli}" ab "${graft_goal}" >/dev/null; then
  printf '✗ graft mock N=3 ab must pass\n' >&2
  fail=1
fi
graft_report="$(bash "${cli}" report "${graft_goal}")"
if ! printf '%s\n' "${graft_report}" | grep -q '"verdict": "pass"'; then
  printf '✗ graft mock ab report must pass\n' >&2
  fail=1
fi

bad_sot="$(mktemp -d "${TMPDIR:-/tmp}/evals-bad-pin.XXXXXX")"
mkdir -p "${bad_sot}/goals/github.com/hermes/hermes"
sed 's/model_pin: free-medium/model_pin: gpt-5/' \
  "${ROOT}/goals/github.com/hermes/hermes/20260918-playground-mini-svc.md" \
  >"${bad_sot}/goals/github.com/hermes/hermes/20260918-playground-mini-svc.md"
if EVALS_ROOT="${bad_sot}" HERMES_EVALS_ROOT="${bad_sot}" bash "${cli}" ab "${mini_goal}" >/dev/null 2>&1; then
  printf '✗ ab must refuse a paid model_pin\n' >&2
  fail=1
fi
rm -rf "${bad_sot}"

hyp_sot="$(mktemp -d "${TMPDIR:-/tmp}/evals-hyp.XXXXXX")"
if ! EVALS_ROOT="${hyp_sot}" HERMES_EVALS_ROOT="${hyp_sot}" bash "${ROOT}/harness/hypothesis-to-goal.sh" \
  --assert-red \
  "${ROOT}/skills/hypothesis-playground/hypothesis.md" >/dev/null; then
  printf '✗ hypothesis-to-goal --assert-red must certify the example\n' >&2
  fail=1
fi
if [[ ! -f "${hyp_sot}/goals/github.com/hermes/hermes/20260918-playground-hypothesis-example.md" ]]; then
  printf '✗ hypothesis converter must write the dated goal\n' >&2
  fail=1
fi
hyp_goal="${hyp_sot}/goals/github.com/hermes/hermes/20260918-playground-hypothesis-example.md"
for section in Decision 'User outcome' Scope 'Success criteria' Dataset Grading 'Acceptance gates' Execution Limitations; do
  if ! grep -q "^# ${section}$" "${hyp_goal}"; then
    printf '✗ converted goal missing section %s\n' "${section}" >&2
    fail=1
  fi
done
rm -rf "${hyp_sot}"

for adapter in .cursor/skills/hypothesis-playground .agents/skills/hypothesis-playground; do
  if [[ ! -L "${ROOT}/${adapter}" ]]; then
    printf '✗ missing skill adapter %s\n' "${adapter}" >&2
    fail=1
  fi
done

if (cd "${mini_fix}" && ./check.sh >/dev/null 2>&1); then
  printf '✗ committed mini-svc must stay F2P-red\n' >&2
  fail=1
fi
if ! (cd "${mini_fix}" && ./p2p-smoke.sh >/dev/null 2>&1); then
  printf '✗ committed mini-svc P2P must stay green\n' >&2
  fail=1
fi

token_tmp="$(mktemp -d)"
python3 -c 'import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); c.execute("CREATE TABLE sessions (id TEXT, input_tokens INT, output_tokens INT)"); c.execute("INSERT INTO sessions VALUES (?,?,?)", ("sess1", 11, 7)); c.commit()' "${token_tmp}/state.db"
printf 'session_id: sess1\n' >"${token_tmp}/transcript.txt"
# shellcheck disable=SC1091
source "${ROOT}/harness/lib/ab.sh"
HERMES_EVAL_STATE_DB="${token_tmp}/state.db" hermes_eval_parse_usage "${token_tmp}/transcript.txt"
if [[ "${HERMES_EVAL_TOKENS_IN}" != "11" || "${HERMES_EVAL_TOKENS_OUT}" != "7" ]]; then
  printf '✗ session_id transcript must yield token counts\n' >&2
  fail=1
fi
rm -rf "${token_tmp}"

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

printf '✓ evals harness\n'
