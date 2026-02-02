#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

# ---- Variable existence tests ----

@test "DOMAIN is defined and non-empty" {
    [ -n "$DOMAIN" ]
}

@test "ROUTER_IP is defined and non-empty" {
    [ -n "$ROUTER_IP" ]
}

@test "PI1_IP is defined and non-empty" {
    [ -n "$PI1_IP" ]
}

@test "PI1_HOSTNAME is defined and non-empty" {
    [ -n "$PI1_HOSTNAME" ]
}

@test "PI1_ROLE is defined and non-empty" {
    [ -n "$PI1_ROLE" ]
}

@test "PI2_IP is defined and non-empty" {
    [ -n "$PI2_IP" ]
}

@test "PI2_HOSTNAME is defined and non-empty" {
    [ -n "$PI2_HOSTNAME" ]
}

@test "PI2_ROLE is defined and non-empty" {
    [ -n "$PI2_ROLE" ]
}

@test "PI3_IP is defined and non-empty" {
    [ -n "$PI3_IP" ]
}

@test "PI3_ROLE is defined and non-empty" {
    [ -n "$PI3_ROLE" ]
}

@test "PI4_IP is defined and non-empty" {
    [ -n "$PI4_IP" ]
}

@test "PI4_ROLE is defined and non-empty" {
    [ -n "$PI4_ROLE" ]
}

@test "POWEREDGE_IP is defined and non-empty" {
    [ -n "$POWEREDGE_IP" ]
}

@test "DNS_UPSTREAM_1 is defined and non-empty" {
    [ -n "$DNS_UPSTREAM_1" ]
}

@test "DNS_UPSTREAM_2 is defined and non-empty" {
    [ -n "$DNS_UPSTREAM_2" ]
}

@test "DEPLOY_USER is defined and non-empty" {
    [ -n "$DEPLOY_USER" ]
}

# ---- Value correctness tests ----

@test "DOMAIN is mindlikewater.net" {
    [ "$DOMAIN" = "mindlikewater.net" ]
}

@test "ROUTER_IP is 192.168.1.1" {
    [ "$ROUTER_IP" = "192.168.1.1" ]
}

@test "PI1_IP is 192.168.1.10" {
    [ "$PI1_IP" = "192.168.1.10" ]
}

@test "PI2_IP is 192.168.1.11" {
    [ "$PI2_IP" = "192.168.1.11" ]
}

@test "PI3_IP is 192.168.1.12" {
    [ "$PI3_IP" = "192.168.1.12" ]
}

@test "PI4_IP is 192.168.1.13" {
    [ "$PI4_IP" = "192.168.1.13" ]
}

@test "POWEREDGE_IP is 192.168.1.200" {
    [ "$POWEREDGE_IP" = "192.168.1.200" ]
}

@test "PI1_ROLE is bastion" {
    [ "$PI1_ROLE" = "bastion" ]
}

@test "PI2_ROLE is dns" {
    [ "$PI2_ROLE" = "dns" ]
}

@test "DEPLOY_USER is deploy" {
    [ "$DEPLOY_USER" = "deploy" ]
}

# ---- IP format validation ----

@test "all PI IPs match IPv4 format" {
    for ip in "$PI1_IP" "$PI2_IP" "$PI3_IP" "$PI4_IP" "$ROUTER_IP" "$POWEREDGE_IP"; do
        [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
    done
}

@test "DNS upstream IPs match IPv4 format" {
    [[ "$DNS_UPSTREAM_1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
    [[ "$DNS_UPSTREAM_2" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}
