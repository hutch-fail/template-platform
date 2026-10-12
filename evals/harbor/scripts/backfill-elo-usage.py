#!/usr/bin/env python3
"""One-shot backfill of Arm A/B snapshots from local + optional guest payloads."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

LIB = Path(__file__).resolve().parents[1] / "lib"
sys.path.insert(0, str(LIB))

from usage.collector import default_collector  # noqa: E402
from usage.domain import RunContext  # noqa: E402
from usage.render import merge_into_snapshot, render_summary_md  # noqa: E402

RESULTS = Path(__file__).resolve().parents[1] / "results"
HARBOR_PROXY = (
    Path(__file__).resolve().parents[1]
    / "jobs"
    / "matching-brackets-terminus-openai-free-medium"
    / "matching-brackets__ehkRtZp"
    / "result.json"
)


def _dt(s: str) -> datetime:
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    dt = datetime.fromisoformat(s)
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def backfill_arm_a(payload_dir: Path | None) -> Path:
    arm_dir = RESULTS / "20261008-211323-paperclip-hermes-cursor-auto"
    arm_dir.mkdir(parents=True, exist_ok=True)
    snap_path = arm_dir / "snapshot.json"
    base = {}
    if snap_path.is_file():
        base = json.loads(snap_path.read_text(encoding="utf-8"))

    paperclip_runs = None
    if payload_dir and (payload_dir / "def101-runs.json").is_file():
        paperclip_runs = json.loads(
            (payload_dir / "def101-runs.json").read_text(encoding="utf-8")
        )

    ctx = RunContext(
        issue_id=base.get("issueId") or "74375395-e847-43a1-8c00-e627c402f8f8",
        run_started_at=_dt("2026-10-08T21:13:40Z"),
        run_finished_at=_dt("2026-10-08T21:23:27Z"),
        paperclip_runs=paperclip_runs,
        harbor_result_path=str(HARBOR_PROXY) if HARBOR_PROXY.is_file() else None,
        model_hint="cursor/auto",
        pricing_profile="cursor_ultra",
    )
    ledger = default_collector().collect(ctx)
    snap = {
        "arm": "A",
        "path": "paperclip→hermes→cursor/auto",
        "identifier": base.get("identifier") or "DEF-101",
        "issueId": ctx.issue_id,
        "status": base.get("status") or "done",
        "reward": base.get("reward", 1.0),
        "elapsedSec": base.get("elapsedSec", 540.3),
        "versionPin": (
            "paperclip 2026.1001.0; cursor-agent 2026.10.01-e373342; "
            "hermes 0.21.5; hermes-cursor-provider v0.1.0"
        ),
        "capturedAt": datetime.now(tz=timezone.utc)
        .strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    # preserve prior fields
    for k in ("workspace", "runDir", "unittest_rc", "comments", "errorsSample"):
        if k in base:
            snap[k] = base[k]
    snap = merge_into_snapshot(snap, ledger)
    snap_path.write_text(json.dumps(snap, indent=2) + "\n", encoding="utf-8")
    (arm_dir / "notes.md").write_text(
        "\n".join(
            [
                "# Arm A result",
                "",
                f"- Issue: {snap.get('identifier')} `{snap.get('status')}`",
                f"- Reward: {snap.get('reward')}",
                f"- Elapsed: {snap.get('elapsedSec')}s",
                f"- Tokens: {snap['usage']}",
                f"- costUsd: {snap.get('costUsd')} ({snap.get('costKind')}; {snap.get('costBasis')})",
                f"- tokenSourceId: {snap.get('tokenSourceId')}",
                *[f"- note: {n}" for n in snap.get("usageNotes") or []],
                "",
            ]
        ),
        encoding="utf-8",
    )
    return snap_path


def backfill_arm_b(payload_dir: Path) -> Path:
    arm_dir = RESULTS / "20261008T180516Z-paperclip-opencode-litellm-premium"
    arm_dir.mkdir(parents=True, exist_ok=True)
    snap_path = arm_dir / "snapshot.json"

    run = json.loads((payload_dir / "arm-b-run.json").read_text(encoding="utf-8"))
    uj = run.get("usageJson") or {}
    paperclip_runs = [{"runId": run.get("id"), "status": run.get("status"), "usageJson": uj}]

    spend = None
    if (payload_dir / "litellm-spend.json").is_file():
        spend = json.loads((payload_dir / "litellm-spend.json").read_text(encoding="utf-8"))
    model_info = None
    if (payload_dir / "model-info.json").is_file():
        model_info = json.loads(
            (payload_dir / "model-info.json").read_text(encoding="utf-8")
        )

    started = run.get("startedAt") or "2026-10-08T18:27:00Z"
    finished = run.get("finishedAt") or "2026-10-08T18:40:40Z"

    ctx = RunContext(
        issue_id=None,
        run_started_at=_dt(started if "T" in str(started) else "2026-10-08T18:27:00Z"),
        run_finished_at=_dt(
            finished if "T" in str(finished) else "2026-10-08T18:40:40Z"
        ),
        paperclip_runs=paperclip_runs,
        litellm_spend_logs=spend if isinstance(spend, list) else None,
        litellm_model_info=model_info if isinstance(model_info, dict) else None,
        model_hint="meter/colin/premium",
        model_family_filter="deepseek",
        pricing_profile="litellm_model",
    )
    ledger = default_collector().collect(ctx)
    snap = {
        "arm": "B",
        "path": "paperclip→opencode→litellm/premium",
        "identifier": "DEF-99",
        "status": "done",
        "reward": 1.0,
        "elapsedSec": 754,
        "versionPin": (
            "paperclip 2026.1001.0; opencode 1.18.34; "
            "litellm meter/colin/premium @ :4000"
        ),
        "capturedAt": datetime.now(tz=timezone.utc)
        .strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    snap = merge_into_snapshot(snap, ledger)
    snap_path.write_text(json.dumps(snap, indent=2) + "\n", encoding="utf-8")
    (arm_dir / "notes.md").write_text(
        "\n".join(
            [
                "# Arm B result",
                "",
                "- Issue: DEF-99 `done`",
                f"- Reward: {snap.get('reward')}",
                f"- Elapsed: {snap.get('elapsedSec')}s",
                f"- Tokens: {snap['usage']}",
                f"- costUsd: {snap.get('costUsd')} ({snap.get('costKind')}; {snap.get('costBasis')})",
                f"- tokenSourceId: {snap.get('tokenSourceId')}",
                *[f"- note: {n}" for n in snap.get("usageNotes") or []],
                "",
            ]
        ),
        encoding="utf-8",
    )
    return snap_path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--payload-dir",
        type=Path,
        default=Path("/tmp/harbor-usage-backfill"),
        help="Directory with arm-b-run.json, litellm-spend.json, model-info.json, def101-runs.json",
    )
    args = ap.parse_args()
    a = backfill_arm_a(args.payload_dir if args.payload_dir.is_dir() else None)
    print("arm A", a)
    if (args.payload_dir / "arm-b-run.json").is_file():
        b = backfill_arm_b(args.payload_dir)
        print("arm B", b)
    rows = []
    for p in sorted(RESULTS.glob("*/snapshot.json")):
        rows.append(json.loads(p.read_text(encoding="utf-8")))
    rows.sort(key=lambda r: str(r.get("arm") or ""))
    footnotes = [
        "† Arm A tokens from Harbor terminus proxy when Paperclip/cursor emit none; "
        "cost from Cursor Ultra flat rate.",
        "Arm B cost prefers LiteLLM `/spend/logs` measured spend over Paperclip `costUsd: 0`.",
        "Generated by `harbor/scripts/backfill-elo-usage.py` + usage ledger.",
    ]
    md = render_summary_md(rows, footnotes=footnotes)
    (RESULTS / "summary.md").write_text(
        md if md.endswith("\n") else md + "\n", encoding="utf-8"
    )
    print("summary", RESULTS / "summary.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
