#!/usr/bin/env bash
# F2P check: sut.sh must print exactly FIXTURE_OK.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$("${here}/sut.sh")"
if [[ "${out}" == "FIXTURE_OK" ]]; then
  exit 0
fi
printf 'expected FIXTURE_OK, got %s\n' "${out}" >&2
exit 1
