---
stepsCompleted: [step-01-validate-prerequisites, step-02-design-epics, step-03-create-stories, step-04-final-validation]
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/brainstorming/architecture-diagram.md
---

# home-tech-infrastructure - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for home-tech-infrastructure, decomposing the requirements from the PRD and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

- FR1: The operator can provision a Pi as an SSH bastion host with hardened, key-only authentication
- FR2: The operator can provision a Pi as a DDNS updater that keeps a DNS provider record current with the home network's public IP
- FR3: The operator can provision a Pi as a split-horizon DNS server that resolves internal hostnames to LAN IPs and external queries to the public IP
- FR4: The operator can provision hot-backup Pis that are identical clones of primary service Pis
- FR5: The operator can add a new hostname to DNS resolution by updating a single configuration source
- FR6: The operator can deploy a complete Pi configuration from a fresh SD card using a single command
- FR7: The operator can deploy to a specific Pi by role and target IP without modifying any scripts
- FR8: The operator can deploy to a hot-backup Pi first as a pre-production staging step before promoting to the primary
- FR9: The operator can roll back a DNS change by reverting a single network pointer in under 30 seconds
- FR10: The operator can run any deploy command multiple times with no errors and no unintended changes (idempotent)
- FR11: The system walks the operator through a first-boot checklist when preparing a fresh Pi image for a given role
- FR12: The operator can run unit tests locally (no Pi required) that validate script logic and catch misconfigurations
- FR13: The operator can run integration tests on a real Pi that verify services are running and correctly configured
- FR14: The operator can run acceptance tests that validate end-to-end network behavior (DNS resolution, SSH access, DDNS updates)
- FR15: The operator can run all quality checks (lint + unit + integration + acceptance) with a single command
- FR16: The operator can verify a specific Pi's health after deployment with a single command
- FR17: The system runs periodic health checks and logs results with pass/fail status and timestamps
- FR18: The operator can store secrets in the git repository in encrypted form that is safe to commit
- FR19: The operator can decrypt secrets as part of the deploy pipeline without manual key handling
- FR20: The system prevents any plaintext credentials from appearing in git history
- FR21: The operator can define all network configuration (IPs, hostnames, roles, domain, ports) in a single source-of-truth file
- FR22: The system generates downstream configuration files (DNS hosts, etc.) from the single source of truth
- FR23: The operator can lint all scripts and catch shell errors before deployment
- FR24: The operator can discover all available operations via a single help command
- FR25: The operator can perform every operation through named commands without memorizing raw tool invocations
- FR26: Every command runs non-interactively with no prompts or confirmations required
- FR27: The operator can understand and operate the entire network from a fresh clone of the repository without external documentation

### NonFunctional Requirements

- NFR1: No plaintext credentials exist in the git repository at any point in history
- NFR2: All secrets are encrypted at rest using SOPS + age; decryption requires a private key stored outside the repo
- NFR3: SSH access to all Pis uses key-only authentication; password authentication is disabled
- NFR4: All Pi SSH daemons are hardened (no root login, restricted ciphers, idle timeout)
- NFR5: Pi firewalls default to deny-all inbound, with explicit allow rules only for required services
- NFR6: All scripts pass ShellCheck with zero warnings (prevents injection and quoting vulnerabilities)
- NFR7: DNS resolution continues without perceptible interruption during any deploy or failover (Pi 4 as secondary DNS in DHCP)
- NFR8: All deploy operations are idempotent -- running twice produces no errors and no state changes
- NFR9: All scripts use `set -euo pipefail` -- no silent failures, errors surface immediately
- NFR10: Recovery from Pi hardware failure requires only a fresh SD card and a single deploy command (< 15 minutes total)
- NFR11: Health checks run every 15 minutes and log pass/fail with timestamps
- NFR12: Every script follows the same conventions: function-based structure, idempotent guards, overridable paths for testing, main guard for sourcing
- NFR13: All scripts are readable by both AI tools (clear interfaces, consistent patterns, inventory.sh contract) and a human debugging at 2am (no magic, descriptive function names)
- NFR14: A fresh `git clone` + `make help` is sufficient to discover and understand all available operations
- NFR15: Adding a new service follows the existing patterns with no new tooling required (same TDD cycle, same deploy pipeline, same test pyramid)

### Additional Requirements

From Architecture:

- Greenfield repo -- no starter template. Scaffolding must be created from scratch.
- Repository structure follows the defined layout: `infrastructure/pi-scripts/`, `scripts/deploy/`, `scripts/ops/`, `tests/{unit,integration,acceptance}/`
- Shell scripts must follow the documented conventions: `set -euo pipefail`, function-based, idempotent guards, overridable paths, PROJECT_ROOT via BASH_SOURCE, main guard
- Deploy pipeline is 3-phase: decrypt.sh -> push.sh -> run-setup.sh, each phase independently testable
- inventory.sh is the single source of truth, sourced by all scripts
- CoreDNS uses hosts plugin with generated hosts file from inventory.sh; Corefile is static
- SOPS + age: single `secrets.enc.yaml` for Pi tier, age private key backed up to 1Password
- SSH key strategy: 3 keypairs (personal, CI/deploy in SOPS, Pi host key backups in SOPS)
- Pi base image: RPi OS Lite 64-bit (Bookworm), `make prep-pi-image` handles first-boot config
- Hot-backup sync: cron/rsync from primary to backup every 15 minutes
- Health check: DNS + SSH + CoreDNS process checks, logged with timestamps
- goss specs for integration testing; bats-core with bats-assert/bats-support for unit testing
- MVP build follows the 12-step sequence from architecture (age keypair -> scaffolding -> common scripts -> bastion scripts -> DNS scripts -> secrets -> deploy pipeline -> flash+deploy -> acceptance -> cut-over -> verify)

### FR Coverage Map

| FR | Epic | Description |
|---|---|---|
| FR1 | Epic 3 | Bastion with hardened SSH |
| FR2 | Epic 3 | DDNS updater |
| FR3 | Epic 4 | Split-horizon DNS |
| FR4 | Epic 6 | Hot-backup Pis |
| FR5 | Epic 4 | Add hostname via inventory.sh |
| FR6 | Epic 5 | Deploy from fresh SD card |
| FR7 | Epic 5 | Deploy by role and target IP |
| FR8 | Epic 6 | Deploy to hot-backup first |
| FR9 | Epic 6 | Rollback via DNS pointer |
| FR10 | Epic 5 | Idempotent deploys |
| FR11 | Epic 5 | First-boot checklist |
| FR12 | Epic 3+4 | Unit tests (created with each script) |
| FR13 | Epic 5 | Integration tests (goss on Pi) |
| FR14 | Epic 5 | Acceptance tests (end-to-end) |
| FR15 | Epic 5 | Single command for all tests |
| FR16 | Epic 5 | Verify Pi health post-deploy |
| FR17 | Epic 6 | Periodic health checks |
| FR18 | Epic 2 | Secrets encrypted in git |
| FR19 | Epic 2 | Decrypt in deploy pipeline |
| FR20 | Epic 2 | No plaintext in git history |
| FR21 | Epic 1 | inventory.sh (single source of truth) |
| FR22 | Epic 4 | Generated config from inventory |
| FR23 | Epic 1 | ShellCheck lint |
| FR24 | Epic 1 | make help |
| FR25 | Epic 1 | Named Makefile targets |
| FR26 | Epic 1 | Non-interactive commands |
| FR27 | Epic 1 | Repo as documentation |

## Epic List

### Epic 1: Repository Foundation & Tooling
Chad can clone the repo, run `make help`, and discover all operations. The TDD toolchain (bats-core, ShellCheck, goss) is installed and ready. inventory.sh defines the entire network.
**FRs covered:** FR21, FR23, FR24, FR25, FR26, FR27

### Epic 2: Secrets Bootstrap
Chad can safely store credentials in git via SOPS + age encryption and decrypt them for deployment. No plaintext secrets ever touch git history.
**FRs covered:** FR18, FR19, FR20

### Epic 3: Bastion & Remote Access
Chad can provision Pi 1 as a hardened SSH bastion with DDNS. Scripts written TDD-first with bats-core unit tests. Common hardening (SSH, firewall, unattended-upgrades) built here and reused by later epics.
**FRs covered:** FR1, FR2, FR12

### Epic 4: DNS & Name Resolution
Chad can provision Pi 2 as a split-horizon DNS server for mindlikewater.net. Hosts file generated from inventory.sh. Scripts written TDD-first.
**FRs covered:** FR3, FR5, FR22, FR12

### Epic 5: Deploy Pipeline & Verification
Chad can deploy any Pi from a fresh SD card with a single command and verify it works. The full test pyramid (unit, integration, acceptance) runs end-to-end.
**FRs covered:** FR6, FR7, FR10, FR11, FR13, FR14, FR15, FR16

### Epic 6: Hot Backups & Steady-State Operations
Chad's network survives Pi hardware failure. Hot backups provide staging targets and automatic DNS fallback. Health checks detect failures.
**FRs covered:** FR4, FR8, FR9, FR17

---

## Epic 1: Repository Foundation & Tooling

Chad can clone the repo, run `make help`, and discover all operations. The TDD toolchain (bats-core, ShellCheck, goss) is installed and ready. inventory.sh defines the entire network.

### Story 1.1: Create Repository Scaffolding and Makefile

As the operator,
I want the repository directory structure and a Makefile with `make help`,
So that I can discover all available operations from a fresh clone.

**Acceptance Criteria:**

**Given** a fresh clone of the repository
**When** I run `make help`
**Then** I see a formatted list of all available Makefile targets with descriptions
**And** the directory structure matches the architecture specification (`infrastructure/pi-scripts/`, `scripts/deploy/`, `scripts/ops/`, `tests/unit/`, `tests/integration/`, `tests/acceptance/`)

**Given** the Makefile exists
**When** I inspect it
**Then** every target uses `.PHONY` declarations
**And** every public target has a `## description` comment for `make help`
**And** all commands run non-interactively with no prompts

**FRs:** FR24, FR25, FR26

### Story 1.2: Create inventory.sh as Single Source of Truth

As the operator,
I want all network configuration defined in a single inventory.sh file,
So that I can update IPs, hostnames, and roles in one place and have all scripts inherit the change.

**Acceptance Criteria:**

**Given** inventory.sh exists at `infrastructure/pi-scripts/inventory.sh`
**When** I source it in a shell
**Then** all network variables are exported (DOMAIN, ROUTER_IP, PI1_IP through PI4_IP, hostnames, roles, DEPLOY_USER, DNS upstreams)
**And** variable values match the architecture specification

**Given** a bats-core unit test exists for inventory.sh
**When** I run `make test-unit`
**Then** the test verifies all expected variables are defined and non-empty
**And** the test verifies IP address format validity

**FRs:** FR21

### Story 1.3: Set Up TDD Toolchain

As the operator,
I want bats-core (with bats-assert and bats-support), ShellCheck, and goss available,
So that I can run unit tests locally and lint scripts before deployment.

**Acceptance Criteria:**

**Given** the repository is freshly cloned
**When** I follow the README setup instructions
**Then** bats-core, bats-assert, and bats-support are installed (git submodules or system install)
**And** ShellCheck is available on the PATH

**Given** the toolchain is installed
**When** I run `make lint`
**Then** ShellCheck runs against all `.sh` files under `infrastructure/` and `scripts/`
**And** zero warnings are reported (NFR6)

**Given** the toolchain is installed
**When** I run `make test-unit`
**Then** bats-core discovers and runs all `tests/unit/*.bats` files
**And** test results show pass/fail with descriptive names

**FRs:** FR23, FR12 (partial)
**NFRs:** NFR6

### Story 1.4: Create README with Setup and Operations Guide

As the operator,
I want a README that documents setup steps and references `make` targets,
So that I can understand and operate the entire network from a fresh clone without external documentation.

**Acceptance Criteria:**

**Given** the README exists
**When** I read it
**Then** it describes the project purpose, network topology, and Pi roles
**And** it documents prerequisites and setup steps
**And** it references `make help` as the primary entry point for operations
**And** it does not contain any raw tool invocations (only `make` targets)

**Given** a fresh clone
**When** I follow the README from top to bottom
**Then** I can set up the development environment and run `make help` successfully

**FRs:** FR27

---

## Epic 2: Secrets Bootstrap

Chad can safely store credentials in git via SOPS + age encryption and decrypt them for deployment. No plaintext secrets ever touch git history.

### Story 2.1: Generate age Keypair and Configure .sops.yaml

As the operator,
I want an age keypair generation script and .sops.yaml configuration,
So that I can encrypt secrets with a key whose private half is backed up in 1Password and never committed to git.

**Acceptance Criteria:**

**Given** no age keypair exists
**When** I run `make bootstrap-secrets`
**Then** an age keypair is generated (public + private key)
**And** the script displays clear instructions to back up the private key to 1Password
**And** a `.sops.yaml` file is created with the age public key as the encryption recipient

**Given** `.sops.yaml` exists
**When** I inspect it
**Then** it contains only the age public key (no private key material)
**And** it specifies the encryption path pattern for `secrets.enc.yaml` files

**Given** `.gitignore` exists
**When** I inspect it
**Then** it includes patterns for `age.key`, `*.agekey`, and `*.dec.yaml`

**Given** a bats-core unit test exists
**When** I run `make test-unit`
**Then** the test verifies the keypair generation function produces valid output
**And** the test verifies `.sops.yaml` structure

**FRs:** FR18, FR20
**NFRs:** NFR1, NFR2

### Story 2.2: Create and Encrypt Secrets File

As the operator,
I want a SOPS-encrypted `secrets.enc.yaml` containing all Pi-tier secrets,
So that credentials are safely committed to git and never appear in plaintext in history.

**Acceptance Criteria:**

**Given** an age keypair exists and `.sops.yaml` is configured
**When** I run the secrets creation target
**Then** a `secrets.enc.yaml` is created at `infrastructure/pi-scripts/secrets.enc.yaml`
**And** it contains encrypted fields for: deploy SSH private key, Namecheap DDNS password, and Pi host key backups

**Given** `secrets.enc.yaml` is committed to git
**When** I inspect git history
**Then** no plaintext secret values appear in any commit

**Given** the `SOPS_AGE_KEY_FILE` environment variable points to the age private key
**When** I run `sops --decrypt infrastructure/pi-scripts/secrets.enc.yaml`
**Then** the plaintext values are correctly decrypted

**FRs:** FR18, FR20
**NFRs:** NFR1, NFR2

### Story 2.3: Create Decrypt Script for Deploy Pipeline

As the operator,
I want a `decrypt.sh` script (Phase 1 of the deploy pipeline),
So that secrets are decrypted to a temp directory for deployment and shredded after use.

**Acceptance Criteria:**

**Given** `secrets.enc.yaml` exists and the age private key is available
**When** I run `scripts/deploy/decrypt.sh`
**Then** secrets are decrypted to a temporary directory
**And** role-specific secrets are extracted

**Given** the decrypt script runs successfully
**When** I inspect the temp directory
**Then** decrypted files have strict permissions (600)

**Given** a bats-core unit test exists with a mocked `sops` command
**When** I run `make test-unit`
**Then** the test verifies `decrypt.sh` calls sops with correct arguments
**And** the test verifies temp directory creation and permissions

**Given** `decrypt.sh` is called with no age key available
**When** I run it
**Then** it fails with a clear error message (not a silent failure)

**FRs:** FR19
**NFRs:** NFR2, NFR9

---

## Epic 3: Bastion & Remote Access

Chad can provision Pi 1 as a hardened SSH bastion with DDNS. Scripts written TDD-first with bats-core unit tests. Common hardening (SSH, firewall, unattended-upgrades) built here and reused by later epics.

### Story 3.1: Create Common SSH and Firewall Hardening Script with Tests

As the operator,
I want a common hardening script that disables password SSH, restricts ciphers, and configures the firewall to deny-all with explicit allows,
So that every Pi starts from a hardened baseline.

**Acceptance Criteria:**

**Given** `harden.sh` exists at `infrastructure/pi-scripts/common/harden.sh`
**When** I run the `harden_ssh` function
**Then** password authentication is disabled in sshd_config
**And** root login is disabled
**And** restricted cipher suites are configured
**And** idle timeout is set

**Given** the firewall function runs
**When** I inspect the iptables rules
**Then** the default policy is deny-all inbound
**And** explicit allow rules exist only for SSH (port 22)
**And** established/related connections are allowed

**Given** the script has already been run once
**When** I run it again
**Then** no errors occur and no configuration changes are made (idempotent)

**Given** bats-core tests exist with overridden paths (`SSHD_CONFIG`, `SYSTEMCTL` point to temp)
**When** I run `make test-unit`
**Then** all hardening tests pass
**And** idempotency is verified by running functions twice

**FRs:** FR1 (partial)
**NFRs:** NFR3, NFR4, NFR5, NFR8, NFR9, NFR12

### Story 3.2: Create Unattended-Upgrades Script with Tests

As the operator,
I want an unattended-upgrades setup script,
So that every Pi automatically receives security updates without manual intervention.

**Acceptance Criteria:**

**Given** `unattended-upgrades.sh` exists at `infrastructure/pi-scripts/common/`
**When** I run the setup function
**Then** the `unattended-upgrades` package is installed
**And** automatic security updates are enabled
**And** the configuration is non-interactive

**Given** unattended-upgrades is already installed and configured
**When** I run the script again
**Then** no errors occur and no changes are made (idempotent)

**Given** bats-core tests exist
**When** I run `make test-unit`
**Then** the install and configuration functions are tested with mocked package commands

**FRs:** FR1 (partial -- hardened Pi)
**NFRs:** NFR8, NFR12

### Story 3.3: Create Bastion Setup Script with Tests

As the operator,
I want a `setup-bastion.sh` script that configures Pi 1 as an SSH bastion host,
So that Pi 1 serves as a hardened jump host for remote access.

**Acceptance Criteria:**

**Given** `setup-bastion.sh` exists at `infrastructure/pi-scripts/bastion/`
**When** I run main
**Then** common hardening is applied (calls harden.sh functions)
**And** the deploy user's `authorized_keys` contains the CI/deploy public key
**And** bastion-specific SSH configuration is applied

**Given** the script follows shell conventions
**When** I inspect it
**Then** it uses `set -euo pipefail`, function-based structure, overridable paths, and main guard
**And** all functions return 0/1 (never `exit`)

**Given** bats-core tests exist
**When** I run `make test-unit`
**Then** tests verify bastion setup with mocked system commands
**And** the test sources `setup-bastion.sh` without executing main

**FRs:** FR1
**NFRs:** NFR3, NFR4, NFR8, NFR12

### Story 3.4: Create DDNS Update Script with Tests

As the operator,
I want a DDNS update script and cron job configuration,
So that mindlikewater.net's bastion A record always reflects the current public IP.

**Acceptance Criteria:**

**Given** `update-namecheap.sh` exists at `scripts/ddns/`
**When** the public IP has changed since the last check
**Then** the script calls the Namecheap DDNS API with the new IP
**And** the update is logged with timestamp

**Given** the public IP has NOT changed
**When** the script runs
**Then** no API call is made (no-op)
**And** the skip is logged

**Given** `setup-ddns.sh` exists at `infrastructure/pi-scripts/bastion/`
**When** I run it
**Then** a cron job is installed that runs `update-namecheap.sh` every 5 minutes
**And** the cron job is idempotent (running `setup-ddns.sh` twice does not create duplicate entries)

**Given** bats-core tests exist with mocked curl and IP detection
**When** I run `make test-unit`
**Then** the IP change detection logic is tested (changed, unchanged, error cases)
**And** the cron installation function is tested

**FRs:** FR2
**NFRs:** NFR8, NFR9, NFR12

---

## Epic 4: DNS & Name Resolution

Chad can provision Pi 2 as a split-horizon DNS server for mindlikewater.net. Hosts file generated from inventory.sh. Scripts written TDD-first.

### Story 4.1: Create DNS Hosts File Generator with Tests

As the operator,
I want a script that generates the CoreDNS hosts file from inventory.sh,
So that adding a new hostname requires only updating inventory.sh.

**Acceptance Criteria:**

**Given** inventory.sh defines all network hosts
**When** I run the `generate_hosts_file` function
**Then** a hosts file is written to the `COREDNS_HOSTS` path
**And** every hostname in inventory.sh appears with its correct IP
**And** the file format is valid for the CoreDNS hosts plugin (`IP<tab>FQDN`)

**Given** a new hostname is added to inventory.sh
**When** I regenerate the hosts file
**Then** the new hostname appears in the output
**And** no manual file editing is required

**Given** bats-core tests exist with `COREDNS_HOSTS` pointing to a temp file
**When** I run `make test-unit`
**Then** the generated file content matches expected hostnames and IPs
**And** the test sources inventory.sh for expected values

**FRs:** FR5, FR22
**NFRs:** NFR12

### Story 4.2: Create CoreDNS Setup Script with Tests

As the operator,
I want a `setup-coredns.sh` script that installs and configures CoreDNS for split-horizon DNS,
So that internal queries resolve to LAN IPs and external queries are forwarded upstream.

**Acceptance Criteria:**

**Given** `setup-coredns.sh` exists at `infrastructure/pi-scripts/dns/`
**When** I run the setup function
**Then** the CoreDNS binary is installed (arm64)
**And** the Corefile is written to `/etc/coredns/Corefile` with the mindlikewater.net zone and forwarder block
**And** the hosts file is generated from inventory.sh
**And** CoreDNS is configured as a systemd service (enabled, started)

**Given** the Corefile is written
**When** I inspect it
**Then** the mindlikewater.net zone uses the hosts plugin with `fallthrough`
**And** the forwarder block forwards to 1.1.1.1 and 9.9.9.9 with 30-second cache

**Given** CoreDNS is already installed and configured
**When** I run the script again
**Then** no errors occur and no changes are made (idempotent)

**Given** bats-core tests exist
**When** I run `make test-unit`
**Then** Corefile generation is tested (expected content, correct upstream DNS)
**And** idempotency is verified

**FRs:** FR3
**NFRs:** NFR7 (partial -- DNS available), NFR8, NFR12

---

## Epic 5: Deploy Pipeline & Verification

Chad can deploy any Pi from a fresh SD card with a single command and verify it works. The full test pyramid (unit, integration, acceptance) runs end-to-end.

### Story 5.1: Create Pi Image Preparation Script

As the operator,
I want a `prep-pi-image.sh` script that walks me through first-boot configuration,
So that I can prepare a fresh SD card for a specific Pi role without memorizing steps.

**Acceptance Criteria:**

**Given** a freshly flashed RPi OS Lite 64-bit SD card
**When** I run `make prep-pi-image ROLE=bastion`
**Then** the script walks through a checklist: enable SSH, set hostname, configure static IP, create deploy user
**And** each step displays what it is doing and verifies completion

**Given** a role is specified (bastion or dns)
**When** the script runs
**Then** the hostname and static IP are set based on inventory.sh values for that role

**Given** bats-core tests exist
**When** I run `make test-unit`
**Then** the checklist logic is tested with mocked system paths

**FRs:** FR11
**NFRs:** NFR12

### Story 5.2: Create Deploy Pipeline Scripts (push.sh and run-setup.sh)

As the operator,
I want `push.sh` (Phase 2) and `run-setup.sh` (Phase 3) scripts,
So that I can deploy scripts to a Pi and execute them remotely by role and target IP.

**Acceptance Criteria:**

**Given** `push.sh` exists at `scripts/deploy/`
**When** I run `push.sh bastion 192.168.1.10`
**Then** setup scripts for the bastion role are copied to the Pi at `/opt/pi-setup/` via scp
**And** decrypted secrets are copied with strict permissions (600)

**Given** `run-setup.sh` exists at `scripts/deploy/`
**When** I run `run-setup.sh bastion 192.168.1.10`
**Then** it connects to the Pi via SSH and executes the role's main setup script
**And** local decrypted secrets are shredded after successful execution

**Given** I specify an invalid role
**When** I run either script
**Then** it fails with a clear error message listing valid roles

**Given** bats-core tests exist
**When** I run `make test-unit`
**Then** `push.sh` is tested with mocked scp (`SCP` variable override)
**And** `run-setup.sh` is tested with mocked ssh (`SSH` variable override)

**FRs:** FR7
**NFRs:** NFR8, NFR9, NFR12

### Story 5.3: Create deploy-pi Makefile Target with Idempotency

As the operator,
I want a single `make deploy-pi` command that orchestrates all 3 deploy phases,
So that I can deploy a complete Pi configuration from start to finish with one command.

**Acceptance Criteria:**

**Given** the age private key is available
**When** I run `make deploy-pi ROLE=bastion TARGET=192.168.1.10`
**Then** Phase 1 (`decrypt.sh`) decrypts secrets
**And** Phase 2 (`push.sh`) copies scripts and secrets to the Pi
**And** Phase 3 (`run-setup.sh`) executes the setup on the Pi

**Given** a Pi has already been deployed
**When** I run `make deploy-pi` again with the same parameters
**Then** the deploy completes with no errors and no unintended changes (idempotent)

**Given** any phase fails
**When** I inspect the output
**Then** the error message identifies which phase failed and why

**FRs:** FR6, FR10
**NFRs:** NFR8, NFR10

### Story 5.4: Create Goss Integration Test Specs

As the operator,
I want goss specs for bastion and DNS roles,
So that I can verify a Pi's configuration is correct after deployment.

**Acceptance Criteria:**

**Given** goss spec files exist at `tests/integration/`
**When** I run `make verify-pi TARGET=192.168.1.10`
**Then** goss validates the bastion Pi: SSH hardening, firewall rules, DDNS cron, deploy user

**Given** goss spec files exist for the DNS role
**When** I run `make verify-pi TARGET=192.168.1.11`
**Then** goss validates the DNS Pi: CoreDNS binary, CoreDNS service running, DNS resolution, port 53 listening

**Given** a `common.yaml` goss spec exists
**When** I verify any Pi
**Then** common checks pass: unattended-upgrades installed, deploy user exists, SSH password auth disabled

**Given** `setup-goss.sh` exists at `infrastructure/pi-scripts/common/`
**When** the deploy pipeline runs
**Then** goss is installed on the Pi as part of the common setup

**FRs:** FR13, FR16
**NFRs:** NFR11 (partial)

### Story 5.5: Create Acceptance Tests and Unified Test Targets

As the operator,
I want acceptance test scripts and a single `make test-all` command,
So that I can validate end-to-end network behavior and run all quality checks with one command.

**Acceptance Criteria:**

**Given** `test_dns_resolution.sh` exists at `tests/acceptance/`
**When** I run it from a LAN client
**Then** it verifies internal DNS resolution (mindlikewater.net hostnames resolve to LAN IPs)
**And** it verifies upstream forwarding (google.com resolves)

**Given** `test_ddns_propagation.sh` exists at `tests/acceptance/`
**When** I run it
**Then** it verifies the Namecheap DDNS record matches the current public IP

**Given** `test_socks_proxy.sh` exists at `tests/acceptance/`
**When** I run it
**Then** it verifies SSH SOCKS proxy through the bastion reaches internal services

**Given** the Makefile has a `test-all` target
**When** I run `make test-all`
**Then** it runs lint, test-unit, test-integration, and test-acceptance in sequence
**And** a single non-zero exit code indicates which stage failed

**FRs:** FR14, FR15
**NFRs:** NFR6

---

## Epic 6: Hot Backups & Steady-State Operations

Chad's network survives Pi hardware failure. Hot backups provide staging targets and automatic DNS fallback. Health checks detect failures.

### Story 6.1: Create Hot-Backup Sync Scripts with Tests

As the operator,
I want sync scripts that keep Pi 3 and Pi 4 as identical clones of Pi 1 and Pi 2,
So that I have standby backups ready for instant promotion.

**Acceptance Criteria:**

**Given** `sync-bastion.sh` exists at `infrastructure/pi-scripts/sync/`
**When** I run it (or the cron job fires)
**Then** configuration from Pi 1 is synced to Pi 3 via rsync
**And** synced items include: `/etc/ssh/sshd_config`, cron jobs, installed package list

**Given** `sync-dns.sh` exists
**When** it runs
**Then** Pi 2 configuration is synced to Pi 4 via rsync
**And** synced items include: `/etc/coredns/`, `/etc/ssh/sshd_config`, cron jobs

**Given** the sync scripts are deployed to the primary Pis
**When** setup completes
**Then** cron jobs run the sync every 15 minutes

**Given** bats-core tests exist
**When** I run `make test-unit`
**Then** sync functions are tested with mocked rsync (`RSYNC` variable override)

**FRs:** FR4
**NFRs:** NFR8, NFR12

### Story 6.2: Create Deploy-to-Backup-First Workflow

As the operator,
I want to deploy changes to hot-backup Pis first,
So that I can verify changes on non-production targets before promoting to primary.

**Acceptance Criteria:**

**Given** I want to update the bastion configuration
**When** I run `make deploy-pi ROLE=bastion TARGET=192.168.1.12` (Pi 3, backup)
**Then** the full deploy pipeline runs against the backup Pi
**And** `make verify-pi TARGET=192.168.1.12` confirms the backup is healthy

**Given** the backup Pi is verified
**When** I then run `make deploy-pi ROLE=bastion TARGET=192.168.1.10` (Pi 1, primary)
**Then** the same configuration is deployed to the primary

**Given** the Makefile documents this workflow
**When** I run `make help`
**Then** the deploy target description mentions the recommended backup-first pattern

**FRs:** FR8

### Story 6.3: Create DNS Rollback Script with Tests

As the operator,
I want a rollback script that reverts the DHCP DNS pointer,
So that I can undo a DNS cut-over in under 30 seconds.

**Acceptance Criteria:**

**Given** DHCP is pointing clients to Pi 2 as DNS server
**When** I run `make rollback-dns`
**Then** the DHCP DNS setting is reverted to the router's default (or a specified fallback)
**And** the rollback completes in under 30 seconds

**Given** rollback documentation exists in the README or ops documentation
**When** I read it during an incident
**Then** I can execute the rollback via either the script or manual router UI steps

**Given** bats-core tests exist
**When** I run `make test-unit`
**Then** rollback logic is tested with mocked router API calls

**FRs:** FR9

### Story 6.4: Create Health Check Script with Cron Scheduling

As the operator,
I want a `health-check.sh` script that verifies Pi infrastructure is healthy,
So that failures are detected automatically and logged with timestamps.

**Acceptance Criteria:**

**Given** `health-check.sh` exists at `scripts/ops/`
**When** I run `make health-check`
**Then** it checks: DNS resolution via Pi 2, SSH to Pi 1, SSH to Pi 2, CoreDNS process running on Pi 2
**And** results are logged with pass/fail status and timestamps

**Given** all checks pass
**When** I inspect the output
**Then** it reports "OK" with the current timestamp

**Given** any check fails
**When** I inspect the output
**Then** it reports which checks failed with descriptive messages
**And** exits with non-zero status

**Given** the health check is deployed for steady-state monitoring
**When** cron runs it every 15 minutes
**Then** results are appended to a log file
**And** failures are detectable by checking the log

**Given** bats-core tests exist with mocked SSH and dig commands
**When** I run `make test-unit`
**Then** pass, fail, and mixed scenarios are tested

**FRs:** FR17
**NFRs:** NFR11
