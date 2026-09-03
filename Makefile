.DEFAULT_GOAL := help

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Override to prove the missing-binary failure path, for example:
# make doctor REQUIRED_TOOLS="git make definitely-not-a-tool"
REQUIRED_TOOLS ?= git make

.PHONY: help doctor

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} \
		/^[a-zA-Z0-9_.-]+:.*##/ { printf "  %-12s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf "\nNo deploy, apply or destroy target exists in Milestone 0.\n"
	@printf "Doctor does not use cloud credentials and does not call AWS.\n\n"

doctor: ## Check required local tools (no cloud credentials, no AWS)
	@missing=0; \
	for t in $(REQUIRED_TOOLS); do \
		if command -v "$$t" >/dev/null 2>&1; then \
			printf 'ok  %s (%s)\n' "$$t" "$$(command -v "$$t")"; \
		else \
			printf 'missing: %s\n' "$$t"; \
			printf 'install %s and re-run make doctor\n' "$$t"; \
			missing=1; \
		fi; \
	done; \
	if command -v gitleaks >/dev/null 2>&1; then \
		printf 'opt gitleaks (%s)\n' "$$(command -v gitleaks)"; \
	else \
		printf 'opt gitleaks not found (CI installs a checksum-pinned binary)\n'; \
	fi; \
	if command -v frictionctl >/dev/null 2>&1; then \
		printf 'opt frictionctl (%s) — journeys are not proved in Milestone 0\n' "$$(command -v frictionctl)"; \
	else \
		printf 'opt frictionctl not found (pin recorded in .friction/; journeys not proved)\n'; \
	fi; \
	if [ "$$missing" -ne 0 ]; then \
		printf 'doctor FAIL: required local tools missing\n'; \
		exit 1; \
	fi; \
	printf 'doctor OK (no cloud credentials used)\n'
