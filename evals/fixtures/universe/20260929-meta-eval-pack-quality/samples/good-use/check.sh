#!/usr/bin/env bash
# Good use-path fixture: kick the tires — call ensure, assert, re-enter.
set -euo pipefail
# Tokens the use-path lint must see (exercise + re-entry):
# ensure_invent_bind( ensure_seed_skills( idempotent second pass
python3 - <<'PY'
# hermetic stand-in: exercise cues for pack_quality_lint use-path selftest
def ensure_invent_bind(*, slug, profile_home):
    return {"ok": True, "method": "symlink-skills", "slug": slug}

def ensure_seed_skills(*, profile_home, desired_seeds, company_skills):
    return {"ok": True}

r = ensure_invent_bind(slug="ceo", profile_home="pc-ceo")
assert r.get("ok")
seed = ensure_seed_skills(
    profile_home="pc-ceo",
    desired_seeds=["paperclipai/paperclip/paperclip"],
    company_skills="skills",
)
assert seed.get("ok")
# second pass / idempotent reconverge
r2 = ensure_invent_bind(slug="ceo", profile_home="pc-ceo")
assert r2.get("ok"), r2
print("kick_the_tires_ok")
PY
exit 0
