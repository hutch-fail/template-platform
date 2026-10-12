"""Experiment metering domain types."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Literal


PricingProfile = Literal["cursor_ultra", "litellm_model", "none"]


@dataclass(frozen=True)
class TokenUsage:
    input_tokens: int = 0
    output_tokens: int = 0
    cache_tokens: int = 0

    @property
    def total(self) -> int:
        return self.input_tokens + self.output_tokens + self.cache_tokens

    def has_tokens(self) -> bool:
        return self.total > 0


@dataclass(frozen=True)
class CostQuote:
    usd: float
    kind: Literal["measured", "extrapolated"]
    basis: str
    model: str | None = None


@dataclass(frozen=True)
class UsageObservation:
    source_id: str
    tokens: TokenUsage | None
    cost: CostQuote | None
    confidence: float
    raw_ref: str


@dataclass
class RunContext:
    """Inputs adapters need; omit fields the collector can skip."""

    issue_id: str | None = None
    run_started_at: datetime | None = None
    run_finished_at: datetime | None = None
    paperclip_base: str | None = None
    litellm_base: str | None = None
    litellm_master_key_path: str | None = None
    ndjson_dir: str | None = None
    harbor_result_path: str | None = None
    model_hint: str | None = None
    pricing_profile: PricingProfile = "none"
    # Optional preloaded payloads for hermetic tests / offline backfill
    paperclip_runs: list[dict[str, Any]] | None = None
    litellm_spend_logs: list[dict[str, Any]] | None = None
    litellm_model_info: dict[str, Any] | None = None
    model_family_filter: str | None = None  # e.g. "deepseek"


@dataclass
class UsageLedger:
    observations: list[UsageObservation] = field(default_factory=list)
    tokens: TokenUsage = field(default_factory=TokenUsage)
    cost_usd: float | None = None
    cost_kind: Literal["measured", "extrapolated", "unknown"] = "unknown"
    cost_basis: str | None = None
    cost_model: str | None = None
    notes: list[str] = field(default_factory=list)
    token_source_id: str | None = None

    def to_snapshot_fields(self) -> dict[str, Any]:
        extrapolate: dict[str, Any] | None = None
        if self.cost_kind == "extrapolated" and self.cost_usd is not None:
            extrapolate = {"usd": self.cost_usd, "basis": self.cost_basis}
        return {
            "usage": {
                "input_tokens": self.tokens.input_tokens,
                "output_tokens": self.tokens.output_tokens,
                "cache_tokens": self.tokens.cache_tokens,
            },
            "costUsd": self.cost_usd if self.cost_usd is not None else 0.0,
            "costKind": self.cost_kind,
            "costBasis": self.cost_basis,
            "costModel": self.cost_model,
            "tokenSourceId": self.token_source_id,
            "usageSources": [
                {
                    "source_id": o.source_id,
                    "confidence": o.confidence,
                    "raw_ref": o.raw_ref,
                    "tokens": (
                        {
                            "input_tokens": o.tokens.input_tokens,
                            "output_tokens": o.tokens.output_tokens,
                            "cache_tokens": o.tokens.cache_tokens,
                        }
                        if o.tokens
                        else None
                    ),
                    "cost": (
                        {
                            "usd": o.cost.usd,
                            "kind": o.cost.kind,
                            "basis": o.cost.basis,
                            "model": o.cost.model,
                        }
                        if o.cost
                        else None
                    ),
                }
                for o in self.observations
            ],
            "extrapolate": extrapolate,
            "usageNotes": list(self.notes),
        }
