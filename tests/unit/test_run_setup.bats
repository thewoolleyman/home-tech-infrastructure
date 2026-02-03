#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Create a mock SSH script that records its arguments
    export SSH="$TEST_TMP/mock_ssh"
    cat > "$SSH" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/ssh_calls.log"
MOCK
    chmod +x "$SSH"

    # Create a fake decrypt_dir with secrets.dec.yaml for shred_secrets testing
    export DECRYPT_DIR="$TEST_TMP/decrypted"
    mkdir -p "$DECRYPT_DIR"
    echo "secret: value" > "$DECRYPT_DIR/secrets.dec.yaml"
    chmod 600 "$DECRYPT_DIR/secrets.dec.yaml"

    # Override shred_secrets so we don't need real sops/age for this test
    export SHRED_SECRETS_OVERRIDE="true"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "run-setup.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/deploy/run-setup.sh" ]
}

@test "run-setup.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/deploy/run-setup.sh" ]
}

@test "run-setup.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
}

# ---- Argument validation ----

@test "run-setup.sh fails with error when no role given" {
    run "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"role"* ]]
}

@test "run-setup.sh fails with error for invalid role" {
    run "$PROJECT_ROOT/scripts/deploy/run-setup.sh" "webserver" "192.168.1.10"
    [ "$status" -ne 0 ]
    [[ "$output" == *"bastion"* ]]
    [[ "$output" == *"dns"* ]]
}

@test "run-setup.sh fails with error when no target_ip given" {
    run "$PROJECT_ROOT/scripts/deploy/run-setup.sh" "bastion"
    [ "$status" -ne 0 ]
    [[ "$output" == *"target_ip"* ]]
}

# ---- Bastion setup sequence ----

@test "run_setup for bastion executes harden.sh" {
    source "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
    run_setup "bastion" "192.168.1.10" "$DECRYPT_DIR"
    grep -q "harden.sh" "$TEST_TMP/ssh_calls.log"
}

@test "run_setup for bastion executes unattended-upgrades.sh" {
    source "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
    run_setup "bastion" "192.168.1.10" "$DECRYPT_DIR"
    grep -q "unattended-upgrades.sh" "$TEST_TMP/ssh_calls.log"
}

@test "run_setup for bastion executes setup-bastion.sh" {
    source "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
    run_setup "bastion" "192.168.1.10" "$DECRYPT_DIR"
    grep -q "setup-bastion.sh" "$TEST_TMP/ssh_calls.log"
}

@test "run_setup for bastion executes setup-ddns.sh" {
    source "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
    run_setup "bastion" "192.168.1.10" "$DECRYPT_DIR"
    grep -q "setup-ddns.sh" "$TEST_TMP/ssh_calls.log"
}

@test "run_setup for bastion executes scripts in correct order" {
    source "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
    run_setup "bastion" "192.168.1.10" "$DECRYPT_DIR"
    # All four scripts should appear in the ssh call
    local ssh_log
    ssh_log="$(cat "$TEST_TMP/ssh_calls.log")"
    # harden.sh must appear before setup-bastion.sh
    [[ "$ssh_log" == *"harden.sh"*"unattended-upgrades.sh"*"setup-bastion.sh"*"setup-ddns.sh"* ]]
}

# ---- DNS setup sequence ----

@test "run_setup for dns executes harden.sh" {
    source "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
    run_setup "dns" "192.168.1.11" "$DECRYPT_DIR"
    grep -q "harden.sh" "$TEST_TMP/ssh_calls.log"
}

@test "run_setup for dns executes unattended-upgrades.sh" {
    source "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
    run_setup "dns" "192.168.1.11" "$DECRYPT_DIR"
    grep -q "unattended-upgrades.sh" "$TEST_TMP/ssh_calls.log"
}

@test "run_setup for dns executes setup-coredns.sh" {
    source "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
    run_setup "dns" "192.168.1.11" "$DECRYPT_DIR"
    grep -q "setup-coredns.sh" "$TEST_TMP/ssh_calls.log"
}

@test "run_setup for dns does not execute bastion scripts" {
    source "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
    run_setup "dns" "192.168.1.11" "$DECRYPT_DIR"
    ! grep -q "setup-bastion.sh" "$TEST_TMP/ssh_calls.log"
    ! grep -q "setup-ddns.sh" "$TEST_TMP/ssh_calls.log"
}

@test "run_setup for dns executes scripts in correct order" {
    source "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
    run_setup "dns" "192.168.1.11" "$DECRYPT_DIR"
    local ssh_log
    ssh_log="$(cat "$TEST_TMP/ssh_calls.log")"
    [[ "$ssh_log" == *"harden.sh"*"unattended-upgrades.sh"*"setup-coredns.sh"* ]]
}

# ---- Deploy user ----

@test "run_setup uses DEPLOY_USER for SSH connection" {
    source "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
    run_setup "bastion" "192.168.1.10" "$DECRYPT_DIR"
    grep -q "deploy@" "$TEST_TMP/ssh_calls.log"
}

# ---- Secrets cleanup ----

@test "run_setup cleans up decrypt_dir after successful execution" {
    source "$PROJECT_ROOT/scripts/deploy/run-setup.sh"
    [ -d "$DECRYPT_DIR" ]
    run_setup "bastion" "192.168.1.10" "$DECRYPT_DIR"
    [ ! -d "$DECRYPT_DIR" ]
}
