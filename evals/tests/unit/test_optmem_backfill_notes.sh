#!/usr/bin/env bash
# Unit: hybrid backfill notes are lasting-shaped (not Touched:-only).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
script="${ROOT}/scripts/optmem-backfill-merged-prs.py"
fix="${ROOT}/fixtures/github.com/hutch-fail/evals/20261005-optmem-backfill-lasting-notes"
sample="${fix}/sample"
pr_json="${fix}/sample_pr.json"

miss() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ -f "${script}" ]] || miss "missing ${script}"

OPTMEM_BACKFILL_NO_LLM=1 python3 - "${script}" "${pr_json}" "${sample}" <<'PY' || miss "assertions"
import importlib.util
import json
import sys
from pathlib import Path

script, pr_path, sample_root = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("optmem_backfill", script)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)
pr = json.loads(Path(pr_path).read_text())
ev = mod.gather_evidence(pr, repo_root=Path(sample_root))
notes = mod.draft_notes_hybrid(ev, allow_llm=False)
assert ev.get("goals"), ev
assert ev.get("checks"), ev
blob = " ".join(notes).lower()
assert "dependabot" in blob or "pack gate" in blob, notes
for n in notes:
    assert len(n.encode()) <= 280, n
    assert not n.strip().lower().startswith("touched:"), n
    assert "Touched:" not in n or "lasting" in n.lower() or "proof" in n.lower(), n
print("test_optmem_backfill_notes_ok")
PY
