#!/usr/bin/env bash
# tofu apply — prefer CI iac-apply on main; local = break-glass only.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/env.sh
source "${SCRIPT_DIR}/lib/env.sh"

cd "${TF_DIR}"
plan_out="${PLAN_OUT:-tfplan}"
if [[ -f "${plan_out}" ]]; then
  exec "${TOFU_BIN}" apply -input=false -auto-approve "${plan_out}" "$@"
fi
exec "${TOFU_BIN}" apply -input=false -auto-approve "$@"
