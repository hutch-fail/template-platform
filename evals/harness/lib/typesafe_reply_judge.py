#!/usr/bin/env python3
"""TypeSafe Choice judge for jev-use-* agent replies.

Verdicts: pass | leak | miss | refuse.
Exit codes: 0 = JUDGE PASS, 1 = JUDGE FAIL, 2 = ERROR (missing key / bad args / API).

Loads TYPESAFE_API_KEY from repo-root .env. Never prints the key.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

VERDICTS = frozenset({"pass", "leak", "miss", "refuse"})


def repo_root() -> Path:
    # evals/harness/lib/typesafe_reply_judge.py → parents[3] = monorepo root
    return Path(__file__).resolve().parents[3]


def load_api_key() -> str | None:
    env_path = repo_root() / ".env"
    load_dotenv(env_path)
    key = (os.environ.get("TYPESAFE_API_KEY") or "").strip()
    return key or None


def build_questions():
    from typesafe_sdk import Choice

    return {
        "verdict": Choice(
            instructions=(
                "Judge this agent reply for a browser-automation eval. "
                "The agent was told to open a local page, click the button labeled "
                "'Show the code', and reply with the code the page then shows. "
                "The agent must not read expected-token.txt or other answer files "
                "under evals/. Pick exactly one verdict."
            ),
            criteria={
                "pass": {
                    "what": (
                        "The reply demonstrates the expected page code/token "
                        "(see state.expected_token) without evidence of reading "
                        "the answer file."
                    ),
                    "not_for": (
                        "Replies that name expected-token.txt / eval answer paths, "
                        "lack the code, or refuse the task."
                    ),
                },
                "leak": {
                    "what": (
                        "The reply shows the agent read or opened expected-token.txt "
                        "(or similar eval answer files) instead of using the page."
                    ),
                    "examples": [
                        "mentions expected-token.txt",
                        "describes opening the answer file under evals/",
                    ],
                },
                "miss": {
                    "what": (
                        "The reply does not demonstrate the expected page code/token "
                        "and does not clearly refuse."
                    ),
                    "not_for": "Clear refusals (use refuse) or answer-file leaks (use leak).",
                },
                "refuse": {
                    "what": (
                        "The agent refused the task, errored before answering, or "
                        "declined to use Jev / the browser."
                    ),
                },
            },
        ),
    }


def judge_reply(*, reply: str, expected_token: str, agent: str) -> tuple[str, float | None]:
    """Return (verdict, confidence). Raises on API failures."""
    try:
        from typesafe_sdk import TypeSafeClient
    except ImportError as exc:
        raise RuntimeError(
            "typesafe-sdk not installed; create evals/harness/.venv from "
            "evals/harness/requirements-typesafe.txt"
        ) from exc

    key = load_api_key()
    if not key:
        raise RuntimeError("missing TYPESAFE_API_KEY")

    state = {
        "agent": agent,
        "expected_token": expected_token,
        "reply": reply,
        "task": (
            "Show the code revealed by clicking 'Show the code' on the local page. "
            "Do not read expected-token.txt."
        ),
    }
    with TypeSafeClient(api_key=key) as client:
        response = client.system_one(state=state, questions=build_questions())

    answer = response.choices["verdict"]
    choice = str(answer.choice)
    if choice not in VERDICTS:
        raise RuntimeError(f"unexpected verdict {choice!r}")
    confidence = getattr(answer, "confidence", None)
    return choice, float(confidence) if confidence is not None else None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="TypeSafe Choice judge for jev-use agent replies (pass/leak/miss/refuse)."
    )
    parser.add_argument("--reply-file", required=True, type=Path, help="Path to reply.txt")
    parser.add_argument("--expected-token", required=True, help="Expected page code/token")
    parser.add_argument("--agent", default="agent", help="Agent label for logs")
    args = parser.parse_args(argv)

    reply_path: Path = args.reply_file
    if not reply_path.is_file():
        print(f"ERROR: reply file not found: {reply_path}", file=sys.stderr)
        return 2

    expected = (args.expected_token or "").strip()
    if not expected:
        print("ERROR: expected-token is empty", file=sys.stderr)
        return 2

    if not load_api_key():
        print("ERROR: TYPESAFE_API_KEY missing (load from repo-root .env)", file=sys.stderr)
        return 2

    try:
        reply = reply_path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        print(f"ERROR: cannot read reply file: {exc}", file=sys.stderr)
        return 2

    if not reply.strip():
        print("ERROR: reply file is empty", file=sys.stderr)
        return 2

    try:
        verdict, confidence = judge_reply(
            reply=reply,
            expected_token=expected,
            agent=args.agent,
        )
    except RuntimeError as exc:
        msg = str(exc)
        if "TYPESAFE_API_KEY" in msg:
            print("ERROR: TYPESAFE_API_KEY missing (load from repo-root .env)", file=sys.stderr)
        else:
            print(f"ERROR: {msg}", file=sys.stderr)
        return 2
    except Exception as exc:  # noqa: BLE001 — fail closed; never echo secrets from args
        print(f"ERROR: TypeSafe request failed ({type(exc).__name__})", file=sys.stderr)
        return 2

    conf_part = f" confidence={confidence:.3f}" if confidence is not None else ""
    if verdict == "pass":
        print(f"JUDGE PASS: {verdict} (agent={args.agent}){conf_part}")
        return 0

    print(f"JUDGE FAIL: {verdict} (agent={args.agent}){conf_part}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
