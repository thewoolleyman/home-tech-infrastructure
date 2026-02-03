#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    SCRIPT="$PROJECT_ROOT/scripts/deploy/prep-pi-image.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "prep-pi-image.sh exists" {
    [ -f "$SCRIPT" ]
}

@test "prep-pi-image.sh is executable" {
    [ -x "$SCRIPT" ]
}

@test "prep-pi-image.sh passes shellcheck" {
    shellcheck "$SCRIPT"
}

# ---- Shell conventions ----

@test "prep-pi-image.sh uses set -euo pipefail" {
    grep -q 'set -euo pipefail' "$SCRIPT"
}

@test "prep-pi-image.sh has main guard" {
    grep -q 'BASH_SOURCE\[0\]' "$SCRIPT"
}

# ---- Argument validation ----

@test "fails with error when no ROLE argument given" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}

@test "error message for missing ROLE mentions usage" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"ROLE"* ]]
}

@test "fails with error for invalid ROLE" {
    run "$SCRIPT" "invalid"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}

@test "error message for invalid ROLE lists valid roles" {
    run "$SCRIPT" "invalid"
    [ "$status" -ne 0 ]
    [[ "$output" == *"bastion"* ]]
    [[ "$output" == *"dns"* ]]
    [[ "$output" == *"bastion-backup"* ]]
    [[ "$output" == *"dns-backup"* ]]
}

# ---- Role resolution ----

@test "ROLE=bastion resolves to hostname bastion and IP 192.168.1.10" {
    source "$SCRIPT"
    resolve_role "bastion"
    [ "$RESOLVED_HOSTNAME" = "bastion" ]
    [ "$RESOLVED_IP" = "192.168.1.10" ]
}

@test "ROLE=dns resolves to hostname dns and IP 192.168.1.11" {
    source "$SCRIPT"
    resolve_role "dns"
    [ "$RESOLVED_HOSTNAME" = "dns" ]
    [ "$RESOLVED_IP" = "192.168.1.11" ]
}

@test "ROLE=bastion-backup resolves to hostname bastion-backup and IP 192.168.1.12" {
    source "$SCRIPT"
    resolve_role "bastion-backup"
    [ "$RESOLVED_HOSTNAME" = "bastion-backup" ]
    [ "$RESOLVED_IP" = "192.168.1.12" ]
}

@test "ROLE=dns-backup resolves to hostname dns-backup and IP 192.168.1.13" {
    source "$SCRIPT"
    resolve_role "dns-backup"
    [ "$RESOLVED_HOSTNAME" = "dns-backup" ]
    [ "$RESOLVED_IP" = "192.168.1.13" ]
}

# ---- Checklist output ----

@test "output contains the resolved hostname for bastion" {
    run "$SCRIPT" "bastion"
    [ "$status" -eq 0 ]
    [[ "$output" == *"bastion"* ]]
}

@test "output contains the resolved IP for bastion" {
    run "$SCRIPT" "bastion"
    [ "$status" -eq 0 ]
    [[ "$output" == *"192.168.1.10"* ]]
}

@test "output contains DEPLOY_USER value" {
    run "$SCRIPT" "bastion"
    [ "$status" -eq 0 ]
    [[ "$output" == *"deploy"* ]]
}

@test "output contains numbered checklist steps" {
    run "$SCRIPT" "bastion"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1."* ]]
    [[ "$output" == *"2."* ]]
    [[ "$output" == *"3."* ]]
    [[ "$output" == *"4."* ]]
    [[ "$output" == *"5."* ]]
    [[ "$output" == *"6."* ]]
    [[ "$output" == *"7."* ]]
}

@test "checklist mentions RPi OS Lite 64-bit" {
    run "$SCRIPT" "bastion"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RPi OS Lite 64-bit"* ]] || [[ "$output" == *"Raspberry Pi OS Lite 64-bit"* ]]
}

@test "checklist mentions SSH" {
    run "$SCRIPT" "bastion"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SSH"* ]]
}

@test "checklist mentions WiFi" {
    run "$SCRIPT" "bastion"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WiFi"* ]] || [[ "$output" == *"Wi-Fi"* ]]
}

@test "checklist mentions static IP" {
    run "$SCRIPT" "bastion"
    [ "$status" -eq 0 ]
    [[ "$output" == *"static IP"* ]] || [[ "$output" == *"Static IP"* ]]
}

@test "output for dns role contains correct hostname and IP" {
    run "$SCRIPT" "dns"
    [ "$status" -eq 0 ]
    [[ "$output" == *"dns"* ]]
    [[ "$output" == *"192.168.1.11"* ]]
}
