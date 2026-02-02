# home-tech-infrastructure

**A fully automated home network, built and maintained with AI.**

This project manages the entire home network infrastructure as code -- from the cable modem and router through Raspberry Pi services (DNS, bastion, DDNS) to a Kubernetes server running GitLab and other workloads. AI (Claude Code) is the development tool that writes, tests, and evolves the automation. The running infrastructure uses deterministic, traditional automation (shell scripts, cron, GitOps) with no LLMs in the critical path.

## What This Manages

| Component | Device | Role |
|-----------|--------|------|
| Edge | Xfinity modem (bridge mode) | WAN pass-through |
| Router | TP-Link Archer AXE95 | NAT, DHCP, firewall, WiFi -- managed via Python API |
| Bastion | Raspberry Pi 1 + hot backup | SSH jump host, DDNS updates |
| DNS | Raspberry Pi 2 + hot backup | CoreDNS split-horizon for mindlikewater.net |
| Server | Dell PowerEdge R630 (Talos/K8s) | GitLab, other workloads (intermittent -- not always on) |

## Key Principles

- **AI as developer**: AI builds and evolves the automation; no LLMs in the runtime infrastructure
- **Infrastructure as code**: Everything in git, nothing configured manually
- **Test pyramid**: bats-core unit tests, goss integration tests, end-to-end acceptance tests
- **Secrets in git**: SOPS + age encryption (private key in 1Password, never in repo)
- **Ansible-compatible scripts**: Shell scripts structured for future Ansible migration
- **GitOps for K8s**: FluxCD reconciles cluster state from this repo

## Prerequisites

- **git** (with submodule support)
- **bash** 4+
- **ShellCheck** -- `brew install shellcheck` (macOS) or `apt install shellcheck` (Debian/Ubuntu)
- **make**

## Quick Start

```bash
# Clone with submodules (bats test framework)
git clone --recurse-submodules <repo-url>
cd home-tech-infrastructure

# If already cloned without submodules:
git submodule update --init --recursive

# See all available targets
make help

# Run lint + unit tests (no Pi hardware needed)
make test
```

## Status

Epic 1 (Repository Foundation & Tooling) in progress. See `_bmad-output/implementation-artifacts/sprint-status.yaml` for current sprint status.

## Project Management with BMAD and Claude Flow

This project uses two complementary systems:

- **BMAD** -- Handles the *what* and *why*: product briefs, PRDs, architecture decisions, epics, stories, sprint tracking
- **Claude Flow** -- Handles the *how*: agent orchestration, memory/pattern learning, swarm coordination for implementation

### Automatic BMAD-to-Memory Sync

When BMAD skills write artifacts to `_bmad-output/`, the post-edit hook automatically detects the write and syncs relevant patterns into Claude Flow's memory database. This makes the statusline metrics reflect actual project state.

**How it works:**

1. Any Write/Edit to a file under `_bmad-output/` triggers the `post-edit` hook
2. The hook bridge (`.claude/hooks/hook-bridge.sh`) detects the `_bmad-output/` path
3. It runs `scripts/sync-bmad-to-memory.sh` in the background with the file path
4. The sync script extracts key data and stores it as patterns in Claude Flow memory

**What gets extracted:**

| Artifact | What's stored | Memory key format |
|----------|--------------|-------------------|
| Architecture decisions (33 total) | Decision + choice from the decision table | `bmad:arch:1` through `bmad:arch:33` |
| Epics | Epic title + story count | `bmad:epic:1` through `bmad:epic:6` |
| Stories | Story title | `bmad:story:1-1`, `bmad:story:1-2`, etc. |
| Sprint status | Story counts by status | `bmad:sprint:status` |
| Product brief | Executive summary (first 200 chars) | `bmad:brief:summary` |
| PRD | FR/NFR counts and project type | `bmad:prd:summary` |
| Brainstorming files | File title | `bmad:brainstorm:<filename>` |
| Story files | Story title + status | `bmad:story-file:<filename>` |

As patterns accumulate, the statusline metrics (DDD domains, intelligence %, AgentDB vectors) rise automatically.

**Manual full sync** (re-syncs all artifacts at once):

```bash
scripts/sync-bmad-to-memory.sh
```

### BMAD Artifact Locations

| Artifact | Location | BMAD Skill |
|----------|----------|------------|
| Product brief | `_bmad-output/planning-artifacts/product-brief-*.md` | `/bmad-bmm-create-product-brief` |
| PRD | `_bmad-output/planning-artifacts/prd.md` | `/bmad-bmm-create-prd` |
| Architecture | `_bmad-output/brainstorming/architecture-diagram.md` | `/bmad-bmm-create-architecture` |
| Epics & stories | `_bmad-output/planning-artifacts/epics.md` | `/bmad-bmm-create-epics-and-stories` |
| Sprint status | `_bmad-output/implementation-artifacts/sprint-status.yaml` | `/bmad-bmm-sprint-planning` |
| Story files | `_bmad-output/implementation-artifacts/stories/` | `/bmad-bmm-create-story` |
| Brainstorming | `_bmad-output/brainstorming/` | `/bmad-brainstorming` |
