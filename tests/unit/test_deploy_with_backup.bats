#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$PROJECT_ROOT/scripts/deploy/deploy-with-backup.sh"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Log file for tracking deploy calls (role, ip, order)
    export DEPLOY_LOG="$TEST_TMP/deploy_calls.log"
    touch "$DEPLOY_LOG"

    # Log file for tracking verify calls
    export VERIFY_LOG="$TEST_TMP/verify_calls.log"
    touch "$VERIFY_LOG"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# Helper: source the script and set mock DEPLOY_CMD / VERIFY_CMD
_source_with_mocks() {
    # Export fail target so it survives into run subshell
    export MOCK_FAIL_TARGET="${1:-}"

    # Mock deploy command: logs calls, optionally fails for a given target
    export DEPLOY_CMD="mock_deploy"
    mock_deploy() {
        local role="$1" ip="$2"
        echo "deploy $role $ip" >> "$DEPLOY_LOG"
        if [ -n "${MOCK_FAIL_TARGET:-}" ] && [ "$ip" = "$MOCK_FAIL_TARGET" ]; then
            return 1
        fi
        return 0
    }
    export -f mock_deploy

    # Mock verify command: logs calls
    export VERIFY_CMD="mock_verify"
    mock_verify() {
        local role="$1" ip="$2"
        echo "verify $role $ip" >> "$VERIFY_LOG"
        return 0
    }
    export -f mock_verify

    # Source the script under test
    source "$SCRIPT"
}

# ---- Script exists and is well-formed ----

@test "deploy-with-backup.sh exists" {
    [ -f "$SCRIPT" ]
}

@test "deploy-with-backup.sh is executable" {
    [ -x "$SCRIPT" ]
}

@test "deploy-with-backup.sh passes shellcheck" {
    shellcheck "$SCRIPT"
}

# ---- Argument validation ----

@test "fails with error when no role given" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"role"* ]]
}

@test "fails for invalid role" {
    export DEPLOY_CMD="true"
    run "$SCRIPT" "webserver"
    [ "$status" -ne 0 ]
    [[ "$output" == *"bastion"* ]] || [[ "$output" == *"dns"* ]]
}

# ---- resolve_backup_target ----

@test "resolve_backup_target returns bastion-backup for bastion role" {
    _source_with_mocks
    run resolve_backup_target "bastion"
    [ "$status" -eq 0 ]
    [[ "$output" == *"bastion-backup"* ]]
    [[ "$output" == *"192.168.1.12"* ]]
}

@test "resolve_backup_target returns dns-backup for dns role" {
    _source_with_mocks
    run resolve_backup_target "dns"
    [ "$status" -eq 0 ]
    [[ "$output" == *"dns-backup"* ]]
    [[ "$output" == *"192.168.1.13"* ]]
}

# ---- resolve_primary_target ----

@test "resolve_primary_target returns bastion for bastion role" {
    _source_with_mocks
    run resolve_primary_target "bastion"
    [ "$status" -eq 0 ]
    [[ "$output" == *"bastion"* ]]
    [[ "$output" == *"192.168.1.10"* ]]
}

@test "resolve_primary_target returns dns for dns role" {
    _source_with_mocks
    run resolve_primary_target "dns"
    [ "$status" -eq 0 ]
    [[ "$output" == *"dns"* ]]
    [[ "$output" == *"192.168.1.11"* ]]
}

# ---- Deploy order: backup first ----

@test "deploys to backup IP first (not primary)" {
    _source_with_mocks
    run deploy_backup_first "bastion"
    [ "$status" -eq 0 ]
    # First deploy call should be to backup IP 192.168.1.12
    local first_call
    first_call="$(head -n1 "$DEPLOY_LOG")"
    [[ "$first_call" == *"192.168.1.12"* ]]
}

# ---- Without CONFIRM_PRIMARY ----

@test "without CONFIRM_PRIMARY: does NOT deploy to primary" {
    unset CONFIRM_PRIMARY
    _source_with_mocks
    run deploy_backup_first "bastion"
    [ "$status" -eq 0 ]
    # Should only have one deploy call (the backup)
    local call_count
    call_count="$(wc -l < "$DEPLOY_LOG")"
    [ "$call_count" -eq 1 ]
    # That single call should be to backup IP
    ! grep -q "192.168.1.10" "$DEPLOY_LOG"
}

# ---- With CONFIRM_PRIMARY=1 ----

@test "with CONFIRM_PRIMARY=1: deploys to primary after backup" {
    export CONFIRM_PRIMARY=1
    _source_with_mocks
    run deploy_backup_first "bastion"
    [ "$status" -eq 0 ]
    # Should have two deploy calls
    local call_count
    call_count="$(wc -l < "$DEPLOY_LOG")"
    [ "$call_count" -eq 2 ]
    # First call is backup, second call is primary
    local first_call second_call
    first_call="$(head -n1 "$DEPLOY_LOG")"
    second_call="$(tail -n1 "$DEPLOY_LOG")"
    [[ "$first_call" == *"192.168.1.12"* ]]
    [[ "$second_call" == *"192.168.1.10"* ]]
}

# ---- Reports backup success before primary prompt ----

@test "reports backup success before primary prompt" {
    unset CONFIRM_PRIMARY
    _source_with_mocks
    run deploy_backup_first "bastion"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Backup deployed successfully"* ]]
    [[ "$output" == *"CONFIRM_PRIMARY"* ]]
}

# ---- Success return code ----

@test "returns 0 when all deployments succeed" {
    export CONFIRM_PRIMARY=1
    _source_with_mocks
    run deploy_backup_first "bastion"
    [ "$status" -eq 0 ]
}

# ---- Failure: backup deploy fails ----

@test "returns 1 when backup deploy fails (does not attempt primary)" {
    export CONFIRM_PRIMARY=1
    # Fail on backup IP for bastion (192.168.1.12)
    _source_with_mocks "192.168.1.12"
    run deploy_backup_first "bastion"
    [ "$status" -eq 1 ]
    # Should NOT have attempted primary
    ! grep -q "192.168.1.10" "$DEPLOY_LOG"
}
