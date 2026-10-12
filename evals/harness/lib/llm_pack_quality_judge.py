#!/usr/bin/env python3
"""Tier-3 LiteLLM pack-quality judge (OpenAI-compatible chat completions).

Env:
  EVAL_LLM_API_KEY  (fallback OPENAI_API_KEY)
  EVAL_LLM_BASE_URL (fallback OPENAI_API_BASE / OPENAI_BASE_URL)
  EVAL_LLM_MODEL    (required when tier runs)

Emits structured JSON verdict; code owns pass/fail. Never echoes secrets.
A fail always prints canned how-to-pass on stderr (not only model notes).
Exit: 0 pass, 1 fail, 2 skip/error configuration.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

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
        "User outcome / production behavior must match what Success criteria actually grade — including kick-the-tires use, not only wiring greps.",
        "Rewrite Success criteria so each meaningful User outcome is observable (call the entrypoint / assert an effect), or move the extra claim to Limitations (wiring-only / use-path out of scope).",
    ),
    "headroom": (
        "The pack must be neither already saturated nor impossible-only.",
        "Say what a skilled try still misses, and what a pass would still not prove (Limitations).",
    ),
    "low_ambiguity": (
        "Two reviewers should agree on pass/fail from the stated checks.",
        "Name the program, person, or model grader per criterion in Grading; avoid vibe-only rows.",
    ),
    "adversarial_warning": (
        "The pack must state a specific reason a careful human (or someone gaming the checks) still gets it wrong — not only that a model fails today.",
        "In Limitations or Success criteria, name that reason (missing oracle, hidden state, scanning files the PR never touched, etc.). A slogan-only line such as 'this pack is hard for humans' is not enough.",
    ),
    "holdout": (
        "Train/test or hold-out discipline must be named, or Limitations must own the gap.",
        "Add a Dataset hold-out sentence, or write in Limitations that there is no split yet and why.",
    ),
    "executive_readable": (
        "A cold reviewer should skim Decision + Executive overview and know what a green result allows.",
        "Lead with 3–6 overview sentences and a Decision that states what a pass lets us believe and what it does not.",
    ),
}

RUBRIC = """You grade eval GOAL MARKDOWN pack quality (not agent trajectory).
Return ONLY JSON:
{"pass": bool, "scores": {"mirror_prod": bool, "headroom": bool, "low_ambiguity": bool,
 "adversarial_warning": bool, "holdout": bool, "executive_readable": bool},
 "notes": "short"}

Rubric (each must be true for pass=true):
1. mirror_prod: Tasks mirror stated production / User outcome (operator use /
   kick-the-tires graded by exercise, not only grep wiring)
2. headroom: Headroom plausible (not saturated / not impossible-only)
3. low_ambiguity: Two experts would agree; grader checks are stated
4. adversarial_warning: The pack states a SPECIFIC reason a careful human or an
   author gaming the checks would still get it wrong (ambiguity, missing oracle,
   hidden state, wrong scan scope, etc.). FAIL if the only signal is "the model
   fails today" OR a bolted slogan such as "this pack is hard for humans" with
   no specific reason.
5. holdout: Train/test or holdout discipline named (or Limitations owns the gap)
6. executive_readable: A non-author can skim Decision + overview for what a
   green result allows (not a vibe check on sentence count)
"""


def _resolve_env() -> tuple[str | None, str | None, str | None]:
    key = (os.environ.get("EVAL_LLM_API_KEY") or os.environ.get("OPENAI_API_KEY") or "").strip()
    base = (
        os.environ.get("EVAL_LLM_BASE_URL")
        or os.environ.get("OPENAI_API_BASE")
        or os.environ.get("OPENAI_BASE_URL")
        or ""
    ).strip() or None
    model = (os.environ.get("EVAL_LLM_MODEL") or "").strip() or None
    return (key or None, base, model)


def format_fail(
    path: str,
    *,
    failed_axes: list[str],
    notes: str = "",
) -> str:
    lines = [f"error: pack-quality LLM fail path={path}"]
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
        lines.append(f"llm notes: {notes}")
    return "\n".join(lines)


def judge_text(goal_markdown: str) -> dict:
    key, base, model = _resolve_env()
    if not key or not model:
        raise RuntimeError("missing EVAL_LLM_API_KEY/OPENAI_API_KEY or EVAL_LLM_MODEL")

    try:
        from openai import OpenAI
    except ImportError as exc:
        raise RuntimeError(
            "openai package missing — pip install -r harness/requirements-llm.txt"
        ) from exc

    client_kwargs: dict = {"api_key": key}
    if base:
        client_kwargs["base_url"] = base
    client = OpenAI(**client_kwargs)

    resp = client.chat.completions.create(
        model=model,
        temperature=0,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": RUBRIC},
            {"role": "user", "content": goal_markdown[:120_000]},
        ],
    )
    raw = (resp.choices[0].message.content or "").strip()
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)
    data = json.loads(raw)
    if not isinstance(data, dict) or "pass" not in data:
        raise RuntimeError(f"judge returned unexpected JSON keys: {sorted(data)}")
    scores = data.get("scores") or {}
    all_true = all(bool(scores.get(k)) for k in REQUIRED_AXES)
    data["pass"] = bool(all_true)
    return data


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("goal", nargs="?", type=Path, help="Path to goal markdown")
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

    if args.goal is None:
        print("error: goal path required unless --format-fail", file=sys.stderr)
        return 2

    key, _base, model = _resolve_env()
    if not key or not model:
        print(
            "llm_pack_quality_skip reason=missing_key_or_model",
            file=sys.stderr,
        )
        return 2

    try:
        text = args.goal.read_text(encoding="utf-8")
        result = judge_text(text)
    except Exception as exc:  # noqa: BLE001 — surface judge errors without secrets
        msg = str(exc)
        msg = re.sub(r"(sk-[A-Za-z0-9]+)", "sk-REDACTED", msg)
        print(f"error: llm pack-quality judge failed: {msg}", file=sys.stderr)
        return 1

    print(json.dumps({"path": str(args.goal), **result}, sort_keys=True))
    if not result.get("pass"):
        scores = result.get("scores") or {}
        failed = [k for k in REQUIRED_AXES if not bool(scores.get(k))]
        print(
            format_fail(
                str(args.goal),
                failed_axes=failed,
                notes=str(result.get("notes") or ""),
            ),
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
