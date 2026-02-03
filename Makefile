.PHONY: help lint test test-unit test-python test-integration test-acceptance test-all \
       deploy-pi deploy-backup-first verify-pi prep-pi-image converge \
       health-check bootstrap-secrets status rollback-dns verify-network \
       modem-status router-status configure-dhcp-dns configure-port-forwards

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

test-python: ## Run Python unit tests (pytest)
	@python3 -m pytest tests/unit/test_tplink_client.py -q

test-integration: ## Run goss specs on Pis (requires SSH to Pis). Usage: make test-integration TARGET=192.168.1.10
	@scripts/deploy/verify-pi.sh $(TARGET)

test-acceptance: ## End-to-end network tests (requires live network)
	@tests/acceptance/test_dns_resolution.sh && \
	 tests/acceptance/test_ddns_propagation.sh && \
	 tests/acceptance/test_socks_proxy.sh

test-all: lint test-unit test-python ## Run everything (lint + unit + python + integration + acceptance)
	@echo "--- Integration and acceptance tests require live network ---"
	@echo "Run: make test-integration TARGET=<pi-ip>"
	@echo "Run: make test-acceptance"

# --- Deployment ---

prep-pi-image: ## Checklist for flashing a new Pi SD card. Usage: make prep-pi-image ROLE=bastion
	@scripts/deploy/prep-pi-image.sh $(ROLE)

deploy-pi: ## Deploy to Pi (3-phase). Usage: make deploy-pi ROLE=bastion TARGET=192.168.1.10
	@scripts/deploy/deploy-pi.sh $(ROLE) $(TARGET)

deploy-backup-first: ## Deploy to backup Pi first, then primary. Usage: make deploy-backup-first ROLE=bastion
	@scripts/deploy/deploy-with-backup.sh $(ROLE)

verify-pi: ## Verify Pi config with goss. Usage: make verify-pi TARGET=192.168.1.10
	@scripts/deploy/verify-pi.sh $(TARGET)

converge: ## Converge fleet to declared state. Usage: make converge [ROLE=bastion] [DRY_RUN=1]
	@scripts/deploy/converge.sh

# --- Secrets ---

bootstrap-secrets: ## Generate age keypair + .sops.yaml (run once per project)
	@scripts/bootstrap/bootstrap-secrets.sh

# --- Operations ---

health-check: ## Run health checks (DNS, SSH, CoreDNS process)
	@scripts/ops/health-check.sh

status: ## Show fleet status (all hosts, DNS, network devices)
	@scripts/ops/fleet-status.sh

rollback-dns: ## Revert DHCP DNS pointer (manual steps + verification)
	@scripts/ops/rollback-dns.sh

verify-network: ## Verify network after modem/router cutover
	@scripts/ops/verify-network.sh

modem-status: ## Show Xfinity XB8 modem status
	@scripts/ops/modem-status.sh

router-status: ## Show Archer router status
	@scripts/ops/router-status.sh

configure-dhcp-dns: ## Point router DHCP DNS to Pi2 (auto or manual). Usage: make configure-dhcp-dns
	@scripts/ops/configure-dhcp-dns.sh

configure-port-forwards: ## Set up SSH port forwarding on router (auto or manual). Usage: make configure-port-forwards
	@scripts/ops/configure-port-forwards.sh
