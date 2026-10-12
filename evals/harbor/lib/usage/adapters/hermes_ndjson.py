"""Hermes / Paperclip run-log ndjson usage aggregation (sum)."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from ..domain import CostQuote, RunContext, TokenUsage, UsageObservation

_TOKEN_KEYS = {
    "input": ("input_tokens", "prompt_tokens", "rawInputTokens", "inputTokens"),
    "output": ("output_tokens", "completion_tokens", "rawOutputTokens", "outputTokens"),
    "cache": (
        "cached_tokens",
        "cache_read_input_tokens",
        "cachedInputTokens",
        "rawCachedInputTokens",
    ),
}


def _as_int(v: Any) -> int:
    try:
        return int(v or 0)
    except (TypeError, ValueError):
        return 0


def _usage_dicts(obj: Any) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if not isinstance(obj, dict):
        return found
    u = obj.get("usage")
    if isinstance(u, dict):
        found.append(u)
    for nest_key in ("response", "data", "message"):
        nest = obj.get(nest_key)
        if isinstance(nest, dict) and isinstance(nest.get("usage"), dict):
            found.append(nest["usage"])
    # usageJson shaped
    uj = obj.get("usageJson")
    if isinstance(uj, dict):
        found.append(uj)
    return found


def sum_ndjson_dir(directory: Path) -> tuple[TokenUsage, float | None]:
    tin = tout = cache = 0
    cost: float | None = None
    files = sorted(directory.glob("*.ndjson"))
    if directory.is_file() and directory.suffix == ".ndjson":
        files = [directory]
    for path in files:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(obj, dict):
                continue
            if obj.get("costUsd") is not None:
                try:
                    cost = float(obj["costUsd"])
                except (TypeError, ValueError):
                    pass
            for u in _usage_dicts(obj):
                for key in _TOKEN_KEYS["input"]:
                    if key in u:
                        tin += _as_int(u.get(key))
                        break
                for key in _TOKEN_KEYS["output"]:
                    if key in u:
                        tout += _as_int(u.get(key))
                        break
                for key in _TOKEN_KEYS["cache"]:
                    if key in u:
                        cache += _as_int(u.get(key))
                        break
            # top-level token fields
            for key in _TOKEN_KEYS["input"]:
                if key in obj:
                    tin += _as_int(obj.get(key))
                    break
    return TokenUsage(tin, tout, cache), cost


class HermesNdjsonSource:
    source_id = "hermes.ndjson"

    def collect(self, ctx: RunContext) -> UsageObservation | None:
        if not ctx.ndjson_dir:
            return None
        path = Path(ctx.ndjson_dir)
        if not path.exists():
            return None
        tokens, cost_usd = sum_ndjson_dir(path)
        if not tokens.has_tokens() and cost_usd is None:
            return None
        cost = None
        if cost_usd is not None:
            cost = CostQuote(
                usd=cost_usd,
                kind="measured",
                basis="hermes.ndjson.costUsd",
                model=None,
            )
        return UsageObservation(
            source_id=self.source_id,
            tokens=tokens if tokens.has_tokens() else None,
            cost=cost,
            confidence=0.7 if tokens.has_tokens() else 0.3,
            raw_ref=str(path),
        )
