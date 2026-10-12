#!/usr/bin/env python3
"""Select goal markdown for pack-quality lint / Tier-3 judge.

Default (no changed-path list, not fixture, not JUDGE_ALL): emit nothing so
historic packs are not graded. PR / path argv sets HERMES_EVAL_CHANGED_PATHS
or --changed-paths. Fixture mode scans the fixture tree. JUDGE_ALL scans all.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

GOAL_PREFIXES = ("goals/", "evals/goals/")


def _is_goal_md(rel: str) -> bool:
    rel = rel.replace("\\", "/").lstrip("./")
    if not rel.endswith(".md") or rel.endswith("-result.md"):
        return False
    return any(rel.startswith(p) for p in GOAL_PREFIXES)


def _discover(scan_root: Path) -> list[Path]:
    found: list[Path] = []
    for sub in (scan_root / "goals", scan_root / "evals" / "goals"):
        if not sub.is_dir():
            continue
        for path in sorted(sub.rglob("*.md")):
            if path.name.endswith("-result.md"):
                continue
            found.append(path)
    return found


def parse_changed_paths(raw: str | None) -> list[str] | None:
    """None = env/flag unset. Empty list = set but no files."""
    if raw is None:
        return None
    return [ln.strip() for ln in raw.splitlines() if ln.strip()]


def select_goals(
    scan_root: Path,
    *,
    changed_paths: list[str] | None,
    fixture_mode: bool = False,
    judge_all: bool = False,
) -> list[Path]:
    scan_root = scan_root.resolve()
    if fixture_mode:
        return _discover(scan_root)
    if changed_paths is not None:
        out: list[Path] = []
        for rel in changed_paths:
            rel_n = rel.replace("\\", "/").lstrip("./")
            if not _is_goal_md(rel_n):
                continue
            cand = (scan_root / rel_n).resolve()
            try:
                cand.relative_to(scan_root)
            except ValueError:
                continue
            if cand.is_file():
                out.append(cand)
        return out
    if judge_all:
        return _discover(scan_root)
    return []


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--scan-root", type=Path, required=True)
    p.add_argument(
        "--changed-paths",
        default=None,
        help="Newline-separated relative paths; empty string = no files",
    )
    p.add_argument("--fixture-mode", action="store_true")
    p.add_argument("--judge-all", action="store_true")
    args = p.parse_args(argv)

    changed = args.changed_paths
    if changed is None and "HERMES_EVAL_CHANGED_PATHS" in os.environ:
        changed = os.environ.get("HERMES_EVAL_CHANGED_PATHS", "")
    paths = parse_changed_paths(changed)
    for path in select_goals(
        args.scan_root,
        changed_paths=paths,
        fixture_mode=args.fixture_mode,
        judge_all=args.judge_all,
    ):
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
