#!/usr/bin/env python3
"""Deterministic eval-pack quality lint (Tier 1).

Checks goal markdown structure, executive prose, grading, holdout signal,
fixture_dir resolution, and optional sibling *-result.md proof shape.

Exit 0 on pass; 1 on structural violations. Never prints secrets.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REQUIRED_SECTIONS = (
    "Decision",
    "User outcome",
    "Success criteria",
    "Dataset",
    "Grading",
    "Acceptance gates",
)

GRADER_RE = re.compile(r"(?i)\b(program|person|model|check\.sh|p2p-smoke|grader)\b")
HOLDOUT_RE = re.compile(
    r"(?i)\b(hold[- ]?out|holdout|train\s*/\s*test|train\s*\|\s*test|train.?test)\b"
)
PROOF_CUE_RE = re.compile(
    r"(?i)(```|make\s+eval/|exit\s*(code|=)|assert-red|eval/verify|eval/bars|certified.?red|verdict=)"
)
VERDICT_RE = re.compile(r"(?i)\b(Adopt|Hold|Inconclusive|Verdict|Recommendation)\b")
SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\s+")


def _section(text: str, name: str) -> str:
    pat = rf"^# {re.escape(name)}\s*\n(.*?)(?=^# |\Z)"
    m = re.search(pat, text, re.M | re.S)
    return m.group(1).strip() if m else ""


def _frontmatter(text: str) -> dict[str, str]:
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end < 0:
        return {}
    block = text[3:end]
    out: dict[str, str] = {}
    for line in block.splitlines():
        if ":" not in line or line.strip().startswith("#"):
            continue
        k, v = line.split(":", 1)
        out[k.strip()] = v.strip().strip("'\"")
    return out


def _sentences(prose: str) -> list[str]:
    cleaned = re.sub(r"\|.*\|", " ", prose)  # drop table rows
    cleaned = re.sub(r"^[-*].*$", " ", cleaned, flags=re.M)
    parts = SENTENCE_SPLIT.split(cleaned.strip())
    return [p.strip() for p in parts if len(p.strip()) > 20]


def _has_executive_lead(text: str, decision: str, user_outcome: str) -> bool:
    if re.search(r"^# Executive overview\s*$", text, re.M):
        overview = _section(text, "Executive overview")
        return len(_sentences(overview)) >= 2
    return len(_sentences(decision)) >= 2 and len(_sentences(user_outcome)) >= 2


def discover_goals(scan_root: Path) -> list[Path]:
    roots: list[Path] = []
    for cand in (scan_root / "goals", scan_root / "evals" / "goals"):
        if cand.is_dir():
            roots.append(cand)
    found: list[Path] = []
    for root in roots:
        for path in sorted(root.rglob("*.md")):
            name = path.name
            if name.endswith("-result.md") or name.startswith("_"):
                continue
            if name in {"PROCESS.md", "README.md"}:
                continue
            found.append(path)
    return found


def resolve_fixture_dir(scan_root: Path, fixture_dir: str) -> Path | None:
    if not fixture_dir:
        return None
    raw = fixture_dir.strip().rstrip("/")
    candidates = [
        scan_root / raw,
        scan_root / raw.removeprefix("evals/"),
        scan_root.parent / raw.removeprefix("evals/"),
    ]
    # Hub kit: scan_root is product; fixture under kit when bars run from kit copy.
    kit = Path(__file__).resolve().parents[2]
    candidates.append(kit / raw.removeprefix("evals/"))
    for c in candidates:
        if c.is_dir():
            return c
    return None


def lint_goal(
    path: Path,
    *,
    scan_root: Path,
    require_executive: bool = True,
) -> list[str]:
    errors: list[str] = []
    text = path.read_text(encoding="utf-8")
    fm = _frontmatter(text)

    for sec in REQUIRED_SECTIONS:
        if not re.search(rf"^# {re.escape(sec)}\s*$", text, re.M):
            errors.append(f"missing section #{sec}")

    decision = _section(text, "Decision")
    user_outcome = _section(text, "User outcome")
    if require_executive and not _has_executive_lead(text, decision, user_outcome):
        errors.append(
            "executive prose weak: need # Executive overview (≥2 sentences) "
            "or Decision + User outcome each ≥2 sentences"
        )

    success = _section(text, "Success criteria")
    grading = _section(text, "Grading")
    dataset = _section(text, "Dataset")
    limitations = _section(text, "Limitations")

    if success and re.search(r"\|.*Criterion", success):
        if not grading.strip() or grading.count("|") < 2:
            errors.append("Grading table empty while Success criteria exist")
        elif not GRADER_RE.search(grading):
            errors.append(
                "Grading rows must name program | person | model (or check.sh)"
            )
        if not dataset.strip():
            errors.append("Dataset missing while Success criteria exist")

    holdout_blob = f"{dataset}\n{limitations}\n{text}"
    if success and not HOLDOUT_RE.search(holdout_blob):
        errors.append(
            "holdout signal missing: Dataset or Limitations must mention "
            "hold-out / train|test (or name the gap)"
        )

    fixture_dir = fm.get("fixture_dir", "")
    f2p = fm.get("f2p_check", "")
    if fixture_dir:
        resolved = resolve_fixture_dir(scan_root, fixture_dir)
        if resolved is None:
            errors.append(f"fixture_dir does not resolve: {fixture_dir}")
        elif f2p:
            check = resolved / f2p
            if not check.is_file():
                errors.append(f"f2p_check missing: {check}")
            elif not (check.stat().st_mode & 0o111):
                errors.append(f"f2p_check not executable: {check}")

    result_path = path.with_name(path.stem + "-result.md")
    if result_path.is_file():
        rtext = result_path.read_text(encoding="utf-8")
        if not VERDICT_RE.search(rtext):
            errors.append(
                f"sibling result {result_path.name} needs Adopt/Hold/Inconclusive "
                "(or Verdict/Recommendation)"
            )
        if not PROOF_CUE_RE.search(rtext):
            errors.append(
                f"sibling result {result_path.name} needs a proof cue "
                "(fenced block, make eval/…, or exit code)"
            )

    return errors


def should_lint(path: Path, text: str, mode: str) -> bool:
    if mode == "all":
        return True
    # opt-in: Executive overview section or pack_quality frontmatter
    fm = _frontmatter(text)
    if fm.get("pack_quality", "").lower() in {"required", "ratchet", "1", "true"}:
        return True
    if re.search(r"^# Executive overview\s*$", text, re.M):
        return True
    return False


def run_lint(
    scan_root: Path,
    *,
    mode: str = "opt-in",
    paths: list[Path] | None = None,
) -> int:
    goals = paths if paths is not None else discover_goals(scan_root)
    fail = 0
    checked = 0
    for path in goals:
        text = path.read_text(encoding="utf-8")
        if "schema: goal/v1" not in text and "fixture_dir:" not in text:
            continue
        if not should_lint(path, text, mode):
            continue
        checked += 1
        errs = lint_goal(path, scan_root=scan_root, require_executive=True)
        if errs:
            fail = 1
            for e in errs:
                print(f"error: {path}: {e}", file=sys.stderr)
        else:
            print(f"pack_quality_ok path={path}")
    if checked == 0 and mode == "all":
        print("error: no goal packs found to lint", file=sys.stderr)
        return 1
    if checked == 0:
        print(f"pack_quality_skip reason=no_opt_in_goals root={scan_root}")
    return fail


def selftest(samples_root: Path) -> int:
    good = samples_root / "good" / "goal.md"
    bad = samples_root / "bad" / "goal.md"
    if not good.is_file() or not bad.is_file():
        print(f"error: missing samples under {samples_root}", file=sys.stderr)
        return 1
    good_errs = lint_goal(good, scan_root=good.parent, require_executive=True)
    bad_errs = lint_goal(bad, scan_root=bad.parent, require_executive=True)
    rc = 0
    if good_errs:
        rc = 1
        for e in good_errs:
            print(f"error: selftest good unexpectedly failed: {e}", file=sys.stderr)
    else:
        print("pack_quality_selftest_good_ok")
    if not bad_errs:
        rc = 1
        print("error: selftest bad unexpectedly passed", file=sys.stderr)
    else:
        print(f"pack_quality_selftest_bad_ok n_errors={len(bad_errs)}")
    return rc


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--scan-root", type=Path, required=True)
    p.add_argument("--mode", choices=("opt-in", "all"), default="opt-in")
    p.add_argument("--selftest", type=Path, default=None, help="samples/ directory")
    p.add_argument(
        "--selftest-only",
        action="store_true",
        help="Run selftest and exit (skip scan-root lint)",
    )
    p.add_argument("paths", nargs="*", type=Path)
    args = p.parse_args(argv)

    rc = 0
    if args.selftest is not None:
        rc = selftest(args.selftest) or rc
        if args.selftest_only:
            return rc
    paths = [Path(x) for x in args.paths] if args.paths else None
    rc = run_lint(args.scan_root, mode=args.mode, paths=paths) or rc
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
