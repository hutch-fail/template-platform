"""Application service: probe sources, estimate gaps, merge."""

from __future__ import annotations

from .domain import RunContext, UsageLedger, UsageObservation
from .merge import merge_ledger
from .ports import CostEstimator, UsageSource


class UsageCollector:
    def __init__(
        self,
        sources: list[UsageSource],
        estimators: list[CostEstimator] | None = None,
    ) -> None:
        self._sources = list(sources)
        self._estimators = list(estimators or [])

    def collect(self, ctx: RunContext) -> UsageLedger:
        observations: list[UsageObservation] = []
        for src in self._sources:
            try:
                obs = src.collect(ctx)
            except Exception as exc:  # noqa: BLE001 — adapters must not abort collect
                observations.append(
                    UsageObservation(
                        source_id=src.source_id,
                        tokens=None,
                        cost=None,
                        confidence=0.0,
                        raw_ref=f"error:{type(exc).__name__}:{exc}",
                    )
                )
                continue
            if obs is not None:
                observations.append(obs)

        profile = ctx.pricing_profile
        estimators = [
            e
            for e in self._estimators
            if _estimator_matches_profile(e.estimator_id, profile)
        ]
        return merge_ledger(observations, estimators, ctx)


def _estimator_matches_profile(estimator_id: str, profile: str) -> bool:
    if profile == "none":
        return False
    if profile == "cursor_ultra":
        return estimator_id == "cursor.ultra"
    if profile == "litellm_model":
        return estimator_id == "litellm.model_info"
    return False


def default_collector() -> UsageCollector:
    """Factory with the built-in adapter set."""
    from .adapters.harbor_result import HarborResultSource
    from .adapters.hermes_ndjson import HermesNdjsonSource
    from .adapters.litellm_spend import LiteLLMSpendSource
    from .adapters.paperclip_runs import PaperclipRunsSource
    from .estimators.cursor_ultra import CursorUltraEstimator
    from .estimators.litellm_model_info import LiteLLMModelInfoEstimator

    return UsageCollector(
        sources=[
            PaperclipRunsSource(),
            LiteLLMSpendSource(),
            HarborResultSource(),
            HermesNdjsonSource(),
        ],
        estimators=[
            CursorUltraEstimator(),
            LiteLLMModelInfoEstimator(),
        ],
    )
