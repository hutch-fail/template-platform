#!/usr/bin/env bash
# Unit coverage for harbor multi-source usage ledger.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 "${ROOT}/tests/unit/test_harbor_usage_ledger.py"
