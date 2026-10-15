# Evals hub — public Make API (host-runnable; no Incus required for TB1/TB2a).
GOAL ?= fixture-token-echo
CONSUMERS_ROOT ?= $(HOME)/github.com/hutch-fail
HUB ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SYNC_FORMAT ?= tsv
# Comma/space-separated repo names to omit from include=true (e.g. machine-layers).
SYNC_EXCLUDE ?=

EVAL ?= meta/calibration/good-01.yaml
META_FLAGS ?=
META_PYTHON ?= $(shell if [ -x meta/.venv/bin/python ]; then echo meta/.venv/bin/python; else echo python3; fi)

.PHONY: help eval/parse eval/assert-red eval/run eval/verify eval/solve eval/ab eval/list eval/select eval/doctor-scope eval/doctor-attach eval/bars eval/report \
	sync/list sync/harvest sync/pull sync/doctor sync/reset-main sync/redistribute sync/ship-land \
	sync/ensure-org-submodules meta/validate meta/calibrate meta/pack-judge-selftest \
	optmem/doctor optmem/reconcile

JEV_SAMPLES ?= fixtures/universe/20260929-meta-eval-pack-quality/samples

help:
	@printf '%s\n' \
		'make eval/parse GOAL=…' \
		'make eval/assert-red GOAL=…' \
		'make eval/run GOAL=…' \
		'make eval/verify GOAL=…' \
		'make eval/solve GOAL=…' \
		'make eval/ab GOAL=…' \
		'make eval/list [GOAL=…]' \
		'make eval/select [GOAL=…]' \
		'make eval/doctor-scope' \
		'make eval/doctor-attach' \
		'make eval/bars   # universe always + language families (manifest + paths)' \
		'make eval/report GOAL=…' \
		'make sync/list [CONSUMERS_ROOT=…] [SYNC_FORMAT=tsv|json] [SYNC_EXCLUDE=…]' \
		'make sync/harvest CONSUMERS_ROOT=…' \
		'make sync/pull HUB=…   # run from consumer root via: make -C evals sync/pull HUB=…' \
		'make sync/reset-main CONSUMERS_ROOT=… [SYNC_EXCLUDE=…]' \
		'make sync/redistribute CONSUMERS_ROOT=… HUB=… [SYNC_EXCLUDE=…]' \
		'make sync/ship-land CONSUMERS_ROOT=… HUB=… [SYNC_EXCLUDE=…]' \
		'make sync/ensure-org-submodules CONSUMERS_ROOT=…  # local parent + submodule pins' \
		'make sync/doctor CONSUMERS_ROOT=… [SYNC_EXCLUDE=…]' \
		'make meta/validate EVAL=meta/calibration/good-01.yaml [META_FLAGS=…]' \
		'make meta/calibrate [META_FLAGS=…]  # hub-only criterion toys (not pack-quality CI)' \
		'make meta/pack-judge-selftest  # Jev pack-quality labeled samples (TYPESAFE_API_KEY)' \
		'make optmem/doctor    # source .env + store doctor + LLM probe (litellm-api)' \
		'make optmem/reconcile # source .env + python3 optmem/repo-memo reconcile (CI twin)'

eval/parse:
	@bash harness/goal.sh parse "$(GOAL)"

eval/assert-red:
	@bash harness/goal.sh assert-red "$(GOAL)"

eval/run:
	@bash harness/goal.sh run "$(GOAL)"

eval/verify:
	@bash harness/goal.sh verify "$(GOAL)"

eval/solve:
	@bash harness/goal.sh solve "$(GOAL)"

eval/ab:
	@bash harness/goal.sh ab "$(GOAL)"

eval/list:
	@bash harness/goal.sh list "$(if $(filter command line environment,$(origin GOAL)),$(GOAL),)"

eval/select:
	@bash harness/goal.sh select "$(if $(filter command line environment,$(origin GOAL)),$(GOAL),)"

eval/doctor-scope:
	@bash harness/goal.sh doctor-scope

eval/doctor-attach:
	@bash harness/goal.sh doctor-attach

# Shared bars: always universe; language families from scope.yaml languages:,
# path args (pre-commit), or HERMES_EVAL_FORCE_FAMILIES. CI: scripts/ci-eval-bars.sh.
eval/bars:
	@bash scripts/eval-bars.sh

eval/report:
	@bash harness/goal.sh report "$(GOAL)"

sync/list:
	@CONSUMERS_ROOT="$(CONSUMERS_ROOT)" SYNC_EXCLUDE="$(SYNC_EXCLUDE)" \
		bash scripts/sync-list-repos.sh --format "$(SYNC_FORMAT)" --consumers-root "$(CONSUMERS_ROOT)"

sync/harvest:
	@CONSUMERS_ROOT="$(CONSUMERS_ROOT)" bash scripts/sync-harvest.sh --consumers-root "$(CONSUMERS_ROOT)"

# Intended from a consumer checkout: make -C evals sync/pull HUB=/path/to/hub
# When invoked inside the hub itself, HUB defaults to this tree (no-op-ish refresh).
sync/pull:
	@bash scripts/sync-pull.sh --hub "$(HUB)"

sync/doctor:
	@CONSUMERS_ROOT="$(CONSUMERS_ROOT)" SYNC_EXCLUDE="$(SYNC_EXCLUDE)" bash scripts/sync-doctor.sh

sync/reset-main:
	@CONSUMERS_ROOT="$(CONSUMERS_ROOT)" SYNC_EXCLUDE="$(SYNC_EXCLUDE)" \
		bash scripts/sync-reset-to-main.sh --consumers-root "$(CONSUMERS_ROOT)"

sync/redistribute:
	@CONSUMERS_ROOT="$(CONSUMERS_ROOT)" SYNC_EXCLUDE="$(SYNC_EXCLUDE)" \
		bash scripts/sync-redistribute.sh --consumers-root "$(CONSUMERS_ROOT)" --hub "$(HUB)"

sync/ship-land:
	@CONSUMERS_ROOT="$(CONSUMERS_ROOT)" SYNC_EXCLUDE="$(SYNC_EXCLUDE)" \
		bash scripts/sync-ship-land.sh --consumers-root "$(CONSUMERS_ROOT)" --hub "$(HUB)"

# Local-only parent at CONSUMERS_ROOT: register include=true (+ hub evals) as submodules.
# Does not publish a GitHub remote for the parent. After sync/reset-main, re-run to refresh pins.
sync/ensure-org-submodules:
	@CONSUMERS_ROOT="$(CONSUMERS_ROOT)" bash scripts/sync-ensure-org-submodules.sh --consumers-root "$(CONSUMERS_ROOT)"

meta/validate:
	@$(META_PYTHON) meta/validate.py validate "$(EVAL)" $(META_FLAGS)

meta/calibrate:
	@$(META_PYTHON) meta/validate.py calibrate $(META_FLAGS)

# Path-triggered in pack-quality CI when judge/samples change; use locally while calibrating.
meta/pack-judge-selftest:
	@$(META_PYTHON) harness/lib/jev_pack_quality_judge.py --selftest "$(JEV_SAMPLES)"

# Load repo .env (same names as Actions secrets) then run CI-shaped OptMem commands.
define OPTMEM_LOAD_ENV
	if [ -f .env ]; then set -a && . ./.env && set +a; fi;
endef

optmem/doctor:
	@$(OPTMEM_LOAD_ENV) OPTMEM_DOCTOR_LLM=1 python3 optmem/repo-memo doctor --llm

optmem/reconcile:
	@$(OPTMEM_LOAD_ENV) python3 optmem/repo-memo reconcile
