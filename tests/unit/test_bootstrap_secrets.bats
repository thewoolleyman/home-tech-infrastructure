#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # Use a temp dir for key generation tests to avoid polluting the project
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Prerequisites ----

@test "age-keygen is on PATH" {
    command -v age-keygen
}

@test "sops is on PATH" {
    command -v sops
}

# ---- bootstrap-secrets.sh exists and is executable ----

@test "bootstrap-secrets.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/bootstrap/bootstrap-secrets.sh" ]
}

@test "bootstrap-secrets.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/bootstrap/bootstrap-secrets.sh" ]
}

@test "bootstrap-secrets.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/bootstrap/bootstrap-secrets.sh"
}

# ---- Key generation function ----

@test "bootstrap-secrets generates age keypair in specified directory" {
    source "$PROJECT_ROOT/scripts/bootstrap/bootstrap-secrets.sh"
    generate_keypair "$TEST_TMP"
    [ -f "$TEST_TMP/age.key" ]
}

@test "generated age.key contains a secret key line" {
    source "$PROJECT_ROOT/scripts/bootstrap/bootstrap-secrets.sh"
    generate_keypair "$TEST_TMP"
    grep -q '^AGE-SECRET-KEY-' "$TEST_TMP/age.key"
}

@test "generate_keypair outputs public key to stdout" {
    source "$PROJECT_ROOT/scripts/bootstrap/bootstrap-secrets.sh"
    run generate_keypair "$TEST_TMP"
    [ "$status" -eq 0 ]
    [[ "$output" == *"age1"* ]]
}

# ---- .sops.yaml generation ----

@test "create_sops_yaml generates valid .sops.yaml" {
    source "$PROJECT_ROOT/scripts/bootstrap/bootstrap-secrets.sh"
    local pubkey="age1testkey1234567890abcdef"
    create_sops_yaml "$TEST_TMP" "$pubkey"
    [ -f "$TEST_TMP/.sops.yaml" ]
}

@test ".sops.yaml contains the age public key" {
    source "$PROJECT_ROOT/scripts/bootstrap/bootstrap-secrets.sh"
    local pubkey="age1testkey1234567890abcdef"
    create_sops_yaml "$TEST_TMP" "$pubkey"
    grep -q "$pubkey" "$TEST_TMP/.sops.yaml"
}

@test ".sops.yaml specifies secrets.enc.yaml path pattern" {
    source "$PROJECT_ROOT/scripts/bootstrap/bootstrap-secrets.sh"
    local pubkey="age1testkey1234567890abcdef"
    create_sops_yaml "$TEST_TMP" "$pubkey"
    grep -q 'secrets.*enc.*yaml' "$TEST_TMP/.sops.yaml"
}

@test ".sops.yaml does not contain private key material" {
    source "$PROJECT_ROOT/scripts/bootstrap/bootstrap-secrets.sh"
    local pubkey="age1testkey1234567890abcdef"
    create_sops_yaml "$TEST_TMP" "$pubkey"
    ! grep -q 'AGE-SECRET-KEY' "$TEST_TMP/.sops.yaml"
}

# ---- Idempotency ----

@test "generate_keypair refuses to overwrite existing key" {
    source "$PROJECT_ROOT/scripts/bootstrap/bootstrap-secrets.sh"
    generate_keypair "$TEST_TMP"
    run generate_keypair "$TEST_TMP"
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

# ---- Makefile target ----

@test "make help lists bootstrap-secrets target" {
    cd "$PROJECT_ROOT"
    run make help
    [[ "$output" == *"bootstrap-secrets"* ]]
}

# ---- .gitignore patterns (already tested but verify for this story) ----

@test ".gitignore blocks age.key" {
    grep -q 'age.key' "$PROJECT_ROOT/.gitignore"
}

@test ".gitignore blocks *.agekey" {
    grep -q '\*.agekey' "$PROJECT_ROOT/.gitignore"
}

@test ".gitignore blocks *.dec.yaml" {
    grep -q '\*.dec.yaml' "$PROJECT_ROOT/.gitignore"
}
