#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test -x "${here}/check.sh"
test -f "${here}/golden.patch"
test -f "${here}/scripts/sync-secrets.sh"
test -f "${here}/scripts/lib/env.sh"
grep -Eq '^GITHUB_OWNER="coachmind-ca"' "${here}/scripts/lib/env.sh"
if grep -Eq '^: "\$\{GITHUB_OWNER:=' "${here}/scripts/lib/env.sh"; then
  printf 'p2p: env.sh still inherits GITHUB_OWNER\n' >&2
  exit 1
fi
exit 0
