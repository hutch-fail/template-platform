"""Single merge policy for token/cost observations."""

from __future__ import annotations

from .domain import CostQuote, TokenUsage, UsageLedger, UsageObservation
from .ports import CostEstimator

# Higher index = preferred on confidence ties.
_TOKEN_SOURCE_RANK = {
    "harbor.result": 0,
    "hermes.ndjson": 1,
    "litellm.spend": 2,
    "paperclip.runs": 3,
}


def _token_rank(source_id: str) -> int:
    return _TOKEN_SOURCE_RANK.get(source_id, -1)


def pick_tokens(observations: list[UsageObservation]) -> tuple[TokenUsage, str | None, list[str]]:
    notes: list[str] = []
    candidates = [
        o for o in observations if o.tokens is not None and o.tokens.has_tokens()
    ]
    if not candidates:
        notes.append("no non-zero token observation")
        return TokenUsage(), None, notes
    best = max(
        candidates,
        key=lambda o: (o.confidence, _token_rank(o.source_id)),
    )
    assert best.tokens is not None
    notes.append(f"tokens from {best.source_id} (confidence={best.confidence})")
    return best.tokens, best.source_id, notes


def pick_measured_cost(observations: list[UsageObservation]) -> CostQuote | None:
    measured = [
        o.cost
        for o in observations
        if o.cost is not None and o.cost.kind == "measured" and o.cost.usd > 0
    ]
    if not measured:
        return None
    # Prefer highest spend among measured positives (LiteLLM window sum).
    return max(measured, key=lambda c: c.usd)


def merge_ledger(
    observations: list[UsageObservation],
    estimators: list[CostEstimator],
    ctx,
) -> UsageLedger:
    ledger = UsageLedger(observations=list(observations))
    tokens, token_src, notes = pick_tokens(observations)
    ledger.tokens = tokens
    ledger.token_source_id = token_src
    ledger.notes.extend(notes)

    measured = pick_measured_cost(observations)
    if measured is not None:
        ledger.cost_usd = measured.usd
        ledger.cost_kind = "measured"
        ledger.cost_basis = measured.basis
        ledger.cost_model = measured.model
        ledger.notes.append(f"cost measured via {measured.basis}")
        return ledger

    # Zero measured costs are ignored for resolution but kept in observations.
    zero_measured = [
        o
        for o in observations
        if o.cost is not None and o.cost.kind == "measured" and o.cost.usd == 0
    ]
    if zero_measured:
        ledger.notes.append(
            "ignored measured costUsd=0 from "
            + ", ".join(sorted({o.source_id for o in zero_measured}))
        )

    if not tokens.has_tokens():
        ledger.cost_kind = "unknown"
        ledger.notes.append("no tokens; cannot extrapolate cost")
        return ledger

    for est in estimators:
        quote = est.estimate(ctx, tokens)
        if quote is None:
            continue
        ledger.cost_usd = quote.usd
        ledger.cost_kind = "extrapolated"
        ledger.cost_basis = quote.basis
        ledger.cost_model = quote.model
        ledger.notes.append(f"cost extrapolated via {quote.basis}")
        return ledger

    ledger.cost_kind = "unknown"
    ledger.notes.append("no estimator produced a cost quote")
    return ledger
