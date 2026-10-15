#!/usr/bin/env bash
# Universe bar: bash budget (GHA YAML + eval check.sh).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ---
kit="${HERMES_EVAL_KIT:-${EVALS_KIT:-${HERMES_EVAL_REPO_ROOT:-${EVALS_ROOT:-${HERMES_EVALS_ROOT:-}}}}}"
# ---
if [[ -z "${kit}" && -f "${here}/../../../harness/lib/bash_budget_lint.py" ]]; then
  kit="$(cd "${here}/../../.." && pwd)"
fi
# ---
[[ -n "${kit}" ]] || { echo "error: set HERMES_EVAL_KIT or HERMES_EVAL_REPO_ROOT" >&2; exit 1; }
lint="${kit}/harness/lib/bash_budget_lint.py"
# ---
[[ -f "${lint}" ]] || lint="${kit}/evals/harness/lib/bash_budget_lint.py"
[[ -f "${lint}" ]] || { echo "error: missing bash_budget_lint.py under ${kit}" >&2; exit 1; }
# ---
exec python3 "${lint}" --drive-fixture "${here}"
