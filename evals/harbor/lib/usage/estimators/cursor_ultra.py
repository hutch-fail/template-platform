"""Cursor Ultra subscription → flat $/token backfill."""

from __future__ import annotations

from ..domain import CostQuote, RunContext, TokenUsage

# Ultra $200 / mo; Other Models pool ~$400; Auto Cost input $1.25/MTok
# → 320M tok/mo → $0.625 / MTok on in+out+cache
ULTRA_USD_PER_MONTH = 200.0
OTHER_MODELS_POOL_USD = 400.0
AUTO_INPUT_USD_PER_MTOK = 1.25


def cursor_ultra_usd_per_mtok() -> float:
    cap_mtok = OTHER_MODELS_POOL_USD / AUTO_INPUT_USD_PER_MTOK
    return ULTRA_USD_PER_MONTH / cap_mtok


class CursorUltraEstimator:
    estimator_id = "cursor.ultra"

    def estimate(self, ctx: RunContext, tokens: TokenUsage) -> CostQuote | None:
        if ctx.pricing_profile != "cursor_ultra":
            return None
        if not tokens.has_tokens():
            return None
        rate = cursor_ultra_usd_per_mtok()
        usd = tokens.total / 1e6 * rate
        return CostQuote(
            usd=round(usd, 6),
            kind="extrapolated",
            basis="cursor.ultra.flat",
            model=ctx.model_hint or "cursor/auto",
        )
