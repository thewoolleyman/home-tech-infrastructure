#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Generate a test keypair and encrypted secrets for decrypt testing
    age-keygen -o "$TEST_TMP/age.key" 2>"$TEST_TMP/keygen.out"
    TEST_PUBKEY=$(grep '^Public key:' "$TEST_TMP/keygen.out" | awk '{print $3}')
    export SOPS_AGE_KEY_FILE="$TEST_TMP/age.key"

    # Create a test encrypted secrets file
    cat > "$TEST_TMP/secrets.yaml" <<'SECRETS'
deploy_ssh_private_key: "test-ssh-key-value"
namecheap_ddns_password: "test-ddns-pass"
pi_host_keys:
  bastion: "test-hostkey-bastion"
  dns: "test-hostkey-dns"
SECRETS
    sops --encrypt --age "$TEST_PUBKEY" --input-type yaml --output-type yaml \
         --output "$TEST_TMP/secrets.enc.yaml" "$TEST_TMP/secrets.yaml"
    rm -f "$TEST_TMP/secrets.yaml"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "decrypt.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/deploy/decrypt.sh" ]
}

@test "decrypt.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/deploy/decrypt.sh" ]
}

@test "decrypt.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/deploy/decrypt.sh"
}

# ---- Decryption ----

@test "decrypt_secrets creates output directory" {
    source "$PROJECT_ROOT/scripts/deploy/decrypt.sh"
    local outdir="$TEST_TMP/decrypted"
    decrypt_secrets "$TEST_TMP/secrets.enc.yaml" "$outdir"
    [ -d "$outdir" ]
}

@test "decrypt_secrets produces decrypted YAML" {
    source "$PROJECT_ROOT/scripts/deploy/decrypt.sh"
    local outdir="$TEST_TMP/decrypted"
    decrypt_secrets "$TEST_TMP/secrets.enc.yaml" "$outdir"
    [ -f "$outdir/secrets.dec.yaml" ]
    grep -q 'deploy_ssh_private_key' "$outdir/secrets.dec.yaml"
}

@test "decrypted file has strict permissions (600)" {
    source "$PROJECT_ROOT/scripts/deploy/decrypt.sh"
    local outdir="$TEST_TMP/decrypted"
    decrypt_secrets "$TEST_TMP/secrets.enc.yaml" "$outdir"
    local perms
    perms=$(stat -f '%Lp' "$outdir/secrets.dec.yaml" 2>/dev/null || stat -c '%a' "$outdir/secrets.dec.yaml" 2>/dev/null)
    [ "$perms" = "600" ]
}

@test "decrypted output directory has strict permissions (700)" {
    source "$PROJECT_ROOT/scripts/deploy/decrypt.sh"
    local outdir="$TEST_TMP/decrypted"
    decrypt_secrets "$TEST_TMP/secrets.enc.yaml" "$outdir"
    local perms
    perms=$(stat -f '%Lp' "$outdir" 2>/dev/null || stat -c '%a' "$outdir" 2>/dev/null)
    [ "$perms" = "700" ]
}

# ---- Error handling ----

@test "decrypt_secrets fails with clear error when encrypted file missing" {
    source "$PROJECT_ROOT/scripts/deploy/decrypt.sh"
    run decrypt_secrets "$TEST_TMP/nonexistent.enc.yaml" "$TEST_TMP/out"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "decrypt_secrets fails with clear error when no age key" {
    unset SOPS_AGE_KEY_FILE
    source "$PROJECT_ROOT/scripts/deploy/decrypt.sh"
    run decrypt_secrets "$TEST_TMP/secrets.enc.yaml" "$TEST_TMP/out"
    [ "$status" -ne 0 ]
    [[ "$output" == *"SOPS_AGE_KEY_FILE"* ]]
}

# ---- Cleanup function ----

@test "shred_secrets removes decrypted files" {
    source "$PROJECT_ROOT/scripts/deploy/decrypt.sh"
    local outdir="$TEST_TMP/decrypted"
    decrypt_secrets "$TEST_TMP/secrets.enc.yaml" "$outdir"
    [ -f "$outdir/secrets.dec.yaml" ]
    shred_secrets "$outdir"
    [ ! -f "$outdir/secrets.dec.yaml" ]
    [ ! -d "$outdir" ]
}
