# Result

**Recommendation:** Adopt

`make eval/verify` passed for `language/opentofu/20260924-remote-backend-locking`
(fixture local backend → golden `backend "s3" {}`).

# Outcome

- Language bar: `goals/language/opentofu/20260924-remote-backend-locking.md`
  (`scope: language`, `languages: opentofu`).
- **Demonstrated red:** `assert-red` — fixture `backend "local"` fails `check.sh`.
- **Pass:** after `golden.patch`, F2P+P2P green.
- Rule A only: remote non-local backend required; DynamoDB locking not enforced.

# Blocking findings

None.

# Comparison

| Question | What this run shows | Requirement | Result |
| --- | --- | --- | --- |
| Demonstrated failure? | assert-red on local backend fixture | Red | Met |
| Pass after patch? | verify green | Green | Met |

# Evidence and limitations

Manifest under `runs/20260924-remote-backend-locking/` (latest verify).
Product enforcement via `scripts/pre-commit-eval-opentofu.sh` is covered by
`20260924-precommit-eval-opentofu`.

# Next action

Wire the pre-commit hook on `platform-github`, then other TF-bearing `platform-*`.

# Manual verification

None — kit redistribute from hub 518db3f; eval-ci and pre-commit bars are the covering automated checks.
