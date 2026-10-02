#!/usr/bin/env bash
# Sync R2 secrets from local .env → GitHub Actions environment production.
# Never prints secret values.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/env.sh
source "${SCRIPT_DIR}/lib/env.sh"

: "${GITHUB_OWNER:=hutch-fail}"
: "${GITHUB_REPO:=template-platform}"
: "${GITHUB_SECRETS_ENV:=production}"
REPO="${GITHUB_OWNER}/${GITHUB_REPO}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

command -v gh >/dev/null 2>&1 || die "gh not on PATH (install GitHub CLI)"

[[ -n "${AWS_ACCESS_KEY_ID:-}" ]] || die "AWS_ACCESS_KEY_ID unset — fill .env (R2)"
[[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]] || die "AWS_SECRET_ACCESS_KEY unset — fill .env (R2)"
[[ -n "${TF_BACKEND_ENDPOINT:-}" ]] || die "TF_BACKEND_ENDPOINT unset — fill .env"
[[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]] || die "CLOUDFLARE_ACCOUNT_ID unset — fill .env"

# Ensure deployment environment exists (idempotent).
if ! gh api "repos/${REPO}/environments/${GITHUB_SECRETS_ENV}" >/dev/null 2>&1; then
  info "creating environment ${GITHUB_SECRETS_ENV} on ${REPO}"
  gh api --method PUT "repos/${REPO}/environments/${GITHUB_SECRETS_ENV}" >/dev/null
fi

set_env_secret() {
  local name="$1" value="$2"
  value="${value%$'\r'}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}" | gh secret set "${name}" --repo "${REPO}" --env "${GITHUB_SECRETS_ENV}"
  info "set ${GITHUB_SECRETS_ENV}/${name}"
}

set_env_secret AWS_ACCESS_KEY_ID "${AWS_ACCESS_KEY_ID}"
set_env_secret AWS_SECRET_ACCESS_KEY "${AWS_SECRET_ACCESS_KEY}"
set_env_secret TF_BACKEND_ENDPOINT "${TF_BACKEND_ENDPOINT}"
set_env_secret CLOUDFLARE_ACCOUNT_ID "${CLOUDFLARE_ACCOUNT_ID}"

info "sync-secrets: done → ${REPO} environment ${GITHUB_SECRETS_ENV}"
info "Optional (runner billing / 1Password helpers used by some reusable workflows):"
info "  OP_SERVICE_ACCOUNT_TOKEN, OP_SERVICE_ACCOUNT_KEY, ORG_BILLING_TOKEN"
info "verify: gh secret list --repo ${REPO} --env ${GITHUB_SECRETS_ENV}"
