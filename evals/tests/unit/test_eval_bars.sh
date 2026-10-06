#!/usr/bin/env bash
# Unit coverage for eval-bars family detection (ui + existing families).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bars="${ROOT}/scripts/eval-bars.sh"
precommit_check="${ROOT}/fixtures/universe/20260929-pre-commit-platform/check.sh"
fail=0

miss() {
  printf '✗ %s\n' "$*" >&2
  fail=1
}

[[ -x "${bars}" ]] || miss "eval-bars.sh not executable"
[[ -x "${precommit_check}" ]] || miss "pre-commit-platform check not executable"

grep -q 'run_ui_bars' "${bars}" || miss "eval-bars missing run_ui_bars"
grep -q 'scope_lists_language' "${bars}" || miss "eval-bars missing scope_lists_language"
grep -q 'ui_bars_skip reason=scope_languages_omit_ui' "${bars}" || miss "eval-bars missing ui scope skip"
grep -q 'is_ui_path' "${bars}" || miss "eval-bars missing is_ui_path"
grep -qE '^\s*ui\)' "${bars}" || miss "eval-bars case missing ui family"
grep -q 'run_ansible_bars' "${bars}" || miss "eval-bars missing run_ansible_bars"
grep -q 'is_ansible_path' "${bars}" || miss "eval-bars missing is_ansible_path"
grep -qE '^\s*ansible\)' "${bars}" || miss "eval-bars case missing ansible family"
grep -q '20260929-pre-commit-platform' "${bars}" || miss "eval-bars missing pre-commit-platform universe bar"
grep -q '20261002-local-eval-gates' "${bars}" || miss "eval-bars missing local-eval-gates universe bar"
grep -q '20261004-sync-secrets-pin-github-owner' "${bars}" || miss "eval-bars missing sync-secrets GITHUB_OWNER pin universe bar"
grep -q '20261004-cf-migration-old-secrets' "${bars}" && miss "eval-bars still lists sunset cf-migration OLD_ secrets universe bar" || true
grep -q '20260929-meta-eval-pack-quality' "${bars}" || miss "eval-bars missing meta-eval-pack-quality universe bar"
local_gates_check="${ROOT}/fixtures/universe/20261002-local-eval-gates/check.sh"
[[ -x "${local_gates_check}" ]] || miss "local-eval-gates check not executable"

pack_check="${ROOT}/fixtures/universe/20260929-meta-eval-pack-quality/check.sh"
[[ -x "${pack_check}" ]] || miss "meta-eval-pack-quality check not executable"
[[ -f "${ROOT}/harness/lib/pack_quality_lint.py" ]] || miss "missing pack_quality_lint.py"
[[ -f "${ROOT}/harness/lib/llm_pack_quality_judge.py" ]] || miss "missing llm_pack_quality_judge.py"

# Pack-quality: fixture baseline fails; PRE_COMMIT skips Tier2/3 without keys on hub root.
if HERMES_EVAL_KIT="${ROOT}" HERMES_EVAL_REPO_ROOT="${ROOT}" HERMES_EVAL_SCAN_ROOT="${ROOT}/fixtures/universe/20260929-meta-eval-pack-quality" \
  TYPESAFE_API_KEY= EVAL_LLM_API_KEY= OPENAI_API_KEY= EVAL_LLM_MODEL= \
  bash "${pack_check}" >/dev/null 2>&1; then
  miss "pack-quality fixture baseline should fail Tier1"
fi

if ! HERMES_EVAL_KIT="${ROOT}" HERMES_EVAL_REPO_ROOT="${ROOT}" HERMES_EVAL_SCAN_ROOT="${ROOT}" \
  PRE_COMMIT=1 TYPESAFE_API_KEY= EVAL_LLM_API_KEY= OPENAI_API_KEY= EVAL_LLM_MODEL= \
  bash "${pack_check}" >/dev/null; then
  miss "pack-quality on hub with PRE_COMMIT=1 should pass Tier1 + skip Tier2/3"
fi

if TYPESAFE_API_KEY= EVAL_LLM_API_KEY= OPENAI_API_KEY= EVAL_LLM_MODEL= \
  HERMES_EVAL_KIT="${ROOT}" HERMES_EVAL_REPO_ROOT="${ROOT}" HERMES_EVAL_SCAN_ROOT="${ROOT}" \
  bash "${pack_check}" >/dev/null 2>&1; then
  miss "pack-quality on hub without TYPESAFE_API_KEY should fail closed (Tier2)"
fi

# Tier3: model unset → skip; model set without key → fail closed
if ! HERMES_EVAL_KIT="${ROOT}" HERMES_EVAL_REPO_ROOT="${ROOT}" HERMES_EVAL_SCAN_ROOT="${ROOT}" \
  PRE_COMMIT=1 TYPESAFE_API_KEY= EVAL_LLM_MODEL=some-model EVAL_LLM_API_KEY= OPENAI_API_KEY= \
  bash "${pack_check}" >/dev/null; then
  miss "pack-quality PRE_COMMIT should skip Tier3 when model set without key"
fi
if HERMES_EVAL_KIT="${ROOT}" HERMES_EVAL_REPO_ROOT="${ROOT}" HERMES_EVAL_SCAN_ROOT="${ROOT}" \
  TYPESAFE_API_KEY= EVAL_LLM_MODEL=some-model EVAL_LLM_API_KEY= OPENAI_API_KEY= \
  bash "${pack_check}" >/dev/null 2>&1; then
  miss "pack-quality should fail closed when EVAL_LLM_MODEL set without API key"
fi

# Extract and run detect_families in isolation
# shellcheck disable=SC1091
eval "$(
  awk '
    /^is_tf_path\(\)/ {keep=1}
    /^run_universe_bars\(\)/ {keep=0}
    keep {print}
  ' "${bars}"
)"

tmp="$(mktemp -d)"
trap 'rm -rf "'"${tmp}"'"' EXIT
# Path-only cases: empty product (no languages:) so ambient cwd cannot leak ui.
mkdir -p "${tmp}/empty/evals"
cat >"${tmp}/empty/evals/scope.yaml" <<'YAML'
schema: evals-scope/v1
repo: github.com/acme/empty
languages: []
YAML
export HERMES_EVAL_SCAN_ROOT="${tmp}/empty"

families="$(detect_families 'src/App.tsx' | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'typescript' || miss "tsx should select typescript: ${families}"
printf '%s' "${families}" | grep -q 'ui' && miss "src/** alone must not select ui: ${families}"

families="$(detect_families 'design/tokens/x.json' | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'ui' || miss "design/** should select ui: ${families}"

families="$(detect_families 'scripts/ui-process-check.mjs' | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'ui' || miss "scripts/ui-* should select ui: ${families}"

families="$(detect_families 'docs/design-system/README.md' | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'ui' || miss "docs/design-system should select ui: ${families}"

families="$(detect_families 'evals/ui/process/fixtures/x.json' | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'ui' || miss "evals/ui should select ui: ${families}"

families="$(detect_families 'evals/fixtures/github.com/acme/demo/ui-process/fixtures/x.json' | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'ui' || miss "own-leaf ui-process should select ui: ${families}"

families="$(detect_families 'main.tf' | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'opentofu' || miss "tf should select opentofu: ${families}"
printf '%s' "${families}" | grep -q 'universe' || miss "universe always: ${families}"

families="$(detect_families 'ansible/playbooks/converge.yml' | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'ansible' || miss "ansible/** should select ansible: ${families}"

families="$(detect_families 'roles/foo/ansible.cfg' | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'ansible' || miss "ansible.cfg should select ansible: ${families}"

families="$(detect_families 'playbook.yml' | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'ansible' && miss "bare *.yml must not select ansible: ${families}"

families="$(detect_families '.github/workflows/pre-commit.yml' | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'gha' || miss "workflows path should select gha: ${families}"

families="$(detect_families '.github/actions/setup/action.yml' | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'gha' || miss "actions path should select gha: ${families}"

families="$(detect_families 'README.md' | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'gha' && miss "non-workflow path must not select gha: ${families}"

families="$(HERMES_EVAL_FORCE_FAMILIES=ci detect_families | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'gha' || miss "FORCE ci should alias to gha: ${families}"
printf '%s' "${families}" | grep -q 'universe' || miss "universe always with FORCE ci: ${families}"

# Manifest languages: drive families with no path args (CI / make eval/bars)
mkdir -p "${tmp}/ui-only/evals"
cat >"${tmp}/ui-only/evals/scope.yaml" <<'YAML'
schema: evals-scope/v1
repo: github.com/acme/demo
languages:
  - ui
YAML
families="$(HERMES_EVAL_SCAN_ROOT="${tmp}/ui-only" detect_families | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'ui' || miss "languages: ui should select ui with no paths: ${families}"
printf '%s' "${families}" | grep -q 'opentofu' && miss "opentofu wrongly selected from ui-only manifest: ${families}"

mkdir -p "${tmp}/ansible-only/evals"
cat >"${tmp}/ansible-only/evals/scope.yaml" <<'YAML'
schema: evals-scope/v1
repo: github.com/acme/layers
languages:
  - ansible
YAML
families="$(HERMES_EVAL_SCAN_ROOT="${tmp}/ansible-only" detect_families | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'ansible' || miss "languages: ansible should select ansible with no paths: ${families}"
printf '%s' "${families}" | grep -q 'ui' && miss "ui wrongly selected from ansible-only manifest: ${families}"

mkdir -p "${tmp}/gha-only/evals"
cat >"${tmp}/gha-only/evals/scope.yaml" <<'YAML'
schema: evals-scope/v1
repo: github.com/acme/ci
languages:
  - gha
YAML
families="$(HERMES_EVAL_SCAN_ROOT="${tmp}/gha-only" detect_families | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'gha' || miss "languages: gha should select gha with no paths: ${families}"

mkdir -p "${tmp}/ci-alias/evals"
cat >"${tmp}/ci-alias/evals/scope.yaml" <<'YAML'
schema: evals-scope/v1
repo: github.com/acme/ci-alias
languages:
  - ci
YAML
families="$(HERMES_EVAL_SCAN_ROOT="${tmp}/ci-alias" detect_families | tr '\n' ' ')"
printf '%s' "${families}" | grep -q 'gha' || miss "languages: ci should alias to gha: ${families}"

# Universe pre-commit bar: fresh product missing config fails; golden shape passes.
mkdir -p "${tmp}/fresh/evals/harness"
printf '#!/bin/sh\nexit 0\n' >"${tmp}/fresh/evals/harness/goal.sh"
chmod +x "${tmp}/fresh/evals/harness/goal.sh"
if HERMES_EVAL_SCAN_ROOT="${tmp}/fresh" bash "${precommit_check}" >/dev/null 2>&1; then
  miss "fresh product without pre-commit should fail"
fi

cat >"${tmp}/fresh/.pre-commit-config.yaml" <<'YAML'
repos:
  - repo: https://github.com/hutch-fail/pre-commit
    rev: v0.3.0
    hooks:
      - id: platform
        exclude: ^evals/
  - repo: local
    hooks:
      - id: evals-pre-commit
        entry: bash evals/scripts/pre-commit-evals.sh
        language: system
        pass_filenames: true
YAML
if ! HERMES_EVAL_SCAN_ROOT="${tmp}/fresh" bash "${precommit_check}"; then
  miss "fresh product with org pre-commit shape should pass"
fi

# Execute bar shapes: temp scan roots with/without scripts.
ui_exec="${ROOT}/fixtures/language/ui/20260929-ui-execute-scripts/check.sh"
ts_exec="${ROOT}/fixtures/language/typescript/20260929-typescript-execute-scripts/check.sh"
jev_opt="${ROOT}/fixtures/language/ui/20260929-ui-jev-optional/check.sh"
[[ -x "${ui_exec}" ]] || miss "missing ui execute check"
[[ -x "${ts_exec}" ]] || miss "missing typescript execute check"
[[ -x "${jev_opt}" ]] || miss "missing ui jev optional check"
grep -q '20260929-ui-execute-scripts' "${bars}" || miss "eval-bars must wire ui execute"
grep -q '20260929-typescript-execute-scripts' "${bars}" || miss "eval-bars must wire typescript execute"

mkdir -p "${tmp}/skip-ui/node_modules"
cat >"${tmp}/skip-ui/package.json" <<'EOF'
{ "name": "skip-ui", "private": true, "scripts": { "build": "true" } }
EOF
if ! HERMES_EVAL_SCAN_ROOT="${tmp}/skip-ui" bash "${ui_exec}" >/dev/null; then
  miss "ui execute should skip when no ui:docs/lint/process scripts"
fi

mkdir -p "${tmp}/need-ci"
cat >"${tmp}/need-ci/package.json" <<'EOF'
{ "name": "need-ci", "private": true, "scripts": { "ui:lint": "true" } }
EOF
if HERMES_EVAL_SCAN_ROOT="${tmp}/need-ci" bash "${ui_exec}" >/dev/null 2>&1; then
  miss "ui execute should fail closed when node_modules missing"
else
  out="$(HERMES_EVAL_SCAN_ROOT="${tmp}/need-ci" bash "${ui_exec}" 2>&1 || true)"
  printf '%s' "${out}" | grep -qi 'npm ci' || miss "missing npm ci hint: ${out}"
fi

mkdir -p "${tmp}/skip-jev/node_modules"
cat >"${tmp}/skip-jev/package.json" <<'EOF'
{ "name": "skip-jev", "private": true, "scripts": {} }
EOF
if ! HERMES_EVAL_SCAN_ROOT="${tmp}/skip-jev" bash "${jev_opt}" >/dev/null; then
  miss "jev optional should skip when no ui:jev"
fi

mkdir -p "${tmp}/jev-nokey/node_modules"
cat >"${tmp}/jev-nokey/package.json" <<'EOF'
{ "name": "jev-nokey", "private": true, "scripts": { "ui:jev": "true" } }
EOF
if TYPESAFE_API_KEY= HERMES_EVAL_SCAN_ROOT="${tmp}/jev-nokey" bash "${jev_opt}" >/dev/null 2>&1; then
  miss "jev optional should fail when ui:jev present without TYPESAFE_API_KEY"
fi

if ! TYPESAFE_API_KEY= PRE_COMMIT=1 HERMES_EVAL_SCAN_ROOT="${tmp}/jev-nokey" bash "${jev_opt}" >/dev/null; then
  miss "jev optional should skip under PRE_COMMIT=1 without TYPESAFE_API_KEY"
fi

mkdir -p "${tmp}/skip-ts/node_modules"
cat >"${tmp}/skip-ts/package.json" <<'EOF'
{ "name": "skip-ts", "private": true, "scripts": { "build": "true" } }
EOF
if ! HERMES_EVAL_SCAN_ROOT="${tmp}/skip-ts" bash "${ts_exec}" >/dev/null; then
  miss "typescript execute should skip when no typecheck/test"
fi

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi
printf '✓ eval-bars family detection\n'
