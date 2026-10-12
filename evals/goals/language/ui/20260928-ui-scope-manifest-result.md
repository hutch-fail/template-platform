# Result

**Recommendation:** Adopt

`make eval/assert-red` failed closed without `languages: ui`; `make eval/verify`
passed with `HERMES_EVAL_REPO_ROOT` pointing at `service-meter` after that
consumer declared `ui` in `evals/scope.yaml`.

# Outcome

- Language seed: `goals/language/ui/20260928-ui-scope-manifest.md`
  (`scope: language`, `languages: ui`).
- **Demonstrated red:** `assert-red` against empty / hub roots lacking
  `languages: ui`.
- **Pass:** service-meter `evals/scope.yaml` lists `ui`; verify green.
- Select: with `languages: [ui]`, language/ui goals select; empty languages
  omits them.

# Blocking findings

None.

# Comparison

| Question | What this run shows | Requirement | Result |
| --- | --- | --- | --- |
| Demonstrated failure? | assert-red without ui in languages | Red | Met |
| Pass in child repo? | scope.yaml + verify green | Green | Met |
| Language seed present? | `goals/language/ui/…` | Present | Met |

# Evidence and limitations

Manifest under `runs/20260928-ui-scope-manifest/` (latest verify).
Product change: `service-meter/evals/scope.yaml` (separate PR).

Does not migrate Jev/visual into hub language bars or enable a required
select gate.

# Next action

Ship hub + service-meter PRs; re-include meter in sync/list (done with
own-leaf layout).
