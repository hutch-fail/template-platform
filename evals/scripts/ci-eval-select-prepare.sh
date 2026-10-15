#!/usr/bin/env bash
# CI helper: overlay caller goals/fixtures onto the hub recipe, then select.
# Env: EVALS_PATH, GITHUB_WORKSPACE (required in Actions).
set -euo pipefail

evals_path="${EVALS_PATH:-.}"
ws="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE required}"

if [[ "${evals_path}" == "." ]]; then
  hub="${ws}"
  caller_kit="${ws}"
else
  hub="${ws}/.evals-hub"
  caller_kit="${ws}/${evals_path}"
fi

# Recipe = hub (universe/language seeds) + caller's product goals/fixtures + manifest.
# Skip when hub is the caller (evals_path: .) — cp same-file fails.
if [[ "${hub}" != "${caller_kit}" ]]; then
  if [[ -f "${caller_kit}/scope.yaml" ]]; then
    cp "${caller_kit}/scope.yaml" "${hub}/scope.yaml"
  fi
  if [[ -d "${caller_kit}/goals/github.com" ]]; then
    mkdir -p "${hub}/goals"
    cp -a "${caller_kit}/goals/github.com" "${hub}/goals/"
  fi
  # Goals reference evals/fixtures/…; overlay must include fixtures or
  # require_goal_v1 fails closed (fixture_dir not found).
  if [[ -d "${caller_kit}/fixtures/github.com" ]]; then
    mkdir -p "${hub}/fixtures"
    cp -a "${caller_kit}/fixtures/github.com" "${hub}/fixtures/"
  fi
fi

# make eval/select lives in the hub kit (not the caller workspace).
HERMES_EVAL_RECIPE_ROOT="${hub}" \
  EVALS_ROOT="${hub}" \
  HERMES_EVALS_ROOT="${hub}" \
  bash "${hub}/scripts/ci-eval-select.sh" "${hub}"
