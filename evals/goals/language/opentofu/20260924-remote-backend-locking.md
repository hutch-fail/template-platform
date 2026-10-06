---
schema: goal/v1
id: 20260924-remote-backend-locking
title: Terraform state must use a remote backend with locking
scope: language
languages: opentofu
fixture_dir: evals/fixtures/language/opentofu/20260924-remote-backend-locking
f2p_check: check.sh
p2p_check: p2p-smoke.sh
golden_patch: golden.patch
solver: none
---

# Decision

A pass lets us say OpenTofu/Terraform consumers that declare `languages: opentofu`
do not use `backend "local"` (or omit a backend entirely) for shared state —
they declare a non-local remote backend (e.g. `backend "s3" {}`). A pass does
**not** prove DynamoDB/lease locking is configured; that is a later bar.
A pass against the fixture does not prove every product CI gate runs this check.

# User outcome

Team applies stop corrupting state via concurrent local backends; remote state
is required before shared environments.

# Scope

| Covered | Not covered |
| --- | --- |
| Fail `backend "local"` and missing backend under scanned `*.tf` | DynamoDB / blob lease lock tables |
| Pass any non-local backend type (incl. partial `s3` {}) | Provider/module quality, fmt/validate |
| Fixture red→green via golden; product scan via `HERMES_EVAL_SCAN_ROOT` | Universe bars; mandatory select→verify CI |

# Success criteria

| Criterion | What we look at |
| --- | --- |
| Starts broken | Fixture `terraform/backend.tf` uses `backend "local"`; `check.sh` exits non-zero |
| The fix works | After `golden.patch`, backend is non-local and `check.sh` exits 0 |
| Nothing else breaks | `p2p-smoke.sh` stays green |

# Dataset

One fixture Terraform root. Product pre-commit scans the consumer tree the same way.

# Grading

| Criterion | Who grades it | Why |
| --- | --- | --- |
| Backend type remote | Program (`check.sh`) | Directly visible in HCL |

# Acceptance gates

Set before the run.

| Question | Pass | Fail |
| --- | --- | --- |
| Did the patch remove local backend? | F2P fails before patch; F2P+P2P pass after | Either check wrong |

# Execution

`make eval/assert-red` then `make eval/verify`. Pre-commit uses
`evals/scripts/pre-commit-eval-opentofu.sh` when `*.tf` change.

# Limitations

Locking (DynamoDB, leases) is documented importance only — not enforced in v1.
Does not scan files under `evals/` or `.terraform/`.

# Result file

After the run, write `20260924-remote-backend-locking-result.md` beside this goal.
