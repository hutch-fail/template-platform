# template-platform — local and CI share these targets.
# Day-to-day: PR → iac-plan comment → merge → iac-apply (avoid local make apply on shared R2).

.PHONY: help doctor init validate plan apply sync-secrets

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SCRIPTS := $(ROOT)/scripts

help:
	@printf '%s\n' \
	  'template-platform Make targets' \
	  '' \
	  '  make doctor               Check local prerequisites (.env, tofu, R2)' \
	  '  make init                 OpenTofu init (R2 backend when configured)' \
	  '  make validate             OpenTofu validate' \
	  '  make plan                 OpenTofu plan (writes terraform/tfplan)' \
	  '  make apply                OpenTofu apply — prefer CI iac-apply on main' \
	  '  make sync-secrets         Push R2 secrets from .env → GitHub env production' \
	  '' \
	  'State: R2 platform-state / template/terraform.tfstate' \
	  'Docs:  docs/bootstrap-state.md'

doctor:
	@bash $(SCRIPTS)/doctor.sh

init:
	@bash $(SCRIPTS)/tofu-init.sh

validate: init
	@bash $(SCRIPTS)/tofu-validate.sh

plan: init
	@bash $(SCRIPTS)/tofu-plan.sh

apply: init
	@bash $(SCRIPTS)/tofu-apply.sh

sync-secrets:
	@bash $(SCRIPTS)/sync-secrets.sh
