---
stepsCompleted: [step-01-init, step-02-discovery, step-03-success, step-04-journeys, step-05-domain, step-06-innovation, step-07-project-type, step-08-scoping, step-09-functional, step-10-nonfunctional, step-11-polish]
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-home-tech-infrastructure-2026-02-01.md
  - _bmad-output/brainstorming/architecture-diagram.md
  - _bmad-output/brainstorming/brainstorming-session-2026-02-01.md
workflowType: 'prd'
briefCount: 1
researchCount: 0
brainstormingCount: 2
projectDocsCount: 0
classification:
  projectType: infrastructure-as-code / cli-tool
  domain: home-network-infrastructure
  complexity: low-medium
  projectContext: greenfield
---

# Product Requirements Document - home-tech-infrastructure

**Author:** Chad
**Date:** 2026-02-01

## Success Criteria

### User Success

| Success criterion | Measurable outcome |
|---|---|
| **Single-command convergence** | `make converge` brings all Pis to declared state. Running twice shows zero changes. |
| **Rebuild from scratch** | `git clone` + `make deploy-pi ROLE=<role> TARGET=<ip>` on a fresh SD card produces a working Pi. Zero manual SSH steps. |
| **Trust the tests** | `make test` catches a real misconfiguration before it hits the live network at least once during MVP development. |
| **Not afraid to change** | Any modification deploys to a hot-backup first. Rollback to previous state takes < 30 seconds (revert DHCP DNS pointer). |
| **Repo is documentation** | A fresh `git clone` + `make help` + README is sufficient to understand and operate the entire network. No tribal knowledge needed. |
| **Household unaffected** | DNS resolution continues without perceptible interruption during any deploy or failover. |

### Business Success

This is a personal project -- no revenue, no user growth. "Business success" means:

| Metric | Target |
|---|---|
| **Time to recover from Pi failure** | < 15 minutes from "Pi is dead" to "services restored" (flash SD + `make deploy` + `make verify-pi`) |
| **Confidence to evolve** | Adding a new service (e.g., Pi-hole) follows the same TDD pipeline with no new tooling |
| **Knowledge durability** | If Chad doesn't touch the system for 6 months, the repo + README is enough to pick it back up |

### Technical Success

| Metric | Target |
|---|---|
| **Test pyramid coverage** | 100% of MVP scripts have corresponding bats-core unit tests |
| **All tests green** | `make test-all` (lint + unit + integration + acceptance) passes |
| **Secrets never in plaintext** | No plaintext credentials in git history. SOPS + age is the only path. |
| **Idempotent convergence** | Running `make converge` twice in a row produces no errors and no changes |
| **Scripts pass ShellCheck** | `make lint` clean with zero warnings |

### Measurable Outcomes

| Outcome | How verified | When |
|---|---|---|
| Pi 1 bastion works | `make verify-pi PI=pi1` passes (SSH, firewall, DDNS cron) | After deploy |
| Pi 2 DNS works | `make verify-pi PI=pi2` passes (CoreDNS running, split-horizon resolves) | After deploy |
| DDNS updates | Public IP matches Namecheap record within 5 minutes of change | Acceptance test |
| Health checks pass | `make health-check` runs every 15 min for 24h post-cutover with zero failures | After cutover |
| Hot-backup ready | Pi 3/Pi 4 pass same `verify-pi` as primaries | After deploy |

## Product Scope

### MVP Strategy & Philosophy

**MVP Approach:** Problem-solving MVP -- the minimum automation that makes the Pi infrastructure reliable, recoverable, and code-managed. Every feature earns its place by supporting one of the four success criteria: rebuild from scratch, trust the tests, not afraid to change, repo is documentation.

**Resource Requirements:** One operator (Chad) directing AI (Claude Code). No team. The AI writes all code, tests, and automation. Chad's only hands-on work is physical tasks (flash SD cards, plug in Pis) and directing the AI.

**Why this MVP boundary:** The Pi layer is always-on infrastructure that the household depends on daily. The server layer (PowerEdge/K8s) is intermittent and optional. Solving the always-on layer first delivers immediate value and proves the AI-driven TDD pipeline before tackling more complex tiers.

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**
- Journey 1 (Build): Full TDD build of all 4 Pis from scratch
- Journey 2 (Recovery): Hardware failure recovery in < 15 minutes
- Journey 4 (Debug): Misconfiguration caught by test pyramid before reaching live network

**Must-Have Capabilities:**

| Capability | Justification | Without it, what breaks? |
|---|---|---|
| Pi 1: Bastion (hardened sshd, key-only auth) | Secure remote access to home network | No SSH access from outside the LAN |
| Pi 1: DDNS updater (cron, Namecheap API) | Dynamic IP tracked for remote access | Remote access breaks on IP change |
| Pi 2: CoreDNS (split-horizon, hosts plugin) | Internal DNS resolution for mindlikewater.net | LAN services unreachable by hostname |
| Pi 3 + Pi 4: Hot-backup clones | Pre-production staging + instant fallback | No safe deploy target, no automatic DNS fallback |
| inventory.sh | Single source of truth for all network config | Config scattered, AI can't discover conventions |
| SOPS + age secrets | Credentials safe in git | Secrets in plaintext = security failure |
| 3-phase deploy pipeline | Repeatable, testable deploys | Manual SSH sessions, no audit trail |
| Makefile as UI | Discoverable operations via `make help` | Commands live in tribal knowledge |
| bats-core unit tests | Fast local validation of script logic | AI-written code deployed without verification |
| goss integration tests | On-Pi state verification | Config looks right but services don't work |
| Acceptance tests | End-to-end network validation | Individual pieces work but system doesn't |
| Health-check cron (log-based) | Post-deploy monitoring | Silent failures go unnoticed |

**Deliberately excluded from MVP (can be manual initially):**

| Excluded | Manual workaround | Why it's safe to defer |
|---|---|---|
| Automated failover (keepalived/VRRP) | Chad switches DNS pointer manually (< 30s) | Hot-backup Pi 4 already in DHCP as secondary DNS; household recovers automatically for DNS |
| Push notifications on failure | Chad reads health-check log | Detection lag is acceptable for a home network |
| GitLab CI | `make test-all` run locally by Claude Code | CI adds convenience, not safety -- the test pyramid runs the same either way |
| Router automation | Chad uses router web UI | Router config changes are rare |
| Monitoring dashboard | `make health-check` output + log file | Dashboard is visualization of data that already exists |

### Post-MVP Features

**Phase 2 -- Growth (Automation & CI):**

| Feature | Depends on | Value added |
|---|---|---|
| Automated hot-backup promotion | MVP health checks | Removes Chad from the recovery loop for DNS failures |
| GitLab CI on LAN | MVP test pyramid + K8s (or bare-metal runner) | Push-triggered pipeline, no manual `make test` |
| Router automation (Python TP-Link API) | MVP inventory.sh patterns | DHCP/firewall managed as code, not via web UI |
| Monitoring dashboard | MVP health-check data | Visualization + historical trends |

**Phase 3 -- Vision (Full Stack as Code):**

| Feature | Depends on | Value added |
|---|---|---|
| Talos Linux on PowerEdge | Phase 2 CI | Immutable OS, single-node K8s |
| FluxCD GitOps | Talos + K8s | Cluster state reconciled from git |
| GitLab Omnibus on K8s | FluxCD | Self-hosted git + CI runners |
| Additional K8s workloads | FluxCD pipeline | Any service deployed via the same GitOps pattern |
| Full network as code | All layers | Modem, router, Pis, server, workloads -- one repo |

### Scoping Risk Mitigation

| Risk | Category | Mitigation |
|---|---|---|
| SD card reliability (Pi failure) | Technical | Hot-backup Pis + fast recovery pipeline. MVP explicitly designs for this failure mode. |
| CoreDNS misconfiguration breaks household internet | Technical | Deploy to hot-backup first. Pi 4 as secondary DNS in DHCP means household auto-recovers. |
| AI writes incorrect automation | Technical | Test pyramid: bats-core catches logic errors, goss catches state errors, acceptance catches end-to-end failures. ShellCheck catches shell bugs. |
| Scope creep into K8s/server tier | Resource | Hard MVP boundary: Pi layer only. Server is intermittent hardware. Post-MVP by design. |
| Solo operator (Chad) unavailable | Resource | Repo is documentation. Standard bash scripts. Any engineer (or AI) can read the repo and operate the system. |
| AI tool outage | Resource | All code is standard bash + standard tools. Zero AI runtime dependency. Chad can operate manually if needed. |

## User Journeys

### Journey 1: Building the MVP (Success Path)

Chad sits down at his desk with a fresh repo and four bare Raspberry Pis. He tells Claude Code: "Set up the repo scaffolding -- Makefile, test directories, inventory.sh." Claude Code creates the files, commits, pushes, and runs `make help` to verify the targets work. Chad reviews the output.

He directs Claude Code through the TDD cycle: "Write the bats-core tests for harden.sh first, then implement the function to pass them." Claude Code writes the test (overriding `SSHD_CONFIG` to a temp path), runs it (red), writes `harden_ssh`, runs again (green). Chad reviews, approves, and Claude Code commits and pushes. Same cycle for `setup-bastion.sh`, `setup-ddns.sh`, `setup-coredns.sh`, the deploy pipeline scripts -- each one test-first, then implementation. Claude Code handles all git operations (commit, push) on Chad's behalf.

When the scripts are done, Chad does the one thing AI cannot: he **physically** flashes an SD card with RPi OS Lite 64-bit and plugs it into the Pi. Claude Code then runs `make prep-pi-image ROLE=bastion` to walk through the first-boot checklist, followed by `make deploy-pi ROLE=bastion TARGET=192.168.1.10` (3-phase pipeline: decrypt, push, run) and `make verify-pi TARGET=192.168.1.10` (goss on the Pi, all checks pass).

He repeats the physical flash + AI deploy/verify cycle for Pi 2, Pi 3, Pi 4. Claude Code runs `make test-acceptance` -- DNS resolution, SOCKS proxy, DDNS updates all confirmed. Chad points DHCP to Pi 2 for DNS (router UI or Claude Code via TP-Link API script). Claude Code sets up health-check cron for 24 hours. Everything holds.

**Capabilities revealed:** Makefile targets, 3-phase deploy pipeline, goss verification, bats-core testing, prep-pi-image checklist, health-check cron, AI-driven TDD workflow, AI handles all git operations.

### Journey 2: Saturday Night Hardware Failure (Error Recovery)

It's 9pm Saturday. The family is streaming. Pi 2's SD card dies. DNS stops resolving -- but clients are already falling back to Pi 4 (.13, secondary DNS in DHCP), so streaming resumes within seconds on its own.

Chad notices the issue when he checks his laptop (the health-check cron logs to `/tmp/pi-health.log` every 15 minutes -- MVP has no push notifications, so detection depends on Chad reading the log or noticing symptoms). He grabs a spare SD card and **physically** flashes RPi OS Lite, plugs it into Pi 2, and powers it on. These physical steps are Chad's only hands-on work.

He opens Claude Code: "Pi 2 had an SD card failure. I've flashed a fresh card. Deploy and verify." Claude Code runs `make prep-pi-image ROLE=dns`, then `make deploy-pi ROLE=dns TARGET=192.168.1.11`, then `make verify-pi TARGET=192.168.1.11`. All green. Pi 2 is back as primary DNS. Total disruption to household: seconds (auto-mitigated by Pi 4 hot backup). Chad's effort: flash a card and direct AI.

**Capabilities revealed:** Hot-backup automatic fallback (Pi 4 as secondary DNS), physical flash is the only manual step, deploy pipeline handles the rest, health-check is log-based (no real-time alerting in MVP).

### Journey 3: Adding Pi-hole Six Months Later (Day 2 Evolution)

Six months pass. Chad hasn't touched the infrastructure. He wants ad-blocking. He opens Claude Code: "I want to add Pi-hole to the network. Read the repo and figure out how services are structured, then propose a plan."

Claude Code reads `make help`, the README, `inventory.sh`, and the existing scripts. It proposes: "I'll create `infrastructure/pi-scripts/pihole/setup-pihole.sh` following the same function-based pattern. Tests first in `tests/unit/test_pihole.bats`. Goss spec in `tests/integration/pihole.yaml`. I'll extend inventory.sh with the new Pi's details."

Chad approves. Claude Code writes the tests (red), writes the implementation (green), runs `make test` -- passes on the laptop. Claude Code commits and pushes. Chad **physically** flashes a spare Pi. "Deploy to the bench Pi, verify, then we'll connect it to the LAN." Claude Code deploys, verifies, all green. Chad plugs the Pi into the LAN. "Update DHCP to chain DNS through Pi-hole, then run acceptance tests." Claude Code handles it. Same pipeline, same safety, no new tooling, no code written by Chad.

**Capabilities revealed:** Repo as documentation (AI reads repo to understand conventions after 6-month gap), consistent conventions enabling AI to extend the system, test pyramid catching regressions, AI handles all code and git operations.

### Journey 4: Debugging a DNS Misconfiguration (Troubleshooting)

Chad tells Claude Code to add a new hostname to the DNS. Claude Code updates `inventory.sh` and re-generates the hosts file, but introduces a typo in the IP. `make test-unit` passes (the unit test checks format, not network reachability). Claude Code deploys to hot-backup Pi 4 first: `make deploy-pi ROLE=dns TARGET=192.168.1.13`. `make verify-pi TARGET=192.168.1.13` -- goss runs a dig check for the new hostname and gets the wrong IP. Test fails. Red.

Claude Code reports the failure, identifies the typo in `inventory.sh`, fixes it, re-runs unit tests (green), re-deploys to Pi 4, re-verifies (green). Chad approves promotion to production. Claude Code deploys to Pi 2, verifies, commits, pushes. Green. The live network was never affected because the hot-backup caught the error.

But what if the typo had slipped through to production? The health-check cron catches it on the next 15-minute cycle and logs: "FAIL: Pi DNS not resolving gitlab.mindlikewater.net." Chad sees the failure when he checks the log (MVP has no push notifications -- detection is log-based, so the issue persists until Chad notices or until the next morning). He opens Claude Code: "Health check failed on DNS. Diagnose and fix." Claude Code SSHs into Pi 2, reads the hosts file, traces the bad line back to `inventory.sh`, fixes it in the repo, re-deploys through the pipeline, re-verifies, commits, and pushes. The fix goes through the full TDD cycle.

**Capabilities revealed:** Hot-backup as pre-production staging, goss catching misconfigurations before live deploy, health-check is log-based (not real-time alerting in MVP), AI-driven diagnosis and repair, all fixes go through repo not manual Pi edits.

### Journey Requirements Summary

| Capability | Revealed by journey |
|---|---|
| Makefile as user interface (`make help`, all targets) | 1, 2, 3 |
| 3-phase deploy pipeline (decrypt -> push -> run) | 1, 2, 4 |
| bats-core unit tests (local, no Pi needed) | 1, 3, 4 |
| goss integration tests (on Pi, verify state) | 1, 2, 4 |
| Acceptance tests (end-to-end network) | 1, 3 |
| prep-pi-image checklist (fresh SD setup) | 1, 2 |
| Hot-backup Pis (pre-production + fallback) | 2, 4 |
| Health-check cron (log-based, no push notifications in MVP) | 1, 2, 4 |
| inventory.sh (single source of truth) | 1, 3, 4 |
| Script conventions (function-based, readable by AI + human) | 3, 4 |
| Repo as documentation (AI reads to understand after gaps) | 3 |
| AI-driven TDD workflow (Claude Code writes/tests/deploys/commits/pushes) | 1, 3, 4 |
| Physical steps are Chad's only hands-on work (flash SD, plug in Pi) | 1, 2, 3 |

## Innovation & Novel Patterns

### Detected Innovation: AI as Sole Developer of Infrastructure-as-Code

Most infrastructure-as-code projects are human-written, sometimes with AI assistance for boilerplate or suggestions. This project inverts that model entirely:

- **Chad writes zero code.** All shell scripts, tests, deployment automation, Makefile targets, and git operations are written and executed by Claude Code under Chad's direction.
- **The test pyramid is the trust mechanism.** AI-written code is not trusted by default -- it earns trust by passing unit tests, integration tests, and acceptance tests before touching the live network. The test suite is what makes AI-authored infrastructure safe to deploy.
- **The codebase is designed for dual readability.** Scripts must be parseable by AI tools (clear interfaces, consistent conventions, well-defined contracts like inventory.sh) AND readable by a human debugging at 2am (no magic, function names say what they do, `make help` is the UI).

### What Makes This Novel

| Conventional IaC | This project |
|---|---|
| Human writes code, AI suggests completions | AI writes all code, human directs and reviews |
| Tests validate human-written code | Tests are the trust mechanism for AI-written code |
| Documentation written separately | Repo structure IS the documentation (AI reads it to understand conventions) |
| Knowledge lives in the developer's head | Knowledge lives in the repo -- AI can pick up after any gap |

### Validation Approach

The innovation validates itself through the MVP process:
- If Claude Code can build the entire Pi infrastructure through TDD with Chad only providing direction and flashing SD cards, the model works.
- If the test pyramid catches real misconfigurations before they hit the live network, the trust mechanism works.
- If Claude Code can read the repo after 6 months and extend it (Journey 3), the dual-readability design works.

### Risk Mitigation

| Risk | Category | Mitigation |
|---|---|---|
| AI writes subtly incorrect code | Technical | Test pyramid catches it -- unit tests for logic, goss for state, acceptance for end-to-end. ShellCheck catches shell bugs. |
| AI doesn't understand existing conventions | Technical | Consistent script patterns + inventory.sh contract + README make conventions explicit and discoverable |
| AI introduces security vulnerability | Technical | ShellCheck (`make lint`), SSH hardening verification (goss), secrets never in plaintext (SOPS) |
| AI tool unavailable (outage, API change) | Resource | All code is standard bash -- Chad can read, understand, and manually edit if needed. Zero AI runtime dependency. |
| SD card reliability (Pi failure) | Technical | Hot-backup Pis + fast recovery pipeline. MVP explicitly designs for this failure mode. |
| CoreDNS misconfiguration breaks household internet | Technical | Deploy to hot-backup first. Pi 4 as secondary DNS in DHCP means household auto-recovers. |
| Scope creep into K8s/server tier | Resource | Hard MVP boundary: Pi layer only. Server is intermittent hardware. Post-MVP by design. |
| Solo operator (Chad) unavailable | Resource | Repo is documentation. Standard bash scripts. Any engineer (or AI) can read the repo and operate the system. |

## Infrastructure-as-Code Specific Requirements

### Command Structure (Makefile Targets)

All developer-facing operations are Makefile targets. No raw commands to memorize.

| Category | Targets | Requires Pi? |
|---|---|---|
| Convergence | `make converge`, `make converge-host HOST=<name>` | Yes |
| Status | `make status`, `make verify`, `make converge DRY_RUN=1` | Yes (status: partial) |
| Quality | `make lint`, `make test`, `make test-unit` | No |
| Integration | `make test-integration`, `make verify-pi` | Yes |
| Acceptance | `make test-acceptance` | Yes |
| Deploy | `make deploy-pi ROLE=<role> TARGET=<ip>` | Yes |
| Setup | `make prep-pi-image ROLE=<role>` | Physical SD card |
| Operations | `make health-check` | Yes |
| Discovery | `make help` | No |

Every target must work non-interactively (no prompts, no confirmations) so Claude Code can execute them directly.

### Configuration Schema

| Config | Format | Location | Mutable? |
|---|---|---|---|
| `inventory.sh` | Bash exports | `infrastructure/pi-scripts/inventory.sh` | Yes (source of truth for IPs, hostnames, roles) |
| `.sops.yaml` | YAML | Repo root | Rarely (only when adding new encrypted files) |
| `secrets.enc.yaml` | SOPS-encrypted YAML | `infrastructure/pi-scripts/secrets.enc.yaml` | Yes (when secrets change) |
| Corefile | CoreDNS config | Generated to `/etc/coredns/Corefile` on Pi | No (static template) |
| Hosts file | Generated hosts | Generated to `/etc/coredns/mindlikewater.hosts` on Pi | Yes (regenerated from inventory.sh) |

### Script Output Conventions

- **Status messages**: `echo "SSH already hardened, skipping"` -- human-readable, present tense
- **Error messages**: Write to stderr, exit non-zero (but never `exit` from functions -- return 1)
- **Goss output**: Standard goss validate format (pass/fail per check, summary count)
- **Health-check output**: `OK: <timestamp>` or `ALERT: N checks failed at <timestamp>`

### Implementation Considerations

- **No interactive prompts anywhere.** Every script, every Makefile target, every deploy step runs without human input. This is a hard requirement for AI-driven operation.
- **Idempotent everything.** Running any command twice produces no errors and no changes. Guards check state before acting.
- **Fail fast, fail loud.** `set -euo pipefail` on every script. No silent failures. Errors surface immediately with context.
- **No runtime dependencies beyond standard tools.** bash, ssh, scp, curl, goss, bats-core, shellcheck, sops, age. No Python for MVP (Python is only for post-MVP router management).

## Functional Requirements

### Network Service Provisioning

- FR1: The operator can provision a Pi as an SSH bastion host with hardened, key-only authentication
- FR2: The operator can provision a Pi as a DDNS updater that keeps a DNS provider record current with the home network's public IP
- FR3: The operator can provision a Pi as a split-horizon DNS server that resolves internal hostnames to LAN IPs and external queries to the public IP
- FR4: The operator can provision hot-backup Pis that are identical clones of primary service Pis
- FR5: The operator can add a new hostname to DNS resolution by updating a single configuration source

### Deployment & Recovery

- FR6: The operator can deploy a complete Pi configuration from a fresh SD card using a single command
- FR7: The operator can deploy to a specific Pi by role and target IP without modifying any scripts
- FR8: The operator can deploy to a hot-backup Pi first as a pre-production staging step before promoting to the primary
- FR9: The operator can roll back a DNS change by reverting a single network pointer in under 30 seconds
- FR10: The operator can run any deploy command multiple times with no errors and no unintended changes (idempotent)
- FR11: The system walks the operator through a first-boot checklist when preparing a fresh Pi image for a given role

### Testing & Verification

- FR12: The operator can run unit tests locally (no Pi required) that validate script logic and catch misconfigurations
- FR13: The operator can run integration tests on a real Pi that verify services are running and correctly configured
- FR14: The operator can run acceptance tests that validate end-to-end network behavior (DNS resolution, SSH access, DDNS updates)
- FR15: The operator can run all quality checks (lint + unit + integration + acceptance) with a single command
- FR16: The operator can verify a specific Pi's health after deployment with a single command
- FR17: The system runs periodic health checks and logs results with pass/fail status and timestamps

### Secrets Management

- FR18: The operator can store secrets in the git repository in encrypted form that is safe to commit
- FR19: The operator can decrypt secrets as part of the deploy pipeline without manual key handling
- FR20: The system prevents any plaintext credentials from appearing in git history

### Configuration Management

- FR21: The operator can define all network configuration (IPs, hostnames, roles, domain, ports) in a single source-of-truth file
- FR22: The system generates downstream configuration files (DNS hosts, etc.) from the single source of truth
- FR23: The operator can lint all scripts and catch shell errors before deployment

### Fleet Convergence

- FR31: The operator can converge all Pis to their declared state with a single command (`make converge`)
- FR32: The operator can check the health status of all hosts with a single command (`make status`)
- FR33: The operator can preview what convergence would change without applying changes (`make converge DRY_RUN=1`)

### Discoverability & Operations

- FR24: The operator can discover all available operations via a single help command
- FR25: The operator can perform every operation through named commands without memorizing raw tool invocations
- FR26: Every command runs non-interactively with no prompts or confirmations required
- FR27: The operator can understand and operate the entire network from a fresh clone of the repository without external documentation

## Non-Functional Requirements

### Security

- NFR1: No plaintext credentials exist in the git repository at any point in history
- NFR2: All secrets are encrypted at rest using SOPS + age; decryption requires a private key stored outside the repo
- NFR3: SSH access to all Pis uses key-only authentication; password authentication is disabled
- NFR4: All Pi SSH daemons are hardened (no root login, restricted ciphers, idle timeout)
- NFR5: Pi firewalls default to deny-all inbound, with explicit allow rules only for required services
- NFR6: All scripts pass ShellCheck with zero warnings (prevents injection and quoting vulnerabilities)

### Reliability

- NFR7: DNS resolution continues without perceptible interruption during any deploy or failover (Pi 4 as secondary DNS in DHCP)
- NFR8: All deploy operations are idempotent -- running twice produces no errors and no state changes
- NFR9: All scripts use `set -euo pipefail` -- no silent failures, errors surface immediately
- NFR10: Recovery from Pi hardware failure requires only a fresh SD card and a single deploy command (< 15 minutes total)
- NFR11: Health checks run every 15 minutes and log pass/fail with timestamps

### Maintainability

- NFR12: Every script follows the same conventions: function-based structure, idempotent guards, overridable paths for testing, main guard for sourcing
- NFR13: All scripts are readable by both AI tools (clear interfaces, consistent patterns, inventory.sh contract) and a human debugging at 2am (no magic, descriptive function names)
- NFR14: A fresh `git clone` + `make help` is sufficient to discover and understand all available operations
- NFR15: Adding a new service follows the existing patterns with no new tooling required (same TDD cycle, same deploy pipeline, same test pyramid)
