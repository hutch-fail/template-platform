#!/usr/bin/env bash
# F2P: Terraform/OpenTofu roots must declare a non-local remote backend.
# Rule A: fail backend "local" and missing backend; pass any other backend type
# (including partial backend "s3" {}). Does not require dynamodb_table.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prefer explicit scan root (product pre-commit). Else fixture cwd if it has .tf.
# Else HERMES_EVAL_REPO_ROOT (consumer product).
#
# Skip kit / recipe trees under the product root: vendored evals/, CI hub clone
# .evals-hub/, and Terraform's own .terraform/ — otherwise language fixtures
# (intentionally backend "local") false-fail product bars when CI checks out
# the hub into the workspace.
tf_find() {
  local root="$1"
  find "${root}" \( -name '*.tf' -o -name '*.tf.json' \) \
    ! -path '*/.terraform/*' \
    ! -path '*/evals/*' \
    ! -path '*/.evals-hub/*' \
    2>/dev/null
}

resolve_scan_root() {
  if [[ -n "${HERMES_EVAL_SCAN_ROOT:-}" && -d "${HERMES_EVAL_SCAN_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_SCAN_ROOT}" && pwd)"
    return 0
  fi
  if tf_find "${here}" | grep -q .; then
    printf '%s\n' "${here}"
    return 0
  fi
  if [[ -n "${HERMES_EVAL_REPO_ROOT:-}" && -d "${HERMES_EVAL_REPO_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_REPO_ROOT}" && pwd)"
    return 0
  fi
  printf 'error: no scan root (set HERMES_EVAL_SCAN_ROOT or place *.tf under the fixture)\n' >&2
  return 1
}

# Print backend types found under root (one per line). Empty if none.
# Ignores # line comments. Matches backend "TYPE" or backend 'TYPE'.
collect_backend_types() {
  local root="$1" f
  while IFS= read -r f; do
    [[ -n "${f}" ]] || continue
    # Strip line comments then extract backend type tokens.
    sed 's/#.*//' "${f}" \
      | tr '\n' ' ' \
      | grep -oE 'backend[[:space:]]+("[^"]+"|'\''[^'\'']+'\'')' \
      | sed -E 's/.*["'\'']([^"'\'']+)["'\''].*/\1/' || true
  done < <(tf_find "${root}")
}

root="$(resolve_scan_root)"
mapfile -t tf_files < <(tf_find "${root}" | sort)

if [[ "${#tf_files[@]}" -eq 0 ]]; then
  printf 'error: no *.tf under %s — cannot assert remote backend\n' "${root}" >&2
  exit 1
fi

mapfile -t backends < <(collect_backend_types "${root}" | sort -u)

if [[ "${#backends[@]}" -eq 0 ]]; then
  printf 'error: Terraform files under %s declare no backend block (implicit local)\n' "${root}" >&2
  exit 1
fi

fail=0
for b in "${backends[@]}"; do
  [[ -z "${b}" ]] && continue
  if [[ "${b}" == "local" ]]; then
    printf 'error: backend "local" is not allowed under %s (use a remote backend)\n' "${root}" >&2
    fail=1
  fi
done

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

exit 0
