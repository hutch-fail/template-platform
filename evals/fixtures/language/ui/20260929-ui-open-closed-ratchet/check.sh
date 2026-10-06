#!/usr/bin/env bash
# Meta F2P: open-closed UI ratchet — declared ui + ui:lint enforced via language
# bars / eval-bars; shared gates must not require a product ui-design.yml.
#
# Baseline (notes != patched): always red for assert-red.
# After golden (notes contains patched): prove hub wiring + live execute via
# a temp consumer (no ui-design.yml).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve hub kit. Fixture copies in /tmp cannot walk relative to `here`.
# Harness sets HERMES_EVAL_REPO_ROOT to the product root when this hub lives
# at <product>/evals, or to the hub itself for a standalone checkout.
resolve_kit() {
  local cand
  if [[ -n "${HERMES_EVAL_KIT:-}" && -f "${HERMES_EVAL_KIT}/scripts/eval-bars.sh" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_KIT}" && pwd)"
    return 0
  fi
  for cand in \
    "${HERMES_EVAL_REPO_ROOT:-}/evals" \
    "${HERMES_EVAL_REPO_ROOT:-}" \
    "${EVALS_ROOT:-}" \
    "${here}/../../../.."; do
    [[ -n "${cand}" ]] || continue
    if [[ -f "${cand}/scripts/eval-bars.sh" ]]; then
      printf '%s\n' "$(cd "${cand}" && pwd)"
      return 0
    fi
  done
  printf 'error: cannot resolve evals kit (set HERMES_EVAL_KIT)\n' >&2
  return 1
}

kit="$(resolve_kit)"
bars="${kit}/scripts/eval-bars.sh"
execute_check="${kit}/fixtures/language/ui/20260929-ui-execute-scripts/check.sh"
jev_check="${kit}/fixtures/language/ui/20260929-ui-jev-optional/check.sh"
eval_ci="${kit}/.github/workflows/eval-ci.yml"

miss() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

if ! grep -qx 'patched' "${here}/notes.txt" 2>/dev/null; then
  printf 'error: baseline fixture not patched (open-closed ratchet F2P red)\n' >&2
  exit 1
fi

[[ -x "${bars}" ]] || miss "missing executable ${bars}"
[[ -x "${execute_check}" ]] || miss "missing execute bar ${execute_check}"
[[ -x "${jev_check}" ]] || miss "missing jev bar ${jev_check}"
[[ -f "${eval_ci}" ]] || miss "missing ${eval_ci}"

grep -q '20260929-ui-execute-scripts' "${bars}" \
  || miss "eval-bars run_ui_bars must wire 20260929-ui-execute-scripts"
grep -q '20260929-ui-jev-optional' "${bars}" \
  || miss "eval-bars run_ui_bars must wire 20260929-ui-jev-optional"
grep -q '20260929-typescript-execute-scripts' "${bars}" \
  || miss "eval-bars run_typescript_bars must wire 20260929-typescript-execute-scripts"

# Shared gates must not require product ui-design.yml.
if grep -R --include='*.sh' -n 'ui-design\.yml' \
  "${kit}/fixtures/language/ui" "${kit}/scripts/eval-bars.sh" 2>/dev/null \
  | grep -v '20260929-ui-open-closed-ratchet' | grep -q .; then
  miss "language/ui bars or eval-bars must not require product ui-design.yml"
fi

grep -Eq 'setup-node|actions/setup-node' "${eval_ci}" \
  || miss "eval-ci.yml must setup-node when ui|typescript consumers need npm"
grep -Eq 'TYPESAFE_API_KEY' "${eval_ci}" \
  || miss "eval-ci.yml must accept/pass TYPESAFE_API_KEY for optional ui:jev"

# Live: temp consumer with languages: ui + failing-then-ok lint path.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/ui-open-closed.XXXXXX")"
trap 'rm -rf "'"${tmp}"'"' EXIT

mkdir -p "${tmp}/evals/fixtures/github.com/acme/demo/ui-process/fixtures" \
  "${tmp}/node_modules" "${tmp}/scripts"
cat >"${tmp}/evals/scope.yaml" <<'YAML'
schema: evals-scope/v1
repo: github.com/acme/demo
languages:
  - ui
YAML
# Minimal process JSON so presence bars would pass if run; we call execute only.
printf '{}\n' >"${tmp}/evals/fixtures/github.com/acme/demo/ui-process/fixtures/pos.json"
cat >"${tmp}/package.json" <<'EOF'
{
  "name": "acme-demo",
  "private": true,
  "scripts": {
    "ui:lint": "node -e \"require('fs').writeFileSync('lint.ran','1'); process.exit(0)\"",
    "ui:process": "node -e \"process.exit(0)\""
  }
}
EOF
# No .github/workflows/ui-design.yml — intentional.

export HERMES_EVAL_KIT="${kit}"
export HERMES_EVAL_SCAN_ROOT="${tmp}"
export HERMES_EVAL_REPO_ROOT="${tmp}"

bash "${execute_check}" || miss "execute bar failed on declared ui consumer with ui:lint"
[[ -f "${tmp}/lint.ran" ]] || miss "ui:lint did not run (marker missing) — language bars must enforce scripts"

# Full ui family (presence + execute + jev skip) via eval-bars force, skipping
# universe by invoking run checks through FORCE — universe still runs; give
# the temp product a minimal org pre-commit so universe bar can pass.
cat >"${tmp}/.pre-commit-config.yaml" <<'YAML'
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
# Universe no-GH_APP needs .github/workflows or skips — provide empty workflows dir.
mkdir -p "${tmp}/.github/workflows"
# Scope-manifest + process-entrypoint need ui:process entrypoint + fixtures (have them).
# Also need package.json ui:process (have it).

if ! HERMES_EVAL_FORCE_FAMILIES=ui bash "${bars}"; then
  miss "eval-bars ui family failed on consumer without ui-design.yml"
fi

printf 'ui_open_closed_ratchet_ok kit=%s consumer=%s\n' "${kit}" "${tmp}"
exit 0
