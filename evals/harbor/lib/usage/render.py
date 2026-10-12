"""Snapshot + summary.md helpers."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .domain import UsageLedger


def merge_into_snapshot(snap: dict[str, Any], ledger: UsageLedger) -> dict[str, Any]:
    out = dict(snap)
    out.update(ledger.to_snapshot_fields())
    return out


def format_tokens(usage: dict[str, Any] | None) -> str:
    if not usage:
        return "— / — / —"
    return (
        f"{int(usage.get('input_tokens') or 0)} / "
        f"{int(usage.get('output_tokens') or 0)} / "
        f"{int(usage.get('cache_tokens') or 0)}"
    )


def format_extrapolate_cell(snap: dict[str, Any]) -> str:
    kind = snap.get("costKind") or "unknown"
    usd = snap.get("costUsd")
    basis = snap.get("costBasis") or ""
    if kind == "measured" and usd is not None:
        label = "LiteLLM spend" if "litellm" in basis else basis or "measured"
        return f"**${float(usd):.4f}** ({label})"
    if kind == "extrapolated" and usd is not None:
        if "cursor" in basis:
            return f"**${float(usd):.4f}** (Cursor Ultra)"
        if "litellm" in basis or "deepseek" in basis:
            return f"**${float(usd):.4f}** (DeepSeek/model-info)"
        return f"**${float(usd):.4f}** ({basis})"
    return "—"


def render_summary_md(rows: list[dict[str, Any]], *, footnotes: list[str] | None = None) -> str:
    """rows: snapshot-like dicts with arm/path/identifier/… + usage fields."""
    lines = [
        "# Matching-brackets ELO summary",
        "",
        "| Arm | Path | Version pin | Issue | Reward | Elapsed | Tokens in / out / cache | costUsd | Extrapolate |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for r in rows:
        arm = r.get("arm") or "?"
        path = r.get("path") or ""
        pin = r.get("versionPin") or "—"
        issue = r.get("identifier") or ""
        reward = r.get("reward")
        elapsed = r.get("elapsedSec")
        elapsed_s = f"{elapsed}s" if elapsed is not None else "—"
        tokens = format_tokens(r.get("usage") if isinstance(r.get("usage"), dict) else None)
        if r.get("tokenSourceId") == "harbor.result":
            tokens += " †"
        if (r.get("costKind") or "") == "measured" and r.get("costUsd") is not None:
            billed_s = f"{float(r['costUsd']):.4f}"
        else:
            billed_s = "0"
        extrap = format_extrapolate_cell(r)
        lines.append(
            f"| {arm} | {path} | {pin} | {issue} | {reward} | {elapsed_s} | {tokens} | {billed_s} | {extrap} |"
        )
    lines.append("")
    if footnotes:
        for fn in footnotes:
            lines.append(fn)
            lines.append("")
    notes = []
    for r in rows:
        for n in r.get("usageNotes") or []:
            notes.append(f"- Arm {r.get('arm')}: {n}")
    if notes:
        lines.append("## Usage notes")
        lines.append("")
        lines.extend(notes)
        lines.append("")
    return "\n".join(lines)


def load_snapshots(results_dir: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    if not results_dir.is_dir():
        return rows
    for snap_path in sorted(results_dir.glob("*/snapshot.json")):
        try:
            data = json.loads(snap_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if isinstance(data, dict):
            data.setdefault("_dir", snap_path.parent.name)
            rows.append(data)
    rows.sort(key=lambda r: str(r.get("arm") or ""))
    return rows
