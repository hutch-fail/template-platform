#!/usr/bin/env bash
# F2P: no raw GitHub App Actions secrets in .github/workflows.
# Fails on secrets.GH_APP_ID / secrets.GH_APP_PRIVATE_KEY and on workflow_call
# or job secrets: declarations named GH_APP_ID / GH_APP_PRIVATE_KEY.
# Allows op://…/GH_APP_*, steps.op.outputs.GH_APP_*, and PEM as a 1Password
# document ref (post-#34 pattern).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_scan_root() {
  if [[ -n "${HERMES_EVAL_SCAN_ROOT:-}" && -d "${HERMES_EVAL_SCAN_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_SCAN_ROOT}" && pwd)"
    return 0
  fi
  if [[ -d "${here}/.github/workflows" ]]; then
    printf '%s\n' "${here}"
    return 0
  fi
  if [[ -n "${HERMES_EVAL_REPO_ROOT:-}" && -d "${HERMES_EVAL_REPO_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_REPO_ROOT}" && pwd)"
    return 0
  fi
  printf 'error: no scan root (set HERMES_EVAL_SCAN_ROOT or place .github/workflows under the fixture)\n' >&2
  return 1
}

# List workflow YAML under scan_root/.github/workflows only (not nested fixtures).
list_workflows() {
  local root="$1" wf
  wf="${root}/.github/workflows"
  if [[ ! -d "${wf}" ]]; then
    return 0
  fi
  find "${wf}" \( -name '*.yml' -o -name '*.yaml' \) -type f 2>/dev/null | sort
}

# Emit forbidden secrets: key declarations (GH_APP_ID / GH_APP_PRIVATE_KEY)
# that are direct children of a secrets: mapping. Ignores env: / with: blocks.
scan_secret_declarations() {
  local file="$1"
  awk '
    BEGIN { in_secrets = 0; secrets_indent = -1 }
    {
      line = $0
      sub(/\r$/, "", line)
      # Strip YAML comments (naive; good enough for Actions workflows).
      comment = index(line, "#")
      if (comment > 0) {
        # Keep # inside quoted strings roughly: only strip if # is outside quotes.
        # Simple path: strip from first unquoted #.
        tmp = line
        in_q = 0
        out = ""
        for (i = 1; i <= length(tmp); i++) {
          c = substr(tmp, i, 1)
          if (c == "\"" && (i == 1 || substr(tmp, i - 1, 1) != "\\")) in_q = !in_q
          if (c == "#" && !in_q) break
          out = out c
        }
        line = out
      }
      if (line ~ /^[[:space:]]*$/) next

      match(line, /^[[:space:]]*/)
      indent = RLENGTH
      content = substr(line, indent + 1)

      if (in_secrets && indent <= secrets_indent) {
        in_secrets = 0
        secrets_indent = -1
      }

      if (content ~ /^secrets:[[:space:]]*$/ || content ~ /^secrets:[[:space:]]+/) {
        # secrets: inherit — not a mapping of named secrets.
        if (content ~ /^secrets:[[:space:]]+inherit[[:space:]]*$/) {
          in_secrets = 0
          secrets_indent = -1
          next
        }
        in_secrets = 1
        secrets_indent = indent
        next
      }

      if (in_secrets && indent > secrets_indent) {
        if (content ~ /^GH_APP_ID:/ || content ~ /^GH_APP_PRIVATE_KEY:/) {
          print FILENAME ":" NR ": forbidden secrets declaration: " content
        }
      }
    }
  ' "${file}"
}

root="$(resolve_scan_root)"
mapfile -t workflows < <(list_workflows "${root}")

if [[ "${#workflows[@]}" -eq 0 ]]; then
  # No workflows → nothing to forbid; pass (hub kits without Actions still OK).
  exit 0
fi

fail=0
for f in "${workflows[@]}"; do
  [[ -f "${f}" ]] || continue

  if grep -Eq 'secrets\.GH_APP_ID|secrets\.GH_APP_PRIVATE_KEY' "${f}"; then
    printf 'error: %s references secrets.GH_APP_ID or secrets.GH_APP_PRIVATE_KEY\n' "${f}" >&2
    fail=1
  fi

  while IFS= read -r hit; do
    [[ -z "${hit}" ]] && continue
    printf 'error: %s\n' "${hit}" >&2
    fail=1
  done < <(scan_secret_declarations "${f}")
done

exit "${fail}"
