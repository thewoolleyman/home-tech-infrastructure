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
- FR31: The operator can converge all Pis to their declared state with a single command (`make converge`)
- FR32: The operator can check the health status of all hosts with a single command (`make status`)
- FR33: The operator can preview what convergence would change without applying changes (`make converge DRY_RUN=1`)

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

- FR28: The operator can programmatically verify the Xfinity modem's bridge mode status and configuration
- FR29: The operator can programmatically read and configure the router (SSID, DHCP, port forwarding, WiFi bands)
- FR30: The operator can verify network health after a modem/router cutover with a single command

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
| FR4 | Epic 7 | Hot-backup Pis |
| FR5 | Epic 4 | Add hostname via inventory.sh |
| FR6 | Epic 6 | Deploy from fresh SD card |
| FR7 | Epic 6 | Deploy by role and target IP |
| FR8 | Epic 7 | Deploy to hot-backup first |
| FR9 | Epic 7 | Rollback via DNS pointer |
| FR10 | Epic 6 | Idempotent deploys |
| FR11 | Epic 6 | First-boot checklist |
| FR12 | Epic 3+4 | Unit tests (created with each script) |
| FR13 | Epic 6 | Integration tests (goss on Pi) |
| FR14 | Epic 6 | Acceptance tests (end-to-end) |
| FR15 | Epic 6 | Single command for all tests |
| FR16 | Epic 6 | Verify Pi health post-deploy |
| FR17 | Epic 7 | Periodic health checks |
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
| FR28 | Epic 0 | Modem bridge mode verification |
| FR29 | Epic 0+5 | Router programmatic configuration |
| FR30 | Epic 0 | Network cutover verification |
| FR31 | Epic 6 | Fleet convergence with single command |
| FR32 | Epic 7 | Fleet status check |
| FR33 | Epic 6 | Dry-run / drift detection |

## Epic List

### Epic 0: Network Device Discovery & Automation (NEW)
Chad can programmatically verify and configure network devices (modem, router). Device automation scripts establish the foundation for infrastructure-as-code from the edge inward. Bridge mode is verified, router is configured, and cutover is validated -- all via scripts.
**FRs covered:** FR28, FR29 (partial), FR30
**Status:** Bridge mode enabled manually 2026-02-01. Automation scripts pending.

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

### Epic 5: Router Automation (NEW)
Chad can manage the Archer AXE95 router programmatically from Pi 2. DHCP DNS pointer, port forwarding, and WiFi settings are all scriptable via the TP-Link Python API. This completes the automation layer that Epic 0 bootstrapped manually.
**FRs covered:** FR29

### Epic 6: Deploy Pipeline, Convergence & Verification (was Epic 5)
Chad can deploy any Pi from a fresh SD card with a single command, converge the entire fleet with `make converge`, and verify everything works. The convergence orchestrator iterates over inventory.sh hosts, pushes idempotent role scripts via SSH, executes them, and verifies with goss. The full test pyramid (unit, integration, acceptance) runs end-to-end.
**FRs covered:** FR6, FR7, FR10, FR11, FR13, FR14, FR15, FR16, FR31, FR33

### Epic 7: Hot Backups & Steady-State Operations (was Epic 6)
Chad's network survives Pi hardware failure. Hot backups provide staging targets and automatic DNS fallback. Health checks and fleet status detect failures. `make status` gives a quick overview of all hosts.
**FRs covered:** FR4, FR8, FR9, FR17, FR32

---

## Epic 0: Network Device Discovery & Automation

Chad can programmatically verify and configure network devices (modem, router). Device automation scripts establish the foundation for infrastructure-as-code from the edge inward.

### Story 0.1: Build Xfinity XB8 Modem Client

As the operator,
I want a script that authenticates with the XB8 modem admin and reads its status,
So that I can programmatically verify bridge mode and modem health.

**Acceptance Criteria:**

**Given** the XB8 modem admin is accessible at 10.0.0.1 with "Admin Tool online access" enabled
**When** I run `make modem-status`
**Then** the script authenticates via HTTP POST to the login form
**And** retrieves current bridge mode status from `at_a_glance.jst`
**And** displays: bridge mode on/off, firmware version, connected devices

**Given** the modem admin is unreachable (Admin Tool disabled or network issue)
**When** the script runs
**Then** it fails with a clear error and instructions to enable admin access via the Xfinity app

**Given** unit tests exist with mocked HTTP responses
**When** I run `make test-unit`
**Then** login, status parsing, and error cases are all tested

**FRs:** FR28

### Story 0.2: Build Archer Router Client

As the operator,
I want a script that connects to the TP-Link router admin and reads its configuration,
So that I can programmatically verify SSID, DHCP, port forwarding, and WAN status.

**Acceptance Criteria:**

**Given** the router is at 192.168.1.1
**When** I run `make router-status`
**Then** the script reads: WAN IP, connection type, SSID(s), DHCP range, port forwards
**And** uses the tplinkrouterc2 Python library or direct HTTP API

**Given** specific port forwards are expected (from inventory.sh)
**When** I run `make router-forwards`
**Then** the script lists current port forwards and flags any missing or misconfigured entries

**Given** unit tests exist with mocked API responses
**When** I run `make test-unit`
**Then** status parsing and port forward verification are tested

**FRs:** FR29 (partial)

### Story 0.3: Create Network Cutover Verification Script

As the operator,
I want a single script that verifies the network is healthy after a modem/router change,
So that I can confirm internet connectivity, DHCP, WiFi, and DNS after any cutover.

**Acceptance Criteria:**

**Given** the modem is in bridge mode and the router is online
**When** I run `make verify-network`
**Then** the script checks: internet connectivity (external DNS resolution), router reachable at 192.168.1.1, modem reachable at 10.0.0.1, WiFi SSID broadcasting, DHCP serving IPs

**Given** any check fails
**When** I inspect the output
**Then** it reports which checks failed with descriptive messages and exits non-zero

**FRs:** FR30

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

## Epic 5: Router Automation

Chad can manage the Archer AXE95 router programmatically from Pi 2. DHCP DNS pointer, port forwarding, and WiFi settings are all scriptable via the TP-Link Python API.

### Story 5.1: Create TP-Link API Wrapper with Tests

As the operator,
I want a Python wrapper around the TP-Link router API,
So that I can programmatically read and configure the Archer AXE95 from Pi 2.

**Acceptance Criteria:**

**Given** the tplinkrouterc2 library (or equivalent) supports the AXE95
**When** I import the wrapper module
**Then** I can authenticate, read status, and configure settings programmatically
**And** the wrapper is tested with mocked API responses

**FRs:** FR29

### Story 6.2: Automate DHCP DNS Pointer to Pi 2

As the operator,
I want a script that configures the router's DHCP to hand out Pi 2's IP as the DNS server,
So that all LAN clients automatically use our CoreDNS instance.

**Acceptance Criteria:**

**Given** Pi 2 (dns, 192.168.1.11) is deployed and running CoreDNS
**When** I run `make configure-dhcp-dns`
**Then** the router's DHCP DNS setting is updated to 192.168.1.11
**And** the change is idempotent (running twice produces no errors)

**FRs:** FR29

### Story 6.3: Automate Port Forwarding for SSH Bastion

As the operator,
I want a script that configures the SSH bastion port forward on the router,
So that external SSH access is routed to Pi 1 without manual router UI steps.

**Acceptance Criteria:**

**Given** Pi 1 (bastion, 192.168.1.10) is deployed
**When** I run `make configure-port-forwards`
**Then** port forward ext:4222 -> 192.168.1.10:22 is created (or verified if it exists)
**And** the change is idempotent

**FRs:** FR29

---

## Epic 6: Deploy Pipeline, Convergence & Verification (was Epic 5)

Chad can deploy any Pi from a fresh SD card with a single command, converge the entire fleet with `make converge`, and verify everything works.

### Story 6.1: Create Pi Image Preparation Script

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

### Story 6.2: Create Deploy Pipeline Scripts (push.sh and run-setup.sh)

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

### Story 6.3: Create deploy-pi Makefile Target with Idempotency

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

### Story 6.4: Create Goss Integration Test Specs

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

### Story 6.5: Create Acceptance Tests and Unified Test Targets

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

### Story 6.6: Add Host Enumeration and Role Mapping to inventory.sh

As the operator,
I want inventory.sh to include a HOSTS array and role-to-scripts mapping,
So that the convergence orchestrator can iterate over all hosts and know which scripts to run per role.

**Acceptance Criteria:**

**Given** inventory.sh is updated
**When** I source it in a shell
**Then** a `HOSTS` array exists with entries in `hostname:ip:role` format
**And** a `CONVERGE_ORDER` array defines the convergence sequence
**And** role-to-scripts mapping variables exist (`ROLE_COMMON`, `ROLE_BASTION`, `ROLE_DNS`)
**And** helper functions exist: `pi_ip()`, `pi_role()`, `pis_with_role()`

**Given** existing flat variables (`PI1_IP`, etc.) remain unchanged
**When** existing scripts source inventory.sh
**Then** they continue to work without modification (backward-compatible)

**Given** bats-core tests are updated
**When** I run `make test-unit`
**Then** the HOSTS array, CONVERGE_ORDER, role mapping, and helper functions are all tested

**FRs:** FR21, FR31
**NFRs:** NFR12

### Story 6.7: Create Fleet Convergence Orchestrator

As the operator,
I want a `converge.sh` script and `make converge` target,
So that I can converge all Pis to their declared state with a single command.

**Acceptance Criteria:**

**Given** `converge.sh` exists at `scripts/deploy/`
**When** I run `make converge`
**Then** secrets are decrypted (Phase 1)
**And** for each host in CONVERGE_ORDER: common scripts are pushed and run, then role-specific scripts are pushed and run
**And** for backup hosts: sync scripts are run (Phase 3)
**And** goss verification runs on all hosts (Phase 4)
**And** a summary table shows per-host status (ok/changed/FAIL) with duration
**And** secrets are shredded after completion

**Given** I run `make converge ROLE=bastion`
**When** convergence runs
**Then** only hosts with role=bastion are converged

**Given** I run `make converge DRY_RUN=1`
**When** convergence runs
**Then** it reports what WOULD change on each host without making changes

**Given** a host is unreachable
**When** convergence runs
**Then** it marks the host as UNREACHABLE, continues to other hosts, and exits non-zero

**Given** all hosts are already in desired state
**When** I run `make converge` twice in a row
**Then** the second run reports all hosts as "ok" with zero changes (idempotent)

**Given** bats-core tests exist
**When** I run `make test-unit`
**Then** host iteration, role mapping, filtering (ROLE=, HOST=, SKIP=), and error handling are tested

**FRs:** FR31, FR33
**NFRs:** NFR8, NFR9, NFR10, NFR12

---

## Epic 7: Hot Backups & Steady-State Operations (was Epic 6)

Chad's network survives Pi hardware failure. Hot backups provide staging targets and automatic DNS fallback. Health checks detect failures.

### Story 7.1: Create Hot-Backup Sync Scripts with Tests

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

### Story 7.2: Create Deploy-to-Backup-First Workflow

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

### Story 7.3: Create DNS Rollback Script with Tests

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

### Story 7.4: Create Health Check Script with Cron Scheduling

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

### Story 7.5: Create Fleet Status Command

As the operator,
I want a `make status` command that shows the health of all hosts at a glance,
So that I can quickly check if everything is okay without running convergence.

**Acceptance Criteria:**

**Given** I run `make status`
**When** the status script runs
**Then** it checks reachability (ping, SSH port) for each host in inventory
**And** it checks DNS resolution (internal and external)
**And** it checks network device reachability (modem, router)
**And** it displays a summary table: hostname, role, reachable (yes/no), services (ok/fail)

**Given** all hosts are healthy
**When** I inspect the output
**Then** the last line reads "N hosts healthy. Network ok. DNS ok."

**Given** a host is unreachable
**When** I inspect the output
**Then** the failing host shows "UNREACHABLE" and the exit code is non-zero

**Given** bats-core tests exist
**When** I run `make test-unit`
**Then** the status script is tested with mocked ping and SSH commands

**FRs:** FR32
**NFRs:** NFR14

---

## Epic 8: Physical Infrastructure Deployment & Commissioning

Chad has successfully deployed the physical infrastructure from scripts to live hardware. The network is operational with all services running in production.

**Context:** Epics 0-7 delivered a complete automation system (scripts, tests, deployment pipeline). Epic 8 executes that system against real hardware to achieve a fully operational network.

### Story 8.1: Prepare Physical Hardware and Network Topology

As the operator,
I want to physically connect and power on all network devices,
So that the hardware foundation is ready for software provisioning.

**Acceptance Criteria:**

**Given** the Xfinity XB8 modem and Archer AXE95 router are unpacked
**When** I connect modem WAN → ISP coax, modem LAN → router WAN
**Then** modem is in bridge mode (verify with `make modem-status`)
**And** router gets public IP on WAN interface
**And** router LAN is serving DHCP (192.168.1.x range)

**Given** four Raspberry Pis have fresh SD cards
**When** I flash RPi OS Lite 64-bit to each SD card
**Then** each SD card boots to login prompt
**And** SSH is enabled on boot partition

**Given** all Pis are powered and connected to router LAN
**When** I check router DHCP leases
**Then** all four Pis appear with assigned IPs

**Physical Verification:**
- Modem power LED: solid (not blinking)
- Router power LED: solid
- Router WAN LED: connected
- All four Pis: power LED on, activity LED flickering
- Laptop can reach router admin at 192.168.1.1

**FRs:** FR28, FR30

---

### Story 8.2: Bootstrap First Pi (Bastion) with Manual Configuration

As the operator,
I want to manually configure Pi 1 as the deployment bootstrap host,
So that I have a working bastion to deploy remaining infrastructure from.

**Acceptance Criteria:**

**Given** Pi 1 has fresh RPi OS booted
**When** I run through first-boot setup manually:
- Set hostname: `bastion`
- Configure static IP: `192.168.1.10`
- Create deploy user: `chadops`
- Enable SSH key authentication
- Copy deployment repo to Pi 1
**Then** I can SSH to `chadops@192.168.1.10` from my laptop

**Given** Pi 1 has repo cloned at `/home/chadops/home-tech-infrastructure`
**When** I run `make test-unit` on Pi 1
**Then** all unit tests pass locally on the Pi

**Given** age private key is available on Pi 1
**When** I run `make decrypt-secrets` on Pi 1
**Then** secrets decrypt successfully

**Physical Verification:**
- Can SSH to Pi 1 from laptop: `ssh chadops@192.168.1.10`
- Pi 1 can reach internet: `ping 1.1.1.1`
- Pi 1 has repo with passing tests

**FRs:** FR1 (partial), FR6 (partial)
**NFRs:** NFR3, NFR10

---

### Story 8.3: Execute Initial Deployment - Bastion and DNS

As the operator,
I want to run the deployment pipeline to provision Pi 1 (bastion) and Pi 2 (DNS),
So that core network services are operational.

**Acceptance Criteria:**

**Given** Pi 1 is bootstrapped and repo is ready
**When** I run `make deploy-pi ROLE=bastion TARGET=192.168.1.10`
**Then** bastion deployment completes successfully:
- Common hardening applied (SSH, firewall, unattended-upgrades)
- DDNS cron job installed
- Goss integration tests pass

**Given** Pi 2 has fresh SD card with static IP `192.168.1.11`
**When** I run `make deploy-pi ROLE=dns TARGET=192.168.1.11`
**Then** DNS deployment completes successfully:
- CoreDNS installed and running
- Hosts file generated from inventory.sh
- DNS resolves mindlikewater.net names to LAN IPs
- Goss integration tests pass

**Given** both deployments succeeded
**When** I run `make verify-pi TARGET=192.168.1.10` and `make verify-pi TARGET=192.168.1.11`
**Then** both verification suites report PASS

**Physical Verification:**
- From laptop: `dig bastion.mindlikewater.net @192.168.1.11` returns `192.168.1.10`
- From laptop: `dig dns.mindlikewater.net @192.168.1.11` returns `192.168.1.11`
- From laptop: `ssh -p 22 chadops@192.168.1.10` succeeds
- Pi 2 process check: `systemctl status coredns` shows active (running)

**FRs:** FR1, FR2, FR3, FR6, FR7, FR10, FR13, FR16
**NFRs:** NFR3, NFR4, NFR7, NFR8, NFR10

---

### Story 8.4: Configure Router Automation and Network Cut-Over

As the operator,
I want to configure the router to use Pi 2 as DNS and enable external SSH access,
So that the network uses our managed services instead of defaults.

**Acceptance Criteria:**

**Given** Pi 2 DNS is verified working
**When** I run `make configure-dhcp-dns`
**Then** router DHCP hands out `192.168.1.11` as primary DNS
**And** DHCP clients (including my laptop) receive the new DNS setting on next lease renewal

**Given** Pi 1 bastion is verified working
**When** I run `make configure-port-forwards`
**Then** router port forward is configured: external 4222 → 192.168.1.10:22

**Given** DDNS is updating bastion.mindlikewater.net
**When** I wait for next DDNS cron run (5 minutes max)
**Then** `dig bastion.mindlikewater.net` from internet returns my public IP
**And** Namecheap DNS record matches current public IP

**Physical Verification:**
- Laptop renews DHCP lease, receives DNS server `192.168.1.11`
- From laptop: `nslookup google.com` uses Pi 2 DNS (check `/etc/resolv.conf`)
- From laptop: `nslookup bastion.mindlikewater.net` resolves to LAN IP
- From external network (phone hotspot): `ssh -p 4222 chadops@bastion.mindlikewater.net` succeeds

**FRs:** FR2, FR3, FR5, FR29
**NFRs:** NFR7

---

### Story 8.5: Deploy Hot Backups and Enable Sync

As the operator,
I want to deploy Pi 3 and Pi 4 as hot backups with automated sync,
So that I have redundancy and staging targets for changes.

**Acceptance Criteria:**

**Given** Pi 3 and Pi 4 have fresh SD cards with static IPs (`.12`, `.13`)
**When** I run `make deploy-pi ROLE=bastion TARGET=192.168.1.12`
**Then** Pi 3 is configured as bastion-backup identical to Pi 1

**When** I run `make deploy-pi ROLE=dns TARGET=192.168.1.13`
**Then** Pi 4 is configured as dns-backup identical to Pi 2

**Given** all four Pis are deployed
**When** I run `make converge` to enable backup sync cron jobs
**Then** Pi 1 has cron job to sync to Pi 3 every 15 minutes
**And** Pi 2 has cron job to sync to Pi 4 every 15 minutes

**Given** 20 minutes have elapsed
**When** I check sync logs on Pi 1 and Pi 2
**Then** at least one successful sync cycle has completed for each

**Physical Verification:**
- `make verify-pi TARGET=192.168.1.12` passes (Pi 3)
- `make verify-pi TARGET=192.168.1.13` passes (Pi 4)
- From laptop: all four Pis respond to SSH
- From laptop: both DNS servers (Pi 2 and Pi 4) resolve queries identically

**FRs:** FR4, FR8
**NFRs:** NFR10

---

### Story 8.6: Run Full Acceptance Test Suite

As the operator,
I want to run the complete acceptance test suite against the live network,
So that I can verify end-to-end functionality matches requirements.

**Acceptance Criteria:**

**Given** all four Pis are deployed and syncing
**When** I run `make test-acceptance`
**Then** all acceptance tests pass:
- DNS resolution test (internal and external queries)
- DDNS propagation test (Namecheap record matches public IP)
- SOCKS proxy test (SSH tunnel through bastion reaches internal services)
- Hot backup failover test (can deploy to backup first, then promote)

**Given** I want to verify fleet status
**When** I run `make status`
**Then** output shows:
- 4 hosts: all reachable ✓
- Services: all ok ✓
- DNS: internal and external resolution ok ✓
- Network devices: modem and router reachable ✓

**Given** I want to verify convergence idempotency
**When** I run `make converge` twice in a row
**Then** second run shows all hosts "ok" with zero changes

**Physical Verification:**
- From laptop on LAN: can access all services
- From phone on cellular: can SSH via bastion to reach internal network
- Router admin shows correct DHCP/DNS/port-forward config
- All Pis respond to ping and SSH within 2 seconds

**FRs:** FR14, FR15, FR31, FR32, FR33
**NFRs:** NFR7, NFR8, NFR10, NFR11, NFR14

---

### Story 8.7: Enable Production Monitoring and Document Operational Procedures

As the operator,
I want health checks running automatically and operational documentation complete,
So that the network self-monitors and I can respond to incidents.

**Acceptance Criteria:**

**Given** the network is fully operational
**When** I enable production monitoring with `make enable-monitoring`
**Then** health check cron job runs every 15 minutes on Pi 1
**And** health check logs are written to `/var/log/network-health.log`

**Given** 30 minutes have elapsed
**When** I inspect health check logs
**Then** at least 2 successful health check runs are logged with timestamps

**Given** operational documentation is needed
**When** I review the README operations section
**Then** it documents:
- How to check fleet status: `make status`
- How to deploy changes: backup-first workflow
- How to roll back DNS: `make rollback-dns`
- How to investigate failures: health check logs, goss verification
- Recovery procedure: SD card reflash + `make deploy-pi`

**Physical Verification:**
- Health checks are logging successfully every 15 minutes
- Can trigger a test failure (stop CoreDNS) and see it detected in logs
- README contains clear operational procedures
- Fresh git clone + README instructions are sufficient for another operator

**FRs:** FR17, FR27, FR32
**NFRs:** NFR11, NFR14

---

### Epic 8 Retrospective

**To be completed after all stories are PHYSICALLY VERIFIED and OPERATIONAL.**

Questions for retrospective:
1. What was the gap between "code complete" and "infrastructure operational"?
2. How should we define "done" for infrastructure stories in future projects?
3. What deployment risks did we discover that weren't apparent during development?
4. How effective was the backup-first deployment workflow?
5. What would we do differently if deploying a fifth Pi or adding a new service?
