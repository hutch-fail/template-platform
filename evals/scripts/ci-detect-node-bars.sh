#!/usr/bin/env bash
# CI helper: set need=1 when consumer declares ui|typescript and has package.json.
# Env: EVALS_PATH. Writes need=0|1 to GITHUB_OUTPUT.
set -euo pipefail

evals_path="${EVALS_PATH:-.}"
scope=""
if [[ "${evals_path}" == "." ]]; then
  [[ -f scope.yaml ]] && scope=scope.yaml
  [[ -f evals/scope.yaml ]] && scope=evals/scope.yaml
else
  [[ -f "${evals_path}/scope.yaml" ]] && scope="${evals_path}/scope.yaml"
fi

need=0
if [[ -n "${scope}" ]]; then
  if grep -Eq '^[[:space:]]*-[[:space:]]*(ui|typescript)[[:space:]]*$|languages:.*(ui|typescript)' "${scope}"; then
    need=1
  fi
fi
if [[ ! -f package.json ]]; then
  need=0
fi
echo "need=${need}" >>"${GITHUB_OUTPUT:?GITHUB_OUTPUT required}"
