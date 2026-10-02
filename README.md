# template-platform

GitHub template for new hutch-fail platform stacks (OpenTofu + IAC CI defaults).

Use **Use this template** on GitHub, then:

1. Rename the remote / repo as needed.
2. Change the R2 state key from `template/terraform.tfstate` in:
   - `.env` / `.env.example` (`TF_BACKEND_KEY`)
   - `.github/workflows/iac-plan.yml` and `iac-apply.yml` (`tf_backend_key`)
3. Add providers and resources under `terraform/`.
4. `cp .env.example .env`, fill R2 vars, run `make doctor`, then `make sync-secrets`.

## Day-to-day

Prefer CI over local apply when the stack is live:

1. Open a PR that touches `terraform/`, `scripts/`, or the Makefile.
2. `iac-plan` posts a plan comment (environment `production` secrets).
3. Merge to `main` → `iac-apply` applies.

Local entrypoints (same scripts CI runs):

```bash
make doctor
make init
make validate
make plan
# make apply   # break-glass only when CI is not the authority
make sync-secrets
```

## Remote state

State lives in Cloudflare R2 bucket `platform-state`. See
[docs/bootstrap-state.md](docs/bootstrap-state.md).
