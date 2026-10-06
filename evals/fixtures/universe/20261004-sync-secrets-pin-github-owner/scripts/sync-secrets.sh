#!/usr/bin/env bash
# Baseline: inherit GITHUB_OWNER from the parent shell (must fail the universe bar).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/env.sh
source "${SCRIPT_DIR}/lib/env.sh"
: "${GITHUB_OWNER:=hutch-fail}"
REPO="${GITHUB_OWNER}/platform-cloudflare"
# gh secret set CLOUDFLARE_API_TOKEN --repo "${REPO}"
