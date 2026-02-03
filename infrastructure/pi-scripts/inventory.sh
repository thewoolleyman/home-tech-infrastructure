#!/usr/bin/env bash
# infrastructure/pi-scripts/inventory.sh
# Single source of truth for all Pi and network configuration.
# Sourced by: setup scripts, deploy scripts, CoreDNS generator, tests.

# --- Network ---
export DOMAIN="mindlikewater.net"
export ROUTER_IP="192.168.1.1"
export WIFI_SSID="FBI_SURVEILLANCE_VAN"
export WIFI_IFACE="wlan0"

# --- Modem (XB8 in bridge mode) ---
export MODEM_IP="10.0.0.1"
export MODEM_MODEL="Technicolor CGM4981COM"

# --- WiFi transition ---
# Current production SSID (Archer C2300, temporary)
export WIFI_SSID_CURRENT="TP-Link_8500"
# Target SSID (Archer AXE95, not yet deployed)
# WIFI_SSID above is the target

# --- Pis ---
export PI1_IP="192.168.1.10"
export PI1_HOSTNAME="bastion"
export PI1_ROLE="bastion"

export PI2_IP="192.168.1.11"
export PI2_HOSTNAME="dns"
export PI2_ROLE="dns"

export PI3_IP="192.168.1.12"
export PI3_HOSTNAME="bastion-backup"
export PI3_ROLE="bastion"

export PI4_IP="192.168.1.13"
export PI4_HOSTNAME="dns-backup"
export PI4_ROLE="dns"

# --- Server ---
export POWEREDGE_IP="192.168.1.200"

# --- DNS upstream ---
export DNS_UPSTREAM_1="1.1.1.1"
export DNS_UPSTREAM_2="9.9.9.9"

# --- Deploy user ---
export DEPLOY_USER="deploy"

# --- SSH external port ---
export SSH_EXTERNAL_PORT="4222"

# --- Host enumeration (structured) ---
HOSTS=(
    "bastion:192.168.1.10:bastion"
    "dns:192.168.1.11:dns"
    "bastion-backup:192.168.1.12:bastion"
    "dns-backup:192.168.1.13:dns"
)

# --- Convergence order (primaries first, then backups) ---
export CONVERGE_ORDER=("bastion" "dns" "bastion-backup" "dns-backup")

# --- Role-to-scripts mapping ---
export ROLE_COMMON="common/harden.sh common/unattended-upgrades.sh"
export ROLE_BASTION="bastion/setup-bastion.sh bastion/setup-ddns.sh"
export ROLE_DNS="dns/setup-coredns.sh"

# --- Helper functions ---

# Get IP for a hostname. Usage: pi_ip "bastion"
pi_ip() {
    local target_host="$1"
    local hostname ip role
    for entry in "${HOSTS[@]}"; do
        IFS=: read -r hostname ip role <<< "$entry"
        if [ "$hostname" = "$target_host" ]; then
            echo "$ip"
            return 0
        fi
    done
    return 1
}

# Get role for a hostname. Usage: pi_role "bastion"
pi_role() {
    local target_host="$1"
    local hostname ip role
    for entry in "${HOSTS[@]}"; do
        IFS=: read -r hostname ip role <<< "$entry"
        if [ "$hostname" = "$target_host" ]; then
            echo "$role"
            return 0
        fi
    done
    return 1
}

# List hostnames with a given role. Usage: pis_with_role "bastion"
pis_with_role() {
    local target_role="$1"
    local hostname ip role
    for entry in "${HOSTS[@]}"; do
        IFS=: read -r hostname ip role <<< "$entry"
        if [ "$role" = "$target_role" ]; then
            echo "$hostname"
        fi
    done
}
