#!/usr/bin/env python3
"""Bash budget lint for GitHub Actions YAML and eval fixture shell.

Fail closed when inline bash is too large — a signal to extract a script or
Python helper instead of growing `run: |` blocks / fat `check.sh` files.

Thresholds (override via env):
  HERMES_EVAL_BASH_MAX_CONSECUTIVE  default 12  — max consecutive content lines
  HERMES_EVAL_BASH_MAX_YAML_PCT     default 35  — max % of a YAML file that is
                                                 `run:` block body (content lines)

Shell files (*.sh): consecutive budget only (a .sh file is mostly bash by
definition; percentage is not a useful refactor signal there).

YAML: consecutive lines inside each `run: |` / `run: >` block, and file-level
bash-body percentage.

Exit: 0 pass, 1 violations, 2 bad args.
Never prints secrets.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

DEFAULT_MAX_CONSECUTIVE = 12
DEFAULT_MAX_YAML_PCT = 35.0

# Captures indent, optional list dash, optional |/>, and remainder.
# Matches both `run: |` and `- run: |` (common GHA step forms).
RUN_KEY_RE = re.compile(r"^(\s*)(?:-\s+)?run:\s*(?:([|>])-?\s*)?(.*)$")


def _max_consecutive() -> int:
    raw = (os.environ.get("HERMES_EVAL_BASH_MAX_CONSECUTIVE") or "").strip()
    if not raw:
        return DEFAULT_MAX_CONSECUTIVE
    return max(1, int(raw))


def _max_yaml_pct() -> float:
    raw = (os.environ.get("HERMES_EVAL_BASH_MAX_YAML_PCT") or "").strip()
    if not raw:
        return DEFAULT_MAX_YAML_PCT
    return max(1.0, float(raw))


def _is_content(line: str) -> bool:
    s = line.strip()
    return bool(s) and not s.startswith("#")


def max_consecutive_content(lines: list[str]) -> tuple[int, int]:
    """Return (max_run, start_line_1based of that run)."""
    max_run = 0
    max_start = 1
    run = 0
    run_start = 1
    for i, line in enumerate(lines, start=1):
        if _is_content(line):
            if run == 0:
                run_start = i
            run += 1
            if run > max_run:
                max_run = run
                max_start = run_start
        else:
            run = 0
    return max_run, max_start


def iter_yaml_run_blocks(text: str) -> list[tuple[int, list[str]]]:
    """Yield (start_line_1based, body_lines) for each run: | / run: > block."""
    lines = text.splitlines()
    blocks: list[tuple[int, list[str]]] = []
    i = 0
    n = len(lines)
    while i < n:
        m = RUN_KEY_RE.match(lines[i])
        if not m:
            i += 1
            continue
        indent = len(m.group(1))
        block_style = m.group(2)  # | or > or None
        if block_style in ("|", ">"):
            body: list[str] = []
            j = i + 1
            while j < n:
                line = lines[j]
                if not line.strip():
                    body.append(line)
                    j += 1
                    continue
                lead = len(line) - len(line.lstrip(" "))
                if line.startswith("\t") or lead > indent:
                    body.append(line)
                    j += 1
                    continue
                break
            blocks.append((i + 2, body))  # 1-based first body line
            i = j
            continue
        # One-liner `run: cmd` — ignore (always within budget).
        i += 1
    return blocks


def lint_shell(path: Path, *, max_consecutive: int) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    run, start = max_consecutive_content(lines)
    errors: list[str] = []
    if run > max_consecutive:
        errors.append(
            f"{path}: consecutive bash content {run} lines starting at line "
            f"{start} (max {max_consecutive}). Extract a helper script or "
            f"Python module — do not grow check.sh / inline shell."
        )
    return errors


def lint_yaml(path: Path, *, max_consecutive: int, max_pct: float) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    total = len(lines) or 1
    errors: list[str] = []
    bash_content = 0
    for start, body in iter_yaml_run_blocks(text):
        content_n = sum(1 for b in body if _is_content(b))
        bash_content += content_n
        if content_n > max_consecutive:
            errors.append(
                f"{path}: run: block has {content_n} consecutive content lines "
                f"starting near line {start} (max {max_consecutive}). Move the "
                f"script to scripts/ or a composite action instead of inline YAML."
            )
    pct = 100.0 * bash_content / total
    if pct > max_pct:
        errors.append(
            f"{path}: inline bash is {pct:.0f}% of file lines "
            f"({bash_content}/{total}; max {max_pct:.0f}%). Prefer thin workflow "
            f"wrappers that call scripts."
        )
    return errors


def is_workflow_yaml(path: Path) -> bool:
    parts = {p.lower() for p in path.parts}
    if path.suffix.lower() not in {".yml", ".yaml"}:
        return False
    return ".github" in parts and ("workflows" in parts or "actions" in parts)


def is_eval_shell(path: Path) -> bool:
    if path.suffix.lower() != ".sh":
        return False
    name = path.name
    if name in {"check.sh", "p2p-smoke.sh"}:
        return True
    # Other fixture/helper shells under fixtures/ or evals/fixtures/
    parts = [p.lower() for p in path.parts]
    return "fixtures" in parts


def _excluded(path: Path, exclude_parts: set[str]) -> bool:
    return any(part in exclude_parts for part in path.parts)


def skip_live_enforcement(path: Path) -> bool:
    """Skip intentional selftest / F2P fixture files on PR-scoped scans.

    - ``samples/bad-*`` are expected to fail the lint (selftest owns them)
    - Any path under a directory with ``BASH_BUDGET_FIXTURE`` is owned by
      fixture-mode ``--all`` / assert-red, not by changed-path enforcement
    """
    parts = path.parts
    for i, part in enumerate(parts):
        if part == "samples" and i + 1 < len(parts) and parts[i + 1].startswith(
            "bad-"
        ):
            return True
    for parent in (path, *path.parents):
        if (parent / "BASH_BUDGET_FIXTURE").is_file():
            return True
    return False


def collect_targets(
    roots: list[Path],
    *,
    changed: list[str] | None,
    exclude_parts: set[str] | None = None,
) -> list[Path]:
    found: list[Path] = []
    exclude_parts = exclude_parts or set()
    if changed is not None:
        for raw in changed:
            raw = raw.strip()
            if not raw:
                continue
            # Try each root + as absolute/cwd-relative
            candidates = [Path(raw)]
            for root in roots:
                candidates.append(root / raw)
                # strip leading evals/ when scanning a product root
                if raw.startswith("evals/"):
                    candidates.append(root / raw[len("evals/") :])
            for c in candidates:
                if c.is_file() and not _excluded(c.resolve(), exclude_parts):
                    found.append(c.resolve())
                    break
        return sorted(set(found))

    for root in roots:
        if not root.is_dir():
            continue
        for p in root.rglob("*"):
            if not p.is_file():
                continue
            if _excluded(p, exclude_parts):
                continue
            if is_workflow_yaml(p) or is_eval_shell(p):
                found.append(p.resolve())
    return sorted(set(found))


def lint_paths(
    paths: list[Path],
    *,
    max_consecutive: int | None = None,
    max_yaml_pct: float | None = None,
) -> list[str]:
    max_c = max_consecutive if max_consecutive is not None else _max_consecutive()
    max_p = max_yaml_pct if max_yaml_pct is not None else _max_yaml_pct()
    errors: list[str] = []
    for path in paths:
        if is_workflow_yaml(path):
            errors.extend(
                lint_yaml(path, max_consecutive=max_c, max_pct=max_p)
            )
        elif is_eval_shell(path):
            errors.extend(lint_shell(path, max_consecutive=max_c))
    return errors


def run_selftest(samples_dir: Path) -> int:
    """Expect samples/good-* to pass and samples/bad-* to fail."""
    if not samples_dir.is_dir():
        print(f"error: selftest samples dir missing: {samples_dir}", file=sys.stderr)
        return 2
    max_c = _max_consecutive()
    max_p = _max_yaml_pct()
    agreed = 0
    errors = 0
    dirs = sorted(p for p in samples_dir.iterdir() if p.is_dir())
    if not dirs:
        print(f"error: no sample dirs under {samples_dir}", file=sys.stderr)
        return 2
    for sample in dirs:
        name = sample.name
        want_fail = name.startswith("bad-")
        want_pass = name.startswith("good-")
        if not want_fail and not want_pass:
            print(f"✗ {name}: name must start with good- or bad-", file=sys.stderr)
            errors += 1
            continue
        targets = collect_targets([sample], changed=None)
        if not targets:
            print(f"✗ {name}: no yaml/sh targets found", file=sys.stderr)
            errors += 1
            continue
        errs = lint_paths(targets, max_consecutive=max_c, max_yaml_pct=max_p)
        failed = bool(errs)
        if want_pass and failed:
            print(f"✗ {name}: expected pass, got:", file=sys.stderr)
            for e in errs:
                print(f"    {e}", file=sys.stderr)
            errors += 1
        elif want_fail and not failed:
            print(
                f"✗ {name}: expected fail under max_consecutive={max_c} "
                f"max_yaml_pct={max_p}, got pass",
                file=sys.stderr,
            )
            errors += 1
        else:
            print(f"✓ {name}: {'fail' if failed else 'pass'} as expected", file=sys.stderr)
            agreed += 1
    print(
        f"bash_budget_selftest: {agreed}/{len(dirs)} agree (errors={errors})",
        file=sys.stderr,
    )
    return 1 if errors or agreed != len(dirs) else 0


def _resolve_scan_root(fixture_dir: Path) -> Path:
    env = (os.environ.get("HERMES_EVAL_SCAN_ROOT") or "").strip()
    if env and Path(env).is_dir():
        return Path(env).resolve()
    return fixture_dir.resolve()


def drive_fixture(fixture_dir: Path) -> int:
    """Selftest + fixture/PR scan. Used by the thin check.sh wrapper."""
    samples = fixture_dir / "samples"
    rc = 0
    st = run_selftest(samples)
    if st != 0:
        rc = 1

    root = _resolve_scan_root(fixture_dir)
    fixture_mode = (root / "BASH_BUDGET_FIXTURE").is_file() or (
        fixture_dir / "BASH_BUDGET_FIXTURE"
    ).is_file() and root == fixture_dir.resolve()

    if fixture_mode:
        scan_rc = main(
            [
                "--all",
                "--scan-root",
                str(root),
                "--exclude-part",
                "samples",
            ]
        )
        if scan_rc != 0:
            rc = 1
    elif "HERMES_EVAL_CHANGED_PATHS" in os.environ:
        scan_rc = main(
            [
                "--scan-root",
                str(root),
                "--changed-paths",
                os.environ.get("HERMES_EVAL_CHANGED_PATHS") or "",
            ]
        )
        if scan_rc != 0:
            rc = 1
    else:
        print(
            f"bash_budget_skip reason=no_changed_paths root={root}",
            file=sys.stderr,
        )

    if rc == 0:
        print(f"bash_budget_ok root={root}")
    return rc


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--scan-root",
        action="append",
        default=[],
        help="Root to scan (repeatable). Default: cwd when linting without --changed-paths",
    )
    p.add_argument(
        "--changed-paths",
        default=None,
        help="Newline- or comma-separated relative paths (PR-scoped). "
        "When set (even empty), only those files are linted — no tree scan.",
    )
    p.add_argument(
        "--selftest",
        type=Path,
        metavar="SAMPLES_DIR",
        help="Run good-*/bad-* samples",
    )
    p.add_argument(
        "--drive-fixture",
        type=Path,
        metavar="FIXTURE_DIR",
        help="Run selftest + fixture/PR scan (thin check.sh entrypoint)",
    )
    p.add_argument(
        "--all",
        action="store_true",
        help="Tree-scan scan roots (ignore changed-paths skip). For fixtures.",
    )
    p.add_argument(
        "--exclude-part",
        action="append",
        default=[],
        help="Skip paths containing this path part (repeatable; e.g. samples)",
    )
    args = p.parse_args(argv)

    if args.drive_fixture is not None:
        return drive_fixture(args.drive_fixture)

    if args.selftest is not None:
        return run_selftest(args.selftest)

    roots = [Path(r).resolve() for r in args.scan_root] or [Path.cwd().resolve()]
    exclude_parts = set(args.exclude_part)
    changed: list[str] | None
    if args.all:
        changed = None
    elif args.changed_paths is not None:
        raw = args.changed_paths.replace(",", "\n")
        changed = [ln.strip() for ln in raw.splitlines() if ln.strip()]
    elif "HERMES_EVAL_CHANGED_PATHS" in os.environ:
        changed = [
            ln.strip()
            for ln in os.environ["HERMES_EVAL_CHANGED_PATHS"].splitlines()
            if ln.strip()
        ]
    else:
        # No path list and not --all → nothing to enforce (CI without diff).
        print("bash_budget_skip reason=no_changed_paths", file=sys.stderr)
        return 0

    if changed is not None and len(changed) == 0:
        print("bash_budget_skip reason=empty_changed_paths", file=sys.stderr)
        return 0

    targets = collect_targets(
        roots, changed=changed, exclude_parts=exclude_parts
    )
    # Only lint paths that look like workflow yaml or eval shell
    targets = [t for t in targets if is_workflow_yaml(t) or is_eval_shell(t)]
    if changed is not None:
        # PR-scoped: do not fail the PR for intentional fat/bad fixture samples.
        targets = [t for t in targets if not skip_live_enforcement(t)]
    if not targets:
        print("bash_budget_skip reason=no_matching_targets", file=sys.stderr)
        return 0

    errs = lint_paths(targets)
    if errs:
        for e in errs:
            print(f"error: {e}", file=sys.stderr)
        print(
            "bash_budget_fail: refactor — keep run:/check.sh blocks ≤ "
            f"{_max_consecutive()} consecutive content lines; YAML inline bash "
            f"≤ {_max_yaml_pct():.0f}% of file. See docs/evals.md § Bash budget.",
            file=sys.stderr,
        )
        return 1
    print(f"bash_budget_ok files={len(targets)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
