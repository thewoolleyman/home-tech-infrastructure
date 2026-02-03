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

    # Mock dig - resolves by default
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
echo "google.com. 300 IN A 142.250.80.46"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    # Mock nmcli - returns active SSID in terse format by default
    cat > "$TEST_TMP/bin/nmcli" <<MOCK
#!/usr/bin/env bash
echo "yes:FBI_SURVEILLANCE_VAN"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/nmcli"

    # Mock ip - returns an IP address by default
    cat > "$TEST_TMP/bin/ip" <<'MOCK'
#!/usr/bin/env bash
echo "    inet 192.168.1.50/24 brd 192.168.1.255 scope global wlan0"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/ip"

    export PING="$TEST_TMP/bin/ping"
    export DIG="$TEST_TMP/bin/dig"
    export NMCLI="$TEST_TMP/bin/nmcli"
    export IP_CMD="$TEST_TMP/bin/ip"

    # Source inventory
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists and is well-formed ----

@test "verify-network.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/ops/verify-network.sh" ]
}

@test "verify-network.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/ops/verify-network.sh" ]
}

@test "verify-network.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/ops/verify-network.sh"
}

# ---- check_internet ----

@test "check_internet returns 0 when DNS resolves" {
    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run check_internet
    [ "$status" -eq 0 ]
}

@test "check_internet returns 1 when DNS fails" {
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run check_internet
    [ "$status" -eq 1 ]
}

# ---- check_router ----

@test "check_router returns 0 when ping succeeds" {
    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run check_router
    [ "$status" -eq 0 ]
}

@test "check_router returns 1 when ping fails" {
    cat > "$TEST_TMP/bin/ping" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/ping"

    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run check_router
    [ "$status" -eq 1 ]
}

# ---- check_modem ----

@test "check_modem returns 0 when ping succeeds" {
    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run check_modem
    [ "$status" -eq 0 ]
}

@test "check_modem returns 1 when ping fails" {
    cat > "$TEST_TMP/bin/ping" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/ping"

    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run check_modem
    [ "$status" -eq 1 ]
}

# ---- check_wifi_ssid ----

@test "check_wifi_ssid returns 0 when SSID matches" {
    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run check_wifi_ssid
    [ "$status" -eq 0 ]
}

@test "check_wifi_ssid returns 1 when SSID does not match" {
    cat > "$TEST_TMP/bin/nmcli" <<'MOCK'
#!/usr/bin/env bash
echo "yes:SomeOtherNetwork"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/nmcli"

    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run check_wifi_ssid
    [ "$status" -eq 1 ]
}

# ---- check_dhcp ----

@test "check_dhcp returns 0 when interface has IP" {
    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run check_dhcp
    [ "$status" -eq 0 ]
}

@test "check_dhcp returns 1 when no IP" {
    cat > "$TEST_TMP/bin/ip" <<'MOCK'
#!/usr/bin/env bash
echo ""
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/ip"

    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run check_dhcp
    [ "$status" -eq 1 ]
}

# ---- verify_network output ----

@test "verify_network output contains [PASS] for passing checks" {
    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run verify_network
    [[ "$output" == *"[PASS]"* ]]
}

@test "verify_network output contains [FAIL] for failing checks" {
    cat > "$TEST_TMP/bin/ping" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/ping"

    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run verify_network
    [[ "$output" == *"[FAIL]"* ]]
}

@test "verify_network returns 0 when all pass" {
    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run verify_network
    [ "$status" -eq 0 ]
}

@test "verify_network returns 1 when any fail" {
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run verify_network
    [ "$status" -eq 1 ]
}

@test "verify_network output contains checks passed summary" {
    source "$PROJECT_ROOT/scripts/ops/verify-network.sh"
    run verify_network
    [[ "$output" == *"checks passed"* ]]
}
