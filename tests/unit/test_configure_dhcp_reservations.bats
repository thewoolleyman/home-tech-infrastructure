#!/usr/bin/env bats

SCRIPT="scripts/ops/configure-dhcp-reservations.sh"

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP
    mkdir -p "$TEST_TMP/bin"

    # A test inventory, so behaviour tests never depend on the real network's
    # values. The arp mock answers with whatever MAC the test sets.
    TEST_POOL_END=150
    TEST_STATIC_HOST=220
    TEST_RESERVED_HOST=30
    TEST_MAC="0a:00:00:00:00:01"
    cat > "$TEST_TMP/inventory.sh" <<INV
export ROUTER_IP="10.99.0.1"
export DHCP_POOL_START="10.99.0.2"
export DHCP_POOL_END="10.99.0.${TEST_POOL_END}"
DHCP_RESERVATIONS=("test-reserved|${TEST_MAC}|10.99.0.${TEST_RESERVED_HOST}")
STATIC_ADDRESSES=("test-static|10.99.0.${TEST_STATIC_HOST}")
INV
    export INVENTORY="$TEST_TMP/inventory.sh"

    cat > "$TEST_TMP/bin/ping" <<'MOCK'
#!/usr/bin/env bash
exit "${PING_EXIT:-0}"
MOCK
    cat > "$TEST_TMP/bin/arp" <<'MOCK'
#!/usr/bin/env bash
echo "? ($2) at ${ARP_MAC} on en0 ifscope [ethernet]"
MOCK
    chmod +x "$TEST_TMP/bin/ping" "$TEST_TMP/bin/arp"
    export PING="$TEST_TMP/bin/ping" ARP="$TEST_TMP/bin/arp" ARP_MAC="$TEST_MAC"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- invariants of the real inventory (hold for any values) ----

@test "the real inventory's DHCP pool bounds are ordered addresses" {
    unset INVENTORY
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    [ "${DHCP_POOL_START##*.}" -le "${DHCP_POOL_END##*.}" ]
}

@test "every static address in the real inventory lies outside its DHCP pool" {
    unset INVENTORY
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    local entry name ip
    for entry in "${STATIC_ADDRESSES[@]}"; do
        IFS='|' read -r name ip <<< "$entry"
        [ "${ip##*.}" -lt "${DHCP_POOL_START##*.}" ] || [ "${ip##*.}" -gt "${DHCP_POOL_END##*.}" ]
    done
}

# ---- behaviour, against the test inventory ----

@test "$SCRIPT passes shellcheck" {
    shellcheck "$PROJECT_ROOT/$SCRIPT"
}

@test "with no argument it prints each declared reservation in router form" {
    run "$PROJECT_ROOT/$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test-reserved: MAC $(tr 'a-f:' 'A-F-' <<< "$TEST_MAC") -> 10.99.0.${TEST_RESERVED_HOST}"* ]]
}

@test "with no reservations declared it says so" {
    sed -i.bak 's/^DHCP_RESERVATIONS=.*/DHCP_RESERVATIONS=()/' "$INVENTORY"
    run "$PROJECT_ROOT/$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"(none declared)"* ]]
}

@test "verify passes when reservations answer from their MAC and statics answer outside the pool" {
    run "$PROJECT_ROOT/$SCRIPT" verify
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK: test-reserved"* ]]
    [[ "$output" == *"OK: test-static"* ]]
}

@test "verify fails when an address does not answer" {
    PING_EXIT=1 run "$PROJECT_ROOT/$SCRIPT" verify
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not answer"* ]]
}

@test "verify fails when another MAC holds a reserved address" {
    ARP_MAC="0a:00:00:00:00:02" run "$PROJECT_ROOT/$SCRIPT" verify
    [ "$status" -eq 1 ]
    [[ "$output" == *"test-reserved"*"not ${TEST_MAC}"* ]]
}

@test "verify fails for a static address inside the pool" {
    sed -i.bak "s/test-static|10.99.0.${TEST_STATIC_HOST}/test-static|10.99.0.$((TEST_POOL_END - 1))/" "$INVENTORY"
    run "$PROJECT_ROOT/$SCRIPT" verify
    [ "$status" -eq 1 ]
    [[ "$output" == *"inside the DHCP pool"* ]]
}

@test "normalize_mac matches macOS arp's short octets" {
    source "$PROJECT_ROOT/$SCRIPT"
    [ "$(normalize_mac 0A-0b-00-01-FF-10)" = "a:b:0:1:ff:10" ]
}

@test "an unknown argument is refused" {
    run "$PROJECT_ROOT/$SCRIPT" apply
    [ "$status" -eq 2 ]
}
