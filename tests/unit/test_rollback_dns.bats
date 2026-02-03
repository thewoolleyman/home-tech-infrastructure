#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    mkdir -p "$TEST_TMP/bin"

    # Mock dig - succeeds by default
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/dig_calls.log"
echo "93.184.216.34"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    # Mock open - records calls
    cat > "$TEST_TMP/bin/open" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/open_calls.log"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/open"

    # Mock curl - succeeds by default
    cat > "$TEST_TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/curl_calls.log"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/curl"

    export DIG="$TEST_TMP/bin/dig"
    export OPEN="$TEST_TMP/bin/open"
    export CURL="$TEST_TMP/bin/curl"

    # Source inventory for host/DNS definitions
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists and is well-formed ----

@test "rollback-dns.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/ops/rollback-dns.sh" ]
}

@test "rollback-dns.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/ops/rollback-dns.sh" ]
}

@test "rollback-dns.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
}

# ---- display_manual_rollback_steps ----

@test "display_manual_rollback_steps output contains router IP" {
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    run display_manual_rollback_steps
    [[ "$output" == *"192.168.1.1"* ]]
}

@test "display_manual_rollback_steps output contains Pi2 IP" {
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    run display_manual_rollback_steps
    [[ "$output" == *"192.168.1.11"* ]]
}

@test "display_manual_rollback_steps output contains upstream DNS 1.1.1.1" {
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    run display_manual_rollback_steps
    [[ "$output" == *"1.1.1.1"* ]]
}

@test "display_manual_rollback_steps output contains upstream DNS 9.9.9.9" {
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    run display_manual_rollback_steps
    [[ "$output" == *"9.9.9.9"* ]]
}

@test "display_manual_rollback_steps output contains numbered steps" {
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    run display_manual_rollback_steps
    [[ "$output" == *"1."* ]]
    [[ "$output" == *"2."* ]]
    [[ "$output" == *"3."* ]]
    [[ "$output" == *"4."* ]]
}

# ---- verify_dns_rollback ----

@test "verify_dns_rollback returns 0 when dig succeeds against both upstreams" {
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    run verify_dns_rollback
    [ "$status" -eq 0 ]
}

@test "verify_dns_rollback queries upstream DNS 1.1.1.1" {
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    verify_dns_rollback
    grep -q '@1.1.1.1' "$TEST_TMP/dig_calls.log"
}

@test "verify_dns_rollback queries upstream DNS 9.9.9.9" {
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    verify_dns_rollback
    grep -q '@9.9.9.9' "$TEST_TMP/dig_calls.log"
}

@test "verify_dns_rollback returns 1 when dig fails against first upstream" {
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
for arg in "$@"; do
    if [ "$arg" = "@1.1.1.1" ]; then
        exit 1
    fi
done
echo "93.184.216.34"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    run verify_dns_rollback
    [ "$status" -eq 1 ]
}

@test "verify_dns_rollback returns 1 when dig fails against second upstream" {
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
for arg in "$@"; do
    if [ "$arg" = "@9.9.9.9" ]; then
        exit 1
    fi
done
echo "93.184.216.34"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    run verify_dns_rollback
    [ "$status" -eq 1 ]
}

# ---- open_router_admin ----

@test "open_router_admin calls open with router URL" {
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    open_router_admin
    grep -q "http://192.168.1.1" "$TEST_TMP/open_calls.log"
}

@test "open_router_admin returns 0" {
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    run open_router_admin
    [ "$status" -eq 0 ]
}

# ---- rollback_dns ----

@test "rollback_dns output contains manual rollback steps" {
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    run rollback_dns
    [[ "$output" == *"192.168.1.1"* ]]
    [[ "$output" == *"1."* ]]
}

@test "rollback_dns calls verify after displaying steps" {
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    run rollback_dns
    [[ "$output" == *"Verifying"* ]]
}

@test "rollback_dns reports success when verification passes" {
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    run rollback_dns
    [ "$status" -eq 0 ]
    [[ "$output" == *"DNS rollback verified"* ]]
}

@test "rollback_dns reports failure when verification fails" {
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    run rollback_dns
    [ "$status" -eq 1 ]
    [[ "$output" == *"DNS rollback verification failed"* ]]
}

@test "rollback_dns opens router admin when AUTO_OPEN=1" {
    export AUTO_OPEN=1
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    rollback_dns
    [ -f "$TEST_TMP/open_calls.log" ]
    grep -q "http://192.168.1.1" "$TEST_TMP/open_calls.log"
}

@test "rollback_dns does not open router admin by default" {
    unset AUTO_OPEN 2>/dev/null || true
    source "$PROJECT_ROOT/scripts/ops/rollback-dns.sh"
    rollback_dns
    [ ! -f "$TEST_TMP/open_calls.log" ]
}
