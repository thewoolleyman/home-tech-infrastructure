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

    # Create a mock SSH script that records its arguments and succeeds
    export SSH="$TEST_TMP/mock_ssh"
    cat > "$SSH" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/ssh_calls.log"
exit 0
MOCK
    chmod +x "$SSH"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "verify-pi.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/deploy/verify-pi.sh" ]
}

@test "verify-pi.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/deploy/verify-pi.sh" ]
}

@test "verify-pi.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/deploy/verify-pi.sh"
}

# ---- Argument validation ----

@test "verify-pi.sh fails with error when no target_ip given" {
    run "$PROJECT_ROOT/scripts/deploy/verify-pi.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"target_ip"* ]] || [[ "$output" == *"Usage"* ]]
}

# ---- Role detection from IP ----

@test "verify-pi.sh uses bastion.yaml spec for target 192.168.1.10" {
    source "$PROJECT_ROOT/scripts/deploy/verify-pi.sh"
    run detect_role "192.168.1.10"
    [ "$status" -eq 0 ]
    [[ "$output" == "bastion" ]]
}

@test "verify-pi.sh uses dns.yaml spec for target 192.168.1.11" {
    source "$PROJECT_ROOT/scripts/deploy/verify-pi.sh"
    run detect_role "192.168.1.11"
    [ "$status" -eq 0 ]
    [[ "$output" == "dns" ]]
}

# ---- SCP copies spec files ----

@test "verify_pi copies spec files to Pi via SCP" {
    source "$PROJECT_ROOT/scripts/deploy/verify-pi.sh"
    verify_pi "192.168.1.10" "bastion"
    [ -f "$TEST_TMP/scp_calls.log" ]
    grep -q "bastion.yaml" "$TEST_TMP/scp_calls.log"
}

@test "verify_pi copies common.yaml to Pi via SCP" {
    source "$PROJECT_ROOT/scripts/deploy/verify-pi.sh"
    verify_pi "192.168.1.10" "bastion"
    grep -q "common.yaml" "$TEST_TMP/scp_calls.log"
}

# ---- SSH runs goss ----

@test "verify_pi runs goss validate via SSH" {
    source "$PROJECT_ROOT/scripts/deploy/verify-pi.sh"
    verify_pi "192.168.1.10" "bastion"
    [ -f "$TEST_TMP/ssh_calls.log" ]
    grep -q "goss" "$TEST_TMP/ssh_calls.log"
}

# ---- Return codes ----

@test "verify_pi returns 0 when goss succeeds" {
    source "$PROJECT_ROOT/scripts/deploy/verify-pi.sh"
    run verify_pi "192.168.1.10" "bastion"
    [ "$status" -eq 0 ]
}

@test "verify_pi returns 1 when goss fails" {
    # Override SSH mock to fail (simulates goss validation failure)
    cat > "$SSH" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/ssh_calls.log"
exit 1
MOCK
    chmod +x "$SSH"

    source "$PROJECT_ROOT/scripts/deploy/verify-pi.sh"
    run verify_pi "192.168.1.10" "bastion"
    [ "$status" -ne 0 ]
}

# ---- Deploy user ----

@test "verify_pi uses DEPLOY_USER for SSH and SCP targets" {
    source "$PROJECT_ROOT/scripts/deploy/verify-pi.sh"
    verify_pi "192.168.1.10" "bastion"
    grep -q "deploy@" "$TEST_TMP/scp_calls.log"
    grep -q "deploy@" "$TEST_TMP/ssh_calls.log"
}
