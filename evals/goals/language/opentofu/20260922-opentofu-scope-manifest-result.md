# Result

**Recommendation:** Adopt

`make eval/verify` passed for `language/opentofu/20260922-opentofu-scope-manifest`
with `HERMES_EVAL_REPO_ROOT` pointing at `platform-github` after landing
`evals/scope.yaml` there.

# Outcome

- Language seed: `goals/language/opentofu/20260922-opentofu-scope-manifest.md`
  (`scope: language`, `languages: opentofu`).
- **Demonstrated red:** `assert-red` against platform-github before the manifest
  (`missing evals/scope.yaml`).
- **Pass:** platform-github `evals/scope.yaml` declares `repo` + `languages: [opentofu]`;
  verify green with that product root.
- Select: with an opentofu manifest, the language goal is selected; without it,
  hub select omits it. Universe smokes still select.

# Blocking findings

None.

# Comparison

| Question | What this run shows | Requirement | Result |
| --- | --- | --- | --- |
| Demonstrated failure? | assert-red vs platform-github pre-manifest | Red | Met |
| Pass in child repo? | scope.yaml + verify green | Green | Met |
| Language seed present? | `goals/language/opentofu/…` | Present | Met |

# Evidence and limitations

Manifest under `runs/20260922-opentofu-scope-manifest/` (latest verify).
Product change: `platform-github/evals/scope.yaml` (separate PR).

Does not migrate other consumers or enable a required select gate.

# Next action

Ship hub + platform-github PRs; close #9. Remaining open issue on the hub is #2
(Make/doctor/secrets) if still desired.

# Manual verification

None — kit redistribute from hub 518db3f; eval-ci and pre-commit bars are the covering automated checks.
