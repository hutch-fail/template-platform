#!/usr/bin/env bash
# F2P: ansible/playbooks/ must contain only converge.yml (no sibling playbooks).
# ROLE-CONTRACT: parallel follow-ons add role entries in converge.yml — do not
# fork per-feature playbooks beside it.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prefer explicit scan root (product pre-commit / bars). Else fixture cwd if it
# has ansible/playbooks/. Else HERMES_EVAL_REPO_ROOT (consumer product).
#
# Skip kit / recipe trees under the product root: vendored evals/, CI hub clone
# .evals-hub/, and hub fixtures/language (intentionally red baselines) — path
# skips are relative to the scan root so a hub checkout whose absolute path
# contains "/evals/" is not falsely excluded.
playbooks_dirs() {
  local root="$1" d parent
  while IFS= read -r d; do
    [[ -n "${d}" ]] || continue
    # d is relative (./ansible/playbooks); normalize to absolute under root.
    d="$(cd "${root}" && cd "${d}" && pwd)"
    parent="$(basename "$(dirname "${d}")")"
    [[ "${parent}" == "ansible" ]] || continue
    printf '%s\n' "${d}"
  done < <(
    # Relative find so ! -path './evals/*' does not match ancestor dir names.
    (cd "${root}" && find . -type d -name playbooks \
      ! -path './evals/*' \
      ! -path './.evals-hub/*' \
      ! -path './fixtures/*' \
      2>/dev/null)
  )
}

resolve_scan_root() {
  if [[ -n "${HERMES_EVAL_SCAN_ROOT:-}" && -d "${HERMES_EVAL_SCAN_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_SCAN_ROOT}" && pwd)"
    return 0
  fi
  if [[ -d "${here}/ansible/playbooks" ]]; then
    printf '%s\n' "${here}"
    return 0
  fi
  if [[ -n "${HERMES_EVAL_REPO_ROOT:-}" && -d "${HERMES_EVAL_REPO_ROOT}" ]]; then
    printf '%s\n' "$(cd "${HERMES_EVAL_REPO_ROOT}" && pwd)"
    return 0
  fi
  printf 'error: no scan root (set HERMES_EVAL_SCAN_ROOT or place ansible/playbooks under the fixture)\n' >&2
  return 1
}

root="$(resolve_scan_root)"
mapfile -t pb_dirs < <(playbooks_dirs "${root}" | sort -u)

if [[ "${#pb_dirs[@]}" -eq 0 ]]; then
  # No product ansible/playbooks after kit skips (hub checkout editing language
  # fixtures, or consumer without Ansible yet). Nothing to enforce.
  printf 'ansible-single-converge_skip reason=no_ansible_playbooks root=%s\n' "${root}" >&2
  exit 0
fi

fail=0
for pb in "${pb_dirs[@]}"; do
  [[ -n "${pb}" ]] || continue
  if [[ ! -f "${pb}/converge.yml" && ! -f "${pb}/converge.yaml" ]]; then
    printf 'error: %s missing converge.yml (or converge.yaml)\n' "${pb}" >&2
    fail=1
    continue
  fi
  while IFS= read -r f; do
    [[ -n "${f}" ]] || continue
    # Apple patch(1) cannot unlink; golden empties the sibling. Ignore zero-byte leftovers.
    [[ -s "${f}" ]] || continue
    base="$(basename "${f}")"
    case "${base}" in
      converge.yml|converge.yaml) continue ;;
      *)
        printf 'error: extra playbook beside converge under %s: %s (ROLE-CONTRACT: single converge only)\n' \
          "${pb}" "${base}" >&2
        fail=1
        ;;
    esac
  done < <(find "${pb}" -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) -type f | sort)
done

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

exit 0
