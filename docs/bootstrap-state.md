# OpenTofu remote state (R2)

`template-platform` (and stacks created from it) store OpenTofu state in
Cloudflare R2:

```text
platform-state
  template/terraform.tfstate
```

After "Use this template", change `TF_BACKEND_KEY` (and the matching
`tf_backend_key` inputs in `.github/workflows/iac-*.yml`) to a unique key for
the new stack (for example `my-stack/terraform.tfstate`).

Credentials are **bucket-scoped** R2 access keys passed only via environment
(`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`). Non-secret backend settings use
`TF_BACKEND_*` and `scripts/tofu-init.sh` `-backend-config` flags.

Create the bucket and keys via the Cloudflare UI first — see
[`platform-cloudflare` docs/r2-state-bootstrap.md](https://github.com/hutch-fail/platform-cloudflare/blob/main/docs/r2-state-bootstrap.md).

## Local bootstrap

1. `cp .env.example .env` and fill R2 vars until `make doctor` is clean.
2. `make init && make validate && make plan`
3. `make sync-secrets` so Actions environment `production` receives the same R2 credentials.
4. Prefer CI for apply: PR → `iac-plan` comment → merge → `iac-apply`.

## CI secrets (environment `production`)

| Secret | Required |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | yes |
| `AWS_SECRET_ACCESS_KEY` | yes |
| `TF_BACKEND_ENDPOINT` | yes |
| `CLOUDFLARE_ACCOUNT_ID` | yes |
| `OP_SERVICE_ACCOUNT_TOKEN` | optional (reusable workflow helpers) |
| `OP_SERVICE_ACCOUNT_KEY` | optional |
| `ORG_BILLING_TOKEN` | optional (runner billing check) |

`iac-plan` / `iac-apply` use R2 only. There is **no** `actions/cache` of
`terraform.tfstate`. Concurrency group `template-platform-production` serializes
applies on this template repo.

## Rules

- Never commit `terraform.tfstate*` or `.terraform/`.
- Never put R2 secrets in committed backend HCL.
- Do not share one state key across multiple stacks.
