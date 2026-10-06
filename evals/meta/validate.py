#!/usr/bin/env python3
"""CLI: meta/validate and meta/calibrate for TypeSafe meta-evals."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import yaml

from definition import DefinitionError, evaluate_definition
from discrimination import DiscriminationError, evaluate_discrimination
from load_env import MissingApiKeyError, load_typesafe_api_key

META_DIR = Path(__file__).resolve().parent
CALIBRATION_DIR = META_DIR / "calibration"

CALIBRATION_FILES = (
    "good-01.yaml",
    "good-02.yaml",
    "bad-subjective.yaml",
    "bad-borderline-multiclaim.yaml",
    "bad-discrimination.yaml",
)


def _load_candidate(path: Path) -> dict[str, Any]:
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise ValueError(f"Invalid YAML at {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError(f"Candidate YAML must be a mapping: {path}")
    return data


def run_meta(candidate: dict[str, Any]) -> dict[str, Any]:
    """Execute Meta-A then Meta-B. Returns PASS/FAIL/ERROR shaped result."""
    try:
        load_typesafe_api_key()
    except MissingApiKeyError as exc:
        return {
            "outcome": "ERROR",
            "pass": False,
            "error": str(exc),
            "definition": None,
            "discrimination": None,
        }

    try:
        definition = evaluate_definition(candidate)
    except DefinitionError as exc:
        return {
            "outcome": "ERROR",
            "pass": False,
            "error": str(exc),
            "definition": None,
            "discrimination": None,
        }

    try:
        discrimination = evaluate_discrimination(
            candidate, definition_passed=bool(definition["pass"])
        )
    except DiscriminationError as exc:
        return {
            "outcome": "ERROR",
            "pass": False,
            "error": str(exc),
            "definition": definition,
            "discrimination": None,
        }

    overall_pass = bool(definition["pass"]) and bool(discrimination["pass"])
    return {
        "outcome": "PASS" if overall_pass else "FAIL",
        "pass": overall_pass,
        "error": None,
        "definition": definition,
        "discrimination": discrimination,
    }


def _print_human(path: Path | None, result: dict[str, Any], *, verbose: bool) -> None:
    label = path.name if path else "(candidate)"
    outcome = result["outcome"]
    print(f"=== {label}: {outcome} ===")
    if result.get("error"):
        print(f"ERROR: {result['error']}")
        return

    definition = result["definition"]
    print("Meta-Eval A — Definition Quality")
    for name, dim in definition["dimensions"].items():
        mark = "✓" if dim["value"] else "✗"
        print(f"  {mark} {name}: score={dim['score']:.3f} value={dim['value']}")
    for reason in definition.get("reasons") or []:
        print(f"  {reason}")

    discrimination = result["discrimination"]
    print("Meta-Eval B — Known-Case Discrimination")
    print(f"  status: {discrimination['status']}")
    if discrimination["status"] == "ran":
        print(f"  positive_result: {discrimination['positive_result']}")
        print(f"  negative_result: {discrimination['negative_result']}")
        print(f"  pass: {discrimination['pass']}")
        if verbose:
            print(f"  positive detail: {discrimination.get('positive')}")
            print(f"  negative detail: {discrimination.get('negative')}")
    for reason in discrimination.get("reasons") or []:
        print(f"  {reason}")
    print(f"overall pass: {result['pass']}")


def _json_payload(path: Path | None, result: dict[str, Any]) -> dict[str, Any]:
    return {
        "path": str(path) if path else None,
        "meta_eval": {
            "outcome": result["outcome"],
            "pass": result["pass"],
            "error": result.get("error"),
            "definition": result.get("definition"),
            "discrimination": result.get("discrimination"),
        },
    }


def cmd_validate(args: argparse.Namespace) -> int:
    path = Path(args.eval).expanduser()
    if not path.is_file():
        # Allow paths relative to meta/ or evals/
        for base in (META_DIR, META_DIR.parent, Path.cwd()):
            candidate = base / args.eval
            if candidate.is_file():
                path = candidate
                break
    if not path.is_file():
        print(f"ERROR: candidate not found: {args.eval}", file=sys.stderr)
        return 2

    try:
        candidate = _load_candidate(path)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    result = run_meta(candidate)
    if args.format == "json":
        print(json.dumps(_json_payload(path, result), indent=2, sort_keys=True))
    else:
        _print_human(path, result, verbose=args.verbose)

    if result["outcome"] == "ERROR":
        return 2
    return 0 if result["pass"] else 1


def _expected_matches(result: dict[str, Any], expected: dict[str, Any]) -> list[str]:
    """Return list of dimension mismatch descriptions (empty = agree)."""
    misses: list[str] = []
    if result["outcome"] == "ERROR":
        misses.append(f"outcome ERROR (not comparable to expected): {result.get('error')}")
        return misses

    exp_def = expected.get("definition") or {}
    got_def = result["definition"]
    for dim in ("decidable", "executable", "single_claim", "binary_outcome"):
        if dim in exp_def:
            want = bool(exp_def[dim])
            got = bool(got_def["dimensions"][dim]["value"])
            if want != got:
                misses.append(f"definition.{dim}: expected {want}, got {got}")
    if "pass" in exp_def and bool(exp_def["pass"]) != bool(got_def["pass"]):
        misses.append(
            f"definition.pass: expected {bool(exp_def['pass'])}, got {got_def['pass']}"
        )

    exp_disc = expected.get("discrimination") or {}
    got_disc = result["discrimination"]
    if "status" in exp_disc and exp_disc["status"] != got_disc["status"]:
        misses.append(
            f"discrimination.status: expected {exp_disc['status']!r}, "
            f"got {got_disc['status']!r}"
        )
    if got_disc["status"] == "ran":
        for key in ("positive_result", "negative_result", "pass"):
            if key in exp_disc and exp_disc[key] is not None:
                if bool(exp_disc[key]) != bool(got_disc[key]):
                    misses.append(
                        f"discrimination.{key}: expected {bool(exp_disc[key])}, "
                        f"got {got_disc[key]}"
                    )
    if "pass" in expected and bool(expected["pass"]) != bool(result["pass"]):
        misses.append(
            f"overall.pass: expected {bool(expected['pass'])}, got {result['pass']}"
        )
    return misses


def cmd_calibrate(args: argparse.Namespace) -> int:
    rows: list[dict[str, Any]] = []
    agreed = 0
    errors = 0
    for name in CALIBRATION_FILES:
        path = CALIBRATION_DIR / name
        if not path.is_file():
            print(f"ERROR: missing calibration fixture {path}", file=sys.stderr)
            return 2
        try:
            candidate = _load_candidate(path)
        except ValueError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
        expected = candidate.get("expected")
        if not isinstance(expected, dict):
            print(f"ERROR: {path} missing expected: block", file=sys.stderr)
            return 2

        result = run_meta(candidate)
        misses = _expected_matches(result, expected)
        ok = not misses
        if result["outcome"] == "ERROR":
            errors += 1
            ok = False
        if ok:
            agreed += 1

        row = {
            "fixture": name,
            "outcome": result["outcome"],
            "pass": result["pass"],
            "agree": ok,
            "misses": misses,
            "error": result.get("error"),
        }
        rows.append(row)

        if args.format != "json":
            mark = "✓" if ok else "✗"
            print(f"{mark} {name}: outcome={result['outcome']} agree={ok}")
            for miss in misses:
                print(f"    {miss}")

    total = len(CALIBRATION_FILES)
    summary = {
        "agreed": agreed,
        "total": total,
        "errors": errors,
        "pass": agreed == total and errors == 0,
        "fixtures": rows,
    }

    if args.format == "json":
        print(json.dumps(summary, indent=2, sort_keys=True))
    else:
        print(f"calibrate: {agreed}/{total} agree (errors={errors})")

    return 0 if summary["pass"] else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="TypeSafe meta-eval validate/calibrate")
    sub = parser.add_subparsers(dest="command", required=True)

    p_val = sub.add_parser("validate", help="Run meta-evals on one candidate YAML")
    p_val.add_argument("eval", help="Path to candidate YAML")
    p_val.add_argument("--format", choices=("text", "json"), default="text")
    p_val.add_argument("--verbose", action="store_true")
    p_val.set_defaults(func=cmd_validate)

    p_cal = sub.add_parser("calibrate", help="Run 5/5 calibration gate")
    p_cal.add_argument("--format", choices=("text", "json"), default="text")
    p_cal.add_argument("--verbose", action="store_true")
    p_cal.set_defaults(func=cmd_calibrate)

    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
