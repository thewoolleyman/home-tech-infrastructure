#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# ---- README exists ----

@test "README.md exists" {
    [ -f "$PROJECT_ROOT/README.md" ]
}

# ---- Required sections ----

@test "README has project purpose heading" {
    grep -qE '^#+ .*What This Manages' "$PROJECT_ROOT/README.md" || \
    grep -qE '^# home-tech-infrastructure' "$PROJECT_ROOT/README.md"
}

@test "README has network topology table" {
    grep -q '| Bastion' "$PROJECT_ROOT/README.md"
    grep -q '| DNS' "$PROJECT_ROOT/README.md"
}

@test "README has Prerequisites section" {
    grep -qE '^#+ .*Prerequisites' "$PROJECT_ROOT/README.md"
}

@test "README lists git as prerequisite" {
    grep -q 'git' "$PROJECT_ROOT/README.md"
}

@test "README lists shellcheck as prerequisite" {
    grep -qi 'shellcheck' "$PROJECT_ROOT/README.md"
}

@test "README has Quick Start or Setup section" {
    grep -qE '^#+ .*(Quick Start|Setup|Getting Started)' "$PROJECT_ROOT/README.md"
}

@test "README references make help" {
    grep -q 'make help' "$PROJECT_ROOT/README.md"
}

@test "README references make test" {
    grep -q 'make test' "$PROJECT_ROOT/README.md"
}

@test "README documents Pi roles" {
    grep -q 'bastion' "$PROJECT_ROOT/README.md"
    grep -q 'DNS' "$PROJECT_ROOT/README.md"
    grep -q 'DDNS' "$PROJECT_ROOT/README.md"
}

# ---- Operational correctness ----

@test "README does not say Planning phase" {
    ! grep -q 'Planning phase' "$PROJECT_ROOT/README.md"
}
