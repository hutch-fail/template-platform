"""Harbor trial result.json agent_result tokens."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from ..domain import RunContext, TokenUsage, UsageObservation


def parse_harbor_result(data: dict[str, Any]) -> TokenUsage | None:
    ar = data.get("agent_result")
    if not isinstance(ar, dict):
        # Sometimes nested under trials[0]
        trials = data.get("trials") or data.get("results")
        if isinstance(trials, list) and trials:
            first = trials[0]
            if isinstance(first, dict):
                ar = first.get("agent_result") or first
        if not isinstance(ar, dict):
            ar = data
    tin = int(ar.get("n_input_tokens") or ar.get("input_tokens") or 0)
    tout = int(ar.get("n_output_tokens") or ar.get("output_tokens") or 0)
    cache = int(ar.get("n_cache_tokens") or ar.get("cache_tokens") or 0)
    # model_usage nested
    mu = ar.get("model_usage")
    if isinstance(mu, dict) and not (tin or tout or cache):
        for _model, stats in mu.items():
            if isinstance(stats, dict):
                tin += int(stats.get("n_input_tokens") or 0)
                tout += int(stats.get("n_output_tokens") or 0)
                cache += int(stats.get("n_cache_tokens") or 0)
    if not (tin or tout or cache):
        return None
    return TokenUsage(tin, tout, cache)


class HarborResultSource:
    source_id = "harbor.result"

    def collect(self, ctx: RunContext) -> UsageObservation | None:
        if not ctx.harbor_result_path:
            return None
        path = Path(ctx.harbor_result_path)
        if not path.is_file():
            return None
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return None
        tokens = parse_harbor_result(data)
        if tokens is None:
            return None
        # Proxy / alternate-run evidence — lower confidence than live Paperclip.
        return UsageObservation(
            source_id=self.source_id,
            tokens=tokens,
            cost=None,
            confidence=0.4,
            raw_ref=str(path),
        )
