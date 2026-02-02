#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# ---- Directory structure tests ----

@test "infrastructure/pi-scripts/ directory exists" {
    [ -d "$PROJECT_ROOT/infrastructure/pi-scripts" ]
}

@test "infrastructure/pi-scripts/common/ directory exists" {
    [ -d "$PROJECT_ROOT/infrastructure/pi-scripts/common" ]
}

@test "infrastructure/pi-scripts/bastion/ directory exists" {
    [ -d "$PROJECT_ROOT/infrastructure/pi-scripts/bastion" ]
}

@test "infrastructure/pi-scripts/dns/ directory exists" {
    [ -d "$PROJECT_ROOT/infrastructure/pi-scripts/dns" ]
}

@test "infrastructure/pi-scripts/sync/ directory exists" {
    [ -d "$PROJECT_ROOT/infrastructure/pi-scripts/sync" ]
}

@test "scripts/bootstrap/ directory exists" {
    [ -d "$PROJECT_ROOT/scripts/bootstrap" ]
}

@test "scripts/deploy/ directory exists" {
    [ -d "$PROJECT_ROOT/scripts/deploy" ]
}

@test "scripts/ops/ directory exists" {
    [ -d "$PROJECT_ROOT/scripts/ops" ]
}

@test "scripts/ddns/ directory exists" {
    [ -d "$PROJECT_ROOT/scripts/ddns" ]
}

@test "tests/unit/ directory exists" {
    [ -d "$PROJECT_ROOT/tests/unit" ]
}

@test "tests/integration/ directory exists" {
    [ -d "$PROJECT_ROOT/tests/integration" ]
}

@test "tests/acceptance/ directory exists" {
    [ -d "$PROJECT_ROOT/tests/acceptance" ]
}

# ---- Makefile tests ----

@test "Makefile exists" {
    [ -f "$PROJECT_ROOT/Makefile" ]
}

@test "make help runs successfully" {
    cd "$PROJECT_ROOT"
    run make help
    [ "$status" -eq 0 ]
}

@test "make help lists help target" {
    cd "$PROJECT_ROOT"
    run make help
    [[ "$output" == *"help"* ]]
}

@test "make help lists lint target" {
    cd "$PROJECT_ROOT"
    run make help
    [[ "$output" == *"lint"* ]]
}

@test "make help lists test target" {
    cd "$PROJECT_ROOT"
    run make help
    [[ "$output" == *"test "* ]] || [[ "$output" == *"test-unit"* ]]
}

@test "make help lists deploy-pi target" {
    cd "$PROJECT_ROOT"
    run make help
    [[ "$output" == *"deploy-pi"* ]]
}

@test "make help lists verify-pi target" {
    cd "$PROJECT_ROOT"
    run make help
    [[ "$output" == *"verify-pi"* ]]
}

@test "make help lists health-check target" {
    cd "$PROJECT_ROOT"
    run make help
    [[ "$output" == *"health-check"* ]]
}

@test "make help lists test-all target" {
    cd "$PROJECT_ROOT"
    run make help
    [[ "$output" == *"test-all"* ]]
}

@test "make help lists prep-pi-image target" {
    cd "$PROJECT_ROOT"
    run make help
    [[ "$output" == *"prep-pi-image"* ]]
}

# ---- .gitignore tests ----

@test ".gitignore contains *.dec.yaml pattern" {
    grep -q '^\*\.dec\.yaml' "$PROJECT_ROOT/.gitignore"
}

@test ".gitignore contains age.key pattern" {
    grep -q '^age\.key' "$PROJECT_ROOT/.gitignore"
}

@test ".gitignore contains *.agekey pattern" {
    grep -q '^\*\.agekey' "$PROJECT_ROOT/.gitignore"
}
