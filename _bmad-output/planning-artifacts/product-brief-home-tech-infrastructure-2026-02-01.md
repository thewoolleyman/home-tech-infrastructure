---
stepsCompleted: [1, 2, 3]
inputDocuments:
  - _bmad-output/brainstorming/architecture-diagram.md
  - _bmad-output/brainstorming/brainstorming-session-2026-02-01.md
date: 2026-02-01
author: Chad
---

# Product Brief: home-tech-infrastructure

## Executive Summary

home-tech-infrastructure is a fully automated home network, built and maintained with AI assistance. Every network component -- cable modem, router, Raspberry Pi services, DNS, bastion host, and Kubernetes server -- is managed as infrastructure-as-code with full test coverage, encrypted secrets, and automated deployment. AI (Claude Code, etc.) is the development tool that writes, tests, and evolves the automation; the running infrastructure itself uses deterministic, traditional automation (shell scripts, cron, GitOps) with no LLMs in the critical path. The comprehensive test pyramid (unit, integration, acceptance) is the safety net that makes AI-assisted development trustworthy. The MVP delivers the always-on Pi infrastructure layer (bastion + DDNS on Pi 1, split-horizon DNS on Pi 2) with zero-risk incremental deployment.

---

## Core Vision

### Problem Statement

Home network infrastructure is managed manually, undocumented, and fragile. Configuration lives in people's heads or scattered notes. When a Raspberry Pi's SD card fails, a DNS server stops resolving, or a router config drifts, there is no automated way to detect the failure, diagnose the cause, or recover to a known-good state. Every change is a manual SSH session with no audit trail, no tests, and no rollback plan.

### Problem Impact

- **Not code-manageable**: Without infrastructure-as-code, you can't use AI development tools to efficiently build, test, and evolve the system -- every change requires manual SSH and tribal knowledge
- **Reliability**: A single component failure (Pi crash, DNS misconfiguration) can take down internet access for the entire household with no automated recovery
- **Knowledge loss**: Configuration knowledge is ephemeral -- rebuilding after hardware failure requires remembering undocumented steps
- **No confidence in changes**: Without tests, any configuration change risks breaking the network with no easy rollback
- **Manual toil**: Routine tasks (DDNS updates, security patching, certificate renewal) require human intervention that should be automated

### Why Existing Solutions Fall Short

| Existing approach | Gap |
|---|---|
| **Ansible/Terraform** | Additional dependency and abstraction layer for a 4-Pi fleet. Shell scripts are simpler today with a clear Ansible migration path if complexity grows. |
| **K8s homelab communities** (onedr0p, r/homelab) | Focus exclusively on the Kubernetes cluster, not the full network stack (modem, router, Pis, DNS). |
| **Router vendor apps** | Closed ecosystems. No API, no git, no automation beyond the vendor's UI. |
| **Manual scripts in ~/bin** | No tests, no idempotency, no version control, no secrets management. |
| **Commercial home automation** (UniFi, etc.) | Proprietary, cloud-dependent, not programmable, expensive. |

No existing solution treats the **entire home network** -- from cable modem to Kubernetes workloads -- as a single, testable, code-managed system.

### Proposed Solution

An infrastructure-as-code repository that manages every layer of the home network, built and maintained using AI development tools:

1. **Always-on Pi layer** (MVP): Raspberry Pis running bastion (SSH jump host + DDNS) and DNS (CoreDNS split-horizon), configured by idempotent shell scripts with full test coverage
2. **Network layer** (Future): Router (TP-Link AXE95) managed via Python API, modem in bridge mode
3. **Server layer** (Future): Dell PowerEdge R630 running Talos Linux / single-node Kubernetes, GitOps via FluxCD
4. **Workload layer** (Future): GitLab Omnibus and other services deployed via FluxCD
5. **Secrets layer** (MVP): SOPS + age encryption for all credentials, unified across K8s and Pi tiers

The running system uses deterministic automation only: shell scripts, cron jobs, CoreDNS, FluxCD, GitOps. AI is the developer, not a runtime dependency. The test pyramid is the quality gate that makes this safe -- every line of AI-written code must pass unit tests, integration verification, and end-to-end acceptance tests before it touches the live network.

### Key Differentiators

- **Full-stack scope**: Manages modem, router, Pis, DNS, bastion, AND server -- not just the K8s cluster
- **AI as developer, not runtime**: AI tools build and evolve the system; the infrastructure runs on deterministic, traditional automation with no LLMs in the critical path
- **Test pyramid as safety net**: bats-core unit tests, goss integration tests, end-to-end acceptance tests ensure AI-written code is correct before deployment -- the test suite is what makes AI-assisted development trustworthy
- **Ansible-compatible shell scripts**: No Ansible dependency for 4 Pis, but structured for migration when complexity warrants it
- **Zero-risk deployment**: MVP designed so steps 0-7 carry zero risk to the live network; cut-over is reversible in seconds

---

## Target Users

### Primary Users

**Chad -- Homeowner & Infrastructure Engineer**

- **Role**: Solo owner-operator of the entire home network stack
- **Environment**: Home office, managing 4 Raspberry Pis, a Dell PowerEdge server, router, and cable modem
- **Motivation**: Eliminate manual SSH sessions and tribal knowledge; make the network self-documenting and recoverable
- **Current experience**: Configuration lives in his head. When something breaks, recovery means remembering undocumented steps under pressure. Every change is a manual SSH session with no audit trail and no rollback.
- **Workarounds**: Scattered notes, manual backups, ad-hoc scripts in `~/bin`
- **Success looks like**: `git clone` + `make deploy` rebuilds everything from scratch. Hardware failure is a non-event -- swap the SD card and re-deploy.

### Secondary Users

**Household Members -- Passive Beneficiaries**

- **Role**: Everyone on the home network (family, guests)
- **Interaction**: None -- they never see the infrastructure. They just expect the internet to work.
- **Needs from the system**: DNS resolves, internet stays up, Wi-Fi works. Zero awareness of the underlying automation.
- **Measurable success criterion**: Zero-downtime deploys -- no perceptible interruption to DNS resolution or internet access during any deployment or failover. Verifiable via external uptime check.

### Developer Experience Constraints

The codebase must support two development modes equally well:

- **AI-assisted development**: Claude Code (or any AI tool) reads the repo, writes shell scripts, runs the test pyramid, and iterates. This requires: clear file organization, well-defined interfaces (inventory.sh contract), testable function-based scripts, comprehensive test suite to validate output.
- **Human debugging at 2am**: Chad SSHs into a Pi when something is broken. Scripts must be readable, structure must be obvious, and `make verify-pi` must work without needing to understand the full repo. No magic -- every script does what it says on the tin.

These are not user personas -- they are non-functional requirements that shape every design decision in the repo.

### User Journey (MVP)

| Phase | Chad's experience | Test level |
|-------|-------------------|------------|
| **Build** | Writes Pi setup scripts with Claude Code. TDD cycle: red-green-refactor. All tests pass locally via `make test`. | Unit tests (bats-core) |
| **Desk test** | Runs `make test-integration` against a fresh Pi on the bench. Goss verifies services are configured correctly. No risk to live network. | Integration tests (goss) |
| **Soft deploy** | Deploys to Pi 3/Pi 4 (hot backups) not yet serving traffic. Runs `make verify-pi` to confirm health. Still zero risk. | Acceptance tests (real Pi) |
| **Cut-over** | Switches DNS/bastion to the new Pis. Old Pis remain as instant rollback. Reversible in seconds. | Manual verification + rollback plan |
| **Steady state** | DDNS updates via cron. DNS resolves split-horizon. Health checks run on schedule. Chad monitors via `make verify-pi`. | Ongoing health checks |
| **Failure/Recovery** | Health check detects the issue. Chad runs `make deploy PI=pi1` to restore from known-good state. Or hot-backup Pi is already serving. Recovery is one command. | Same test pyramid validates the fix |
| **Day 2 evolution** | New requirement (e.g., add Pi-hole, change DDNS provider). Same TDD cycle through the pipeline. Future changes are as safe as the first deploy. | Full pyramid for every change |
