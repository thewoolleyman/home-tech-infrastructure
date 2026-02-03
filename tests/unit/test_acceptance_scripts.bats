#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Create mock bin directory
    mkdir -p "$TEST_TMP/bin"

    # Source inventory for expected values
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ============================================================
# test_dns_resolution.sh -- exists, executable, shellcheck
# ============================================================

@test "test_dns_resolution.sh exists" {
    [ -f "$PROJECT_ROOT/tests/acceptance/test_dns_resolution.sh" ]
}

@test "test_dns_resolution.sh is executable" {
    [ -x "$PROJECT_ROOT/tests/acceptance/test_dns_resolution.sh" ]
}

@test "test_dns_resolution.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/tests/acceptance/test_dns_resolution.sh"
}

# ============================================================
# test_dns_resolution.sh -- function tests with mocks
# ============================================================

@test "test_internal_resolution returns 0 when dig returns correct IP" {
    # Mock dig: return the expected bastion IP
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
echo "192.168.1.10"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    export DIG="$TEST_TMP/bin/dig"
    source "$PROJECT_ROOT/tests/acceptance/test_dns_resolution.sh"
    test_internal_resolution
}

@test "test_internal_resolution returns 1 when dig returns wrong IP" {
    # Mock dig: return a wrong IP
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
echo "10.0.0.99"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    export DIG="$TEST_TMP/bin/dig"
    source "$PROJECT_ROOT/tests/acceptance/test_dns_resolution.sh"
    run test_internal_resolution
    [ "$status" -eq 1 ]
}

@test "test_upstream_forwarding returns 0 when dig resolves" {
    # Mock dig: return an A record
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
echo "142.250.80.46"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    export DIG="$TEST_TMP/bin/dig"
    source "$PROJECT_ROOT/tests/acceptance/test_dns_resolution.sh"
    test_upstream_forwarding
}

# ============================================================
# test_ddns_propagation.sh -- exists, executable, shellcheck
# ============================================================

@test "test_ddns_propagation.sh exists" {
    [ -f "$PROJECT_ROOT/tests/acceptance/test_ddns_propagation.sh" ]
}

@test "test_ddns_propagation.sh is executable" {
    [ -x "$PROJECT_ROOT/tests/acceptance/test_ddns_propagation.sh" ]
}

@test "test_ddns_propagation.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/tests/acceptance/test_ddns_propagation.sh"
}

# ============================================================
# test_ddns_propagation.sh -- function tests with mocks
# ============================================================

@test "get_public_ip returns an IP address" {
    # Mock curl: return a fake public IP
    cat > "$TEST_TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
echo "203.0.113.42"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/curl"

    export CURL="$TEST_TMP/bin/curl"
    source "$PROJECT_ROOT/tests/acceptance/test_ddns_propagation.sh"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "test_ddns_matches returns 0 when IPs match" {
    # Mock curl: return a public IP
    cat > "$TEST_TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
echo "203.0.113.42"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/curl"

    # Mock dig: return the same IP for DDNS record
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
echo "203.0.113.42"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    export CURL="$TEST_TMP/bin/curl"
    export DIG="$TEST_TMP/bin/dig"
    source "$PROJECT_ROOT/tests/acceptance/test_ddns_propagation.sh"
    test_ddns_matches
}

@test "test_ddns_matches returns 1 when IPs differ" {
    # Mock curl: return a public IP
    cat > "$TEST_TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
echo "203.0.113.42"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/curl"

    # Mock dig: return a different IP
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
echo "198.51.100.1"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    export CURL="$TEST_TMP/bin/curl"
    export DIG="$TEST_TMP/bin/dig"
    source "$PROJECT_ROOT/tests/acceptance/test_ddns_propagation.sh"
    run test_ddns_matches
    [ "$status" -eq 1 ]
}

# ============================================================
# test_socks_proxy.sh -- exists, executable, shellcheck
# ============================================================

@test "test_socks_proxy.sh exists" {
    [ -f "$PROJECT_ROOT/tests/acceptance/test_socks_proxy.sh" ]
}

@test "test_socks_proxy.sh is executable" {
    [ -x "$PROJECT_ROOT/tests/acceptance/test_socks_proxy.sh" ]
}

@test "test_socks_proxy.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/tests/acceptance/test_socks_proxy.sh"
}
