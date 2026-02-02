#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Generate a temporary age keypair for encrypt/decrypt tests
    age-keygen -o "$TEST_TMP/age.key" 2>"$TEST_TMP/keygen.out"
    TEST_PUBKEY=$(grep '^Public key:' "$TEST_TMP/keygen.out" | awk '{print $3}')
    export TEST_PUBKEY
    export SOPS_AGE_KEY_FILE="$TEST_TMP/age.key"

    # Create a .sops.yaml for the test
    cat > "$TEST_TMP/.sops.yaml" <<SOPSEOF
creation_rules:
  - path_regex: secrets\.enc\.yaml$
    age: >-
      $TEST_PUBKEY
SOPSEOF
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "create-secrets.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/bootstrap/create-secrets.sh" ]
}

@test "create-secrets.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/bootstrap/create-secrets.sh" ]
}

@test "create-secrets.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/bootstrap/create-secrets.sh"
}

# ---- Template generation ----

@test "generate_secrets_template creates valid YAML with expected fields" {
    source "$PROJECT_ROOT/scripts/bootstrap/create-secrets.sh"
    generate_secrets_template "$TEST_TMP/secrets.yaml"
    [ -f "$TEST_TMP/secrets.yaml" ]
    grep -q 'deploy_ssh_private_key' "$TEST_TMP/secrets.yaml"
    grep -q 'namecheap_ddns_password' "$TEST_TMP/secrets.yaml"
    grep -q 'pi_host_keys' "$TEST_TMP/secrets.yaml"
}

@test "template contains placeholder values" {
    source "$PROJECT_ROOT/scripts/bootstrap/create-secrets.sh"
    generate_secrets_template "$TEST_TMP/secrets.yaml"
    grep -q 'REPLACE_ME' "$TEST_TMP/secrets.yaml"
}

# ---- Encryption roundtrip ----

@test "encrypt_secrets creates an encrypted file" {
    source "$PROJECT_ROOT/scripts/bootstrap/create-secrets.sh"
    generate_secrets_template "$TEST_TMP/secrets.yaml"
    encrypt_secrets "$TEST_TMP/secrets.yaml" "$TEST_TMP/secrets.enc.yaml" "$TEST_TMP/.sops.yaml"
    [ -f "$TEST_TMP/secrets.enc.yaml" ]
}

@test "encrypted file contains sops metadata" {
    source "$PROJECT_ROOT/scripts/bootstrap/create-secrets.sh"
    generate_secrets_template "$TEST_TMP/secrets.yaml"
    encrypt_secrets "$TEST_TMP/secrets.yaml" "$TEST_TMP/secrets.enc.yaml" "$TEST_TMP/.sops.yaml"
    grep -q 'sops' "$TEST_TMP/secrets.enc.yaml"
}

@test "encrypted file does not contain plaintext REPLACE_ME" {
    source "$PROJECT_ROOT/scripts/bootstrap/create-secrets.sh"
    generate_secrets_template "$TEST_TMP/secrets.yaml"
    encrypt_secrets "$TEST_TMP/secrets.yaml" "$TEST_TMP/secrets.enc.yaml" "$TEST_TMP/.sops.yaml"
    ! grep -q 'REPLACE_ME' "$TEST_TMP/secrets.enc.yaml"
}

@test "decrypted file matches original template" {
    source "$PROJECT_ROOT/scripts/bootstrap/create-secrets.sh"
    generate_secrets_template "$TEST_TMP/secrets.yaml"
    encrypt_secrets "$TEST_TMP/secrets.yaml" "$TEST_TMP/secrets.enc.yaml" "$TEST_TMP/.sops.yaml"
    sops --decrypt "$TEST_TMP/secrets.enc.yaml" > "$TEST_TMP/decrypted.yaml"
    grep -q 'deploy_ssh_private_key' "$TEST_TMP/decrypted.yaml"
    grep -q 'REPLACE_ME' "$TEST_TMP/decrypted.yaml"
}

# ---- Idempotency ----

@test "encrypt_secrets refuses to overwrite existing encrypted file" {
    source "$PROJECT_ROOT/scripts/bootstrap/create-secrets.sh"
    generate_secrets_template "$TEST_TMP/secrets.yaml"
    encrypt_secrets "$TEST_TMP/secrets.yaml" "$TEST_TMP/secrets.enc.yaml" "$TEST_TMP/.sops.yaml"
    run encrypt_secrets "$TEST_TMP/secrets.yaml" "$TEST_TMP/secrets.enc.yaml" "$TEST_TMP/.sops.yaml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}
