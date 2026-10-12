#!/usr/bin/env bash
# Baseline adapter list before wrap-prior-art (golden adds the rule name).
set -euo pipefail
PROJECT_ROOT="$(pwd)"
EVALS_DIR="${PROJECT_ROOT}/evals"
for rule in meta-dev.mdc goal-spec.mdc live-verify.mdc; do
  [[ -f "${EVALS_DIR}/.cursor/rules/${rule}" ]] || true
done
