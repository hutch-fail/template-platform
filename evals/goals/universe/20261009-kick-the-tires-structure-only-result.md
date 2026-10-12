# Executive outcome

Shared eval procedure now fail-closes on structure-only done. Universe pack
`20261009-kick-the-tires-structure-only` certified red on baseline and green
after golden; live `PROCESS.md` + grader reject the DEF-108 closeout pattern.

# Result

**Recommendation:** Adopt

# Outcome

- Hub `PROCESS.md` documents PM observable final state before build, SDET
  fail-closed/certified-red gates, and structure-only ⇒ `blocked`/`in_review`.
- `scripts/grade-structure-only-disposition.sh` rejects `done` for
  structure-only-done and allows `blocked` for the same evidence.
- Company AGENTS / kick-the-tires skill / PR template remain **proposed** under
  `docs/proposals/DEF-115-kick-the-tires/` pending CEO/board confirmation
  (not hot-swapped).

# Proof

```text
assert-red OK: F2P is red on baseline (check.sh exit 1)
manifest=.../runs/20261009-kick-the-tires-structure-only/20261009T021038Z-1724921/manifest.json
verify OK: F2P+P2P green after golden.patch
manifest=.../runs/20261009-kick-the-tires-structure-only/20261009T021039Z-1724972/manifest.json
```

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| `make eval/assert-red GOAL=universe/20261009-kick-the-tires-structure-only` | certified red | fixture `check.sh` | hermetic |
| `make eval/verify GOAL=universe/20261009-kick-the-tires-structure-only` | F2P+P2P green after golden | `check.sh` + `p2p-smoke.sh` | hermetic |
| Ran live grader on structure-only-done / blocked cases | exit 1 / exit 0 | `scripts/grade-structure-only-disposition.sh` | hermetic |

# Blocking findings

None for (a). (b) company-wide AGENTS/skill/PR template require CEO/board
accept before landing.

# Comparison

| Question | What this run shows | Requirement | Result |
| --- | --- | --- | --- |
| Baseline red? | assert-red OK | F2P red | Met |
| Golden verify green? | verify OK | F2P+P2P | Met |
| Live PROCESS + grader? | p2p-smoke | procedure + reject done | Met |

# Evidence and limitations

Does not apply company AGENTS closeout, the kick-the-tires skill, or PR
template sections until board confirmation. Does not replace the game-dev
instance pack (`game-dev-agent-process`).

# Next action

Merge evals pack on branch; keep DEF-115 `in_review` until CEO/board accepts
proposal pack; then apply AGENTS/skill/template in a follow-up reviewable PR.

# Manifest

`evals/runs/20261009-kick-the-tires-structure-only/` (assert-red + verify).
