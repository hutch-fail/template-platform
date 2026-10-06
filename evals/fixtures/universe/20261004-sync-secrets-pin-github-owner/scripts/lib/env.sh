#!/usr/bin/env bash
# Baseline: inherit GITHUB_OWNER (must fail the universe bar).
set -euo pipefail
: "${GITHUB_OWNER:=hutch-fail}"
: "${GITHUB_REPO:=platform-cloudflare}"
export GITHUB_OWNER GITHUB_REPO
