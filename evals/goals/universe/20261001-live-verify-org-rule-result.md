# Executive outcome

Org live-verify procedure is in hub git and wired through host adapters.
`make eval/verify` passed for `universe/20261001-live-verify-org-rule`.

# Result

**Recommendation:** Adopt

# Outcome

- Fixture baseline omits `.cursor/rules/live-verify.mdc` and the adapter entry;
  F2P stays red on baseline.
- After golden, baseline rule has `alwaysApply`, ask-before, real-system
  evidence, and no product hosts; adapter lists `live-verify.mdc`.
- Live hub ships `.cursor/rules/live-verify.mdc`,
  `scripts/install-host-adapters.sh` lists it, and `PROCESS.md` documents
  Procedure homes.

# Proof

```text
assert-red OK: F2P is red on baseline (check.sh exit 1)
verify OK: F2P+P2P green after golden.patch
```

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| Ran `make eval/assert-red` then `make eval/verify` for this goal | certified red; verify green | fixture `check.sh` + `p2p-smoke.sh` | hermetic |
| Inspected live rule for Incus/volumes/Colima strings | none present | `p2p-smoke.sh` product-agnostic grep | hermetic |

# Blocking findings

None.

# Comparison

| Question | What this run shows | Requirement | Result |
| --- | --- | --- | --- |
| Baseline red? | `assert-red` / check exit 1 | F2P red | Met |
| Patched baseline green? | `verify` F2P after golden | Rule + adapter | Met |
| Live hub wired? | `p2p-smoke.sh` | Rule + adapter + Procedure homes | Met |
| Verify green? | `verdict=pass` | F2P+P2P after golden | Met |

# Evidence and limitations

Does not remove personal `~/.cursor/rules/live-verify-not-weasel.mdc` on
laptops. Does not prove product `AGENTS.md` host-plane recipes. Does not prove
every consumer re-ran `install-host-adapters.sh`.

# Next action

Merge this PR; consumers `sync/pull` + re-run
`evals/scripts/install-host-adapters.sh`. Follow with platform-incus product
`AGENTS.md` and retire the personal alwaysApply duplicate.

# Manifest

`evals/runs/20261001-live-verify-org-rule/` (`verdict=pass` on verify).

# Manual verification

None — kit redistribute from hub 518db3f; eval-ci and pre-commit bars are the covering automated checks.
