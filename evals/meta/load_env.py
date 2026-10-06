"""Load TYPESAFE_API_KEY from process env, then repo-root .env (fail closed)."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

_REPO_ROOT_ENV = Path(__file__).resolve().parents[2] / ".env"


class MissingApiKeyError(RuntimeError):
    """TYPESAFE_API_KEY is unset after env + .env fallback."""


def load_typesafe_api_key() -> str:
    """Return TYPESAFE_API_KEY.

    Order: existing process environment, then ``../../.env`` relative to this
    package (repo root) via python-dotenv with ``override=False``. Never print
    or log the key value.
    """
    existing = os.environ.get("TYPESAFE_API_KEY", "").strip()
    if existing:
        return existing

    if _REPO_ROOT_ENV.is_file():
        load_dotenv(_REPO_ROOT_ENV, override=False)

    key = os.environ.get("TYPESAFE_API_KEY", "").strip()
    if not key:
        raise MissingApiKeyError(
            "TYPESAFE_API_KEY is missing. Set it in the environment "
            f"(CI secret) or in {_REPO_ROOT_ENV} (local only; gitignored)."
        )
    return key
