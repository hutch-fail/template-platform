#!/usr/bin/env python3
"""Render results/summary.md from results/*/snapshot.json via the usage ledger helpers."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

LIB = Path(__file__).resolve().parents[1] / "lib"
sys.path.insert(0, str(LIB))

from usage.render import load_snapshots, render_summary_md  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--results-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "results",
    )
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--footnote", action="append", default=[])
    args = parser.parse_args()
    rows = load_snapshots(args.results_dir)
    md = render_summary_md(rows, footnotes=args.footnote or None)
    out = args.out or (args.results_dir / "summary.md")
    out.write_text(md if md.endswith("\n") else md + "\n", encoding="utf-8")
    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
