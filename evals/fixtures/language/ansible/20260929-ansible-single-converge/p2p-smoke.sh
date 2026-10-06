#!/usr/bin/env bash
# P2P: fixture still has converge.yml and no non-empty sibling playbooks after the patch.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test -x "${here}/check.sh"
test -f "${here}/golden.patch"
test -f "${here}/ansible/playbooks/converge.yml"
# After golden: sibling feature.yml must be gone or emptied (Apple patch cannot unlink).
if [[ -s "${here}/ansible/playbooks/feature.yml" ]]; then
  printf 'p2p: feature.yml still has content beside converge.yml\n' >&2
  exit 1
fi
extra=0
while IFS= read -r f; do
  [[ -n "${f}" ]] || continue
  [[ -s "${f}" ]] || continue
  base="$(basename "${f}")"
  case "${base}" in
    converge.yml|converge.yaml) ;;
    *)
      printf 'p2p: unexpected sibling playbook %s\n' "${base}" >&2
      extra=1
      ;;
  esac
done < <(find "${here}/ansible/playbooks" -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) -type f)
[[ "${extra}" -eq 0 ]]
exit 0
