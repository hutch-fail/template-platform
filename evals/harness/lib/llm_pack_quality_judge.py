#!/usr/bin/env python3
"""Tier-3 LiteLLM pack-quality judge (OpenAI-compatible chat completions).

Env:
  EVAL_LLM_API_KEY  (fallback OPENAI_API_KEY)
  EVAL_LLM_BASE_URL (fallback OPENAI_API_BASE / OPENAI_BASE_URL)
  EVAL_LLM_MODEL    (required when tier runs)

Emits structured JSON verdict; code owns pass/fail. Never echoes secrets.
Exit: 0 pass, 1 fail, 2 skip/error configuration.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

RUBRIC = """You grade eval GOAL MARKDOWN pack quality (not agent trajectory).
Return ONLY JSON:
{"pass": bool, "scores": {"mirror_prod": bool, "headroom": bool, "low_ambiguity": bool,
 "adversarial_warning": bool, "holdout": bool, "executive_readable": bool},
 "notes": "short"}

Rubric (each must be true for pass=true):
1. mirror_prod: Tasks mirror stated production / User outcome
2. headroom: Headroom plausible (not saturated / not impossible-only)
3. low_ambiguity: Two experts would agree; grader checks are stated
4. adversarial_warning: Tasks justified as hard for humans, not only "model fails today"
5. holdout: Train/test or holdout discipline named (or Limitations owns the gap)
6. executive_readable: A non-author can skim intent from the overview/Decision
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
    # Strip accidental fences
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)
    data = json.loads(raw)
    if not isinstance(data, dict) or "pass" not in data:
        raise RuntimeError(f"judge returned unexpected JSON keys: {sorted(data)}")
    scores = data.get("scores") or {}
    required = (
        "mirror_prod",
        "headroom",
        "low_ambiguity",
        "adversarial_warning",
        "holdout",
        "executive_readable",
    )
    all_true = all(bool(scores.get(k)) for k in required)
    # Code owns pass/fail from structured scores
    data["pass"] = bool(all_true)
    return data


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("goal", type=Path, help="Path to goal markdown")
    args = p.parse_args(argv)

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
    return 0 if result.get("pass") else 1


if __name__ == "__main__":
    raise SystemExit(main())
