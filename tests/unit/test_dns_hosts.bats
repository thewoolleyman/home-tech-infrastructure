#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Override output path
    export COREDNS_HOSTS="$TEST_TMP/hosts"

    # Source inventory for expected values
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "generate-hosts.sh exists" {
    [ -f "$PROJECT_ROOT/infrastructure/pi-scripts/dns/generate-hosts.sh" ]
}

@test "generate-hosts.sh is executable" {
    [ -x "$PROJECT_ROOT/infrastructure/pi-scripts/dns/generate-hosts.sh" ]
}

@test "generate-hosts.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/infrastructure/pi-scripts/dns/generate-hosts.sh"
}

# ---- Hosts file generation ----

@test "generate_hosts_file creates the hosts file" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/generate-hosts.sh"
    generate_hosts_file
    [ -f "$COREDNS_HOSTS" ]
}

@test "hosts file contains bastion with correct IP" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/generate-hosts.sh"
    generate_hosts_file
    grep -q "${PI1_IP}.*bastion\.${DOMAIN}" "$COREDNS_HOSTS"
}

@test "hosts file contains dns with correct IP" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/generate-hosts.sh"
    generate_hosts_file
    grep -q "${PI2_IP}.*dns\.${DOMAIN}" "$COREDNS_HOSTS"
}

@test "hosts file contains bastion-backup with correct IP" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/generate-hosts.sh"
    generate_hosts_file
    grep -q "${PI3_IP}.*bastion-backup\.${DOMAIN}" "$COREDNS_HOSTS"
}

@test "hosts file contains dns-backup with correct IP" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/generate-hosts.sh"
    generate_hosts_file
    grep -q "${PI4_IP}.*dns-backup\.${DOMAIN}" "$COREDNS_HOSTS"
}

@test "hosts file contains router" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/generate-hosts.sh"
    generate_hosts_file
    grep -q "${ROUTER_IP}.*router\.${DOMAIN}" "$COREDNS_HOSTS"
}

@test "hosts file contains poweredge" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/generate-hosts.sh"
    generate_hosts_file
    grep -q "${POWEREDGE_IP}.*server\.${DOMAIN}" "$COREDNS_HOSTS" || \
    grep -q "${POWEREDGE_IP}.*poweredge\.${DOMAIN}" "$COREDNS_HOSTS"
}

@test "hosts file uses tab-separated format" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/generate-hosts.sh"
    generate_hosts_file
    # Every non-comment, non-empty line should be IP<tab>FQDN
    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[[:space:]] ]]
    done < "$COREDNS_HOSTS"
}

# ---- Idempotency ----

@test "generate_hosts_file is idempotent" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/dns/generate-hosts.sh"
    generate_hosts_file
    cp "$COREDNS_HOSTS" "$TEST_TMP/first"
    generate_hosts_file
    diff "$TEST_TMP/first" "$COREDNS_HOSTS"
}
