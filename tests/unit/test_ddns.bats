#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Mock curl to return a fake public IP
    export CURL_CMD="$TEST_TMP/mock-curl"
    cat > "$CURL_CMD" <<'MOCK'
#!/usr/bin/env bash
echo "203.0.113.42"
MOCK
    chmod +x "$CURL_CMD"

    # Mock IP cache file location
    export IP_CACHE_FILE="$TEST_TMP/last_ip.txt"
    export DDNS_LOG_FILE="$TEST_TMP/ddns.log"

    # Mock DDNS API call (just echo, don't actually call Namecheap)
    export DDNS_CURL_CMD="$TEST_TMP/mock-ddns-curl"
    cat > "$DDNS_CURL_CMD" <<'MOCK'
#!/usr/bin/env bash
echo "<interface-response><ErrCount>0</ErrCount></interface-response>"
MOCK
    chmod +x "$DDNS_CURL_CMD"

    # Source inventory for domain
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    export NAMECHEAP_DDNS_PASSWORD="test-password"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Scripts exist ----

@test "update-namecheap.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/ddns/update-namecheap.sh" ]
}

@test "update-namecheap.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/ddns/update-namecheap.sh" ]
}

@test "update-namecheap.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/ddns/update-namecheap.sh"
}

# ---- IP detection ----

@test "get_public_ip returns an IP address" {
    source "$PROJECT_ROOT/scripts/ddns/update-namecheap.sh"
    run get_public_ip
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# ---- IP change detection ----

@test "ip_has_changed returns 0 (true) when no cache exists" {
    source "$PROJECT_ROOT/scripts/ddns/update-namecheap.sh"
    ip_has_changed "203.0.113.42"
}

@test "ip_has_changed returns 1 (false) when IP matches cache" {
    echo "203.0.113.42" > "$IP_CACHE_FILE"
    source "$PROJECT_ROOT/scripts/ddns/update-namecheap.sh"
    ! ip_has_changed "203.0.113.42"
}

@test "ip_has_changed returns 0 (true) when IP differs from cache" {
    echo "198.51.100.1" > "$IP_CACHE_FILE"
    source "$PROJECT_ROOT/scripts/ddns/update-namecheap.sh"
    ip_has_changed "203.0.113.42"
}

# ---- DDNS update ----

@test "update_ddns writes new IP to cache" {
    source "$PROJECT_ROOT/scripts/ddns/update-namecheap.sh"
    update_ddns "203.0.113.42"
    [ -f "$IP_CACHE_FILE" ]
    [ "$(cat "$IP_CACHE_FILE")" = "203.0.113.42" ]
}

@test "update_ddns logs the update" {
    source "$PROJECT_ROOT/scripts/ddns/update-namecheap.sh"
    update_ddns "203.0.113.42"
    [ -f "$DDNS_LOG_FILE" ]
    grep -q '203.0.113.42' "$DDNS_LOG_FILE"
}

# ---- Cron setup ----

@test "setup-ddns.sh exists" {
    [ -f "$PROJECT_ROOT/infrastructure/pi-scripts/bastion/setup-ddns.sh" ]
}

@test "setup-ddns.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/infrastructure/pi-scripts/bastion/setup-ddns.sh"
}

@test "generate_cron_entry produces 5-minute interval" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/bastion/setup-ddns.sh"
    run generate_cron_entry "/usr/local/bin/update-namecheap.sh"
    [[ "$output" == *"*/5"* ]]
}
