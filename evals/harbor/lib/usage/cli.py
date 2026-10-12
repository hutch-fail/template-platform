"""CLI: collect usage for a run context JSON and/or render summary.md."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# Allow `python -m usage` when cwd/lib is on path, and script execution.
if __name__ == "__main__" and (__package__ is None or __package__ == ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from usage.collector import default_collector
    from usage.domain import RunContext
    from usage.render import load_snapshots, merge_into_snapshot, render_summary_md
else:
    from .collector import default_collector
    from .domain import RunContext
    from .render import load_snapshots, merge_into_snapshot, render_summary_md


def _parse_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    s = value.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    dt = datetime.fromisoformat(s)
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def context_from_dict(data: dict) -> RunContext:
    return RunContext(
        issue_id=data.get("issue_id") or data.get("issueId"),
        run_started_at=_parse_dt(data.get("run_started_at") or data.get("startedAt")),
        run_finished_at=_parse_dt(data.get("run_finished_at") or data.get("finishedAt")),
        paperclip_base=data.get("paperclip_base"),
        litellm_base=data.get("litellm_base"),
        litellm_master_key_path=data.get("litellm_master_key_path"),
        ndjson_dir=data.get("ndjson_dir"),
        harbor_result_path=data.get("harbor_result_path"),
        model_hint=data.get("model_hint"),
        pricing_profile=data.get("pricing_profile") or "none",
        paperclip_runs=data.get("paperclip_runs"),
        litellm_spend_logs=data.get("litellm_spend_logs"),
        litellm_model_info=data.get("litellm_model_info"),
        model_family_filter=data.get("model_family_filter"),
    )


def cmd_collect(args: argparse.Namespace) -> int:
    ctx_path = Path(args.context)
    ctx = context_from_dict(json.loads(ctx_path.read_text(encoding="utf-8")))
    ledger = default_collector().collect(ctx)
    out = ledger.to_snapshot_fields()
    out["notes"] = ledger.notes
    text = json.dumps(out, indent=2) + "\n"
    if args.out:
        Path(args.out).write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)
    return 0


def cmd_merge_snapshot(args: argparse.Namespace) -> int:
    snap_path = Path(args.snapshot)
    snap = json.loads(snap_path.read_text(encoding="utf-8"))
    ctx = context_from_dict(json.loads(Path(args.context).read_text(encoding="utf-8")))
    ledger = default_collector().collect(ctx)
    merged = merge_into_snapshot(snap, ledger)
    text = json.dumps(merged, indent=2) + "\n"
    dest = Path(args.out) if args.out else snap_path
    dest.write_text(text, encoding="utf-8")
    sys.stdout.write(text)
    return 0


def cmd_summary(args: argparse.Namespace) -> int:
    results = Path(args.results_dir)
    rows = load_snapshots(results)
    md = render_summary_md(rows, footnotes=args.footnote or None)
    out = Path(args.out) if args.out else results / "summary.md"
    out.write_text(md, encoding="utf-8")
    sys.stdout.write(md)
    if not md.endswith("\n"):
        sys.stdout.write("\n")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="usage", description="Harbor usage ledger")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_collect = sub.add_parser("collect", help="Collect usage for a context JSON")
    p_collect.add_argument("--context", required=True, help="RunContext JSON path")
    p_collect.add_argument("--out", help="Write ledger JSON here")
    p_collect.set_defaults(func=cmd_collect)

    p_merge = sub.add_parser("merge-snapshot", help="Merge ledger into snapshot.json")
    p_merge.add_argument("--snapshot", required=True)
    p_merge.add_argument("--context", required=True)
    p_merge.add_argument("--out", help="Default: overwrite snapshot")
    p_merge.set_defaults(func=cmd_merge_snapshot)

    p_sum = sub.add_parser("summary", help="Render summary.md from results/*/snapshot.json")
    p_sum.add_argument("--results-dir", required=True)
    p_sum.add_argument("--out", help="Default: <results-dir>/summary.md")
    p_sum.add_argument("--footnote", action="append", default=[])
    p_sum.set_defaults(func=cmd_summary)

    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
