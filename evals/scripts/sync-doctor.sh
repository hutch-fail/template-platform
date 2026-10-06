#!/usr/bin/env bash
# Org-wide doctor: every non-skipped include repo must be kit-class and
# roughly match hub tip (Makefile + harness present; packs for own leaf if hub has them).
set -euo pipefail

HUB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONSUMERS_ROOT="${CONSUMERS_ROOT:-$HOME/github.com/hutch-fail}"
ORG=hutch-fail
FAIL=0

LIST_SCRIPT="$HUB_ROOT/scripts/sync-list-repos.sh"
[[ -x "$LIST_SCRIPT" ]] || { echo "missing $LIST_SCRIPT" >&2; exit 1; }

hub_sha="$(git -C "$HUB_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
printf 'sync/doctor hub=%s consumers_root=%s\n' "$hub_sha" "$CONSUMERS_ROOT"

# Parse JSON (not TSV): bash IFS collapses consecutive tabs, so empty skip_reason
# would shift the path field.
while IFS= read -r row; do
  name="$(jq -r '.name' <<<"$row")"
  class="$(jq -r '.class' <<<"$row")"
  include="$(jq -r '.include|tostring' <<<"$row")"
  skip="$(jq -r '.skip_reason // empty' <<<"$row")"
  path="$(jq -r '.path // empty' <<<"$row")"
  if [[ "$include" != true ]]; then
    printf 'SKIP  %-24s class=%-10s reason=%s\n' "$name" "$class" "$skip"
    continue
  fi
  if [[ -z "$path" || ! -d "$path" ]]; then
    printf 'FAIL  %-24s uncloned\n' "$name"
    FAIL=1
    continue
  fi
  if [[ "$class" != kit ]]; then
    printf 'FAIL  %-24s expected kit, got %s (%s)\n' "$name" "$class" "$path"
    FAIL=1
    continue
  fi
  if [[ ! -f "$path/evals/Makefile" || ! -f "$path/evals/harness/goal.sh" ]]; then
    printf 'FAIL  %-24s kit incomplete\n' "$name"
    FAIL=1
    continue
  fi
  if [[ ! -f "$path/evals/scope.yaml" ]]; then
    printf 'FAIL  %-24s missing scope.yaml\n' "$name"
    FAIL=1
    continue
  fi
  # Hub tip fingerprint: compare Makefile to hub
  if ! cmp -s "$HUB_ROOT/Makefile" "$path/evals/Makefile"; then
    printf 'WARN  %-24s Makefile differs from hub tip\n' "$name"
  fi
  own_hub="$HUB_ROOT/goals/github.com/$ORG/$name"
  own_cons="$path/evals/goals/github.com/$ORG/$name"
  if [[ -d "$own_hub" ]]; then
    if [[ ! -d "$own_cons" ]]; then
      printf 'WARN  %-24s hub has own pack but consumer missing goals leaf\n' "$name"
    fi
  fi
  printf 'OK    %-24s kit scope=%s\n' "$name" "$(grep -E '^repo:' "$path/evals/scope.yaml" | head -1 | awk '{print $2}')"
done < <(CONSUMERS_ROOT="$CONSUMERS_ROOT" "$LIST_SCRIPT" --format json --consumers-root "$CONSUMERS_ROOT" --org "$ORG" | jq -c '.[]')

if [[ "$FAIL" -ne 0 ]]; then
  printf 'sync/doctor: FAIL\n' >&2
  exit 1
fi
printf 'sync/doctor: OK\n'
exit 0
