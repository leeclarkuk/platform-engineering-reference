.DEFAULT_GOAL := help

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

PROVIDER     ?=
ENVIRONMENT  ?=
STACK        ?=
CONFIRM      ?=
TEST         ?= pod-delete
GO           ?= go
GOBIN        := $(CURDIR)/bin

ifeq ($(PROVIDER),aws)
  ifneq ($(STACK),)
    TF_DIR := terraform/aws/$(STACK)
  else
    TF_DIR := terraform/aws/workload
  endif
else
  TF_DIR := terraform/$(PROVIDER)
endif

TFVARS := $(TF_DIR)/environments/$(ENVIRONMENT).tfvars

.PHONY: help init lint test validate security docs build clean \
	plan deploy destroy fmt tf-init tf-validate \
	cli sample-service check-provider check-environment check-stack \
	verify-aws verify-live failure-test

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} \
		/^[a-zA-Z0-9_.-]+:.*##/ { printf "  %-18s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf "\nDangerous targets require PROVIDER and ENVIRONMENT.\n"
	@printf "Example: make plan PROVIDER=aws ENVIRONMENT=dev STACK=network\n"
	@printf "AWS stacks: bootstrap, network, workload.\n\n"

init: ## Install local hooks and Go modules
	@if command -v pre-commit >/dev/null 2>&1; then pre-commit install; fi
	@$(GO) -C examples/sample-service mod download
	@$(GO) -C developer-platform/cli mod download

fmt: ## Format Terraform and Go
	@terraform fmt -recursive terraform landing-zones
	@$(GO) -C examples/sample-service fmt ./...
	@$(GO) -C developer-platform/cli fmt ./...

lint: ## Lint Markdown, YAML, shell, Terraform and Go
	@scripts/lint.sh

test: ## Run unit tests
	@$(GO) -C examples/sample-service test ./...
	@$(GO) -C developer-platform/cli test ./...
	@scripts/test-policy.sh
	@scripts/aws/assert-routes.sh

validate: ## Validate Terraform, Helm and Kubernetes manifests without cloud credentials
	@scripts/validate.sh

security: ## Run IaC and filesystem scanners, including the insecure fixture proof
	@scripts/security.sh

docs: ## Check documentation layout
	@test -f docs/principles/README.md
	@test -f docs/decisions/README.md
	@test -f docs/ROADMAP.md
	@test -f docs/aws/deployment.md
	@echo "Documentation layout OK"

build: cli sample-service ## Build CLI and sample service into ./bin

cli: ## Build the platform CLI
	@mkdir -p $(GOBIN)
	@$(GO) -C developer-platform/cli build -o $(GOBIN)/platform ./

sample-service: ## Build the sample API
	@mkdir -p $(GOBIN)
	@$(GO) -C examples/sample-service build -o $(GOBIN)/sample-service ./cmd/sample-service

clean: ## Remove build artefacts and local Terraform directories
	@rm -rf $(GOBIN) coverage.out
	@find terraform landing-zones -type d -name .terraform -prune -exec rm -rf {} +
	@find terraform landing-zones -name '*.tfstate*' -delete

verify-aws: ## Static AWS verification with no cloud credentials
	@scripts/aws/verify-aws.sh

verify-live: ## Prove the sample application answers (requires kubeconfig)
	@scripts/aws/verify-live.sh

failure-test: ## Run a failure-lab experiment. TEST=pod-delete|bad-deployment|network-policy|node-loss
	@scripts/failure-lab/run.sh

check-provider:
	@if [ -z "$(PROVIDER)" ]; then echo "PROVIDER is required (aws|azure|gcp)"; exit 1; fi
	@if [ "$(PROVIDER)" = "aws" ]; then \
		if [ -n "$(STACK)" ] && [ ! -d "terraform/aws/$(STACK)" ]; then echo "Unknown STACK=$(STACK)"; exit 1; fi; \
	elif [ ! -d "$(TF_DIR)" ]; then echo "Unknown PROVIDER=$(PROVIDER)"; exit 1; fi

check-environment:
	@if [ -z "$(ENVIRONMENT)" ]; then echo "ENVIRONMENT is required (dev|staging|prod)"; exit 1; fi
	@if [ ! -f "$(TFVARS)" ]; then echo "Missing $(TFVARS)"; exit 1; fi

tf-init: check-provider ## terraform init -backend=false for a provider or AWS stack
	@if [ "$(PROVIDER)" = "aws" ] && [ -z "$(STACK)" ]; then \
		for s in bootstrap network workload; do terraform -chdir=terraform/aws/$$s init -backend=false -input=false; done; \
	else \
		terraform -chdir=$(TF_DIR) init -backend=false -input=false; \
	fi

tf-validate: tf-init ## terraform validate for a provider or AWS stack
	@if [ "$(PROVIDER)" = "aws" ] && [ -z "$(STACK)" ]; then \
		for s in bootstrap network workload; do terraform -chdir=terraform/aws/$$s validate; done; \
	else \
		terraform -chdir=$(TF_DIR) validate; \
	fi

plan: check-provider check-environment ## Plan changes (requires PROVIDER and ENVIRONMENT)
	@if [ "$(PROVIDER)" = "aws" ] && [ -z "$(STACK)" ]; then \
		for s in network workload; do \
			echo "== plan $$s"; \
			terraform -chdir=terraform/aws/$$s init -backend=false -input=false; \
			terraform -chdir=terraform/aws/$$s plan -input=false -var-file=environments/$(ENVIRONMENT).tfvars; \
		done; \
	else \
		terraform -chdir=$(TF_DIR) init -backend=false -input=false; \
		terraform -chdir=$(TF_DIR) plan -input=false -var-file=environments/$(ENVIRONMENT).tfvars; \
	fi

deploy: check-provider check-environment ## Apply changes. Requires CONFIRM=yes.
	@if [ "$(CONFIRM)" != "yes" ]; then \
		echo "Refusing to apply. Re-run with CONFIRM=yes PROVIDER=$(PROVIDER) ENVIRONMENT=$(ENVIRONMENT) STACK=$(STACK)"; \
		echo "Sequence for AWS: STACK=bootstrap, then network, then workload."; \
		exit 1; \
	fi
	@if [ "$(PROVIDER)" = "aws" ] && [ -z "$(STACK)" ]; then \
		echo "AWS deploy requires STACK=bootstrap|network|workload so account boundaries stay explicit."; \
		exit 1; \
	fi
	terraform -chdir=$(TF_DIR) init -input=false
	terraform -chdir=$(TF_DIR) apply -input=false -var-file=environments/$(ENVIRONMENT).tfvars

destroy: check-provider check-environment ## Destroy is never the default. Prints the command unless CONFIRM=yes.
	@if [ -z "$(STACK)" ] && [ "$(PROVIDER)" = "aws" ]; then \
		echo "AWS destroy requires STACK so it cannot infer a target."; \
		echo "Example: make destroy PROVIDER=aws ENVIRONMENT=dev STACK=workload"; \
		exit 1; \
	fi
	@if [ "$(CONFIRM)" != "yes" ]; then \
		echo "Destruction is deliberate. This target will not run it for you."; \
		echo "Run: make destroy PROVIDER=$(PROVIDER) ENVIRONMENT=$(ENVIRONMENT) STACK=$(STACK) CONFIRM=yes"; \
		echo "Or: terraform -chdir=$(TF_DIR) destroy -var-file=environments/$(ENVIRONMENT).tfvars"; \
		exit 1; \
	fi
	terraform -chdir=$(TF_DIR) destroy -input=false -var-file=environments/$(ENVIRONMENT).tfvars
