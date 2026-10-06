# Result

**Recommendation:** Adopt

`make eval/assert-red` certified red on the fixture baseline
(`converge.yml` + sibling `feature.yml`). `make eval/verify` passed after
`golden.patch` emptied the sibling. Product scan of machine-layers
(`ansible/playbooks/converge.yml` only) and
`HERMES_EVAL_FORCE_FAMILIES=ansible make eval/bars` both green.

# Outcome

- Language seed: `goals/language/ansible/20260929-ansible-single-converge.md`
  (`scope: language`, `languages: ansible`).
- **Demonstrated red:** fixture ships extra `feature.yml`; check exits 1.
- **Pass:** golden empties sibling (Apple `patch` cannot unlink); F2P+P2P green.
- **Bars:** `run_ansible_bars` runs this check only (OpenTofu shape;
  scope-manifest stays select/verify).

# Blocking findings

None.

# Comparison

| Question | What this run shows | Requirement | Result |
| --- | --- | --- | --- |
| Demonstrated failure? | assert-red on fixture with sibling playbook | Red | Met |
| Golden → green? | verify F2P+P2P after patch | Green | Met |
| Product green? | machine-layers single converge.yml + bars | Green | Met |

# Evidence and limitations

Manifest under `runs/20260929-ansible-single-converge/` (latest verify
`20260929T204710Z-48446`, verdict=pass).

Does not run `ansible-playbook`, ansible-lint, or per-role naming bars.
Empty zero-byte siblings after Apple `patch` are ignored by design.

# Next action

Ship hub PR (goal+fixture first; this result in a later local commit).

# Manual verification

None — kit redistribute from hub 518db3f; eval-ci and pre-commit bars are the covering automated checks.
