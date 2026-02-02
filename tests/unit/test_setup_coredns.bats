#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Override paths
    export COREDNS_DIR="$TEST_TMP/coredns"
    export COREDNS_COREFILE="$TEST_TMP/coredns/Corefile"
    export COREDNS_HOSTS="$TEST_TMP/coredns/hosts"
    export SYSTEMCTL_CMD="echo"

    # Source inventory
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "setup-coredns.sh exists" {
    [ -f "$PROJECT_ROOT/infrastructure/pi-scripts/dns/setup-coredns.sh" ]
}

@test "setup-coredns.sh is executable" {
    [ -x "$PROJECT_ROOT/infrastructure/pi-scripts/dns/setup-coredns.sh" ]
}

@test "setup-coredns.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/infrastructure/pi-scripts/dns/setup-coredns.sh"
}

# ---- Corefile generation ----

@test "generate_corefile creates Corefile" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/setup-coredns.sh"
    generate_corefile
    [ -f "$COREDNS_COREFILE" ]
}

@test "Corefile contains mindlikewater.net zone" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/setup-coredns.sh"
    generate_corefile
    grep -q "mindlikewater.net" "$COREDNS_COREFILE"
}

@test "Corefile uses hosts plugin with fallthrough" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/setup-coredns.sh"
    generate_corefile
    grep -q 'hosts' "$COREDNS_COREFILE"
    grep -q 'fallthrough' "$COREDNS_COREFILE"
}

@test "Corefile contains forward block with upstream DNS" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/setup-coredns.sh"
    generate_corefile
    grep -q 'forward' "$COREDNS_COREFILE"
    grep -q "$DNS_UPSTREAM_1" "$COREDNS_COREFILE"
    grep -q "$DNS_UPSTREAM_2" "$COREDNS_COREFILE"
}

@test "Corefile contains cache directive" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/setup-coredns.sh"
    generate_corefile
    grep -q 'cache' "$COREDNS_COREFILE"
}

# ---- Systemd unit generation ----

@test "generate_systemd_unit creates unit file" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/setup-coredns.sh"
    local unit_file="$TEST_TMP/coredns.service"
    generate_systemd_unit "$unit_file"
    [ -f "$unit_file" ]
    grep -q '\[Service\]' "$unit_file"
    grep -q 'ExecStart' "$unit_file"
}

# ---- Idempotency ----

@test "generate_corefile is idempotent" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/setup-coredns.sh"
    generate_corefile
    cp "$COREDNS_COREFILE" "$TEST_TMP/first"
    generate_corefile
    diff "$TEST_TMP/first" "$COREDNS_COREFILE"
}
