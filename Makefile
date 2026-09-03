.DEFAULT_GOAL := help

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Override to prove the missing-binary failure path, for example:
# make doctor REQUIRED_TOOLS="git make definitely-not-a-tool"
REQUIRED_TOOLS ?= git make

FILE ?= testdata/workloadcontract-valid.yaml
NAME ?= sample
OWNER ?= platform
NAMESPACE ?= apps
OUT_DIR ?=

.PHONY: help doctor check-prohibited check-prohibited-stdin0 \
	check-m0-assertions check-no-cloud-mutation friction-pin-verify \
	platform-doctor platform-validate platform-create test

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} \
		/^[a-zA-Z0-9_.-]+:.*##/ { printf "  %-28s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf "\nMilestone 1 adds a local platform CLI (doctor, validate, create).\n"
	@printf "No deploy, apply or destroy target exists.\n"
	@printf "Doctor does not use cloud credentials and does not call AWS.\n"
	@printf "friction-pin-verify does not run journeys.\n\n"

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

check-prohibited: ## Reject tracked prohibited files (tfstate, keys, env, tfvars)
	@scripts/check-prohibited-tracked.sh

check-prohibited-stdin0: ## Stdin0 denylist cases (does not create or stage secrets)
	@set -euo pipefail; \
	script=scripts/check-prohibited-tracked.sh; \
	assert_zero() { \
	  local desc="$$1" payload="$$2"; \
	  local out code; \
	  set +e; \
	  out=$$(printf '%s\0' "$$payload" | "$$script" --stdin0 2>&1); \
	  code=$$?; \
	  set -e; \
	  if [ "$$code" -ne 0 ]; then \
	    printf 'FAIL %s: wanted exit 0, got %s\n%s\n' "$$desc" "$$code" "$$out" >&2; \
	    exit 1; \
	  fi; \
	  printf 'ok %s (exit %s)\n' "$$desc" "$$code"; \
	}; \
	assert_nonzero() { \
	  local desc="$$1" payload="$$2"; \
	  local out code; \
	  set +e; \
	  out=$$(printf '%s\0' "$$payload" | "$$script" --stdin0 2>&1); \
	  code=$$?; \
	  set -e; \
	  if [ "$$code" -eq 0 ]; then \
	    printf 'FAIL %s: wanted non-zero, got 0\n%s\n' "$$desc" "$$out" >&2; \
	    exit 1; \
	  fi; \
	  printf '%s\n' "$$out" | grep -Fq 'PROHIBITED:' || { \
	    printf 'FAIL %s: non-zero without PROHIBITED message (unexpected error must not count as rejection)\n%s\n' "$$desc" "$$out" >&2; \
	    exit 1; \
	  }; \
	  printf '%s\n' "$$out" | grep -Fq "$$payload" || { \
	    printf 'FAIL %s: output missing path %s\n%s\n' "$$desc" "$$payload" "$$out" >&2; \
	    exit 1; \
	  }; \
	  printf 'ok %s (exit %s)\n' "$$desc" "$$code"; \
	}; \
	set +e; \
	default_out=$$("$$script" 2>&1); \
	default_code=$$?; \
	set -e; \
	if [ "$$default_code" -ne 0 ]; then \
	  printf 'FAIL default tree: wanted exit 0, got %s\n%s\n' "$$default_code" "$$default_out" >&2; \
	  exit 1; \
	fi; \
	printf 'ok default tree (exit %s)\n' "$$default_code"; \
	assert_nonzero 'secret.tfstate' 'secret.tfstate'; \
	assert_zero '.env.example' '.env.example'; \
	assert_zero 'safe.tfvars.example' 'safe.tfvars.example'; \
	assert_nonzero 'production.tfvars' 'production.tfvars'; \
	assert_nonzero 'nested/path/id_rsa' 'nested/path/id_rsa'; \
	assert_zero 'allowed file.txt' 'allowed file.txt'; \
	assert_nonzero 'my secret.tfstate' 'my secret.tfstate'

check-m0-assertions: ## Targeted Milestone 0 governance assertions
	@set -euo pipefail; \
	grep -Fq 'MODEL_MODE: GROK_ONLY_AUTHORISED_BY_LEE' AGENTS.md; \
	grep -Fq 'REVIEW_INDEPENDENCE: PROCESS_ISOLATED_NOT_MODEL_DIVERSE' AGENTS.md; \
	grep -Fq 'REVIEW_DEBT: RECHECK_WITH_OPUS_WHEN_AVAILABLE' AGENTS.md; \
	grep -Fq 'CONTEXT_MODE: FRESH' AGENTS.md; \
	test -f .cursor/agents/specification-architect.md; \
	test -f .cursor/agents/platform-product-builder.md; \
	test -f .cursor/agents/aws-foundations-builder.md; \
	test -f .cursor/agents/gitops-golden-path-builder.md; \
	test -f .cursor/agents/reliability-security-reviewer.md; \
	test -f .cursor/agents/evidence-adversarial-reviewer.md; \
	test ! -e .cursor/agents/architecture-reasoning.md; \
	test ! -e .cursor/agents/independent-reviewer.md; \
	test ! -e .cursor/agents/reliability-security-builder.md; \
	test ! -e .cursor/agents/aws-platform-builder.md; \
	test ! -e .cursor/agents/multicloud-parity-builder.md; \
	grep -Fq 'readonly: true' .cursor/agents/specification-architect.md; \
	grep -Fq 'readonly: true' .cursor/agents/reliability-security-reviewer.md; \
	grep -Fq 'readonly: true' .cursor/agents/evidence-adversarial-reviewer.md; \
	! grep -RFn 'MODEL_MODE: SOL_OPUS_REQUIRED' AGENTS.md .cursor/agents; \
	! grep -RFn 'REVIEW_INDEPENDENCE: MODEL_INDEPENDENT' AGENTS.md .cursor/agents; \
	! grep -RFn 'version: latest' .github/workflows; \
	! grep -RFn 'go-version: stable' .github/workflows; \
	! grep -RFn 'go-version: oldstable' .github/workflows; \
	! grep -REn "go-version:[[:space:]]*['\"]?[0-9]+\.[0-9]+\.x" .github/workflows; \
	grep -Fq 'PASS_WITH_CONDITIONS' AGENTS.md; \
	grep -Fq 'PASS_WITH_CONDITIONS' .cursor/agents/reliability-security-reviewer.md; \
	grep -Fq 'PASS_WITH_CONDITIONS' .cursor/agents/evidence-adversarial-reviewer.md; \
	grep -Fq 'Any Blocker or High finding must produce `DENY`' AGENTS.md; \
	grep -Fq 'Any Blocker or High finding must produce `DENY`' .cursor/agents/reliability-security-reviewer.md; \
	grep -Fq 'Any Blocker or High finding must produce `DENY`' .cursor/agents/evidence-adversarial-reviewer.md; \
	! grep -Fn '`VERDICT` is `PASS` or `BLOCKED`' AGENTS.md; \
	! grep -Fn '`VERDICT` is `PASS` or `BLOCKED`' .cursor/agents/reliability-security-reviewer.md; \
	! grep -Fn '`VERDICT` is `PASS` or `BLOCKED`' .cursor/agents/evidence-adversarial-reviewer.md; \
	grep -Fq '`VERDICT` is `PASS`, `PASS_WITH_CONDITIONS`, or `DENY`' AGENTS.md; \
	! grep -RFn 'github.event.workflow_run.head_sha' .github/workflows; \
	grep -Fn 'github.event.pull_request.head.sha' .github/workflows/ci.yml; \
	grep -Fn 'github.event.pull_request.base.sha' .github/workflows/ci.yml; \
	printf 'ok m0 assertions\n'

check-no-cloud-mutation: ## Reject runnable cloud-mutation commands in workflows/Make/scripts
	@scripts/check-no-cloud-mutation.sh

friction-pin-verify: ## Verify frictionctl module sums then install the pinned CLI
	@scripts/friction-pin-verify.sh

platform-doctor: ## Run platform doctor (git, make, go; no AWS)
	go run ./cmd/platform doctor

platform-validate: ## Validate a WorkloadContract YAML (FILE=path)
	go run ./cmd/platform validate "$(FILE)"

platform-create: ## Write a WorkloadContract and Helm skeleton (NAME OWNER NAMESPACE [OUT_DIR])
	@if [ -n "$(OUT_DIR)" ]; then \
	  go run ./cmd/platform create --name "$(NAME)" --owner "$(OWNER)" --namespace "$(NAMESPACE)" --out-dir "$(OUT_DIR)"; \
	else \
	  go run ./cmd/platform create --name "$(NAME)" --owner "$(OWNER)" --namespace "$(NAMESPACE)"; \
	fi

test: ## Run Go unit tests
	go test ./...
