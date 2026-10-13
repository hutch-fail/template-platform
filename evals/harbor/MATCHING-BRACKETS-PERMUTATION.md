# Matching-brackets — single-permutation report (Harbor MVP)

Research: [`../docs/research/20261007-coding-agent-eval-harbor-langfuse.md`](../docs/research/20261007-coding-agent-eval-harbor-langfuse.md)
Task: [`tasks/matching-brackets/`](tasks/matching-brackets/)

## Permutation A — oracle (verifier + timing proved)

| Field | Value |
| --- | --- |
| Task | `hutch-fail/matching-brackets` (Exercism Python matching-brackets) |
| Agent (harness) | `oracle` (Harbor built-in; installs `solution/`) |
| Model | n/a (no LLM) |
| Sandbox | Harbor `docker` |
| Success (reward) | **1.0** |
| Tokens in | null (no LLM) |
| Tokens out | null (no LLM) |
| Cost USD | null |
| Wall — job | ~63 s (`result.json` started/finished) |
| Wall — agent_execution | ~0.38 s |
| Wall — verifier | ~20 s |
| Job dir | `jobs/matching-brackets-oracle/` |
| Trial | `matching-brackets__o4D7UYG` |

Command:

```bash
cd evals
harbor run -p harbor/tasks/matching-brackets -a oracle \
  -o harbor/jobs --job-name matching-brackets-oracle
```

## Permutation B — nop (stub fails; red baseline)

| Field | Value |
| --- | --- |
| Agent | `nop` (no edits) |
| Model | n/a |
| Success (reward) | **0.0** |
| Wall — job | ~32 s |
| Job dir | `jobs/matching-brackets-nop/` |

Proves F2P-style red on the Exercism stub without weakening checks.

## Permutation C — live LLM via Cloudflare LiteLLM (measured)

Hosted OpenAI-compatible API: `https://litellm-api.hutch.fail/v1`
(not `litellm.hutch.fail` Admin UI). Free alias on that proxy: `meter/colin/free-medium`.
Harbor’s LiteLLM client needs the OpenAI provider prefix: `-m openai/meter/colin/free-medium`.

| Field | Value |
| --- | --- |
| Task | `hutch-fail/matching-brackets` |
| Agent (harness) | `terminus-2` v2.0.0 |
| Model | `openai/meter/colin/free-medium` → proxy `meter/colin/free-medium` |
| LLM API | Cloudflare LiteLLM `https://litellm-api.hutch.fail/v1` |
| Sandbox | Harbor `docker` |
| Success (reward) | **1.0** |
| Tokens in | **15608** |
| Tokens out | **3235** |
| Cache tokens | 2176 |
| Cost USD | null (free route) |
| Wall — job | ~363 s (6m 3s) |
| Wall — trial | ~121 s |
| Wall — agent_execution | ~80 s |
| Wall — verifier | ~12 s |
| Episodes | 7 |
| ATIF steps | 8 |
| Job dir | `jobs/matching-brackets-terminus-openai-free-medium/` |
| Trial | `matching-brackets__ehkRtZp` |
| Job id | `a806fd23-eb6a-4663-a57f-a3d41b8f27ac` |

Command (key from `service-litellm/.env` `LITELLM_MASTER_KEY`; do not commit):

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
  -o harbor/jobs \
  --job-name matching-brackets-terminus-openai-free-medium
```

Notes:

- First attempt with bare `-m meter/colin/free-medium` failed (`LLM Provider NOT provided`); prefix `openai/` fixed it.
- `OPENAI_API_KEY` in `service-litellm/.env` was empty; master key authenticated to the hosted API for this POC.

## How to read metrics

| Metric | Where |
| --- | --- |
| Success | `verifier_result.rewards.reward` or job Mean |
| Wall | trial `started_at`/`finished_at`; phases `agent_execution`, `verifier` |
| Tokens | trial `agent_result.n_input_tokens` / `n_output_tokens`; ATIF `final_metrics` |
| Trajectory | `agent/trajectory.json` (ATIF) |

Optional compose: Harbor `--plugin atif2otel` → OTEL → Langfuse for dashboards (not required for this row).
