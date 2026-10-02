#!/usr/bin/env bash
# Shared env for template-platform OpenTofu scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PLATFORM_TEMPLATE_ROOT="${PLATFORM_TEMPLATE_ROOT:-${ROOT}}"

load_env_file() {
  local file="$1"
  [[ -f "${file}" ]] || return 0
  # shellcheck disable=SC1090
  set -a
  # shellcheck disable=SC1090
  source "${file}"
  set +a
}

load_env_file "${PLATFORM_TEMPLATE_ROOT}/.env"

: "${TF_DIR:=${PLATFORM_TEMPLATE_ROOT}/terraform}"
: "${TOFU_BIN:=tofu}"
: "${TF_BACKEND_BUCKET:=platform-state}"
: "${TF_BACKEND_KEY:=template/terraform.tfstate}"
: "${TF_BACKEND_REGION:=auto}"

export TF_DIR TOFU_BIN TF_BACKEND_BUCKET TF_BACKEND_KEY TF_BACKEND_REGION

if [[ -z "${TF_BACKEND_ENDPOINT:-}" && -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  TF_BACKEND_ENDPOINT="https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com"
fi
export TF_BACKEND_ENDPOINT="${TF_BACKEND_ENDPOINT:-}"

r2_backend_ready() {
  [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] \
    && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]] \
    && [[ -n "${TF_BACKEND_ENDPOINT:-}" ]] \
    && [[ -n "${TF_BACKEND_BUCKET:-}" ]] \
    && [[ -n "${TF_BACKEND_KEY:-}" ]]
}

tofu_backend_config_args() {
  printf '%s\n' \
    "-backend-config=bucket=${TF_BACKEND_BUCKET}" \
    "-backend-config=key=${TF_BACKEND_KEY}" \
    "-backend-config=region=${TF_BACKEND_REGION}" \
    "-backend-config=endpoints={s3=\"${TF_BACKEND_ENDPOINT}\"}" \
    "-backend-config=skip_credentials_validation=true" \
    "-backend-config=skip_metadata_api_check=true" \
    "-backend-config=skip_region_validation=true" \
    "-backend-config=skip_requesting_account_id=true" \
    "-backend-config=skip_s3_checksum=true" \
    "-backend-config=use_path_style=true"
}
