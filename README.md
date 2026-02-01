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

## Status

Planning phase. See `_bmad-output/brainstorming/architecture-diagram.md` for architecture decisions and diagrams.
