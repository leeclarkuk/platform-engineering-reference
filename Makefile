.DEFAULT_GOAL := help

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

PROVIDER     ?=
ENVIRONMENT  ?=
TF_DIR       := terraform/$(PROVIDER)
TFVARS       := $(TF_DIR)/environments/$(ENVIRONMENT).tfvars
GO           ?= go
GOBIN        := $(CURDIR)/bin

.PHONY: help init lint test validate security docs build clean \
	plan deploy destroy fmt tf-init tf-validate \
	cli sample-service check-provider check-environment

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} \
		/^[a-zA-Z0-9_.-]+:.*##/ { printf "  %-18s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf "\nDangerous targets require PROVIDER and ENVIRONMENT.\n"
	@printf "Example: make plan PROVIDER=aws ENVIRONMENT=dev\n\n"

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

validate: ## Validate Terraform, Helm and Kubernetes manifests without cloud credentials
	@scripts/validate.sh

security: ## Run IaC and filesystem scanners, including the insecure fixture proof
	@scripts/security.sh

docs: ## Check documentation layout
	@test -f docs/principles/README.md
	@test -f docs/decisions/README.md
	@test -f docs/ROADMAP.md
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

check-provider:
	@if [ -z "$(PROVIDER)" ]; then echo "PROVIDER is required (aws|azure|gcp)"; exit 1; fi
	@if [ ! -d "$(TF_DIR)" ]; then echo "Unknown PROVIDER=$(PROVIDER)"; exit 1; fi

check-environment:
	@if [ -z "$(ENVIRONMENT)" ]; then echo "ENVIRONMENT is required (dev|staging|prod)"; exit 1; fi
	@if [ ! -f "$(TFVARS)" ]; then echo "Missing $(TFVARS)"; exit 1; fi

tf-init: check-provider ## terraform init -backend=false for a provider
	@terraform -chdir=$(TF_DIR) init -backend=false -input=false

tf-validate: tf-init ## terraform validate for a provider
	@terraform -chdir=$(TF_DIR) validate

plan: check-provider check-environment ## Plan changes (requires PROVIDER and ENVIRONMENT)
	@terraform -chdir=$(TF_DIR) init -backend=false -input=false
	@terraform -chdir=$(TF_DIR) plan -input=false -var-file=environments/$(ENVIRONMENT).tfvars

deploy: check-provider check-environment ## Apply changes. Refuses to run without PROVIDER and ENVIRONMENT.
	@echo "Refusing to apply from Make without an interactive confirmation."
	@echo "Run: terraform -chdir=$(TF_DIR) apply -var-file=environments/$(ENVIRONMENT).tfvars"
	@exit 1

destroy: check-provider check-environment ## Destroy is never the default. Prints the command instead.
	@echo "Destruction is deliberate. This target will not run it for you."
	@echo "Run: terraform -chdir=$(TF_DIR) destroy -var-file=environments/$(ENVIRONMENT).tfvars"
	@exit 1
