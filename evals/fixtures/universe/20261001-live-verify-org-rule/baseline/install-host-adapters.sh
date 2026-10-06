#!/usr/bin/env bash
# Install project-root editor adapters that point into ./evals/skills and rules.
# Run once from a host project after adding this hub as a subtree/mount at evals/.
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

PROJECT_ROOT="$(pwd)"
EVALS_DIR="${PROJECT_ROOT}/evals"

[[ -d "${EVALS_DIR}/skills" ]] || die "no ${EVALS_DIR}/skills — run from the host project root (expected ./evals)"
[[ -f "${EVALS_DIR}/harness/goal.sh" ]] || die "no ${EVALS_DIR}/harness/goal.sh — is evals/ this hub?"

mkdir -p "${PROJECT_ROOT}/.cursor/skills" "${PROJECT_ROOT}/.cursor/rules" \
  "${PROJECT_ROOT}/.agents/skills"

skills=(goal goal-author goal-develop goal-solve goal-judge meta-dev hypothesis-playground evals-org-redistribute build-eval hillclimb)
for name in "${skills[@]}"; do
  [[ -d "${EVALS_DIR}/skills/${name}" ]] || die "missing skill ${name}"
  ln -sfn "../../evals/skills/${name}" "${PROJECT_ROOT}/.cursor/skills/${name}"
  ln -sfn "../../evals/skills/${name}" "${PROJECT_ROOT}/.agents/skills/${name}"
done

for rule in meta-dev.mdc goal-spec.mdc; do
  [[ -f "${EVALS_DIR}/.cursor/rules/${rule}" ]] || die "missing rule ${rule}"
  ln -sfn "../../evals/.cursor/rules/${rule}" "${PROJECT_ROOT}/.cursor/rules/${rule}"
done

printf '✓ host adapters installed under .cursor/ and .agents/ → evals/skills\n'
printf '  next: make -C evals eval/assert-red GOAL=fixture-token-echo\n'
