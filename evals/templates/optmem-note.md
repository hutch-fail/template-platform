# OptMem note checklist

One note = one lasting fact, ≤280 bytes. Prefer two short notes over one dump.

## Decision (required)

What should a future agent treat as true about this hub / PR / failure?

- Good: `Dependabot PRs skip eval pack gate; human PRs still require packs.`
- Bad: `PR #19 (ci/skip-dependabot): ci(evals): skip pack gate. Touched: .github/workflows/...`

## Failure avoided (when relevant)

What approach failed or must not be retried?

- Good: `Blacksmith pack/select failed when two useblacksmith/checkout steps raced; keep a single checkout.`
- Bad: `Maybe need incorporate race? Length feat 4 + / 1…`

## Proof (optional second note)

Point at the eval, not the path laundry:

- Goal id: `20260924-blacksmith-runners`
- Check claim: `fixture fails dual-checkout race shape`
- Result: `Adopt — F2P green; live Action still required for runtime proof`

## Forbidden

- `Touched: a.md, b.md, c.md…` as the whole note
- Full PR description paste
- Chat recaps, hedging, byte counting, prompt echo
- Editing `.optmem/**/memory` by hand

## Backfill

Historical shards use the evidence-pack recipe in [`docs/optmem.md`](../docs/optmem.md)
(`scripts/optmem-backfill-merged-prs.py`).
