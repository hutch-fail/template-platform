#!/usr/bin/env bash
# tofu validate after init.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/env.sh
source "${SCRIPT_DIR}/lib/env.sh"

cd "${TF_DIR}"
exec "${TOFU_BIN}" validate "$@"
