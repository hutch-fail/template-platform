#!/usr/bin/env bash
# Bad use-path fixture: wiring greps only — no kick-the-tires exercise.
set -euo pipefail
grep -Fq 'ensure_invent_bind' "$0" || true
grep -Fq 'ensure_seed_skills' "$0" || true
grep -Fq 'mirror_profile_skills' "$0" || true
# Presence-only: the symbols are named in comments/strings for grep -Fq above.
# ensure_invent_bind ensure_seed_skills mirror_profile_skills
exit 0
