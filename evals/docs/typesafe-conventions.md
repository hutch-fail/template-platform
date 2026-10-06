# TypeSafe conventions (hutch-fail)

Shared rules for every TypeSafe (System One / Jev) integration in this monorepo.
Code owns control flow; Jev supplies typed **Choice** / **Noul** / **Score**.
Live docs are the source of truth — read the primitive page and closest cookbook
from [llms.txt](https://docs.typesafe.ai/llms.txt) before coding.

This file is conventions only, not a shared client library. Each workstream
installs and uses the SDK in its own package so agents do not fight over one
`package.json`.

## API key

| Item | Value |
| --- | --- |
| Env var | `TYPESAFE_API_KEY` |
| Source | Repo-root [`.env`](../../.env) at `/home/hutchic/github.com/hutch-fail/.env` |
| Load | `python-dotenv` / Node `dotenv` (or equivalent) from that root `.env` |
| Missing key | **Fail closed** — do not invent a PASS, default “success,” or soft skip that looks green |

Never commit the key. Never print, log, or echo it (including in CI output,
fixture dumps, or error messages).

## SDKs

| Language | Pointer |
| --- | --- |
| Python | [Python SDK](https://docs.typesafe.ai/sdk/python.md) |
| JavaScript / TypeScript | [`@typesafe-ai/sdk`](https://docs.typesafe.ai/sdk/javascript.md) |

Skill context: `~/.agents/skills/typesafe-ai`. Prefer server-side or CLI usage;
never expose the API key to the browser.

## Thresholds

- **Noul PASS** when `score >= 0.5`, unless a pack’s own docs say otherwise.
- Treat scores below the threshold as FAIL (or the pack’s explicit negative path).

## Design

- **One narrow claim per question.** Compose AND/OR (and speculative independent
  questions) in code, not in a single overloaded prompt.
- Prefer structured primitives over free-form LLM rubrics for soft judges.
- Hard gates (HTTP status, exact lookups, pin==running, allowlists) stay in code.

## Fail-closed

| Situation | Expected behavior |
| --- | --- |
| Missing / unloadable `TYPESAFE_API_KEY` | ERROR / fail / safe fallback (`other`, exit 2, etc.) — **not** PASS |
| API / network failure | Fail closed per caller docs; do not invent a typed verdict |
| Ambiguous product path | Document the closed path (e.g. Meter probe → treat as `other`) |

## Secrets

- Use the key only on the server, in CLI helpers, or in CI with secret stores.
- Never browser-expose `TYPESAFE_API_KEY`.
- Agents and scripts must not echo the key when running live calls.

## Non-goals (do not TypeSafe)

Keep these as code or contract fixes — do not replace them with Jev:

- Token **number** scraping from transcripts (prefer structured usage emitters).
- YAML / frontmatter parsers.
- Feature allowlists and pin==running equality checks.
- Gateway `ENABLED_FEATURES` / LiteLLM SSO exact lookups.
- SaaSMail in-repo asserts (no mail semantics in this wave; upstream keyword
  classify is a later patch track).

## Related deferred work

Documented elsewhere / next wave — not covered by these conventions alone:

- Prod-landing fail-closed Noul pack
- Meter prompt→cost-class Score/Choice router
- Paperclip design-critique Score / escalation Noul
- SaaSMail upstream send-error classify
