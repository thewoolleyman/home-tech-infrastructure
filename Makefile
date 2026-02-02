.PHONY: help lint test test-unit test-integration test-acceptance test-all \
       deploy-pi verify-pi prep-pi-image health-check bootstrap-secrets

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  %-20s %s\n", $$1, $$2}'

# --- Quality ---

lint: ## ShellCheck all shell scripts
	@find infrastructure/ scripts/ -name '*.sh' -print0 | xargs -0 shellcheck

# --- Tests ---

test: lint test-unit ## Run lint + unit tests (no Pi needed)

test-unit: ## Run bats-core unit tests
	@./tests/libs/bats-core/bin/bats tests/unit/

test-integration: ## Run goss specs on Pis (requires SSH to Pis)
	@echo "Not implemented yet (Story 5.4)"

test-acceptance: ## End-to-end network tests (requires live network)
	@echo "Not implemented yet (Story 5.5)"

test-all: ## Run everything (lint + unit + integration + acceptance)
	@echo "Not implemented yet (Story 5.5)"

# --- Deployment ---

prep-pi-image: ## Checklist for flashing a new Pi SD card. Usage: make prep-pi-image ROLE=bastion
	@echo "Not implemented yet (Story 5.1)"

deploy-pi: ## Deploy to Pi (3-phase). Usage: make deploy-pi ROLE=bastion TARGET=192.168.1.10
	@echo "Not implemented yet (Story 5.3)"

verify-pi: ## Smoke test a Pi after deploy. Usage: make verify-pi TARGET=192.168.1.10
	@echo "Not implemented yet (Story 5.4)"

# --- Secrets ---

bootstrap-secrets: ## Generate age keypair + .sops.yaml (run once per project)
	@scripts/bootstrap/bootstrap-secrets.sh

# --- Operations ---

health-check: ## Run health checks (DNS, SSH, CoreDNS process)
	@echo "Not implemented yet (Story 6.4)"
