#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    mkdir -p "$TEST_TMP/bin"

    # Mock nc - port is open by default
    cat > "$TEST_TMP/bin/nc" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/nc"

    # Mock curl - returns a minimal response by default
    cat > "$TEST_TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/curl"

    export NC="$TEST_TMP/bin/nc"
    export CURL="$TEST_TMP/bin/curl"

    # Source inventory for host definitions
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists and is well-formed ----

@test "router-forwards.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/ops/router-forwards.sh" ]
}

@test "router-forwards.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/ops/router-forwards.sh" ]
}

@test "router-forwards.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/ops/router-forwards.sh"
}

# ---- list_expected_forwards ----

@test "list_expected_forwards output contains 4222" {
    source "$PROJECT_ROOT/scripts/ops/router-forwards.sh"
    run list_expected_forwards
    [[ "$output" == *"4222"* ]]
}

@test "list_expected_forwards output contains bastion IP" {
    source "$PROJECT_ROOT/scripts/ops/router-forwards.sh"
    run list_expected_forwards
    [[ "$output" == *"$PI1_IP"* ]]
}

# ---- check_port_forward ----

@test "check_port_forward returns 0 when nc succeeds" {
    source "$PROJECT_ROOT/scripts/ops/router-forwards.sh"
    run check_port_forward "$SSH_EXTERNAL_PORT" "$PI1_IP" 22
    [ "$status" -eq 0 ]
}

@test "check_port_forward returns 1 when nc fails" {
    cat > "$TEST_TMP/bin/nc" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/nc"

    source "$PROJECT_ROOT/scripts/ops/router-forwards.sh"
    run check_port_forward "$SSH_EXTERNAL_PORT" "$PI1_IP" 22
    [ "$status" -eq 1 ]
}

# ---- verify_forwards ----

@test "verify_forwards output contains PASS when forward works" {
    source "$PROJECT_ROOT/scripts/ops/router-forwards.sh"
    run verify_forwards
    [[ "$output" == *"PASS"* ]]
}

@test "verify_forwards output contains FAIL when forward broken" {
    cat > "$TEST_TMP/bin/nc" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/nc"

    source "$PROJECT_ROOT/scripts/ops/router-forwards.sh"
    run verify_forwards
    [[ "$output" == *"FAIL"* ]]
}

@test "verify_forwards returns 0 when all forwards pass" {
    source "$PROJECT_ROOT/scripts/ops/router-forwards.sh"
    run verify_forwards
    [ "$status" -eq 0 ]
}

@test "verify_forwards returns 1 when any forward fails" {
    cat > "$TEST_TMP/bin/nc" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/nc"

    source "$PROJECT_ROOT/scripts/ops/router-forwards.sh"
    run verify_forwards
    [ "$status" -eq 1 ]
}
