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

# ---- Host enumeration (Story 6.6) ----

@test "HOSTS array is defined with 4 entries" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    [ "${#HOSTS[@]}" -eq 4 ]
}

@test "HOSTS entries use hostname:ip:role format" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    for entry in "${HOSTS[@]}"; do
        [[ "$entry" =~ ^[a-z-]+:[0-9.]+:[a-z]+$ ]]
    done
}

@test "CONVERGE_ORDER is defined with 4 entries" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    [ "${#CONVERGE_ORDER[@]}" -eq 4 ]
}

@test "CONVERGE_ORDER first entry is bastion (primary first)" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    [ "${CONVERGE_ORDER[0]}" = "bastion" ]
}

@test "ROLE_COMMON contains harden.sh" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    [[ "$ROLE_COMMON" == *"harden.sh"* ]]
}

@test "ROLE_BASTION contains setup-bastion.sh" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    [[ "$ROLE_BASTION" == *"setup-bastion.sh"* ]]
}

@test "ROLE_DNS contains setup-coredns.sh" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    [[ "$ROLE_DNS" == *"setup-coredns.sh"* ]]
}

@test "pi_ip returns correct IP for bastion" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    result="$(pi_ip "bastion")"
    [ "$result" = "192.168.1.10" ]
}

@test "pi_ip returns correct IP for dns" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    result="$(pi_ip "dns")"
    [ "$result" = "192.168.1.11" ]
}

@test "pi_ip returns correct IP for bastion-backup" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    result="$(pi_ip "bastion-backup")"
    [ "$result" = "192.168.1.12" ]
}

@test "pi_ip fails for unknown hostname" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    run pi_ip "nonexistent"
    [ "$status" -ne 0 ]
}

@test "pi_role returns bastion for bastion host" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    result="$(pi_role "bastion")"
    [ "$result" = "bastion" ]
}

@test "pi_role returns dns for dns host" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    result="$(pi_role "dns")"
    [ "$result" = "dns" ]
}

@test "pis_with_role bastion returns bastion and bastion-backup" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    result="$(pis_with_role "bastion")"
    [[ "$result" == *"bastion"* ]]
    [[ "$result" == *"bastion-backup"* ]]
}

@test "pis_with_role dns returns dns and dns-backup" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    result="$(pis_with_role "dns")"
    [[ "$result" == *"dns"* ]]
    [[ "$result" == *"dns-backup"* ]]
}

@test "existing flat variables still work after enumeration additions" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
    [ "$PI1_IP" = "192.168.1.10" ]
    [ "$PI2_IP" = "192.168.1.11" ]
    [ "$DOMAIN" = "mindlikewater.net" ]
    [ "$DEPLOY_USER" = "deploy" ]
}
