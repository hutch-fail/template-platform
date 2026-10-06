# Result

**Recommendation:** Adopt

`make eval/assert-red` certified red with `HERMES_EVAL_REPO_ROOT` pointing at
`machine-layers` while `languages: []`. `make eval/verify` passed after that
consumer declared `ansible` in `evals/scope.yaml`.

# Outcome

- Language seed: `goals/language/ansible/20260929-ansible-scope-manifest.md`
  (`scope: language`, `languages: ansible`).
- **Demonstrated red:** assert-red against machine-layers pre-declare
  (`languages must include ansible (got [])`).
- **Pass:** machine-layers `evals/scope.yaml` lists `ansible`; verify green.
- Select: with `languages: [ansible]`, language/ansible goals select; empty
  languages omits them.

# Blocking findings

None.

# Comparison

| Question | What this run shows | Requirement | Result |
| --- | --- | --- | --- |
| Demonstrated failure? | assert-red without ansible in languages | Red | Met |
| Pass in child repo? | scope.yaml + verify green | Green | Met |
| Language seed present? | `goals/language/ansible/…` | Present | Met |

# Evidence and limitations

Manifest under `runs/20260929-ansible-scope-manifest/` (latest verify
`20260929T204709Z-48343`, verdict=pass).
Product change: `machine-layers/evals/scope.yaml` (separate consumer PR).

Does not prove other consumers, live guest converge, or a mandatory select gate.

# Next action

Ship hub PR (goal+fixture, then result in a later commit). Consumer declare
lands with machine-layers. Redistribute / sync/pull is a later explicit ask.
