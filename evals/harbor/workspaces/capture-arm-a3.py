#!/usr/bin/env python3
"""Capture Arm A experiment artifacts + multi-source usage ledger."""

from __future__ import annotations

import json
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

LIB = Path(__file__).resolve().parents[1] / "lib"
sys.path.insert(0, str(LIB))

from usage.collector import default_collector  # noqa: E402
from usage.domain import RunContext  # noqa: E402
from usage.render import merge_into_snapshot  # noqa: E402

API = "http://127.0.0.1:3100"
CO = "86361a8a-ef34-41c2-907c-4b6d7a0777ef"
BE = "8a33e990-c9d7-4d00-948f-00beedfc3675"
LITELLM = "http://127.0.0.1:4000"
MASTER_KEY = Path.home() / ".hermes" / "litellm" / "master.key"

state = json.loads(Path("/tmp/arm-a3-state.json").read_text())
IID = state["issueId"]
EXP = Path(state["experiment"])
WS = Path(state["workspace"])

iss = json.load(urllib.request.urlopen(f"{API}/api/issues/{IID}", timeout=30))
comments: list = []
for path in (
    f"/api/issues/{IID}/comments",
    f"/api/companies/{CO}/issues/{IID}/comments",
):
    try:
        data = json.load(urllib.request.urlopen(API + path, timeout=30))
        comments = (
            data
            if isinstance(data, list)
            else data.get("comments") or data.get("data") or []
        )
        break
    except Exception:
        continue

ut = subprocess.run(
    ["python3", "-m", "unittest", "tests.test_outputs"],
    cwd=str(WS),
    capture_output=True,
    text=True,
)

logroot = (
    Path("/home/ubuntu/.hermes/paperclip-data/instances/default/data/run-logs")
    / CO
    / BE
)
run_id = state.get("runId")
run_dir = logroot / run_id if run_id and (logroot / run_id).is_dir() else None
if run_dir is None and logroot.is_dir():
    # Prefer directory of ndjson files named by run id, else newest ndjson parent.
    nds = sorted(logroot.glob("*.ndjson"), key=lambda p: p.stat().st_mtime, reverse=True)
    run_dir = nds[0].parent if nds else None

errors: list[str] = []
if run_dir and run_dir.is_dir():
    for nd in sorted(run_dir.glob("*.ndjson")):
        for line in nd.read_text(errors="replace").splitlines():
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            chunk = obj.get("chunk") or ""
            if any(x in chunk for x in ("429", "Rate limited", "Final error")):
                errors.append(chunk[:240])

elapsed = None
started_at = None
if state.get("startedAt"):
    started_epoch = float(state["startedAt"])
    elapsed = time.time() - started_epoch
    started_at = datetime.fromtimestamp(started_epoch, tz=timezone.utc)

finished_at = datetime.now(tz=timezone.utc)

# Optional Harbor proxy tokens when Paperclip/cursor emit none.
harbor_proxy = state.get("harborResultPath") or state.get("harbor_result_path")
default_proxy = (
    Path(__file__).resolve().parents[1]
    / "jobs"
    / "matching-brackets-terminus-openai-free-medium"
    / "matching-brackets__ehkRtZp"
    / "result.json"
)
if not harbor_proxy and default_proxy.is_file():
    harbor_proxy = str(default_proxy)

ctx = RunContext(
    issue_id=IID,
    run_started_at=started_at,
    run_finished_at=finished_at,
    paperclip_base=API,
    litellm_base=LITELLM,
    litellm_master_key_path=str(MASTER_KEY) if MASTER_KEY.is_file() else None,
    ndjson_dir=str(run_dir) if run_dir else None,
    harbor_result_path=harbor_proxy,
    model_hint="cursor/auto",
    pricing_profile="cursor_ultra",
)
ledger = default_collector().collect(ctx)

snap = {
    "arm": "A",
    "path": "paperclip->hermes_local->hermes-cursor->cursor/auto",
    "identifier": iss.get("identifier"),
    "issueId": IID,
    "status": iss.get("status"),
    "reward": 1.0 if ut.returncode == 0 and iss.get("status") == "done" else 0.0,
    "unittest_rc": ut.returncode,
    "elapsedSec": round(elapsed, 1) if elapsed else None,
    "workspace": str(WS),
    "runDir": str(run_dir) if run_dir else None,
    "comments": [{"body": (c.get("body") or "")[:500]} for c in comments[:5]],
    "errorsSample": errors[-5:],
    "capturedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "versionPin": {
        "path": "paperclip->hermes_local->hermes-cursor->cursor/auto",
        "pricing_profile": "cursor_ultra",
    },
}
snap = merge_into_snapshot(snap, ledger)

EXP.mkdir(parents=True, exist_ok=True)
(EXP / "snapshot.json").write_text(json.dumps(snap, indent=2) + "\n")
(EXP / "artifact").mkdir(exist_ok=True)
(EXP / "artifact" / "matching_brackets.py").write_text(
    (WS / "matching_brackets.py").read_text()
)
ident = iss.get("identifier")
status = iss.get("status")
usage = snap.get("usage") or {}
notes_lines = [
    "# Arm A result",
    "",
    f"- Issue: {ident} `{status}`",
    f"- Unittest: rc={ut.returncode}",
    f"- Reward: {snap['reward']}",
    f"- Elapsed: {snap['elapsedSec']}s",
    f"- Tokens in/out/cache: {usage.get('input_tokens')} / {usage.get('output_tokens')} / {usage.get('cache_tokens')}",
    f"- tokenSourceId: {snap.get('tokenSourceId')}",
    f"- costUsd: {snap.get('costUsd')} ({snap.get('costKind')}; {snap.get('costBasis')})",
]
for n in snap.get("usageNotes") or []:
    notes_lines.append(f"- note: {n}")
notes_lines.append("")
(EXP / "notes.md").write_text("\n".join(notes_lines))
print(json.dumps(snap, indent=2))
