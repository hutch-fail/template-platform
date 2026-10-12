#!/usr/bin/env bash
# Reject disposition=done when live-behavior was claimed but only structure exists.
# Usage: grade-structure-only-disposition.sh <case.json>
# Exit 0 = disposition allowed; exit 1 = reject (structure-only done).
set -euo pipefail

case_file="${1:-}"
[[ -n "${case_file}" && -f "${case_file}" ]] || {
  printf 'usage: %s <case.json>\n' "$(basename "$0")" >&2
  exit 2
}

python3 - "$case_file" <<'PY'
import json, sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    case = json.load(f)

disposition = (case.get("disposition") or "").strip().lower()
claim = (case.get("claim_kind") or "").strip().lower()
wrote = bool(case.get("wrote_iac_or_examples"))
ran = bool(case.get("ran_or_converged"))
surfaced = bool(case.get("surfaced_durable_artifact"))
waiver = bool(case.get("explicit_waiver"))

# Live-behavior claims require run/converge or durable surface (or waiver).
live_claims = {
    "install",
    "configure",
    "hire",
    "run",
    "publish",
    "demo",
    "integrate",
    "converge",
    "verify",
    "live",
}

needs_live = claim in live_claims or wrote
has_proof = ran or surfaced or waiver

if disposition == "done" and needs_live and not has_proof:
    print(
        "REJECT: disposition=done with structure-only evidence "
        f"(claim_kind={claim!r}, wrote_iac_or_examples={wrote}, "
        f"ran_or_converged={ran}, surfaced_durable_artifact={surfaced}, "
        f"explicit_waiver={waiver})",
        file=sys.stderr,
    )
    sys.exit(1)

if disposition in {"blocked", "in_review"} and needs_live and not has_proof:
    print(
        f"OK: disposition={disposition} appropriate for structure-only "
        "(not done)",
    )
    sys.exit(0)

print(f"OK: disposition={disposition} allowed for this case")
sys.exit(0)
PY
