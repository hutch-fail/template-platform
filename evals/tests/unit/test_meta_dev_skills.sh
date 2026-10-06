#!/usr/bin/env bash
# Contracts for meta-dev rule + author/develop/judge/meta skills.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0

require() {
  local path="$1"
  if [[ ! -e "${ROOT}/${path}" ]]; then
    printf '✗ missing %s\n' "${path}" >&2
    fail=1
  fi
}

require .cursor/rules/meta-dev.mdc
require skills/goal-author/SKILL.md
require skills/goal-develop/SKILL.md
require skills/goal-solve/SKILL.md
require skills/goal-judge/SKILL.md
require skills/meta-dev/SKILL.md
require skills/hypothesis-playground/SKILL.md
require skills/build-eval/SKILL.md
require skills/hillclimb/SKILL.md
require skills/hypothesis-playground/hypothesis.md

if ! grep -q '!.cursor/rules/' "${ROOT}/.gitignore"; then
  printf '✗ .gitignore must un-ignore .cursor/rules/\n' >&2
  fail=1
fi

if ! grep -q 'alwaysApply: true' "${ROOT}/.cursor/rules/meta-dev.mdc"; then
  printf '✗ meta-dev.mdc must set alwaysApply: true\n' >&2
  fail=1
fi

if ! grep -q 'goal-author' "${ROOT}/.cursor/rules/meta-dev.mdc"; then
  printf '✗ meta-dev.mdc must reference goal-author\n' >&2
  fail=1
fi

for name in goal-author goal-develop goal-solve goal-judge meta-dev hypothesis-playground build-eval hillclimb; do
  skill="${ROOT}/skills/${name}/SKILL.md"
  if [[ -f "${skill}" ]]; then
    if ! grep -Eq "^name:[[:space:]]*${name}\$" "${skill}"; then
      printf '✗ %s frontmatter name must be %s\n' "${name}" "${name}" >&2
      fail=1
    fi
  fi
  for adapter_root in .cursor/skills .agents/skills; do
    link="${ROOT}/${adapter_root}/${name}"
    if [[ ! -L "${link}" ]]; then
      printf '✗ missing relative adapter %s/%s\n' "${adapter_root}" "${name}" >&2
      fail=1
      continue
    fi
    target="$(readlink "${link}")"
    case "${target}" in
      ../../skills/"${name}") ;;
      *)
        printf '✗ %s/%s must link to ../../skills/%s (got %s)\n' \
          "${adapter_root}" "${name}" "${name}" "${target}" >&2
        fail=1
        ;;
    esac
  done
done

meta="${ROOT}/skills/meta-dev/SKILL.md"
for child in goal-author goal-develop goal-solve goal-judge build-eval hillclimb; do
  if ! grep -q "${child}" "${meta}"; then
    printf '✗ meta-dev must reference %s\n' "${child}" >&2
    fail=1
  fi
done

if ! grep -q 'Executive overview\|executive' "${ROOT}/skills/goal-author/SKILL.md"; then
  printf '✗ goal-author must mention executive overview\n' >&2
  fail=1
fi

if ! grep -qi 'proof' "${ROOT}/skills/goal-judge/SKILL.md"; then
  printf '✗ goal-judge must require proof snippets in results\n' >&2
  fail=1
fi

if ! grep -qi 'out of scope' "${ROOT}/skills/goal-judge/SKILL.md"; then
  printf '✗ goal-judge must mark soft LLM rubrics out of scope\n' >&2
  fail=1
fi

if ! grep -q 'assert-red' "${ROOT}/skills/goal-author/SKILL.md"; then
  printf '✗ goal-author must mention assert-red\n' >&2
  fail=1
fi

if ! grep -q 'verify' "${ROOT}/skills/goal-judge/SKILL.md"; then
  printf '✗ goal-judge must mention verify\n' >&2
  fail=1
fi

if ! grep -q 'eval/solve' "${ROOT}/skills/goal-judge/SKILL.md"; then
  printf '✗ goal-judge must document TB2a eval/solve\n' >&2
  fail=1
fi

if ! grep -q 'eval/solve' "${ROOT}/skills/goal-solve/SKILL.md"; then
  printf '✗ goal-solve must mention eval/solve\n' >&2
  fail=1
fi

if ! grep -q 'meta-dev' "${ROOT}/README.md"; then
  printf '✗ README.md must document meta-dev loop\n' >&2
  fail=1
fi

if ! grep -q 'TB2a' "${ROOT}/README.md"; then
  printf '✗ README.md must document TB2a agent-solver\n' >&2
  fail=1
fi

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi

printf '✓ meta-dev skills\n'
