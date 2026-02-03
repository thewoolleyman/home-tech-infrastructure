#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    mkdir -p "$TEST_TMP/bin"

    # Mock ping - succeeds by default
    cat > "$TEST_TMP/bin/ping" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/ping"

    # Mock curl - returns a minimal HTML response by default
    cat > "$TEST_TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
echo "<html><title>Archer AXE95</title><body>WAN: Connected</body></html>"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/curl"

    export PING="$TEST_TMP/bin/ping"
    export CURL="$TEST_TMP/bin/curl"

    # Source inventory for host definitions
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists and is well-formed ----

@test "router-status.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/ops/router-status.sh" ]
}

@test "router-status.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/ops/router-status.sh" ]
}

@test "router-status.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/ops/router-status.sh"
}

# ---- check_router_reachable ----

@test "check_router_reachable returns 0 when ping succeeds" {
    source "$PROJECT_ROOT/scripts/ops/router-status.sh"
    run check_router_reachable
    [ "$status" -eq 0 ]
}

@test "check_router_reachable returns 1 when ping fails" {
    cat > "$TEST_TMP/bin/ping" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/ping"

    source "$PROJECT_ROOT/scripts/ops/router-status.sh"
    run check_router_reachable
    [ "$status" -eq 1 ]
}

# ---- get_router_status ----

@test "get_router_status output contains router IP" {
    source "$PROJECT_ROOT/scripts/ops/router-status.sh"
    run get_router_status
    [[ "$output" == *"$ROUTER_IP"* ]]
}

@test "get_router_status output contains Reachable" {
    source "$PROJECT_ROOT/scripts/ops/router-status.sh"
    run get_router_status
    [[ "$output" == *"Reachable"* ]]
}

@test "get_router_status output contains expected SSID" {
    source "$PROJECT_ROOT/scripts/ops/router-status.sh"
    run get_router_status
    [[ "$output" == *"$WIFI_SSID"* ]]
}

@test "get_router_status returns 0 when router is reachable" {
    source "$PROJECT_ROOT/scripts/ops/router-status.sh"
    run get_router_status
    [ "$status" -eq 0 ]
}

@test "get_router_status returns 1 when router is unreachable" {
    cat > "$TEST_TMP/bin/ping" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/ping"

    source "$PROJECT_ROOT/scripts/ops/router-status.sh"
    run get_router_status
    [ "$status" -eq 1 ]
}

# ---- router_status (main function) ----

@test "router_status outputs error when unreachable" {
    cat > "$TEST_TMP/bin/ping" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/ping"

    source "$PROJECT_ROOT/scripts/ops/router-status.sh"
    run router_status
    [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"unreachable"* ]]
}
