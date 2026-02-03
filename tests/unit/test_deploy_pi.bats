#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Track which phase functions were called and in what order
    export PHASE_LOG="$TEST_TMP/phase_calls.log"
    touch "$PHASE_LOG"

    # Track shred_secrets calls
    export SHRED_LOG="$TEST_TMP/shred_calls.log"
    touch "$SHRED_LOG"

    # Mock encrypted file
    mkdir -p "$TEST_TMP/infrastructure/pi-scripts"
    touch "$TEST_TMP/infrastructure/pi-scripts/secrets.enc.yaml"
    export ENCRYPTED_FILE="$TEST_TMP/infrastructure/pi-scripts/secrets.enc.yaml"

    # Enable test mode so deploy-pi.sh does not source real phase scripts
    export DEPLOY_PI_TEST_MODE=1

    # Phase to fail (empty = no failure). Tests override this before calling.
    export DEPLOY_PI_FAIL_PHASE=""
}

teardown() {
    rm -rf "$TEST_TMP"
}

# Helper: source deploy-pi.sh and define + export mock phase functions.
# Mock functions are exported so they survive bats `run` subshells.
_setup_mocks() {
    source "$PROJECT_ROOT/scripts/deploy/deploy-pi.sh"

    # Override the phase functions with mocks that log calls
    decrypt_secrets() {
        echo "decrypt_secrets $*" >> "$PHASE_LOG"
        if [ "$DEPLOY_PI_FAIL_PHASE" = "1" ]; then return 1; fi
    }
    export -f decrypt_secrets

    push_scripts() {
        echo "push_scripts $*" >> "$PHASE_LOG"
        if [ "$DEPLOY_PI_FAIL_PHASE" = "2" ]; then return 1; fi
    }
    export -f push_scripts

    run_setup() {
        echo "run_setup $*" >> "$PHASE_LOG"
        if [ "$DEPLOY_PI_FAIL_PHASE" = "3" ]; then return 1; fi
    }
    export -f run_setup

    shred_secrets() {
        echo "shred_secrets $*" >> "$SHRED_LOG"
    }
    export -f shred_secrets
}

# ---- Script exists ----

@test "deploy-pi.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/deploy/deploy-pi.sh" ]
}

@test "deploy-pi.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/deploy/deploy-pi.sh" ]
}

@test "deploy-pi.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/deploy/deploy-pi.sh"
}

# ---- Argument validation ----

@test "deploy_pi fails with error when no role given" {
    _setup_mocks
    run deploy_pi
    [ "$status" -ne 0 ]
    [[ "$output" == *"role"* ]]
}

@test "deploy_pi fails with error when no target_ip given" {
    _setup_mocks
    run deploy_pi "bastion"
    [ "$status" -ne 0 ]
    [[ "$output" == *"target_ip"* ]]
}

@test "deploy_pi fails with error for invalid role" {
    _setup_mocks
    run deploy_pi "webserver" "192.168.1.10"
    [ "$status" -ne 0 ]
    [[ "$output" == *"bastion"* ]]
    [[ "$output" == *"dns"* ]]
}

# ---- Phase execution order ----

@test "deploy_pi executes Phase 1 (decrypt) first" {
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 0 ]
    local first_call
    first_call="$(head -n1 "$PHASE_LOG")"
    [[ "$first_call" == "decrypt_secrets"* ]]
}

@test "deploy_pi executes Phase 2 (push) after Phase 1" {
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 0 ]
    local second_call
    second_call="$(sed -n '2p' "$PHASE_LOG")"
    [[ "$second_call" == "push_scripts"* ]]
}

@test "deploy_pi executes Phase 3 (execute) after Phase 2" {
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 0 ]
    local third_call
    third_call="$(sed -n '3p' "$PHASE_LOG")"
    [[ "$third_call" == "run_setup"* ]]
}

@test "deploy_pi passes role and target_ip to push_scripts" {
    _setup_mocks
    run deploy_pi "dns" "192.168.1.11"
    [ "$status" -eq 0 ]
    grep -q "push_scripts dns 192.168.1.11" "$PHASE_LOG"
}

@test "deploy_pi passes role and target_ip to run_setup" {
    _setup_mocks
    run deploy_pi "dns" "192.168.1.11"
    [ "$status" -eq 0 ]
    grep -q "run_setup dns 192.168.1.11" "$PHASE_LOG"
}

# ---- Phase markers in output ----

@test "output contains Phase 1 marker" {
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== Phase 1: Decrypt ==="* ]]
}

@test "output contains Phase 2 marker" {
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== Phase 2: Push ==="* ]]
}

@test "output contains Phase 3 marker" {
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== Phase 3: Execute ==="* ]]
}

# ---- Success reporting ----

@test "deploy_pi returns 0 on success" {
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 0 ]
}

@test "deploy_pi reports success when all phases complete" {
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deploy complete"* ]]
}

# ---- Failure reporting ----

@test "deploy_pi returns 1 when Phase 1 fails" {
    export DEPLOY_PI_FAIL_PHASE="1"
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 1 ]
}

@test "deploy_pi reports which phase failed (Phase 1)" {
    export DEPLOY_PI_FAIL_PHASE="1"
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Phase 1"* ]] || [[ "$output" == *"Decrypt"* ]]
}

@test "deploy_pi returns 1 when Phase 2 fails" {
    export DEPLOY_PI_FAIL_PHASE="2"
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 1 ]
}

@test "deploy_pi reports which phase failed (Phase 2)" {
    export DEPLOY_PI_FAIL_PHASE="2"
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Phase 2"* ]] || [[ "$output" == *"Push"* ]]
}

@test "deploy_pi returns 1 when Phase 3 fails" {
    export DEPLOY_PI_FAIL_PHASE="3"
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 1 ]
}

@test "deploy_pi reports which phase failed (Phase 3)" {
    export DEPLOY_PI_FAIL_PHASE="3"
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Phase 3"* ]] || [[ "$output" == *"Execute"* ]]
}

# ---- Secrets cleanup (trap) ----

@test "deploy_pi shreds secrets on success" {
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 0 ]
    [ -s "$SHRED_LOG" ]
}

@test "deploy_pi shreds secrets even when Phase 2 fails" {
    export DEPLOY_PI_FAIL_PHASE="2"
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 1 ]
    [ -s "$SHRED_LOG" ]
}

@test "deploy_pi shreds secrets even when Phase 3 fails" {
    export DEPLOY_PI_FAIL_PHASE="3"
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 1 ]
    [ -s "$SHRED_LOG" ]
}

# ---- Phase 2/3 not called on earlier failure ----

@test "deploy_pi does not call push_scripts when Phase 1 fails" {
    export DEPLOY_PI_FAIL_PHASE="1"
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 1 ]
    ! grep -q "push_scripts" "$PHASE_LOG"
}

@test "deploy_pi does not call run_setup when Phase 2 fails" {
    export DEPLOY_PI_FAIL_PHASE="2"
    _setup_mocks
    run deploy_pi "bastion" "192.168.1.10"
    [ "$status" -eq 1 ]
    ! grep -q "run_setup" "$PHASE_LOG"
}
