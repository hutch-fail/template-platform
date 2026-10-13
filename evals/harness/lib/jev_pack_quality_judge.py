#!/usr/bin/env python3
"""Tier-2 Jev pack-quality judge (TypeSafe Noul on goal markdown).

Holistic axes match Tier-3 LiteLLM (`llm_pack_quality_judge.py`) so authors
share one vocabulary. Grades real goal markdown — not toy calibration YAML.

Env:
  TYPESAFE_API_KEY — required for live judge / selftest (CI secret or .env)

Exit: 0 pass, 1 fail, 2 missing key / API ERROR / bad args.
Never echoes secrets.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

REQUIRED_AXES = (
    "mirror_prod",
    "headroom",
    "low_ambiguity",
    "adversarial_warning",
    "holdout",
    "executive_readable",
)

HOW_TO_PASS: dict[str, tuple[str, str]] = {
    "mirror_prod": (
        "Hermetic Success criteria must exercise the claim (entrypoint effect "
        "or unit/integration test runner + assert), not only wiring greps. "
        "User outcome may state production why when Limitations own the "
        "live/production gap as hold-out or out of scope.",
        "Add a hermetic exercise (call the entrypoint, run the pack's unit "
        "tests and assert an effect) and/or own the live gap in Limitations "
        "(hold-out / live out of scope). Do not rewrite User outcome to only "
        "describe running check.sh.",
    ),
    "headroom": (
        "The pack must be neither already saturated nor impossible-only.",
        "Say what a skilled try still misses, and what a pass would still "
        "not prove (Limitations).",
    ),
    "low_ambiguity": (
        "Two reviewers should agree on pass/fail from the stated checks.",
        "Name the program, person, or model grader per criterion in Grading; "
        "avoid vibe-only rows.",
    ),
    "adversarial_warning": (
        "The pack must state a specific reason a careful human (or someone "
        "gaming the checks) still gets it wrong — not only that a model "
        "fails today.",
        "In Limitations or Success criteria, name that reason (missing "
        "oracle, hidden state, scanning files the PR never touched, etc.). "
        "A slogan-only line such as 'this pack is hard for humans' is not "
        "enough.",
    ),
    "holdout": (
        "Train/test or hold-out discipline must be named, or Limitations "
        "must own the gap.",
        "Add a Dataset hold-out sentence, or write in Limitations that "
        "there is no split yet and why.",
    ),
    "executive_readable": (
        "A cold reviewer should skim Decision + Executive overview and know "
        "what a green result allows.",
        "Lead with 3–6 overview sentences and a Decision that states what "
        "a pass lets us believe and what it does not.",
    ),
}

THRESHOLD = 0.5

# Abstract Noul criteria — never mention sample domains or HTTP status codes.
_AXIS_NOULS: dict[str, tuple[str, str, str]] = {
    "mirror_prod": (
        "Do Success criteria hermetically exercise the core claim "
        "(entrypoint effect or running the pack's unit/integration test "
        "runner and asserting an effect), not only grepping wiring? If User "
        "outcome states live or production behavior, do Limitations own that "
        "gap as hold-out or out of scope?",
        "Criteria exercise the claim hermetically (entrypoint or unit-test "
        "runner + effect). Live/production User outcome is allowed when "
        "Limitations own that gap.",
        "Criteria only grep wiring while User outcome claims live or "
        "operator behavior, and Limitations do not own that gap.",
    ),
    "headroom": (
        "Is headroom plausible — neither already saturated nor "
        "impossible-only?",
        "The pack leaves room for a skilled try to miss something and states "
        "what a pass still would not prove.",
        "The pack is saturated (already always green) or impossible-only "
        "with no useful Limitations.",
    ),
    "low_ambiguity": (
        "Would two reviewers agree on pass/fail from the stated checks, "
        "with graders named (program / person / model)?",
        "Grading names who grades each criterion; checks are concrete.",
        "Pass/fail is vibe-only or graders are unspecified.",
    ),
    "adversarial_warning": (
        "Does the pack state a SPECIFIC reason a careful human or someone "
        "gaming the checks would still get it wrong?",
        "Limitations or Success criteria name a concrete failure mode "
        "(missing oracle, hidden state, wrong scan scope, etc.).",
        "Only 'model fails today' or a slogan like 'hard for humans' with "
        "no specific reason.",
    ),
    "holdout": (
        "Is train/test or hold-out discipline named, or does Limitations "
        "own the gap?",
        "Dataset names a hold-out / contrast, or Limitations explains why "
        "there is no split.",
        "No hold-out cue and Limitations does not own the gap.",
    ),
    "executive_readable": (
        "Can a non-author skim Decision + Executive overview and know what "
        "a green result allows (and does not)?",
        "Overview + Decision state belief granted by a pass and its limits.",
        "Missing or hollow Decision / Executive overview for a cold reader.",
    ),
}


def _kit_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _ensure_meta_on_path() -> None:
    meta = _kit_root() / "meta"
    s = str(meta)
    if s not in sys.path:
        sys.path.insert(0, s)


def format_fail(
    path: str,
    *,
    failed_axes: list[str],
    notes: str = "",
) -> str:
    lines = [f"error: pack-quality Jev fail path={path}"]
    for axis in failed_axes:
        means, fix = HOW_TO_PASS.get(
            axis,
            ("This axis failed.", "Fix the pack so the axis is true, then re-run."),
        )
        lines.append(f"axis {axis}: FAIL")
        lines.append(f"what this means: {means}")
        lines.append(f"how to pass: {fix}")
    if notes:
        notes = notes.replace("\n", " ").strip()
        if len(notes) > 400:
            notes = notes[:400] + "…"
        lines.append(f"jev notes: {notes}")
    return "\n".join(lines)


def judge_text(goal_markdown: str, *, path: str = "") -> dict[str, Any]:
    """Run six axis Nouls; code owns pass = all scores >= THRESHOLD."""
    _ensure_meta_on_path()
    from load_env import MissingApiKeyError, load_typesafe_api_key  # type: ignore
    from typesafe_sdk import Noul, NoulCriteria, TypeSafeClient

    try:
        load_typesafe_api_key()
    except MissingApiKeyError as exc:
        raise RuntimeError(str(exc)) from exc

    questions: dict[str, Any] = {}
    for axis, (instructions, true_c, false_c) in _AXIS_NOULS.items():
        questions[axis] = Noul(
            instructions=instructions,
            criteria=NoulCriteria(true=true_c, false=false_c),
        )

    state = {
        "goal_markdown": goal_markdown[:120_000],
        "path": path or "goal.md",
    }
    try:
        with TypeSafeClient() as client:
            response = client.system_one(state=state, questions=questions)
    except Exception as exc:  # noqa: BLE001
        raise RuntimeError(f"TypeSafe pack-quality judge failed: {exc}") from exc

    scores: dict[str, bool] = {}
    raw: dict[str, float] = {}
    for axis in REQUIRED_AXES:
        noul = float(response.nouls[axis].noul)
        raw[axis] = noul
        scores[axis] = noul >= THRESHOLD

    overall = all(scores.values())
    return {
        "pass": overall,
        "scores": scores,
        "raw_scores": raw,
        "notes": "",
    }


def _load_expected(path: Path) -> dict[str, Any]:
    import yaml

    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"expected.yaml must be a mapping: {path}")
    return data


def run_selftest(samples_dir: Path) -> int:
    """Judge each samples/jev-*/goal.md against sibling expected.yaml."""
    if not samples_dir.is_dir():
        print(f"error: selftest samples dir missing: {samples_dir}", file=sys.stderr)
        return 2

    dirs = sorted(
        p for p in samples_dir.iterdir() if p.is_dir() and p.name.startswith("jev-")
    )
    if not dirs:
        print(
            f"error: no jev-* sample dirs under {samples_dir}",
            file=sys.stderr,
        )
        return 2

    agreed = 0
    errors = 0
    for sample in dirs:
        goal = sample / "goal.md"
        expected_path = sample / "expected.yaml"
        if not goal.is_file() or not expected_path.is_file():
            print(
                f"✗ {sample.name}: missing goal.md or expected.yaml",
                file=sys.stderr,
            )
            errors += 1
            continue
        try:
            expected = _load_expected(expected_path)
            result = judge_text(goal.read_text(encoding="utf-8"), path=str(goal))
        except Exception as exc:  # noqa: BLE001
            print(f"✗ {sample.name}: ERROR {exc}", file=sys.stderr)
            errors += 1
            continue

        misses: list[str] = []
        exp_scores = expected.get("scores") or {}
        got_scores = result.get("scores") or {}
        for axis in REQUIRED_AXES:
            if axis in exp_scores and bool(exp_scores[axis]) != bool(
                got_scores.get(axis)
            ):
                misses.append(
                    f"scores.{axis}: expected {bool(exp_scores[axis])}, "
                    f"got {bool(got_scores.get(axis))}"
                )
        if "pass" in expected and bool(expected["pass"]) != bool(result.get("pass")):
            misses.append(
                f"pass: expected {bool(expected['pass'])}, got {bool(result.get('pass'))}"
            )

        if misses:
            print(f"✗ {sample.name}: disagree", file=sys.stderr)
            for m in misses:
                print(f"    {m}", file=sys.stderr)
        else:
            print(f"✓ {sample.name}: agree", file=sys.stderr)
            agreed += 1

    total = len(dirs)
    print(
        f"jev_pack_judge_selftest: {agreed}/{total} agree (errors={errors})",
        file=sys.stderr,
    )
    if errors or agreed != total:
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("goal", nargs="?", type=Path, help="Path to goal markdown")
    p.add_argument(
        "--selftest",
        type=Path,
        metavar="SAMPLES_DIR",
        help="Run labeled jev-* samples under SAMPLES_DIR",
    )
    p.add_argument(
        "--format-fail",
        action="store_true",
        help="Print canned how-to-pass for --axis (no API call)",
    )
    p.add_argument("--path", default="", help="Path shown in --format-fail output")
    p.add_argument(
        "--axis",
        action="append",
        default=[],
        help="Failed axis for --format-fail (repeatable)",
    )
    args = p.parse_args(argv)

    if args.format_fail:
        axes = args.axis or ["adversarial_warning"]
        path = args.path or (str(args.goal) if args.goal else "goals/unknown.md")
        print(format_fail(path, failed_axes=axes), file=sys.stderr)
        return 1

    if args.selftest is not None:
        return run_selftest(args.selftest)

    if args.goal is None:
        print(
            "error: goal path required unless --selftest or --format-fail",
            file=sys.stderr,
        )
        return 2

    try:
        text = args.goal.read_text(encoding="utf-8")
        result = judge_text(text, path=str(args.goal))
    except Exception as exc:  # noqa: BLE001
        msg = str(exc)
        if "TYPESAFE_API_KEY" in msg or "missing" in msg.lower():
            print(f"error: {msg}", file=sys.stderr)
            return 2
        print(f"error: jev pack-quality judge failed: {msg}", file=sys.stderr)
        return 1

    out = {
        "path": str(args.goal),
        "pass": result["pass"],
        "scores": result["scores"],
    }
    print(json.dumps(out, sort_keys=True))
    if not result.get("pass"):
        scores = result.get("scores") or {}
        failed = [k for k in REQUIRED_AXES if not bool(scores.get(k))]
        print(
            format_fail(str(args.goal), failed_axes=failed),
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
