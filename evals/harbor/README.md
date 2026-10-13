# Harbor coding-agent evals (thin wrap)

Off-the-shelf runner: [Harbor](https://www.harborframework.com/) (`uv tool install harbor`).

Research decision: [`docs/research/20261007-coding-agent-eval-harbor-langfuse.md`](../docs/research/20261007-coding-agent-eval-harbor-langfuse.md).

## Matching brackets (Exercism)

Task: [`tasks/matching-brackets/`](tasks/matching-brackets/)

Oracle (no model; proves verifier):

```bash
cd evals
harbor run -p harbor/tasks/matching-brackets -a oracle -o harbor/jobs
```

Live permutation via **Cloudflare LiteLLM** (`https://litellm-api.hutch.fail/v1`):

```bash
cd evals
set -a && source ../service-litellm/.env && set +a
export OPENAI_API_KEY="$LITELLM_MASTER_KEY"
export PROXY_BASE_URL="https://litellm-api.hutch.fail/v1"

harbor run -p harbor/tasks/matching-brackets \
  -a terminus-2 \
  -m openai/meter/colin/free-medium \
  --ak api_base="$PROXY_BASE_URL" \
  --ak max_turns=30 \
  -o harbor/jobs
harbor view harbor/jobs
```

Use `litellm-api.hutch.fail` (API), not `litellm.hutch.fail` (Admin UI / Access).
LiteLLM client needs the `openai/` provider prefix for custom proxy model ids.

Permutation notes: [`MATCHING-BRACKETS-PERMUTATION.md`](MATCHING-BRACKETS-PERMUTATION.md).

## Usage ledger (tokens + cost)

Paperclip ELO arms often omit or zero `costUsd` even when LiteLLM recorded spend.
[`lib/usage/`](lib/usage/) is a small multi-source meter:

| Port | Role |
| --- | --- |
| `UsageSource` | Probe one telemetry surface → `UsageObservation` |
| `CostEstimator` | Fill cost when no positive measured spend exists |
| `UsageCollector` + `MergePolicy` | Merge observations with provenance |

Built-in sources: Paperclip runs `usageJson`, LiteLLM `/spend/logs`, Harbor `result.json`, Hermes ndjson. Estimators: Cursor Ultra flat rate, LiteLLM `/v1/model/info` rates.

```bash
# Collect from a RunContext JSON (offline fixtures or live URLs/paths)
cd evals/harbor/lib && python3 -m usage collect --context /tmp/ctx.json

# Regenerate results/summary.md from results/*/snapshot.json
python3 harbor/scripts/render-summary.py --results-dir harbor/results
```

**Add a source:** implement `UsageSource` in `lib/usage/adapters/`, register it in `default_collector()` in [`lib/usage/collector.py`](lib/usage/collector.py).

**Add a price model:** implement `CostEstimator` in `lib/usage/estimators/`, map its `estimator_id` in `_estimator_matches_profile`, and select it via `RunContext.pricing_profile`.

Unit tests: `tests/unit/test_harbor_usage_ledger.sh`.
