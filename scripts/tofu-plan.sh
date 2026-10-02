#!/usr/bin/env bash
# tofu plan — same entrypoint for local and CI.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/env.sh
source "${SCRIPT_DIR}/lib/env.sh"

cd "${TF_DIR}"
plan_out="${PLAN_OUT:-tfplan}"
exec "${TOFU_BIN}" plan -input=false -no-color -out="${plan_out}" "$@"
