#!/usr/bin/env python3
"""Fill evals/templates/result.md from a run manifest (and compare.json if present)."""

import json
import sys
from pathlib import Path


def load_json(path: Path) -> dict:
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return data if isinstance(data, dict) else {}


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: write_result.py TEMPLATE MANIFEST OUT", file=sys.stderr)
        return 2
    template = Path(sys.argv[1]).read_text(encoding="utf-8")
    manifest_path = Path(sys.argv[2])
    out_path = Path(sys.argv[3])
    manifest = load_json(manifest_path)
    compare = load_json(manifest_path.parent / "compare.json")

    def raw(key: str) -> str:
        if key in compare and str(compare.get(key, "")) != "":
            return str(compare[key])
        if key in manifest and str(manifest.get(key, "")) != "":
            return str(manifest[key])
        return ""

    def show(key: str) -> str:
        value = raw(key)
        return value if value else "—"

    command = raw("command") or "unknown"
    verdict = raw("verdict") or "unknown"
    goal_id = raw("goal_id") or "this test"
    tokens = raw("tokens")
    adoption = raw("adoption")

    if command == "assert-red" and verdict == "certified_red":
        recommendation = "Inconclusive"
        opening = (
            f"The starting point is still broken, so {goal_id} is ready to run. "
            "This note is not a result."
        )
        outcome = "No one has tried the fix yet."
        blocking = "None yet. The attempt has not been made."
        comparison = "No before-and-after numbers yet."
        next_action = "Run the attempt, then fill this report from that run."
    elif command == "assert-red":
        recommendation = "Hold"
        opening = (
            f"The starting point for {goal_id} was already fixed. "
            "The test cannot show that an attempt caused the fix."
        )
        outcome = "Nothing new was shown for the user."
        blocking = "The test was already passing before any attempt."
        comparison = "No comparison. The baseline was already a pass."
        next_action = "Change the test so the starting program is actually broken."
    elif command == "ab" and verdict == "pass" and tokens != "parsed":
        recommendation = "Inconclusive"
        opening = (
            f"On {goal_id}, the Graft tries fixed the bug as often as the tries without notes"
            f" ({show('treatment_success')} of {show('trials')} versus "
            f"{show('control_success')} of {show('trials')}). "
            f"Median time was {show('treatment_median_wall')}s with notes and "
            f"{show('control_median_wall')}s without. "
            "Token counts were not recorded, so this run cannot support an install decision."
        )
        outcome = "The bug still got fixed when Graft notes were present."
        blocking = "Token counts are missing. One small case is not enough to install Graft."
        comparison = "\n".join(
            [
                "| Measure | Without notes | With Graft notes | Requirement | Result |",
                "| --- | --- | --- | --- | --- |",
                (
                    f"| Fixes that worked | {show('control_success')}/{show('trials')} | "
                    f"{show('treatment_success')}/{show('trials')} | "
                    "Each side at least 2 of 3; Graft at least as often | Met |"
                ),
                (
                    f"| Median time | {show('control_median_wall')}s | "
                    f"{show('treatment_median_wall')}s | "
                    f"Graft at most {show('max_wall_ratio')} times as long | Met |"
                ),
                "| Tokens | Not recorded | Not recorded | If counted, Graft at most 20% more | Not scored |",
            ]
        )
        next_action = "Record token counts on a broader set of bugs before deciding to install Graft."
    elif command == "ab" and verdict == "pass":
        recommendation = "Hold"
        opening = (
            f"The checks for {goal_id} passed, including token counts. "
            "A person still has to decide whether to install the change. This report does not install it."
        )
        outcome = "The measured checks passed on this case."
        blocking = "None of the written gates failed. Scope may still be too small to adopt."
        comparison = (
            f"Graft median time {show('treatment_median_wall')}s versus "
            f"{show('control_median_wall')}s without notes. "
            f"Token ratio {show('token_ratio')} (limit {show('max_token_ratio')})."
        )
        next_action = "Read the case list and decide. Do not treat one report as a rollout."
    elif command == "ab":
        recommendation = "Hold"
        opening = f"The checks for {goal_id} failed ({show('reason')}). Do not adopt from this run."
        outcome = "The user outcome in the specification was not met."
        blocking = f"Failed gate: {show('reason')}."
        comparison = (
            f"Without notes: {show('control_success')}/{show('trials')} fixes, "
            f"median {show('control_median_wall')}s. "
            f"With notes: {show('treatment_success')}/{show('trials')} fixes, "
            f"median {show('treatment_median_wall')}s."
        )
        next_action = "Fix the failing gate and run the same cases again. Do not move the pass line after seeing these numbers."
    elif verdict == "pass":
        recommendation = "Hold"
        opening = f"The program checks for {goal_id} passed. That shows the checked behavior works on this case."
        outcome = "The checked behavior succeeded."
        blocking = "None of the program checks failed."
        comparison = "This command does not compare two versions."
        next_action = "Use the specification to decide what this pass is allowed to change."
    else:
        recommendation = "Hold"
        opening = f"{goal_id} did not pass ({command}, {verdict})."
        outcome = "The checked behavior did not succeed."
        blocking = "A required check failed."
        comparison = "See the manifest in this run folder for exit codes."
        next_action = "Fix the failed check without weakening the test."

    if adoption == "inconclusive" and command == "ab":
        recommendation = "Inconclusive"
        opening += " These tries used stand-in solvers, not a live model."

    evidence_lines = [
        f"Goal `{goal_id}`. Command `{command}`.",
        "Program checks grade the fix. A second model does not grade the writing.",
        "Can it succeed at all, and does it succeed on every try, are separate questions. Read the counts above as tries on this case, not as a rate across many bugs.",
        "- `manifest.json` in this run directory",
    ]
    if compare:
        evidence_lines.append("- `compare.json` in this run directory")
    if raw("transcript"):
        evidence_lines.append(f"- `{raw('transcript')}`")
    if tokens == "unparsed":
        evidence_lines.append("Token counts were missing, so the token row is unknown, not a pass.")

    fields = {
        "recommendation": recommendation,
        "opening": opening,
        "outcome": outcome,
        "blocking": blocking,
        "comparison": comparison,
        "evidence": "\n".join(evidence_lines),
        "next_action": next_action,
    }
    text = template
    for key, value in fields.items():
        text = text.replace("{{" + key + "}}", value)
    if "{{" in text:
        print("result template has an unfilled placeholder", file=sys.stderr)
        return 2
    out_path.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
