#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    mkdir -p "$TEST_TMP/bin"

    # Mock python3 - fails import by default (no tplink_client available)
    cat > "$TEST_TMP/bin/python3" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/python3_calls.log"
# Fail on import check by default
if echo "$@" | grep -q "import"; then
    echo "ModuleNotFoundError: No module named 'scripts'" >&2
    exit 1
fi
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/python3"

    # Mock nc - succeeds by default
    cat > "$TEST_TMP/bin/nc" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/nc_calls.log"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/nc"

    export PYTHON="$TEST_TMP/bin/python3"
    export NC="$TEST_TMP/bin/nc"

    # Source inventory for host/DNS definitions
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists and is well-formed ----

@test "configure-port-forwards.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh" ]
}

@test "configure-port-forwards.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh" ]
}

@test "configure-port-forwards.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
}

# ---- check_python_client ----

@test "check_python_client returns 1 when Python client not available" {
    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run check_python_client
    [ "$status" -eq 1 ]
}

@test "check_python_client returns 0 when Python client is available" {
    cat > "$TEST_TMP/bin/python3" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/python3"

    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run check_python_client
    [ "$status" -eq 0 ]
}

# ---- configure_forwards_manual ----

@test "configure_forwards_manual output contains ext port 4222" {
    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run configure_forwards_manual
    [[ "$output" == *"4222"* ]]
}

@test "configure_forwards_manual output contains bastion IP" {
    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run configure_forwards_manual
    [[ "$output" == *"192.168.1.10"* ]]
}

@test "configure_forwards_manual output contains numbered steps" {
    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run configure_forwards_manual
    [[ "$output" == *"1."* ]]
    [[ "$output" == *"2."* ]]
    [[ "$output" == *"3."* ]]
    [[ "$output" == *"4."* ]]
}

@test "configure_forwards_manual returns 0" {
    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run configure_forwards_manual
    [ "$status" -eq 0 ]
}

@test "configure_forwards_manual output contains router IP" {
    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run configure_forwards_manual
    [[ "$output" == *"192.168.1.1"* ]]
}

# ---- verify_port_forward ----

@test "verify_port_forward returns 0 when nc succeeds" {
    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run verify_port_forward 4222 "192.168.1.10" 22
    [ "$status" -eq 0 ]
}

@test "verify_port_forward returns 1 when nc fails" {
    cat > "$TEST_TMP/bin/nc" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/nc"

    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run verify_port_forward 4222 "192.168.1.10" 22
    [ "$status" -eq 1 ]
}

# ---- configure_port_forwards (main function) ----

@test "configure_port_forwards falls back to manual when Python unavailable" {
    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run configure_port_forwards
    # Should contain manual steps since python client is mocked to fail
    [[ "$output" == *"Manual"* ]]
    [[ "$output" == *"4222"* ]]
}

@test "configure_port_forwards attempts auto configuration first" {
    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run configure_port_forwards
    [[ "$output" == *"auto"* ]] || [[ "$output" == *"Auto"* ]] || [[ "$output" == *"Python"* ]]
}

@test "configure_port_forwards runs verification" {
    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run configure_port_forwards
    [[ "$output" == *"Verif"* ]]
}

@test "configure_port_forwards returns 0 when verification passes" {
    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run configure_port_forwards
    [ "$status" -eq 0 ]
}

@test "configure_port_forwards returns 1 when verification fails" {
    cat > "$TEST_TMP/bin/nc" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/nc"

    source "$PROJECT_ROOT/scripts/ops/configure-port-forwards.sh"
    run configure_port_forwards
    [ "$status" -eq 1 ]
}
