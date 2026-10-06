#!/usr/bin/env bash
# CI helper for eval-select.yml / eval-ci.yml: run make eval/select, summarize
# opt-outs, emit JSON.
# Usage: ci-eval-select.sh <make_dir>
#   make_dir: directory that contains the hub Makefile (usually the hub checkout
#   path; "." when the caller IS the hub).
set -euo pipefail

evals_path="${1:-.}"
if [[ "${evals_path}" == "." ]]; then
  make_dir="."
else
  make_dir="${evals_path}"
fi

[[ -d "${make_dir}" ]] || {
  printf 'error: evals_path not a directory: %s\n' "${make_dir}" >&2
  exit 1
}

tmp_out="$(mktemp)"
tmp_err="$(mktemp)"
trap 'rm -f "'"${tmp_out}"'" "'"${tmp_err}"'"' EXIT

set +e
make --no-print-directory -C "${make_dir}" eval/select >"${tmp_out}" 2>"${tmp_err}"
rc=$?
set -e

# Always surface harness stderr (opt-outs + errors).
if [[ -s "${tmp_err}" ]]; then
  cat "${tmp_err}" >&2
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    printf '## eval/select\n\n'
    if grep -qE '^opt_out ' "${tmp_err}" 2>/dev/null; then
      printf '### Opt-outs\n\n'
      printf '```\n'
      grep -E '^opt_out ' "${tmp_err}" || true
      printf '```\n\n'
    else
      printf 'No opt-outs reported.\n\n'
    fi
    printf '### Selected paths\n\n'
    if [[ -s "${tmp_out}" ]]; then
      printf '```\n'
      cat "${tmp_out}"
      printf '```\n'
    else
      printf '_none_\n'
    fi
  } >>"${GITHUB_STEP_SUMMARY}"
fi

if [[ "${rc}" -ne 0 ]]; then
  printf 'error: make -C %s eval/select exited %s\n' "${make_dir}" "${rc}" >&2
  exit "${rc}"
fi

# JSON array of selected absolute paths (one path per stdout line).
selected_json="$(
  python3 - "${tmp_out}" <<'PY'
import json, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(encoding="utf-8")
paths = [line.strip() for line in text.splitlines() if line.strip()]
print(json.dumps(paths))
PY
)"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf 'selected<<EOF\n'
    printf '%s\n' "${selected_json}"
    printf 'EOF\n'
  } >>"${GITHUB_OUTPUT}"
fi

# Echo selected paths on stdout for local debugging / CI logs.
cat "${tmp_out}"
