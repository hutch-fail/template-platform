"""LiteLLM /spend/logs window sum."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from ..domain import CostQuote, RunContext, TokenUsage, UsageObservation
from ._http import get_json_optional


def _parse_ts(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(float(value), tz=timezone.utc)
    s = str(value).strip()
    if not s:
        return None
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(s)
    except ValueError:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def filter_and_sum_logs(
    logs: list[dict[str, Any]],
    started: datetime | None,
    finished: datetime | None,
    model_family: str | None,
) -> tuple[TokenUsage, float, int]:
    """Return (tokens, spend_usd, n_rows)."""
    tin = tout = cache = 0
    spend = 0.0
    n = 0
    for row in logs:
        if not isinstance(row, dict):
            continue
        model = str(row.get("model") or "")
        if model_family and model_family.lower() not in model.lower():
            continue
        ts = _parse_ts(row.get("startTime") or row.get("start_time"))
        if started and ts and ts < started:
            continue
        if finished and ts and ts > finished:
            continue
        # Skip non-completion noise when family filter unset but spend=0 tools.
        call_type = str(row.get("call_type") or "")
        if call_type and call_type not in ("acompletion", "completion", "agenerate", ""):
            if float(row.get("spend") or 0) == 0 and not (
                row.get("prompt_tokens") or row.get("completion_tokens")
            ):
                continue
        n += 1
        tin += int(row.get("prompt_tokens") or 0)
        tout += int(row.get("completion_tokens") or 0)
        cache += int(
            row.get("cache_read_input_tokens")
            or row.get("cached_tokens")
            or 0
        )
        spend += float(row.get("spend") or 0)
    return TokenUsage(tin, tout, cache), spend, n


class LiteLLMSpendSource:
    source_id = "litellm.spend"

    def collect(self, ctx: RunContext) -> UsageObservation | None:
        logs = ctx.litellm_spend_logs
        ref = "ctx.litellm_spend_logs"
        if logs is None:
            if not ctx.litellm_base:
                return None
            key = None
            if ctx.litellm_master_key_path:
                p = Path(ctx.litellm_master_key_path)
                if p.is_file():
                    key = p.read_text(encoding="utf-8").strip()
            headers = {"Accept": "application/json"}
            if key:
                headers["Authorization"] = f"Bearer {key}"
            url = f"{ctx.litellm_base.rstrip('/')}/spend/logs?limit=500"
            data = get_json_optional(url, headers=headers)
            if data is None:
                return None
            logs = data if isinstance(data, list) else data.get("data") or []
            ref = url

        family = ctx.model_family_filter
        if family is None and ctx.model_hint and "premium" in ctx.model_hint:
            family = "deepseek"

        tokens, spend, n = filter_and_sum_logs(
            logs,
            ctx.run_started_at,
            ctx.run_finished_at,
            family,
        )
        if n == 0 and not tokens.has_tokens() and spend == 0:
            return None

        cost = CostQuote(
            usd=spend,
            kind="measured",
            basis="litellm.spend.logs",
            model=family or ctx.model_hint,
        )
        conf = 0.85 if spend > 0 else 0.4
        return UsageObservation(
            source_id=self.source_id,
            tokens=tokens if tokens.has_tokens() else None,
            cost=cost,
            confidence=conf,
            raw_ref=ref,
        )
