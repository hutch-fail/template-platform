#!/usr/bin/env bash
# Compatibility wrapper — prefer scripts/pre-commit-evals.sh from host configs.
# Forces the opentofu family when TF paths are present (same as the generic
# dispatcher); with no args, fast-passes like the generic entry.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${here}/pre-commit-evals.sh" "$@"
