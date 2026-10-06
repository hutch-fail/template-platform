# Meta-eval bootstrap (TypeSafe)

Crawl-sized gate for **candidate eval criteria** before they become trusted
LLM/TypeSafe rubrics.

| Meta-eval | What it checks | Primitive |
| --- | --- | --- |
| **A — Definition Quality** | `decidable`, `executable`, `single_claim`, `binary_outcome` | Four parallel **Noul**s in one `system_one` call |
| **B — Known-Case Discrimination** | Author-supplied positive → PASS and negative → FAIL | One **Noul** per fixture |

Code owns composition (`pass = all(score >= 0.5)`). Noul scores are
**classification boundaries**, not confidence percentages.

## Narrow discrimination claim

Meta-Eval B proves only that the criterion classifies **hand-authored known
cases**. It is **not** real-world sensitivity/specificity, IRR, or statistical
validity. `bad-discrimination.yaml` is a malformed fixture (sound criterion,
both cases negatives) so a broken B path cannot still score 5/5.

## Commands

```bash
# from repo root (TYPESAFE_API_KEY in .env or process env)
make -C evals meta/validate EVAL=meta/calibration/good-01.yaml
make -C evals meta/validate EVAL=meta/calibration/good-01.yaml META_FLAGS='--format json --verbose'
make -C evals meta/calibrate
make -C evals meta/calibrate META_FLAGS='--format json'
```

Exit codes: `0` PASS, `1` FAIL, `2` ERROR (missing key, invalid YAML, API failure).
`ERROR ≠ FAIL` — calibrate never treats ERROR as agreeing with an expected FAIL.

## Env / CI

```text
process env (CI: secrets.TYPESAFE_API_KEY)
        ↓ fallback if unset
repo-root .env   (local only; gitignored)
```

```yaml
# GitHub Actions (when gated)
env:
  TYPESAFE_API_KEY: ${{ secrets.TYPESAFE_API_KEY }}
```

Never print or commit the key. Install deps: `pip install -r evals/meta/requirements.txt`.

## Progression

- **v0 (this bootstrap):** 5/5 calibration + validate CLI.
- **v1:** Grow calibration from disagreements; keep per-dimension expected labels.
- **v2:** Optional generative/adversarial fixtures (out of scope here).

## Adding fixture #6+

1. Author a candidate YAML (see [`schema.md`](schema.md)).
2. Hand-label `expected.definition.*`, `expected.discrimination.*`, `expected.pass`.
3. Run `meta/validate` until outcomes match intent.
4. Only then add it to `CALIBRATION_FILES` in `validate.py` and raise the 5/5 gate.
