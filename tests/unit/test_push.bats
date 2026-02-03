#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Create a mock SCP script that records its arguments
    export SCP="$TEST_TMP/mock_scp"
    cat > "$SCP" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/scp_calls.log"
MOCK
    chmod +x "$SCP"

    # Create a mock SSH script that records its arguments
    export SSH="$TEST_TMP/mock_ssh"
    cat > "$SSH" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/ssh_calls.log"
MOCK
    chmod +x "$SSH"

    # Create a fake decrypt_dir with secrets.dec.yaml
    export DECRYPT_DIR="$TEST_TMP/decrypted"
    mkdir -p "$DECRYPT_DIR"
    echo "secret: value" > "$DECRYPT_DIR/secrets.dec.yaml"
    chmod 600 "$DECRYPT_DIR/secrets.dec.yaml"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "push.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/deploy/push.sh" ]
}

@test "push.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/deploy/push.sh" ]
}

@test "push.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/deploy/push.sh"
}

# ---- Argument validation ----

@test "push.sh fails with error when no role given" {
    run "$PROJECT_ROOT/scripts/deploy/push.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"role"* ]]
}

@test "push.sh fails with error for invalid role" {
    run "$PROJECT_ROOT/scripts/deploy/push.sh" "webserver" "192.168.1.10" "$DECRYPT_DIR"
    [ "$status" -ne 0 ]
    [[ "$output" == *"bastion"* ]]
    [[ "$output" == *"dns"* ]]
}

@test "push.sh fails with error when no target_ip given" {
    run "$PROJECT_ROOT/scripts/deploy/push.sh" "bastion"
    [ "$status" -ne 0 ]
    [[ "$output" == *"target_ip"* ]]
}

@test "push.sh fails with error when decrypt_dir missing" {
    run "$PROJECT_ROOT/scripts/deploy/push.sh" "bastion" "192.168.1.10" "$TEST_TMP/nonexistent"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"does not exist"* ]]
}

@test "push.sh fails with error when secrets.dec.yaml not in decrypt_dir" {
    local empty_dir="$TEST_TMP/empty_decrypt"
    mkdir -p "$empty_dir"
    run "$PROJECT_ROOT/scripts/deploy/push.sh" "bastion" "192.168.1.10" "$empty_dir"
    [ "$status" -ne 0 ]
    [[ "$output" == *"secrets.dec.yaml"* ]]
}

# ---- Bastion role ----

@test "push_scripts for bastion copies common/ directory" {
    source "$PROJECT_ROOT/scripts/deploy/push.sh"
    push_scripts "bastion" "192.168.1.10" "$DECRYPT_DIR"
    grep -q "common/" "$TEST_TMP/scp_calls.log"
}

@test "push_scripts for bastion copies bastion/ directory" {
    source "$PROJECT_ROOT/scripts/deploy/push.sh"
    push_scripts "bastion" "192.168.1.10" "$DECRYPT_DIR"
    grep -q "bastion/" "$TEST_TMP/scp_calls.log"
}

@test "push_scripts for bastion does not copy dns/ directory" {
    source "$PROJECT_ROOT/scripts/deploy/push.sh"
    push_scripts "bastion" "192.168.1.10" "$DECRYPT_DIR"
    ! grep -q "dns/" "$TEST_TMP/scp_calls.log"
}

# ---- DNS role ----

@test "push_scripts for dns copies common/ directory" {
    source "$PROJECT_ROOT/scripts/deploy/push.sh"
    push_scripts "dns" "192.168.1.11" "$DECRYPT_DIR"
    grep -q "common/" "$TEST_TMP/scp_calls.log"
}

@test "push_scripts for dns copies dns/ directory" {
    source "$PROJECT_ROOT/scripts/deploy/push.sh"
    push_scripts "dns" "192.168.1.11" "$DECRYPT_DIR"
    grep -q "dns/" "$TEST_TMP/scp_calls.log"
}

@test "push_scripts for dns does not copy bastion/ directory" {
    source "$PROJECT_ROOT/scripts/deploy/push.sh"
    push_scripts "dns" "192.168.1.11" "$DECRYPT_DIR"
    ! grep -q "bastion/" "$TEST_TMP/scp_calls.log"
}

# ---- Common assets ----

@test "push_scripts always copies inventory.sh" {
    source "$PROJECT_ROOT/scripts/deploy/push.sh"
    push_scripts "bastion" "192.168.1.10" "$DECRYPT_DIR"
    grep -q "inventory.sh" "$TEST_TMP/scp_calls.log"
}

@test "push_scripts copies decrypted secrets" {
    source "$PROJECT_ROOT/scripts/deploy/push.sh"
    push_scripts "bastion" "192.168.1.10" "$DECRYPT_DIR"
    grep -q "secrets.dec.yaml" "$TEST_TMP/scp_calls.log" || grep -q "$DECRYPT_DIR" "$TEST_TMP/scp_calls.log"
}

# ---- Remote directory setup ----

@test "push_scripts creates remote directory via ssh before scp" {
    source "$PROJECT_ROOT/scripts/deploy/push.sh"
    push_scripts "bastion" "192.168.1.10" "$DECRYPT_DIR"
    [ -f "$TEST_TMP/ssh_calls.log" ]
    grep -q "mkdir" "$TEST_TMP/ssh_calls.log"
}

# ---- Deploy user ----

@test "push_scripts uses DEPLOY_USER for scp target" {
    source "$PROJECT_ROOT/scripts/deploy/push.sh"
    push_scripts "bastion" "192.168.1.10" "$DECRYPT_DIR"
    grep -q "deploy@" "$TEST_TMP/scp_calls.log"
}
