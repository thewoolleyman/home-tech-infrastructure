#!/usr/bin/env bash
# infrastructure/pi-scripts/inventory.sh
# Single source of truth for all Pi and network configuration.
# Sourced by: setup scripts, deploy scripts, CoreDNS generator, tests.

# --- Network ---
export DOMAIN="mindlikewater.net"
export ROUTER_IP="192.168.1.1"

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
