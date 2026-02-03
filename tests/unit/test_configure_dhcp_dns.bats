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

    # Mock curl - succeeds by default
    cat > "$TEST_TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/curl_calls.log"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/curl"

    # Mock dig - returns expected DNS by default
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/dig_calls.log"
echo "192.168.1.11"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    export PYTHON="$TEST_TMP/bin/python3"
    export CURL="$TEST_TMP/bin/curl"
    export DIG="$TEST_TMP/bin/dig"

    # Source inventory for host/DNS definitions
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists and is well-formed ----

@test "configure-dhcp-dns.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh" ]
}

@test "configure-dhcp-dns.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh" ]
}

@test "configure-dhcp-dns.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
}

# ---- check_python_client ----

@test "check_python_client returns 1 when Python client not available" {
    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run check_python_client
    [ "$status" -eq 1 ]
}

@test "check_python_client returns 0 when Python client is available" {
    cat > "$TEST_TMP/bin/python3" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/python3"

    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run check_python_client
    [ "$status" -eq 0 ]
}

# ---- configure_dhcp_dns_manual ----

@test "configure_dhcp_dns_manual output contains router IP" {
    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run configure_dhcp_dns_manual "$PI2_IP"
    [[ "$output" == *"192.168.1.1"* ]]
}

@test "configure_dhcp_dns_manual output contains PI2 IP (192.168.1.11)" {
    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run configure_dhcp_dns_manual "$PI2_IP"
    [[ "$output" == *"192.168.1.11"* ]]
}

@test "configure_dhcp_dns_manual output contains numbered steps" {
    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run configure_dhcp_dns_manual "$PI2_IP"
    [[ "$output" == *"1."* ]]
    [[ "$output" == *"2."* ]]
    [[ "$output" == *"3."* ]]
    [[ "$output" == *"4."* ]]
}

@test "configure_dhcp_dns_manual returns 0" {
    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run configure_dhcp_dns_manual "$PI2_IP"
    [ "$status" -eq 0 ]
}

# ---- verify_dhcp_dns ----

@test "verify_dhcp_dns returns 0 when DNS resolves correctly" {
    # Mock dig returns 192.168.1.11 which matches expected
    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run verify_dhcp_dns "192.168.1.11"
    [ "$status" -eq 0 ]
}

@test "verify_dhcp_dns returns 1 when DNS doesn't match" {
    # Mock dig to fail when querying against a non-matching DNS server
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/dig_calls.log"
# Succeed only for 192.168.1.11, fail for anything else
for arg in "$@"; do
    if [ "$arg" = "@10.0.0.1" ]; then
        exit 1
    fi
done
echo "192.168.1.11"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run verify_dhcp_dns "10.0.0.1"
    [ "$status" -eq 1 ]
}

@test "verify_dhcp_dns returns 1 when dig fails" {
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run verify_dhcp_dns "192.168.1.11"
    [ "$status" -eq 1 ]
}

# ---- configure_dhcp_dns (main function) ----

@test "configure_dhcp_dns falls back to manual when Python unavailable" {
    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run configure_dhcp_dns
    # Should contain manual steps since python client is mocked to fail
    [[ "$output" == *"Manual"* ]]
    [[ "$output" == *"192.168.1.1"* ]]
}

@test "configure_dhcp_dns attempts auto configuration first" {
    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run configure_dhcp_dns
    # Should mention attempting auto config
    [[ "$output" == *"auto"* ]] || [[ "$output" == *"Auto"* ]] || [[ "$output" == *"Python"* ]]
}

@test "configure_dhcp_dns runs verification" {
    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run configure_dhcp_dns
    [[ "$output" == *"Verif"* ]]
}

@test "configure_dhcp_dns returns 0 when verification passes" {
    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run configure_dhcp_dns
    [ "$status" -eq 0 ]
}

@test "configure_dhcp_dns returns 1 when verification fails" {
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-dns.sh"
    run configure_dhcp_dns
    [ "$status" -eq 1 ]
}
