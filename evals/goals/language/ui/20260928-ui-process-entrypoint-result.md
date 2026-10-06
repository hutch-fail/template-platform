# Result

**Recommendation:** Adopt

`make eval/assert-red` failed closed without process entrypoint/fixtures;
`make eval/verify` passed against `service-meter` after own-leaf
`ui-process/fixtures` + `npm run ui:process` wiring.

# Outcome

- Language bar: `goals/language/ui/20260928-ui-process-entrypoint.md`.
- **Demonstrated red:** empty product root (no `ui:process` / fixtures).
- **Pass:** Meter exposes `scripts.ui:process` and own-leaf process JSON;
  `eval/bars` `ui` family runs both scope-manifest and process-entrypoint
  checks.
- Crawl only: Jev/visual/System-2 stay product-owned.

# Blocking findings

None.

# Comparison

| Question | What this run shows | Requirement | Result |
| --- | --- | --- | --- |
| Demonstrated failure? | assert-red on empty root | Red | Met |
| Pass in child repo? | entrypoint + fixtures + verify | Green | Met |
| Bars dispatcher? | `run_ui_bars` in `eval-bars.sh` | Present | Met |

# Evidence and limitations

Manifest under `runs/20260928-ui-process-entrypoint/` (latest verify).
Does not execute `npm run ui:process` inside the language check (path
contract only); Meter CI still runs the npm gate.

# Next action

Promote further shared UI rules into `language/ui/` only when org-wide.
