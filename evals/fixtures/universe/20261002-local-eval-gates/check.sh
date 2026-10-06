#!/usr/bin/env bash
# F2P: consumer pre-push hook + kit local gates (schema parse, CI pack on push).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_scan_root() {
  if [[ -n "${HERMES_EVAL_SCAN_ROOT:-}" && -d "${HERMES_EVAL_SCAN_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_SCAN_ROOT}" && pwd)"
    return 0
  fi
  printf '%s\n' "${here}"
}

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
    if [[ -f "${cand}/harness/goal.sh" && -f "${cand}/scripts/pre-commit-evals.sh" ]]; then
      printf '%s\n' "$(cd "${cand}" && pwd)"
      return 0
    fi
  done
  printf 'error: cannot resolve evals kit (set HERMES_EVAL_KIT)\n' >&2
  return 1
}

root="$(resolve_scan_root)"
cfg="${root}/.pre-commit-config.yaml"
kit="$(resolve_kit)"
fail=0
tmp="$(mktemp -d)"
trap 'rm -rf "'"${tmp}"'"' EXIT

if [[ ! -f "${cfg}" ]]; then
  printf 'error: missing %s\n' "${cfg}" >&2
  exit 1
fi

if ! grep -Fq 'pre-push-evals.sh' "${cfg}"; then
  printf 'error: %s must include a local hook entry running pre-push-evals.sh\n' "${cfg}" >&2
  fail=1
fi

if ! grep -Eq 'default_install_hook_types:.*pre-push' "${cfg}"; then
  printf 'error: %s must list pre-push in default_install_hook_types\n' "${cfg}" >&2
  fail=1
fi

pre_commit_evals="${kit}/scripts/pre-commit-evals.sh"
pre_push_evals="${kit}/scripts/pre-push-evals.sh"
pack_assert="${kit}/tests/unit/assert_pr_has_eval_pack.sh"
goal_sh="${kit}/harness/goal.sh"

if [[ ! -f "${pre_push_evals}" ]]; then
  printf 'error: missing kit script %s\n' "${pre_push_evals}" >&2
  fail=1
fi

if [[ ! -f "${pre_commit_evals}" ]]; then
  printf 'error: missing kit script %s\n' "${pre_commit_evals}" >&2
  fail=1
fi

# Schema gate: pre-commit entry must invoke goal.sh parse (or shared assert that does).
if [[ -f "${pre_commit_evals}" ]] && ! grep -Eq 'goal\.sh[[:space:]]+parse|assert_goals_schema' "${pre_commit_evals}"; then
  printf 'error: %s must parse staged goals (goal.sh parse or assert_goals_schema)\n' \
    "${pre_commit_evals}" >&2
  fail=1
fi

if [[ -f "${pre_push_evals}" ]] && ! grep -Eq 'assert_pr_has_eval_pack|--mode[[:space:]]+ci' "${pre_push_evals}"; then
  printf 'error: %s must run pack gate in ci mode\n' "${pre_push_evals}" >&2
  fail=1
fi

# Behavioral pack modes (require pack assert present).
if [[ -f "${pack_assert}" ]]; then
  mkdir -p "${tmp}/evals/fixtures/github.com/o/r/20261002-x" \
    "${tmp}/evals/goals/github.com/o/r" \
    "${tmp}/scripts/instance"
  printf '#!/bin/bash\nexit 0\n' >"${tmp}/evals/fixtures/github.com/o/r/20261002-x/check.sh"
  chmod +x "${tmp}/evals/fixtures/github.com/o/r/20261002-x/check.sh"
  printf 'print("ok")\n' >"${tmp}/scripts/instance/create.sh"
  cat >"${tmp}/evals/goals/github.com/o/r/20261002-x.md" <<'GOAL'
---
schema: goal/v1
id: 20261002-x
title: pack smoke
fixture_dir: evals/fixtures/github.com/o/r/20261002-x
f2p_check: check.sh
solver: none
---

# Executive overview

Pack gate smoke for local eval gates.
GOAL
  cat >"${tmp}/paths-prerun" <<'PATHS'
scripts/instance/create.sh
evals/fixtures/github.com/o/r/20261002-x/check.sh
evals/goals/github.com/o/r/20261002-x.md
PATHS

  if ! EVALS_PACK_ROOT="${tmp}" bash "${pack_assert}" --mode pre-commit --paths-file "${tmp}/paths-prerun" >/dev/null 2>&1; then
    printf 'error: pre-commit pack mode must accept fixture + goal without result\n' >&2
    fail=1
  fi
  if EVALS_PACK_ROOT="${tmp}" bash "${pack_assert}" --mode ci --paths-file "${tmp}/paths-prerun" >/dev/null 2>&1; then
    printf 'error: ci pack mode must reject missing result\n' >&2
    fail=1
  fi
fi

# Bad schema must fail goal.sh parse when kit ships it.
if [[ -f "${goal_sh}" ]]; then
  bad_goal="${tmp}/bad-goal.md"
  cat >"${bad_goal}" <<'BAD'
---
id: 20261002-bad-schema
title: missing schema
fixture_dir: evals/fixtures/universe/20261002-local-eval-gates
f2p_check: check.sh
solver: none
---

# Executive overview

Intentionally missing schema for parse fail.
BAD
  if bash "${goal_sh}" parse "${bad_goal}" >/dev/null 2>&1; then
    printf 'error: goal.sh parse must reject goals missing schema: goal/v1\n' >&2
    fail=1
  fi
fi

exit "${fail}"
