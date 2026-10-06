#!/usr/bin/env bash
# Unit matrix for scope frontmatter + path validation (host-only).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cli="${ROOT}/harness/goal.sh"
fx="evals/fixtures/github.com/hutch-fail/evals/20260921-scope-frontmatter-validation"
fail=0

if [[ ! -f "${ROOT}/harness/lib/scope.sh" ]]; then
  printf '✗ missing harness/lib/scope.sh\n' >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "'"${tmp}"'"; rm -f "'"${ROOT}/goals/github.com/hutch-fail/evals/.scope-unit-active-$$.md"'"' EXIT

miss() {
  printf '✗ %s\n' "$*" >&2
  fail=1
}

write_goal() {
  local path="$1"
  shift
  mkdir -p "$(dirname "${path}")"
  {
    printf '%s\n' '---'
    printf '%s\n' 'schema: goal/v1'
    printf '%s\n' 'id: 20260921-scope-unit'
    printf '%s\n' "fixture_dir: ${fx}"
    printf '%s\n' 'f2p_check: check.sh'
    printf '%s\n' 'p2p_check: p2p-smoke.sh'
    for line in "$@"; do
      printf '%s\n' "${line}"
    done
    printf '%s\n' '---'
    printf '%s\n' '# unit'
  } >"${path}"
}

expect_fail() {
  local label="$1" goal_arg="$2"
  local out rc
  set +e
  out="$(EVALS_ROOT="${tmp}" HERMES_EVALS_ROOT="${tmp}" bash "${cli}" parse "${goal_arg}" 2>&1)"
  rc=$?
  set -e
  if [[ "${rc}" -eq 0 ]]; then
    miss "${label}: expected fail; got: ${out}"
  fi
}

expect_ok() {
  local label="$1" goal_arg="$2" want_scope="$3"
  local out rc
  set +e
  out="$(EVALS_ROOT="${tmp}" HERMES_EVALS_ROOT="${tmp}" bash "${cli}" parse "${goal_arg}" 2>&1)"
  rc=$?
  set -e
  if [[ "${rc}" -ne 0 ]]; then
    miss "${label}: expected ok; got rc=${rc}: ${out}"
    return
  fi
  printf '%s\n' "${out}" | grep -q "scope=${want_scope}" \
    || miss "${label}: missing scope=${want_scope} in: ${out}"
}

# Happy paths
write_goal "${tmp}/goals/github.com/acme/demo/20260921-infer.md"
expect_ok 'infer repo' 'github.com/acme/demo/20260921-infer' 'repo'

write_goal "${tmp}/goals/github.com/acme/demo/20260921-repo.md" 'scope: repo'
expect_ok 'explicit repo' 'github.com/acme/demo/20260921-repo' 'repo'

write_goal "${tmp}/goals/github.com/acme/demo/20260921-repos-ok.md" \
  'scope: repo' \
  'repos: github.com/acme/demo'
expect_ok 'repos matches path' 'github.com/acme/demo/20260921-repos-ok' 'repo'

write_goal "${tmp}/goals/language/typescript/20260921-lang.md" \
  'scope: language' \
  'languages: typescript'
expect_ok 'language ok' 'language/typescript/20260921-lang' 'language'

write_goal "${tmp}/goals/language/python/20260921-lang-infer.md"
expect_ok 'infer language + default languages' 'language/python/20260921-lang-infer' 'language'

write_goal "${tmp}/goals/universe/20260921-uni.md" 'scope: universe'
expect_ok 'universe path' 'universe/20260921-uni' 'universe'

write_goal "${tmp}/goals/fixture-token-echo.md"
expect_ok 'legacy flat universe' 'fixture-token-echo' 'universe'

write_goal "${tmp}/goals/hub-kit-smoke.md"
expect_ok 'legacy hub-kit-smoke' 'hub-kit-smoke' 'universe'

write_goal "${tmp}/goals/scratch/20260921-active.md" 'scope: active'
expect_ok 'active under evals git' 'scratch/20260921-active' 'active'

write_goal "${tmp}/goals/odd-name.md"
expect_ok 'infer active for non-recipe flat' 'odd-name' 'active'

# Fail closed
write_goal "${tmp}/goals/github.com/acme/demo/20260921-galaxy.md" 'scope: galaxy'
expect_fail 'unknown scope' 'github.com/acme/demo/20260921-galaxy'

write_goal "${tmp}/goals/language/typescript/20260921-nolang.md" 'scope: language'
expect_fail 'language missing languages' 'language/typescript/20260921-nolang'

write_goal "${tmp}/goals/language/typescript/20260921-wronglang.md" \
  'scope: language' \
  'languages: python'
expect_fail 'languages path mismatch' 'language/typescript/20260921-wronglang'

write_goal "${tmp}/goals/github.com/acme/demo/20260921-uni-mis.md" 'scope: universe'
expect_fail 'universe under github.com' 'github.com/acme/demo/20260921-uni-mis'

write_goal "${tmp}/goals/language/typescript/20260921-repo-mis.md" 'scope: repo'
expect_fail 'repo under language/' 'language/typescript/20260921-repo-mis'

write_goal "${tmp}/goals/github.com/acme/demo/20260921-repos-bad.md" \
  'scope: repo' \
  'repos: github.com/other/other'
expect_fail 'repos mismatch' 'github.com/acme/demo/20260921-repos-bad'

write_goal "${tmp}/goals/github.com/acme/demo/20260921-langs-on-repo.md" \
  'scope: repo' \
  'languages: typescript'
expect_fail 'languages on non-language scope' 'github.com/acme/demo/20260921-langs-on-repo'

active="${ROOT}/goals/github.com/hutch-fail/evals/.scope-unit-active-$$.md"
write_goal "${active}" 'scope: active'
set +e
out="$(EVALS_ROOT="${ROOT}" HERMES_EVALS_ROOT="${ROOT}" bash "${cli}" parse "${active}" 2>&1)"
rc=$?
set -e
if [[ "${rc}" -ne 0 ]]; then
  miss "active under recipe goals should parse; got: ${out}"
fi
printf '✓ active under recipe goals ok\n'


# Real tracked goals still parse
for goal in fixture-token-echo \
  github.com/hutch-fail/evals/20260921-scope-frontmatter-validation \
  github.com/hutch-fail/evals/20260921-eval-scoping-design; do
  set +e
  out="$(EVALS_ROOT="${ROOT}" HERMES_EVALS_ROOT="${ROOT}" bash "${cli}" parse "${goal}" 2>&1)"
  rc=$?
  set -e
  if [[ "${rc}" -ne 0 ]]; then
    miss "tracked goal ${goal} must still parse: ${out}"
  fi
  printf '%s\n' "${out}" | grep -q '^scope=' \
    || miss "tracked goal ${goal} must print scope="
done

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

printf '✓ scope validation\n'
