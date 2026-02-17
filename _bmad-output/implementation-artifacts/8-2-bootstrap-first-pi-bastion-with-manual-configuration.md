# Story 8.2: Bootstrap First Pi (Bastion) with Manual Configuration

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the operator,
I want to manually configure Pi 1 as the deployment bootstrap host,
So that I have a working bastion to deploy remaining infrastructure from.

## Acceptance Criteria

**Given** Pi 1 has fresh RPi OS booted
**When** I run through first-boot setup manually:
- Set hostname: `bastion`
- Configure static IP: `192.168.1.10`
- Create deploy user: `deploy`
- Enable SSH key authentication
- Copy deployment repo to Pi 1
**Then** I can SSH to `deploy@192.168.1.10` from my laptop

**Given** Pi 1 has repo cloned at `/home/deploy/home-tech-infrastructure`
**When** I run `make test-unit` on Pi 1
**Then** all unit tests pass locally on the Pi

**Given** age private key is available on Pi 1
**When** I run `make decrypt-secrets` on Pi 1
**Then** secrets decrypt successfully

**Physical Verification:**
- Can SSH to Pi 1 from laptop: `ssh deploy@192.168.1.10`
- Pi 1 can reach internet: `ping 1.1.1.1`
- Pi 1 has repo with passing tests

## Tasks / Subtasks

- [ ] Task 1: First-boot Pi 1 Configuration (AC: Manual setup checklist)
  - [ ] Subtask 1.1: Boot fresh RPi OS Lite 64-bit on Pi 1
  - [ ] Subtask 1.2: Set hostname to `bastion` via `raspi-config` or `/etc/hostname`
  - [ ] Subtask 1.3: Configure static IP `192.168.1.10` in `/etc/dhcpcd.conf` or NetworkManager
  - [ ] Subtask 1.4: Verify Pi 1 is reachable at `192.168.1.10` from laptop

- [ ] Task 2: Create Deploy User and Enable SSH (AC: SSH key authentication)
  - [ ] Subtask 2.1: Create user `deploy` with sudo privileges
  - [ ] Subtask 2.2: Generate SSH keypair on laptop (if not existing)
  - [ ] Subtask 2.3: Copy public key to Pi 1 `~/.ssh/authorized_keys`
  - [ ] Subtask 2.4: Verify passwordless SSH: `ssh deploy@192.168.1.10`

- [ ] Task 3: Clone Repository to Pi 1 (AC: Repo available at `/home/deploy/home-tech-infrastructure`)
  - [ ] Subtask 3.1: Install git on Pi 1 if missing: `sudo apt-get install -y git`
  - [ ] Subtask 3.2: Clone repo: `git clone <repo-url> ~/home-tech-infrastructure`
  - [ ] Subtask 3.3: Verify repo structure matches architecture (infrastructure/, scripts/, tests/)

- [ ] Task 4: Verify TDD Toolchain on Pi 1 (AC: Unit tests pass)
  - [ ] Subtask 4.1: Install bats-core dependencies (git submodules or apt)
  - [ ] Subtask 4.2: Install ShellCheck: `sudo apt-get install -y shellcheck`
  - [ ] Subtask 4.3: Run `make test-unit` and confirm all tests pass

- [ ] Task 5: Transfer and Verify Secrets (AC: Secrets decrypt successfully)
  - [ ] Subtask 5.1: Copy age private key to Pi 1 (secure transfer, e.g., scp)
  - [ ] Subtask 5.2: Set `SOPS_AGE_KEY_FILE` environment variable
  - [ ] Subtask 5.3: Run `make decrypt-secrets` or `sops --decrypt` and verify success

- [ ] Task 6: Physical Verification Checklist (AC: All physical verifications pass)
  - [ ] Subtask 6.1: Confirm SSH access: `ssh chadops@192.168.1.10`
  - [ ] Subtask 6.2: Confirm internet connectivity from Pi 1: `ping 1.1.1.1`
  - [ ] Subtask 6.3: Confirm repo is present with passing tests

## Dev Notes

### Story Context

This story marks the **transition from development to physical deployment** (Epic 8). All automation code from Epics 0-7 is complete and tested. Now we execute that code against real hardware for the first time.

**Why this story exists:**
- Pi 1 must be manually configured because we need a *working bastion* before we can deploy anything else
- This is the **bootstrap problem**: we can't use the deploy pipeline to provision the machine that *runs* the deploy pipeline
- Once Pi 1 is operational, all remaining Pis (2, 3, 4) can be deployed via `make deploy-pi`

**What makes this different from other stories:**
- This is **NOT** a coding story -- it's a physical provisioning story
- Success means a working Pi, not new code
- The operator follows a manual checklist, not TDD
- The output is a *configured device*, not a pull request

### Critical Architecture Patterns and Constraints

**From Architecture Decision Records (ADRs):**

1. **ADR 30: Pi Base Image**
   - **MUST** use RPi OS Lite 64-bit (Bookworm)
   - Minimal footprint -- no desktop environment
   - 64-bit required for compatibility with CoreDNS and modern packages

2. **ADR 17: Pi Configuration Style**
   - Scripts are function-based, idempotent, Ansible-compatible by design
   - Every script must work when sourced by bats-core tests
   - Scripts assume deploy from *outside* the Pi (SSH-based push model)

3. **ADR 14: Secrets Management**
   - Secrets encrypted with SOPS + age
   - Age private key **NEVER** committed to git
   - Private key backed up to 1Password
   - For this story: manually transfer age private key to Pi 1 via secure channel (scp, USB)

4. **ADR 31: Deploy Pipeline (3-Phase)**
   - Phase 1: `decrypt.sh` (local)
   - Phase 2: `push.sh` (local → Pi)
   - Phase 3: `run-setup.sh` (on Pi)
   - For this story: we're setting up the machine that will *run* the local phases

5. **Network Topology (Architecture)**
   - Router: 192.168.1.1
   - Pi 1 (bastion): 192.168.1.10
   - Pi 2 (dns): 192.168.1.11
   - Pi 3 (bastion-backup): 192.168.1.12
   - Pi 4 (dns-backup): 192.168.1.13
   - Domain: mindlikewater.net

### Source Tree Components to Touch

**This story does NOT create new files.** It provisions a physical Pi using *existing* code.

**Files you'll reference (already exist from Epics 0-7):**

1. **`Makefile`**
   - `make test-unit` -- verify TDD toolchain works on Pi
   - `make decrypt-secrets` -- verify secrets can be decrypted on Pi
   - `make help` -- discover available commands

2. **`infrastructure/pi-scripts/inventory.sh`**
   - Single source of truth for network config
   - Defines `PI1_IP=192.168.1.10`, `PI1_HOSTNAME=bastion`
   - Used by all scripts to maintain consistency

3. **`infrastructure/pi-scripts/secrets.enc.yaml`**
   - SOPS-encrypted secrets file
   - Contains: deploy SSH key, Namecheap DDNS password, Pi host key backups
   - Decryption requires age private key

4. **`tests/unit/*.bats`**
   - bats-core unit tests for all scripts
   - Confirm these pass on Pi 1 architecture (ARM64)

5. **`.sops.yaml`**
   - SOPS configuration pointing to age public key
   - Used by `sops --decrypt` command

6. **Manual Commands (not in repo):**
   - `raspi-config` -- Pi configuration utility (set hostname, enable SSH)
   - `/etc/dhcpcd.conf` or NetworkManager -- static IP configuration
   - `ssh-keygen` -- generate SSH keypair (if needed)
   - `ssh-copy-id` or manual `authorized_keys` setup

### Testing Standards Summary

**For this story, testing is OPERATIONAL, not code-based:**

1. **Physical Verification Replaces Traditional Testing:**
   - Instead of unit tests: SSH to Pi 1 and verify commands work
   - Instead of integration tests: Run `make test-unit` on Pi 1
   - Instead of acceptance tests: Confirm end-to-end workflow (laptop → Pi 1 SSH)

2. **Success Criteria:**
   - ✅ Pi 1 boots with static IP `192.168.1.10`
   - ✅ Hostname set to `bastion`
   - ✅ User `chadops` created with sudo + SSH key auth
   - ✅ Repo cloned to `/home/chadops/home-tech-infrastructure`
   - ✅ `make test-unit` passes on Pi 1
   - ✅ Age private key present and secrets decrypt successfully
   - ✅ Internet connectivity confirmed (`ping 1.1.1.1`)

3. **No New Code = No New Tests:**
   - Existing unit tests (from Epics 1-7) must pass on Pi 1
   - If tests fail on ARM64, that's a BUG (not expected -- all scripts are portable)

### Project Structure Notes

**Alignment with Unified Project Structure:**

This story uses the repository structure defined in Architecture:

```
home-tech-infrastructure/
├── infrastructure/pi-scripts/     # Scripts to run on Pis
│   ├── inventory.sh               # Network config
│   ├── secrets.enc.yaml           # Encrypted secrets
│   ├── common/                    # Shared scripts
│   ├── bastion/                   # Bastion-specific
│   ├── dns/                       # DNS-specific
│   └── sync/                      # Hot-backup sync
├── scripts/
│   ├── bootstrap/                 # Age keypair generation
│   ├── deploy/                    # Deploy pipeline
│   ├── ops/                       # Operations scripts
│   └── ddns/                      # DDNS update
├── tests/
│   ├── unit/                      # bats-core
│   ├── integration/               # goss
│   └── acceptance/                # end-to-end
├── .sops.yaml
├── Makefile
└── README.md
```

**Key Paths:**
- Repo root on Pi 1: `/home/chadops/home-tech-infrastructure`
- Deploy user home: `/home/chadops`
- Age private key: `/home/chadops/.config/sops/age/keys.txt` (or custom location via `SOPS_AGE_KEY_FILE`)

**Detected Conflicts or Variances:**
- **NONE** -- This story does not modify the structure. It provisions a Pi that will *use* the structure.

### References

**Epic 8 Context:**
- [Source: _bmad-output/planning-artifacts/epics.md#Epic-8-Physical-Infrastructure-Deployment--Commissioning]
  - Epic 8 Context: "Epics 0-7 delivered a complete automation system (scripts, tests, deployment pipeline). Epic 8 executes that system against real hardware to achieve a fully operational network."
  - Story 8.1 Prerequisite: Physical hardware prepared, modem in bridge mode, router serving DHCP, all Pis powered
  - Story 8.2 Purpose: Bootstrap first Pi manually to enable automated deployment of remaining Pis

**Architecture Decisions:**
- [Source: _bmad-output/planning-artifacts/architecture.md]
  - ADR 30: RPi OS Lite 64-bit (Bookworm)
  - ADR 17: Function-based, idempotent scripts
  - ADR 14: SOPS + age for secrets
  - ADR 31: 3-phase deploy pipeline
  - Network topology: Pi 1 = 192.168.1.10 (bastion)

**Repository Structure:**
- [Source: _bmad-output/planning-artifacts/architecture.md#Repository-Structure-MVP]
  - Defines complete directory layout
  - No external starter template (greenfield repo)

**Functional Requirements Covered:**
- [Source: _bmad-output/planning-artifacts/epics.md#Requirements-Inventory]
  - FR1: Bastion with hardened SSH (partial -- full hardening in Story 8.3)
  - FR6: Deploy from fresh SD card (partial -- this story enables the deploy pipeline)

**Recent Commit Analysis:**
- [Source: git log --oneline -5]
  - `8ffe13d`: Epic 8 added with router DHCP reference screenshots
  - `5316571`: All BMAD epics (0, 5, 6, 7) implemented -- 18 stories, 581 tests
  - **Insight:** Codebase is feature-complete for Epics 0-7. Epic 8 is physical deployment.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)

### Debug Log References

(To be filled during implementation)

### Completion Notes List

(To be filled during implementation)

### File List

**Files Referenced (no new files created):**
- Makefile
- infrastructure/pi-scripts/inventory.sh
- infrastructure/pi-scripts/secrets.enc.yaml
- .sops.yaml
- tests/unit/*.bats
- README.md

**Physical Artifacts Created:**
- Pi 1 (Raspberry Pi) with hostname `bastion`, IP `192.168.1.10`
- User `chadops` on Pi 1 with SSH key authentication
- Cloned repository at `/home/chadops/home-tech-infrastructure`
- Age private key on Pi 1 (secure location, not committed)
