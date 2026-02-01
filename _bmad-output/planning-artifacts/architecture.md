# Architecture - home-tech-infrastructure

**Author:** Chad
**Date:** 2026-02-01

## Architecture Source

The complete architecture for this project is documented in the brainstorming output:

**`_bmad-output/brainstorming/architecture-diagram.md`**

That document contains 33 resolved architecture decisions, all diagrams (network topology, remote access, DDNS, DNS, secrets, bootstrap order, test pyramid, deploy pipeline), repository structure, and detailed technical specifications.

This document summarizes the key decisions relevant to epic and story creation.

## Key Architecture Decisions (MVP)

| # | Decision | Choice |
|---|----------|--------|
| 3 | Pi 1 role | Bastion + DDNS |
| 4 | Pi 2 role | DNS (CoreDNS split-horizon) |
| 9 | DNS software | CoreDNS with hosts plugin |
| 14 | Secrets management | SOPS + age encryption |
| 17 | Pi configuration | Ansible-compatible shell scripts (function-based, idempotent) |
| 22 | Pi redundancy | Hot-backup Pis (Pi 3 mirrors Pi 1, Pi 4 mirrors Pi 2) |
| 23 | Infrastructure testing | Full test pyramid (bats-core, goss, acceptance) |
| 27 | Shell script conventions | Function-based, idempotent guards, overridable paths, main guard |
| 28 | CoreDNS config style | hosts plugin + generated hosts file from inventory.sh |
| 29 | MVP CI strategy | Local Makefile only, no GitHub Actions |
| 30 | Pi base image | RPi OS Lite 64-bit (Bookworm) |
| 31 | Deploy pipeline | 3-phase (decrypt -> push -> run) |
| 32 | Pi smoke test | `make verify-pi` (goss on Pi) |
| 33 | Health monitoring | `make health-check` script via cron |

## Repository Structure (MVP)

```
home-tech-infrastructure/
├── infrastructure/pi-scripts/     # Ansible-compatible shell scripts
│   ├── inventory.sh               # Single source of truth (IPs, hostnames, roles)
│   ├── secrets.enc.yaml           # SOPS-encrypted secrets
│   ├── common/                    # Shared: harden.sh, unattended-upgrades.sh, setup-goss.sh
│   ├── bastion/                   # setup-bastion.sh, setup-ddns.sh
│   ├── dns/                       # setup-coredns.sh
│   └── sync/                      # Hot-backup sync scripts
├── scripts/
│   ├── bootstrap/                 # generate-age-keypair.sh
│   ├── deploy/                    # 3-phase: decrypt.sh, push.sh, run-setup.sh, prep-pi-image.sh
│   ├── ops/                       # health-check.sh
│   └── ddns/                      # update-namecheap.sh
├── tests/
│   ├── unit/                      # bats-core (*.bats)
│   ├── integration/               # goss (*.yaml)
│   └── acceptance/                # end-to-end (test_*.sh)
├── .sops.yaml
├── Makefile
└── README.md
```

## Deploy Pipeline (3-Phase)

```
make deploy-pi ROLE=bastion TARGET=192.168.1.10
    ├── Phase 1: decrypt.sh      (local: SOPS decrypt to temp)
    ├── Phase 2: push.sh         (local -> Pi: scp scripts + secrets)
    └── Phase 3: run-setup.sh    (on Pi: ssh + run main.sh)
```

## Shell Script Conventions

- `set -euo pipefail` on every script
- Functions for every action (testable via bats-core source)
- Idempotent guards (check before changing)
- Overridable paths via env vars (tests redirect to temp dirs)
- `PROJECT_ROOT` via `BASH_SOURCE`
- Main guard: `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi`
- Functions return 0/1, never `exit`

## Starter Template

No external starter template. This is a greenfield repo. Epic 1 Story 1 should create the repo scaffolding (Makefile, directory structure, inventory.sh) from scratch following the repository structure above.

## Network Configuration

| Device | IP | Role |
|---|---|---|
| Router | 192.168.1.1 | NAT, DHCP, firewall, WiFi |
| Pi 1 | 192.168.1.10 | Bastion + DDNS |
| Pi 2 | 192.168.1.11 | DNS (CoreDNS) |
| Pi 3 | 192.168.1.12 | Hot backup (bastion) |
| Pi 4 | 192.168.1.13 | Hot backup (DNS) |
| Domain | mindlikewater.net | Split-horizon DNS |
