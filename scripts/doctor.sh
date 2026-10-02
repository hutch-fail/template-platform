#!/usr/bin/env bash
# Check local/CI prerequisites and print what to do when something is missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/env.sh
source "${SCRIPT_DIR}/lib/env.sh"

FAILED=0

pass() { printf 'OK  %s\n' "$*"; }
fail() {
  printf 'MISS %s\n' "$1"
  if [[ -n "${2:-}" ]]; then
    printf '     → %s\n' "$2"
  fi
  FAILED=1
}
hint() { printf '     → %s\n' "$*"; }

printf 'template-platform doctor\n'
printf 'root: %s\n\n' "${PLATFORM_TEMPLATE_ROOT}"

if command -v "${TOFU_BIN}" >/dev/null 2>&1; then
  pass "${TOFU_BIN} ($(${TOFU_BIN} version | head -1))"
else
  fail "${TOFU_BIN} not on PATH" "Install OpenTofu: https://opentofu.org/docs/intro/install/"
fi

if [[ -f "${PLATFORM_TEMPLATE_ROOT}/.env.example" ]]; then
  pass ".env.example present"
else
  fail ".env.example missing" "Restore from git"
fi

if [[ -f "${PLATFORM_TEMPLATE_ROOT}/.env" ]]; then
  pass ".env present (syncable secrets)"
else
  fail ".env missing" "cp .env.example .env && fill R2 backend vars (docs/bootstrap-state.md)"
fi

if [[ -d "${TF_DIR}" && -f "${TF_DIR}/main.tf" ]]; then
  pass "OpenTofu root at ${TF_DIR#"${PLATFORM_TEMPLATE_ROOT}/"}"
else
  fail "terraform/ missing" "Expected OpenTofu stack under terraform/"
fi

if [[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  pass "CLOUDFLARE_ACCOUNT_ID set"
else
  fail "CLOUDFLARE_ACCOUNT_ID unset" "Copy Account ID → .env (docs/bootstrap-state.md)"
fi

if [[ -n "${TF_BACKEND_ENDPOINT:-}" ]]; then
  pass "TF_BACKEND_ENDPOINT set"
else
  fail "TF_BACKEND_ENDPOINT unset" "Set https://<ACCOUNT_ID>.r2.cloudflarestorage.com in .env"
fi

if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]]; then
  pass "AWS_ACCESS_KEY_ID set (R2 bucket-scoped)"
else
  fail "AWS_ACCESS_KEY_ID unset" "Bucket-scoped R2 Access Key ID → .env"
fi

if [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  pass "AWS_SECRET_ACCESS_KEY set (R2 bucket-scoped)"
else
  fail "AWS_SECRET_ACCESS_KEY unset" "Bucket-scoped R2 Secret → .env"
fi

if [[ "${TF_BACKEND_BUCKET}" == "platform-state" && "${TF_BACKEND_KEY}" == "template/terraform.tfstate" ]]; then
  pass "TF_BACKEND_BUCKET/KEY → platform-state / template/terraform.tfstate"
else
  fail "TF_BACKEND_* unexpected" "Expect bucket=platform-state key=template/terraform.tfstate (or override intentionally)"
fi

if [[ -f "${PLATFORM_TEMPLATE_ROOT}/docs/bootstrap-state.md" ]]; then
  pass "state runbook docs/bootstrap-state.md"
else
  fail "docs/bootstrap-state.md missing"
fi

printf '\n'
if [[ "${FAILED}" -ne 0 ]]; then
  printf 'Next steps:\n'
  hint "1. R2 platform-state — create bucket + bucket-scoped keys (platform-cloudflare docs/r2-state-bootstrap.md)"
  hint "2. cp .env.example .env && fill CLOUDFLARE_ACCOUNT_ID, TF_BACKEND_ENDPOINT, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
  hint "3. make doctor   # until clean"
  hint "4. make init && make validate && make plan"
  hint "5. make sync-secrets   # R2 secrets for CI environment production"
  hint "6. Day-to-day: PR → iac-plan → merge → iac-apply (avoid local make apply when CI is live)"
  printf '\ndoctor: incomplete prerequisites\n' >&2
  exit 1
fi

printf 'doctor: ready\n'
exit 0
