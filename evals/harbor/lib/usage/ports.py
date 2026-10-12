"""Ports for usage sources and cost estimators."""

from __future__ import annotations

from typing import Protocol

from .domain import CostQuote, RunContext, TokenUsage, UsageObservation


class UsageSource(Protocol):
    source_id: str

    def collect(self, ctx: RunContext) -> UsageObservation | None: ...


class CostEstimator(Protocol):
    estimator_id: str

    def estimate(self, ctx: RunContext, tokens: TokenUsage) -> CostQuote | None: ...
