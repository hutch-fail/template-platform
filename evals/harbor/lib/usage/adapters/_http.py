"""Tiny urllib helpers (stdlib only)."""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from typing import Any


def get_json(url: str, headers: dict[str, str] | None = None, timeout: float = 30) -> Any:
    req = urllib.request.Request(url, headers=headers or {"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def get_json_optional(
    url: str, headers: dict[str, str] | None = None, timeout: float = 30
) -> Any | None:
    try:
        return get_json(url, headers=headers, timeout=timeout)
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, json.JSONDecodeError):
        return None
