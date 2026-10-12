# OptMem (hub work memory)

This hub pins unmodified OptMem (`optmem/upstream/memo`) and wraps it with
[`optmem/repo-memo`](../optmem/repo-memo). See [`prior-art.md`](prior-art.md).

## What OptMem is for here

| OptMem owns | Docs / skills / PROCESS own |
| --- | --- |
| Accumulating **work memory**: decisions, failures, session continuity | Cold-start **methodology**: goals, F2P/P2P, meta-dev loop |
| Cross-session recall after compaction / vendor change | How to run `make eval/…` and author packs |

Do not treat wake as a substitute for `README.md` / `PROCESS.md` / `skills/`.

## Agent protocol

Follow the Memory block in [`AGENTS.md`](../AGENTS.md):

1. `python3 optmem/repo-memo wake` at session start; do what it prints.
2. `python3 optmem/repo-memo note "…"` for lasting facts (≤280 bytes).
3. Pay `nap` when note asks, before the next action.
4. PR inbox: `.optmem/shards/<UTC>-<branch>/memory`. Never hand-edit
   `.optmem/**/memory`. Never edit `.optmem/main` on a PR (reconcile owns it).

Subagents: do not run memo.

## Note rules (lasting facts)

Copy the checklist in [`templates/optmem-note.md`](../templates/optmem-note.md).

**Do write:** decisions, failures avoided, proof pointers (goal id, check claim,
result recommendation).

**Do not write:** path laundry (`Touched: a, b, c…`), full PR bodies, chat
recaps, meta-reasoning (“maybe”, byte counts, “Sentence:”).

Hard limit: OptMem `ENTRY_CHARS` ≈ 280 bytes per note.

## Backfill recipe (historical PRs)

Garbage-in yields garbage TREE covers. Prefer **nuke-and-reinit** over patching
a bad LOG.

For each broad-kit merged PR:

1. Build a deterministic **evidence pack**: title, desired-result (or short
   body), kit paths, linked `goals/**/*.md` + sibling `*-result.md`, skim of
   linked `fixtures/**/check.sh` / `p2p-smoke.sh`.
2. **Hybrid summarize** into 1–2 notes ≤280 bytes (`decision`, optional
   `proof`): LLM compress with reject/junk gate + heuristic fallback from the
   pack. Never paste the full PR body into LOG.
3. Write notes via unmodified `memo note` into a shard (wrapper sets
   `MEMORY_DIR`).
4. Fold with `make optmem/reconcile` (or the Action twin).

Helper: [`scripts/optmem-backfill-merged-prs.py`](../scripts/optmem-backfill-merged-prs.py).

```bash
# Inventory (enriched evidence + notes) under runs/ (gitignored)
python3 scripts/optmem-backfill-merged-prs.py --inventory-only

# Demo-only: wipe shards + main, then rewrite shards merge-order
python3 scripts/optmem-backfill-merged-prs.py --reset-store --write-shards --commit --force
make optmem/reconcile
python3 optmem/repo-memo wake | tee runs/optmem-backfill/wake.txt
```

## Wake vs mid-band TREE

- Agents follow `repo-memo wake` (budget `WAKE_LINES`, default 96).
- Humans judging cover quality: prefer `TREE/16` and above (or a mid-band
  export). `TREE/2` / full wake of a PR chronicle is high noise.
- `TREE/128` alone is too thin for handoff.

## Make targets

| Target | Role |
| --- | --- |
| `make optmem/doctor` | Pin + layout (+ optional `--llm` / `OPTMEM_DOCTOR_LLM=1`) |
| `make optmem/reconcile` | Fold shards into `.optmem/main` and drain naps |
