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
- When `HERMES_EVAL_CHANGED_PATHS` is set (eval-bars path argv / PR diff), lint
  only those goal files — not the historic archive
- Fixture mode (`PACK_QUALITY_FIXTURE`): lint all packs under the scan root
- Checks: required sections, executive prose, Grading names program|person|model,
  Dataset when Success criteria exist, hold-out cue, `fixture_dir` / executable
  `f2p_check`, (if present) sibling result proof cues, **launch-path**:
  in-session GUI claims (openbox / Kasm / menu.d / Desktop IDE) must grade
  menu/launcher + DISPLAY in the fixture, not only PATH/dpkg (CLI-only
  Limitations escape hatch), and **use-path** (kick-the-tires): behavior claims
  (ensure/heal/reconcile/seed/mirror/bind, invent receives seed, etc.) must
  exercise the entrypoint in the fixture — not only `grep -Fq` wiring — and
  prefer an idempotent second pass unless Limitations say single-shot /
  reconverge out of scope, and **live-path**: Host URL / portless /
  dashboard / curl-health claims must grade doctor/`test/smoke`/`make up`
  wiring (probe invoked from smoke), not only `grep` that a probe script
  mentions `curl`. Sibling PASS/Adopt results for those claims need a
  Manual verification `live-proof` tier (or Limitations escape + non-PASS).
  Selftest includes `samples/good-desktop` / `samples/bad-desktop`,
  `samples/good-use` / `samples/bad-use`, and `samples/good-live` /
  `samples/bad-live`.

No API keys.

### Tier 2 — Jev pack-quality on **changed goals** (key-gated)

When `TYPESAFE_API_KEY` is set → ensure `meta/.venv` + `pip install -r
meta/requirements.txt`, then run `harness/lib/jev_pack_quality_judge.py` on
**changed** goal markdown only (`HERMES_EVAL_CHANGED_PATHS` / same selector as
Tier3). Six holistic axes match Tier3 vocabulary: `mirror_prod`, `headroom`,
`low_ambiguity`, `adversarial_warning`, `holdout`, `executive_readable`.
Code owns `score >= 0.5` per Noul and overall AND. Fail closed on FAIL/ERROR.

When unset:

- Skip if `PRE_COMMIT=1`, `HERMES_EVAL_SKIP_JEV=1`, or fixture marker present
- Otherwise fail closed (CI / bare `make eval/bars`)

**Labeled samples** (`fixtures/.../samples/jev-*` + `expected.yaml`):

- Used to calibrate the judge during development (`make meta/pack-judge-selftest`)
- Documented for authors (`samples/README-jev.md`)
- Re-run fail-closed in CI **only** when the judge, `jev-*` samples, or Tier2
  wiring change — not on every product PR

**Not Tier2:** `make meta/calibrate` (toy criterion YAML under `meta/calibration/`)
is hub-only / optional. It does not grade product goals and must not fail-close
consumer `eval-ci`.

### Tier 3 — LiteLLM pack rubric (model opt-in)

`harness/lib/llm_pack_quality_judge.py` (OpenAI-compatible chat completions).

| Env | Purpose |
| --- | --- |
| `EVAL_LLM_API_KEY` (fallback `OPENAI_API_KEY`) | Meter / LiteLLM virtual key |
| `EVAL_LLM_BASE_URL` (fallback `OPENAI_API_BASE` / `OPENAI_BASE_URL`) | OpenAI-compatible base — default `https://litellm-api.hutch.fail/v1` (Access bypassed). Do not use `litellm.hutch.fail` (Admin UI behind Cloudflare Access). |
| `EVAL_LLM_MODEL` | Opt-in model id — unset → skip; set → require key |

Local template: [`.env.example`](../.env.example) → copy to gitignored `.env`.
Load and probe with `make optmem/doctor` (same names feed `optmem-reconcile.yml`
naps after shards fold into `.optmem/main`).

Deps: `harness/requirements-llm.txt` (`openai`). Never echo secrets.
`eval-ci.yml` accepts optional `EVAL_LLM_*` secrets.

- `EVAL_LLM_MODEL` unset → skip (CI stays green until the secret exists)
- Model set, key missing → fail closed (unless `PRE_COMMIT=1` / fixture /
  `HERMES_EVAL_SKIP_LLM_PACK=1`)
- Model + key set → run judge on **changed** goal markdown only
  (`HERMES_EVAL_CHANGED_PATHS` from eval-bars argv / PR diff). Unset path list
  → skip (`reason=no_changed_goals`) unless `HERMES_EVAL_LLM_JUDGE_ALL=1` or
  fixture mode. A harness-only PR must not fail because a historic pack exists.
- Fail closed on bad verdict or API error. Stderr is **code-owned**: file,
  failed axis, `what this means`, `how to pass` (a slogan such as “hard for
  humans” is not enough for `adversarial_warning`). Model `notes` are extra.

Rubric claims (code owns pass/fail from structured JSON scores): mirror prod,
headroom, low ambiguity, a **specific** human-easy-to-get-wrong reason (not a
slogan), holdout, executive readability (what a green result allows).

## Soft product judges stay deferred

`goal-judge` still marks soft LLM trajectory/rubric scoring **out of scope**.
Tier 3 grades **pack quality** only.

## Goal pack

`goals/universe/20260929-meta-eval-quality-ratchet.md` and
`goals/universe/20261006-pack-quality-pr-scope-readable-fail.md` share fixture
`fixtures/universe/20260929-meta-eval-pack-quality/`.
