#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP
    mkdir -p "$TEST_TMP/bin"

    cat > "$TEST_TMP/bin/ping" <<'MOCK'
#!/usr/bin/env bash
exit "${PING_EXIT:-0}"
MOCK
    cat > "$TEST_TMP/bin/arp" <<'MOCK'
#!/usr/bin/env bash
echo "? (192.168.1.201) at ${ARP_MAC:-52:55:55:ba:a1:61} on en0 ifscope [ethernet]"
MOCK
    chmod +x "$TEST_TMP/bin/ping" "$TEST_TMP/bin/arp"
    export PING="$TEST_TMP/bin/ping"
    export ARP="$TEST_TMP/bin/arp"
}

teardown() {
    rm -rf "$TEST_TMP"
}

@test "configure-dhcp-reservations.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/ops/configure-dhcp-reservations.sh"
}

@test "the inventory declares the homelab worker reservation" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    [[ " ${DHCP_RESERVATIONS[*]} " == *"macbook-m4-max-homelab-worker|52:55:55:ba:a1:61|192.168.1.201"* ]]
}

@test "with no argument it prints the router steps for each reservation" {
    run "$PROJECT_ROOT/scripts/ops/configure-dhcp-reservations.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Address Reservation"* ]]
    [[ "$output" == *"macbook-m4-max-homelab-worker: MAC 52-55-55-BA-A1-61 -> 192.168.1.201"* ]]
}

@test "verify passes when the reserved address answers from its MAC" {
    run "$PROJECT_ROOT/scripts/ops/configure-dhcp-reservations.sh" verify
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK: macbook-m4-max-homelab-worker"* ]]
}

@test "verify fails when the reserved address does not answer" {
    PING_EXIT=1 run "$PROJECT_ROOT/scripts/ops/configure-dhcp-reservations.sh" verify
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not answer"* ]]
}

@test "verify fails when another MAC holds the reserved address" {
    ARP_MAC="aa:bb:cc:dd:ee:ff" run "$PROJECT_ROOT/scripts/ops/configure-dhcp-reservations.sh" verify
    [ "$status" -eq 1 ]
    [[ "$output" == *"not 52:55:55:ba:a1:61"* ]]
}

@test "normalize_mac matches macOS arp's short octets" {
    source "$PROJECT_ROOT/scripts/ops/configure-dhcp-reservations.sh"
    [ "$(normalize_mac 0A-0b-00-01-FF-10)" = "a:b:0:1:ff:10" ]
}

@test "an unknown argument is refused" {
    run "$PROJECT_ROOT/scripts/ops/configure-dhcp-reservations.sh" apply
    [ "$status" -eq 2 ]
}
