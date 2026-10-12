"""Extrapolate from LiteLLM /v1/model/info rates (or DeepSeek V3.2 list fallback)."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from ..adapters._http import get_json_optional
from ..domain import CostQuote, RunContext, TokenUsage

# Fallback list (DeepSeek V3.2 non-thinking) when model_info unavailable.
_FALLBACK_IN = 0.28 / 1e6
_FALLBACK_CACHE = 0.028 / 1e6
_FALLBACK_OUT = 0.42 / 1e6


def _rates_from_model_info(
    payload: dict[str, Any], model_hint: str | None
) -> tuple[float, float, float, str] | None:
    data = payload.get("data") if isinstance(payload.get("data"), list) else None
    rows = data if data is not None else []
    if not rows and isinstance(payload, list):
        rows = payload
    hint = (model_hint or "").lower()
    chosen = None
    for row in rows:
        if not isinstance(row, dict):
            continue
        name = str(row.get("model_name") or row.get("id") or "")
        if hint and hint == name.lower():
            chosen = row
            break
        if hint and hint in name.lower():
            chosen = row
    if chosen is None:
        for row in rows:
            name = str(row.get("model_name") or "")
            if "premium" in name.lower():
                chosen = row
                break
    if chosen is None:
        return None
    info = chosen.get("model_info") or {}
    params = chosen.get("litellm_params") or {}
    tin = info.get("input_cost_per_token")
    tout = info.get("output_cost_per_token")
    tcache = info.get("cache_read_input_token_cost")
    if tin is None or tout is None:
        return None
    if tcache is None:
        tcache = 0.0
    label = str(params.get("model") or chosen.get("model_name") or model_hint)
    return float(tin), float(tcache), float(tout), label


def compute_cost(
    tokens: TokenUsage,
    rate_in: float,
    rate_cache: float,
    rate_out: float,
    *,
    additive_cache: bool,
) -> float:
    """Harbor-style: cache ⊆ input when not additive; Paperclip: in+cache additive."""
    if additive_cache:
        return (
            tokens.input_tokens * rate_in
            + tokens.cache_tokens * rate_cache
            + tokens.output_tokens * rate_out
        )
    miss = max(0, tokens.input_tokens - tokens.cache_tokens)
    cached = min(tokens.input_tokens, tokens.cache_tokens)
    return miss * rate_in + cached * rate_cache + tokens.output_tokens * rate_out


class LiteLLMModelInfoEstimator:
    estimator_id = "litellm.model_info"

    def estimate(self, ctx: RunContext, tokens: TokenUsage) -> CostQuote | None:
        if ctx.pricing_profile != "litellm_model":
            return None
        if not tokens.has_tokens():
            return None

        rates = None
        payload = ctx.litellm_model_info
        if payload is None and ctx.litellm_base:
            key = None
            if ctx.litellm_master_key_path:
                p = Path(ctx.litellm_master_key_path)
                if p.is_file():
                    key = p.read_text(encoding="utf-8").strip()
            headers = {"Accept": "application/json"}
            if key:
                headers["Authorization"] = f"Bearer {key}"
            url = f"{ctx.litellm_base.rstrip('/')}/v1/model/info"
            payload = get_json_optional(url, headers=headers)

        basis = "deepseek.v3.2.list_fallback"
        model_label = ctx.model_hint
        if isinstance(payload, dict):
            rates = _rates_from_model_info(payload, ctx.model_hint)
        if rates:
            rate_in, rate_cache, rate_out, model_label = rates
            basis = "litellm.model_info"
        else:
            rate_in, rate_cache, rate_out = _FALLBACK_IN, _FALLBACK_CACHE, _FALLBACK_OUT

        # Paperclip reports cache separately from input (often cache >> input).
        additive = tokens.cache_tokens > tokens.input_tokens
        usd = compute_cost(
            tokens, rate_in, rate_cache, rate_out, additive_cache=additive
        )
        return CostQuote(
            usd=round(usd, 6),
            kind="extrapolated",
            basis=basis,
            model=model_label,
        )
