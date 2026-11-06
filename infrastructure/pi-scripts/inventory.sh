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

# --- DHCP pool on the Archer AXE95 (set 2026-11-05) ---
# Addresses outside the pool (.201-.254) are never leased, so a static
# assignment there cannot collide with a lease. Inside the pool, a fixed
# address is safe only as a router reservation.
export DHCP_POOL_START="192.168.1.2"
export DHCP_POOL_END="192.168.1.200"

# --- DHCP reservations this repository declares (name|mac|ip) ---
# Applied on the router by scripts/ops/configure-dhcp-reservations.sh.
# A device bridged over Wi-Fi cannot be reserved: the router sees its frames
# under the host's Wi-Fi MAC (MAC NAT), shared with the host.
# gmktec-xubuntu: K3s agent node of the livespec CI fleet; its kubelet pins
# --node-ip to this address on eno1. Already reserved on the router (recorded
# 2026-11-06 from the maintainer; the MAC read from the host's eno1).
DHCP_RESERVATIONS=(
    "gmktec-xubuntu|84:47:09:68:b1:79|192.168.1.156"
)

# --- Static addresses set on the device itself (name|ip), outside the pool ---
# macbook-m4-max-homelab-worker: the Lima VM on the MacBook M4 Max that runs a
# homelab K3s worker (livespec-dev-tooling plan homelab-k8s-worker-nodes). It
# is bridged over the Mac's Wi-Fi, so the router lists it under the Mac's MAC
# 86-CB-DA-37-03-91 and cannot reserve it; the VM sets this address itself.
STATIC_ADDRESSES=(
    "macbook-m4-max-homelab-worker|192.168.1.201"
)

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
