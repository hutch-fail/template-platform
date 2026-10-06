# Meta-eval pack quality (universe ratchet)

Always-on quality bar for **eval packs** (goal + fixture), not soft product
agent trajectory judges. Wired in `scripts/eval-bars.sh` → `run_universe_bars`
via `fixtures/universe/20260929-meta-eval-pack-quality/check.sh`.

## Executive narrative pair

| When | Artifact | Job |
| --- | --- | --- |
| Before the run | Goal markdown | What we will accomplish, why, vaguely how |
| After the run | Sibling `<goal>-result.md` | What happened, Adopt/Hold, **proof snippets** |

Templates: `templates/goal.md` (`# Executive overview` lead),
`templates/result.md` (`# Proof`). Commit the result in a **later** local
commit than the goal/fixture (`result-not-with-eval`).

Skills: **build-eval** (author), **hillclimb** (optimize), composed by
**meta-dev** / **goal-author** / **goal-judge**.

## Three tiers

### Tier 1 — Deterministic (always)

`harness/lib/pack_quality_lint.py`:

- Selftest: fixture `samples/good` must pass; `samples/bad` must fail
- Scan `HERMES_EVAL_SCAN_ROOT` goals (`goals/` or `evals/goals/`)
- Opt-in mode (default on products/hub): lint packs with `# Executive overview`
  or `pack_quality: required|ratchet`
- Fixture mode (`PACK_QUALITY_FIXTURE`): lint all packs under the scan root
- Checks: required sections, executive prose, Grading names program|person|model,
  Dataset when Success criteria exist, hold-out cue, `fixture_dir` / executable
  `f2p_check`, and (if present) sibling result proof cues

No API keys.

### Tier 2 — Jev `meta/calibrate` (key-gated)

When `TYPESAFE_API_KEY` is set → ensure `meta/.venv` + `pip install -r
meta/requirements.txt`, then `make meta/calibrate` (fail closed).

When unset:

- Skip if `PRE_COMMIT=1`, `HERMES_EVAL_SKIP_JEV=1`, or fixture marker present
- Otherwise fail closed (CI / bare `make eval/bars`)

Same contract as optional `ui:jev` (`fixtures/language/ui/20260929-ui-jev-optional`).

### Tier 3 — LiteLLM pack rubric (model opt-in)

`harness/lib/llm_pack_quality_judge.py` (OpenAI-compatible chat completions).

| Env | Purpose |
| --- | --- |
| `EVAL_LLM_API_KEY` (fallback `OPENAI_API_KEY`) | LiteLLM virtual key |
| `EVAL_LLM_BASE_URL` (fallback `OPENAI_API_BASE` / `OPENAI_BASE_URL`) | Proxy URL |
| `EVAL_LLM_MODEL` | Opt-in model id — unset → skip; set → require key |

Deps: `harness/requirements-llm.txt` (`openai`). Never echo secrets.
`eval-ci.yml` accepts optional `EVAL_LLM_*` secrets.

- `EVAL_LLM_MODEL` unset → skip (CI stays green until the secret exists)
- Model set, key missing → fail closed (unless `PRE_COMMIT=1` / fixture /
  `HERMES_EVAL_SKIP_LLM_PACK=1`)
- Model + key set → run judge; fail closed on bad verdict or API error

Rubric claims (code owns pass/fail from structured JSON scores): mirror prod,
headroom, low ambiguity, adversarial-sampling warning, holdout, executive
readability.

## Soft product judges stay deferred

`goal-judge` still marks soft LLM trajectory/rubric scoring **out of scope**.
Tier 3 grades **pack quality** only.

## Goal pack

`goals/universe/20260929-meta-eval-quality-ratchet.md` + fixture
`fixtures/universe/20260929-meta-eval-pack-quality/`.
