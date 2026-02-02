# Story 1.1: Create Repository Scaffolding and Makefile

Status: review

## Story

As the operator,
I want the repository directory structure and a Makefile with `make help`,
so that I can discover all available operations from a fresh clone.

## Acceptance Criteria

1. **Given** a fresh clone of the repository
   **When** I run `make help`
   **Then** I see a formatted list of all available Makefile targets with descriptions
   **And** the directory structure matches the architecture specification (`infrastructure/pi-scripts/{common,bastion,dns,sync}`, `scripts/{bootstrap,deploy,ops,ddns}`, `tests/{unit,integration,acceptance}`)

2. **Given** the Makefile exists
   **When** I inspect it
   **Then** every target uses `.PHONY` declarations
   **And** every public target has a `## description` comment for `make help`
   **And** all commands run non-interactively with no prompts

**FRs:** FR24 (make help), FR25 (named Makefile targets), FR26 (non-interactive)

## Tasks / Subtasks

- [x] Task 1: Bootstrap minimal test infrastructure (AC: 1, 2)
  - [x] 1.1: Add bats-core, bats-assert, bats-support as git submodules under `tests/libs/`
  - [x] 1.2: Verify bats runs with a trivial smoke test
- [x] Task 2: Create directory structure -- TDD (AC: 1)
  - [x] 2.1: RED -- Write `tests/unit/test_scaffolding.bats` asserting all architecture-specified directories exist
  - [x] 2.2: GREEN -- Create all required directories with `.gitkeep` files
  - [x] 2.3: REFACTOR -- Verify test passes, all directories tracked by git
- [x] Task 3: Create Makefile with `make help` -- TDD (AC: 1, 2)
  - [x] 3.1: RED -- Write bats test asserting `make help` lists all MVP targets with descriptions
  - [x] 3.2: GREEN -- Create Makefile with self-documenting help target and all MVP target stubs
  - [x] 3.3: REFACTOR -- Verify `.PHONY` on every target, `## description` on every public target, no interactive prompts
- [x] Task 4: Update .gitignore for secrets patterns (AC: related to FR20)
  - [x] 4.1: RED -- Write bats test asserting .gitignore contains secrets exclusion patterns
  - [x] 4.2: GREEN -- Add `*.dec.yaml`, `age.key`, `*.agekey` patterns to .gitignore
  - [x] 4.3: REFACTOR -- Verify test passes
- [x] Task 5: Validate all acceptance criteria (AC: all)
  - [x] 5.1: Run full test suite (`bats tests/unit/`) -- all 25 tests pass
  - [x] 5.2: Run `make help` and verify formatted output (11 targets, sorted, aligned)
  - [x] 5.3: Verify all targets are non-interactive (FR26) -- all stubs use `@echo`, no prompts

## Dev Notes

### Architecture Requirements

**Repository structure** (from architecture-diagram.md, "Repository Structure" section):

The repo already contains: `.gitignore`, `CLAUDE.md`, `README.md`, `LICENSE`, `_bmad/`, `_bmad-output/`, `reference/`, `scripts/` (partially created).

This story creates the MVP infrastructure directories that don't yet exist:

```
infrastructure/pi-scripts/           # Ansible-compatible shell scripts for Pis
  inventory.sh                       # (Story 1.2 -- not this story)
  common/                            # Shared: harden.sh, unattended-upgrades.sh, setup-goss.sh
  bastion/                           # setup-bastion.sh, setup-ddns.sh
  dns/                               # setup-coredns.sh
  sync/                              # Hot-backup sync scripts
scripts/
  bootstrap/                         # generate-age-keypair.sh
  deploy/                            # 3-phase: decrypt.sh, push.sh, run-setup.sh, prep-pi-image.sh
  ops/                               # health-check.sh
  ddns/                              # update-namecheap.sh
tests/
  libs/                              # bats-core, bats-assert, bats-support (git submodules)
  unit/                              # bats-core (*.bats)
  integration/                       # goss (*.yaml)
  acceptance/                        # end-to-end (test_*.sh)
```

**Makefile** (from architecture-diagram.md, "Makefile (MVP)" section):

All MVP targets with `## description` comments for self-documenting `make help`:

```makefile
help          ## Show available targets
lint          ## ShellCheck all shell scripts
test          ## Run lint + unit tests (no Pi needed)
test-unit     ## Run bats-core unit tests
test-integration  ## Run goss specs on Pis (requires SSH to Pis)
test-acceptance   ## End-to-end network tests (requires live network)
test-all      ## Run everything
prep-pi-image ## Checklist for flashing a new Pi SD card
deploy-pi     ## Deploy to Pi (3-phase)
verify-pi     ## Smoke test a Pi after deploy
health-check  ## Run health checks (DNS, SSH, CoreDNS process)
```

Targets other than `help` should be stubs in this story (print "Not implemented yet" and exit 0). They will be fleshed out in later stories.

The `help` target uses the self-documenting pattern:
```makefile
@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | sort | \
    awk 'BEGIN {FS = ":.*## "}; {printf "  %-20s %s\n", $$1, $$2}'
```

**Make help pattern** (from architecture decision #29: "Local Makefile only"):
- Every public target has `## description` suffix
- `make help` is the primary entry point for discovering operations
- All commands run non-interactively with no prompts or confirmations

### .gitignore Updates

Add to existing .gitignore (from architecture-diagram.md, ".gitignore Additions"):
```
# Never commit unencrypted secrets or private keys
*.dec.yaml
age.key
*.agekey
```

### Shell Script Conventions (Context for Later Stories)

All scripts under `infrastructure/pi-scripts/` must follow conventions from architecture decision #27:
- `set -euo pipefail`
- Function-based structure with idempotent guards
- Overridable paths via env vars (for test isolation)
- `PROJECT_ROOT` via `BASH_SOURCE`
- `main` guard: `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi`
- Functions return 0/1, never `exit`

This story does NOT create any shell scripts (that starts in Story 1.2). It only creates the directory structure where they will live.

### Testing Approach

**Bootstrap problem**: bats-core is the unit test framework, but Story 1.3 is "Set Up TDD Toolchain". To follow TDD in Story 1.1, we need a minimal bats-core setup.

**Resolution**: Install bats-core/bats-assert/bats-support as git submodules in `tests/libs/` during this story. Story 1.3 will formalize the setup (add README docs, `make lint` with ShellCheck, `make test-unit` wiring, goss installation).

**bats-core git submodules**:
```bash
git submodule add https://github.com/bats-core/bats-core.git tests/libs/bats-core
git submodule add https://github.com/bats-core/bats-support.git tests/libs/bats-support
git submodule add https://github.com/bats-core/bats-assert.git tests/libs/bats-assert
```

**Run bats locally** (no system install needed):
```bash
./tests/libs/bats-core/bin/bats tests/unit/
```

**Test file structure** for `tests/unit/test_scaffolding.bats`:
```bash
#!/usr/bin/env bats
load '../libs/bats-support/load'
load '../libs/bats-assert/load'

@test "infrastructure/pi-scripts/common/ directory exists" {
    [ -d "infrastructure/pi-scripts/common" ]
}
# ... similar for all required directories

@test "make help lists all MVP targets" {
    run make help
    assert_success
    assert_output --partial "help"
    assert_output --partial "deploy-pi"
    # ... assert all MVP targets appear
}
```

### What This Story Does NOT Include

- inventory.sh (Story 1.2)
- ShellCheck setup, `make lint` wiring, goss (Story 1.3)
- README documentation (Story 1.4)
- Any shell scripts in infrastructure/ or scripts/ directories
- .sops.yaml (Story 2.1)

### Anti-Patterns to Avoid

- Do NOT hardcode IPs, hostnames, or paths in the Makefile (those come from inventory.sh in Story 1.2)
- Do NOT create shell scripts yet -- only directories
- Do NOT install ShellCheck or goss (that's Story 1.3)
- Do NOT add `bootstrap-secrets` target (that's Story 2.1)
- Do NOT make `make test-unit` call bats yet -- that's a stub. Story 1.3 wires it up properly.
- The `make test` stub should NOT call lint (Story 1.3 adds that). For now, `test` is just a stub.
- Do NOT create Kubernetes directories (post-MVP scope)

### Project Structure Notes

- Alignment: All paths match architecture-diagram.md "Repository Structure" exactly (MVP subset only)
- Variance: `tests/libs/` is added for bats git submodules (not in architecture diagram but implied by bats-core usage)
- The `scripts/` directory already partially exists in the repo -- do not recreate, just add subdirectories

### References

- [Source: _bmad-output/brainstorming/architecture-diagram.md#Repository Structure] -- full directory tree
- [Source: _bmad-output/brainstorming/architecture-diagram.md#Makefile (MVP)] -- all targets with exact syntax
- [Source: _bmad-output/brainstorming/architecture-diagram.md#Shell Script Conventions] -- script structure template
- [Source: _bmad-output/brainstorming/architecture-diagram.md#.gitignore Additions] -- secrets patterns
- [Source: _bmad-output/brainstorming/architecture-diagram.md#Testing Strategy] -- bats-core conventions
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.1] -- acceptance criteria and FR mapping

## Change Log

| Date | Change |
|------|--------|
| 2026-02-01 | Story created by create-story workflow |
| 2026-02-01 | Implementation complete: scaffolding, Makefile, .gitignore, 25 bats tests |

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- RED phase: 20/25 tests failed (directories missing, Makefile missing, .gitignore patterns missing)
- GREEN phase: Created directories, Makefile, .gitignore patterns
- Final run: 25/25 tests pass

### Completion Notes List

- Installed bats-core, bats-support, bats-assert as git submodules in tests/libs/
- Created 10 directories with .gitkeep files per architecture spec
- Created Makefile with 11 MVP targets (help functional, others are stubs)
- Updated .gitignore with secrets exclusion patterns (*.dec.yaml, age.key, *.agekey)
- Wrote 25 bats tests covering directory structure, Makefile targets, and .gitignore patterns
- All tests pass, make help output is formatted and sorted

### File List

- `tests/libs/bats-core/` (git submodule)
- `tests/libs/bats-support/` (git submodule)
- `tests/libs/bats-assert/` (git submodule)
- `tests/unit/test_scaffolding.bats` (new)
- `infrastructure/pi-scripts/common/.gitkeep` (new)
- `infrastructure/pi-scripts/bastion/.gitkeep` (new)
- `infrastructure/pi-scripts/dns/.gitkeep` (new)
- `infrastructure/pi-scripts/sync/.gitkeep` (new)
- `scripts/bootstrap/.gitkeep` (new)
- `scripts/deploy/.gitkeep` (new)
- `scripts/ops/.gitkeep` (new)
- `scripts/ddns/.gitkeep` (new)
- `tests/integration/.gitkeep` (new)
- `tests/acceptance/.gitkeep` (new)
- `Makefile` (new)
- `.gitignore` (modified)
- `.gitmodules` (new)
- `_bmad-output/implementation-artifacts/1-1-create-repository-scaffolding-and-makefile.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/planning-artifacts/implementation-readiness-report-2026-02-01.md` (modified)
