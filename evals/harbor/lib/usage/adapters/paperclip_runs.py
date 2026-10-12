"""Paperclip issue runs → usageJson."""

from __future__ import annotations

from typing import Any

from ..domain import CostQuote, RunContext, TokenUsage, UsageObservation
from ._http import get_json_optional


def parse_usage_json(uj: dict[str, Any] | None) -> tuple[TokenUsage | None, CostQuote | None]:
    if not isinstance(uj, dict):
        return None, None
    tin = int(
        uj.get("inputTokens")
        or uj.get("rawInputTokens")
        or uj.get("prompt_tokens")
        or 0
    )
    tout = int(
        uj.get("outputTokens")
        or uj.get("rawOutputTokens")
        or uj.get("completion_tokens")
        or 0
    )
    cache = int(
        uj.get("cachedInputTokens")
        or uj.get("rawCachedInputTokens")
        or uj.get("cached_tokens")
        or 0
    )
    tokens = TokenUsage(tin, tout, cache) if (tin or tout or cache) else None
    cost_usd = uj.get("costUsd")
    if cost_usd is None and uj.get("cacheAdjustedCostUsd") is not None:
        cost_usd = uj.get("cacheAdjustedCostUsd")
    cost = None
    if cost_usd is not None:
        cost = CostQuote(
            usd=float(cost_usd),
            kind="measured",
            basis="paperclip.runs.usageJson",
            model=uj.get("model"),
        )
    return tokens, cost


class PaperclipRunsSource:
    source_id = "paperclip.runs"

    def collect(self, ctx: RunContext) -> UsageObservation | None:
        runs = ctx.paperclip_runs
        ref = "ctx.paperclip_runs"
        if runs is None:
            if not ctx.paperclip_base or not ctx.issue_id:
                return None
            url = f"{ctx.paperclip_base.rstrip('/')}/api/issues/{ctx.issue_id}/runs"
            data = get_json_optional(url)
            if data is None:
                return None
            runs = data if isinstance(data, list) else data.get("data") or []
            ref = url

        best_tokens: TokenUsage | None = None
        best_cost: CostQuote | None = None
        for run in runs:
            if not isinstance(run, dict):
                continue
            uj = run.get("usageJson") or run.get("usage")
            tokens, cost = parse_usage_json(uj if isinstance(uj, dict) else None)
            if tokens and tokens.has_tokens():
                if best_tokens is None or tokens.total > best_tokens.total:
                    best_tokens = tokens
            if cost is not None:
                # Prefer positive measured; keep last zero as fallback signal.
                if best_cost is None or cost.usd > best_cost.usd:
                    best_cost = cost

        if best_tokens is None and best_cost is None:
            return UsageObservation(
                source_id=self.source_id,
                tokens=None,
                cost=None,
                confidence=0.1,
                raw_ref=ref,
            )

        # Tokens from Paperclip are authoritative for the issue run even when
        # costUsd is unplumbed (often 0); merge ignores zero measured costs.
        conf = 0.9 if best_tokens is not None else 0.3

        return UsageObservation(
            source_id=self.source_id,
            tokens=best_tokens,
            cost=best_cost,
            confidence=conf,
            raw_ref=ref,
        )
