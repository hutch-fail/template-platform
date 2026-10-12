#!/usr/bin/env python3
"""Unit tests for Harbor multi-source usage ledger."""

from __future__ import annotations

import json
import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "harbor" / "lib"
sys.path.insert(0, str(LIB))

from usage.adapters.harbor_result import HarborResultSource, parse_harbor_result  # noqa: E402
from usage.adapters.hermes_ndjson import HermesNdjsonSource, sum_ndjson_dir  # noqa: E402
from usage.adapters.litellm_spend import LiteLLMSpendSource, filter_and_sum_logs  # noqa: E402
from usage.adapters.paperclip_runs import PaperclipRunsSource, parse_usage_json  # noqa: E402
from usage.collector import UsageCollector, default_collector  # noqa: E402
from usage.domain import CostQuote, RunContext, TokenUsage, UsageObservation  # noqa: E402
from usage.estimators.cursor_ultra import (  # noqa: E402
    CursorUltraEstimator,
    cursor_ultra_usd_per_mtok,
)
from usage.estimators.litellm_model_info import (  # noqa: E402
    LiteLLMModelInfoEstimator,
    compute_cost,
)
from usage.merge import merge_ledger, pick_measured_cost, pick_tokens  # noqa: E402

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "harbor_usage"


def _load(name: str):
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


class ParseAdaptersTest(unittest.TestCase):
    def test_paperclip_usage_json(self):
        runs = _load("paperclip_runs_arm_b.json")
        tokens, cost = parse_usage_json(runs[0]["usageJson"])
        assert tokens is not None
        self.assertEqual(tokens.input_tokens, 29557)
        self.assertEqual(tokens.output_tokens, 1273)
        self.assertEqual(tokens.cache_tokens, 232576)
        assert cost is not None
        self.assertEqual(cost.usd, 0.0)
        self.assertEqual(cost.kind, "measured")

    def test_paperclip_source_arm_b(self):
        ctx = RunContext(paperclip_runs=_load("paperclip_runs_arm_b.json"))
        obs = PaperclipRunsSource().collect(ctx)
        assert obs is not None
        assert obs.tokens is not None
        self.assertEqual(obs.tokens.input_tokens, 29557)
        self.assertEqual(obs.confidence, 0.9)

    def test_litellm_window_filter(self):
        logs = _load("litellm_spend_window.json")
        started = datetime(2026, 10, 8, 18, 40, 0, tzinfo=timezone.utc)
        finished = datetime(2026, 10, 8, 18, 41, 0, tzinfo=timezone.utc)
        tokens, spend, n = filter_and_sum_logs(logs, started, finished, "deepseek")
        self.assertEqual(n, 2)
        self.assertAlmostEqual(spend, 0.0016137 + 0.001109592)
        self.assertEqual(tokens.input_tokens, 30162 + 28808)
        self.assertNotIn(9.99, [spend])  # outside window excluded

    def test_harbor_result(self):
        data = _load("harbor_result.json")
        tokens = parse_harbor_result(data)
        assert tokens is not None
        self.assertEqual(tokens.input_tokens, 15608)
        self.assertEqual(tokens.cache_tokens, 2176)
        ctx = RunContext(harbor_result_path=str(FIXTURES / "harbor_result.json"))
        obs = HarborResultSource().collect(ctx)
        assert obs is not None
        self.assertEqual(obs.confidence, 0.4)

    def test_ndjson_sum(self):
        tokens, cost = sum_ndjson_dir(FIXTURES / "sample.ndjson")
        self.assertEqual(tokens.input_tokens, 300)
        self.assertEqual(tokens.output_tokens, 50)
        self.assertEqual(tokens.cache_tokens, 60)
        self.assertEqual(cost, 0.0)
        ctx = RunContext(ndjson_dir=str(FIXTURES / "sample.ndjson"))
        obs = HermesNdjsonSource().collect(ctx)
        assert obs is not None
        assert obs.tokens is not None


class MergePolicyTest(unittest.TestCase):
    def test_prefers_paperclip_tokens_over_harbor(self):
        obs = [
            UsageObservation(
                "harbor.result",
                TokenUsage(15608, 3235, 2176),
                None,
                0.4,
                "harbor",
            ),
            UsageObservation(
                "paperclip.runs",
                TokenUsage(29557, 1273, 232576),
                CostQuote(0.0, "measured", "paperclip.runs.usageJson"),
                0.9,
                "pc",
            ),
        ]
        tokens, src, _ = pick_tokens(obs)
        self.assertEqual(src, "paperclip.runs")
        self.assertEqual(tokens.input_tokens, 29557)

    def test_measured_litellm_beats_zero_paperclip(self):
        obs = [
            UsageObservation(
                "paperclip.runs",
                TokenUsage(29557, 1273, 0),
                CostQuote(0.0, "measured", "paperclip.runs.usageJson"),
                0.9,
                "pc",
            ),
            UsageObservation(
                "litellm.spend",
                TokenUsage(1000, 10, 0),
                CostQuote(0.42, "measured", "litellm.spend.logs"),
                0.85,
                "ll",
            ),
        ]
        quote = pick_measured_cost(obs)
        assert quote is not None
        self.assertEqual(quote.usd, 0.42)
        ledger = merge_ledger(obs, [], RunContext(pricing_profile="none"))
        self.assertEqual(ledger.cost_kind, "measured")
        self.assertEqual(ledger.cost_usd, 0.42)
        # Tokens: paperclip confidence wins over litellm window sum
        self.assertEqual(ledger.token_source_id, "paperclip.runs")
        self.assertEqual(ledger.tokens.input_tokens, 29557)

    def test_cursor_ultra_extrapolate_when_no_measured(self):
        tokens = TokenUsage(15608, 3235, 2176)
        obs = [
            UsageObservation("harbor.result", tokens, None, 0.4, "h"),
        ]
        ctx = RunContext(pricing_profile="cursor_ultra", model_hint="cursor/auto")
        ledger = merge_ledger(obs, [CursorUltraEstimator()], ctx)
        self.assertEqual(ledger.cost_kind, "extrapolated")
        expected = tokens.total / 1e6 * cursor_ultra_usd_per_mtok()
        self.assertAlmostEqual(ledger.cost_usd or 0, expected, places=5)
        self.assertEqual(ledger.cost_basis, "cursor.ultra.flat")


class EstimatorTest(unittest.TestCase):
    def test_cursor_rate(self):
        self.assertAlmostEqual(cursor_ultra_usd_per_mtok(), 0.625)

    def test_model_info_additive_cache(self):
        tokens = TokenUsage(29557, 1273, 232576)
        usd = compute_cost(
            tokens,
            1.32e-06,
            4.4e-08,
            3.96e-06,
            additive_cache=True,
        )
        self.assertGreater(usd, 0.04)
        ctx = RunContext(
            pricing_profile="litellm_model",
            model_hint="meter/colin/premium",
            litellm_model_info=_load("model_info_premium.json"),
        )
        quote = LiteLLMModelInfoEstimator().estimate(ctx, tokens)
        assert quote is not None
        self.assertEqual(quote.basis, "litellm.model_info")
        self.assertEqual(quote.model, "deepseek/deepseek-v4-pro")


class CollectorIntegrationTest(unittest.TestCase):
    def test_arm_b_style_collect(self):
        started = datetime(2026, 10, 8, 18, 40, 0, tzinfo=timezone.utc)
        finished = datetime(2026, 10, 8, 18, 41, 0, tzinfo=timezone.utc)
        ctx = RunContext(
            paperclip_runs=_load("paperclip_runs_arm_b.json"),
            litellm_spend_logs=_load("litellm_spend_window.json"),
            litellm_model_info=_load("model_info_premium.json"),
            run_started_at=started,
            run_finished_at=finished,
            model_hint="meter/colin/premium",
            model_family_filter="deepseek",
            pricing_profile="litellm_model",
        )
        ledger = default_collector().collect(ctx)
        self.assertEqual(ledger.cost_kind, "measured")
        self.assertAlmostEqual(ledger.cost_usd or 0, 0.0016137 + 0.001109592)
        self.assertEqual(ledger.tokens.input_tokens, 29557)

    def test_arm_a_proxy_cursor(self):
        ctx = RunContext(
            paperclip_runs=_load("paperclip_runs_arm_a_null.json"),
            harbor_result_path=str(FIXTURES / "harbor_result.json"),
            pricing_profile="cursor_ultra",
            model_hint="cursor/auto",
        )
        ledger = default_collector().collect(ctx)
        self.assertEqual(ledger.token_source_id, "harbor.result")
        self.assertEqual(ledger.cost_kind, "extrapolated")
        self.assertEqual(ledger.cost_basis, "cursor.ultra.flat")
        self.assertAlmostEqual(ledger.cost_usd or 0, 0.013137, places=4)


if __name__ == "__main__":
    unittest.main()
