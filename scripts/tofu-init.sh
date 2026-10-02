#!/usr/bin/env bash
# tofu init — S3-compatible R2 backend via env credentials + -backend-config.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/env.sh
source "${SCRIPT_DIR}/lib/env.sh"

if ! r2_backend_ready; then
  printf 'error: R2 backend env incomplete (need AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, TF_BACKEND_ENDPOINT)\n' >&2
  printf 'hint: fill .env from docs/bootstrap-state.md then make doctor\n' >&2
  printf 'hint: CI needs the same secrets in environment production (make sync-secrets)\n' >&2
  exit 1
fi

cd "${TF_DIR}"
mapfile -t backend_args < <(tofu_backend_config_args)
exec "${TOFU_BIN}" init -input=false "${backend_args[@]}" "$@"
