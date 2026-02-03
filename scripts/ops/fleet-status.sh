#!/usr/bin/env bash
set -euo pipefail

# scripts/ops/fleet-status.sh
# Fleet status overview: checks reachability, SSH, and DNS for all Pis and network devices.
# Sourced by tests (for function access) or run directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"

# Overridable commands for testability
PING="${PING:-ping}"
SSH="${SSH:-ssh}"
DIG="${DIG:-dig}"
NC="${NC:-nc}"

# Check if a host is reachable via ping.
# Usage: check_host_reachable <ip>
# Returns: 0 if reachable, 1 if not
check_host_reachable() {
    local ip="$1"
    if $PING -c 1 -W 2 "$ip" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Check if SSH port (22) is open on a host.
# Usage: check_ssh_port <ip>
# Returns: 0 if open, 1 if not
check_ssh_port() {
    local ip="$1"
    if $NC -z -w 2 "$ip" 22 >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Check internal DNS resolution via Pi2 (dns).
# Resolves bastion.mindlikewater.net and verifies it returns the expected IP.
# Returns: 0 if resolves correctly, 1 if not
check_dns_internal() {
    local result
    result="$($DIG +short "bastion.$DOMAIN" "@$PI2_IP" 2>/dev/null)" || true
    if [ -n "$result" ]; then
        return 0
    fi
    return 1
}

# Check external DNS forwarding via Pi2 (dns).
# Resolves google.com to verify upstream forwarding works.
# Returns: 0 if resolves, 1 if not
check_dns_external() {
    local result
    result="$($DIG +short "google.com" "@$PI2_IP" 2>/dev/null)" || true
    if [ -n "$result" ]; then
        return 0
    fi
    return 1
}

# Check if a network device (router/modem) is reachable.
# Usage: check_device_reachable <ip> <name>
# Returns: 0 if reachable, 1 if not
check_device_reachable() {
    local ip="$1"
    # name parameter kept for call-site readability
    local _name="$2"
    check_host_reachable "$ip"
}

# Print the fleet status table.
# Iterates all Pis, network devices, and DNS checks.
# Returns: 0 if all healthy, 1 if any failures
print_status_table() {
    local failures=0
    local healthy_count=0
    local total_hosts=0
    local network_ok="yes"
    local dns_ok="yes"

    printf "\n=== Fleet Status ===\n"
    printf "%-18s%-18s%-12s%-7s%s\n" "HOSTNAME" "ROLE" "REACHABLE" "SSH" "SERVICES"

    local hostname ip role
    for entry in "${HOSTS[@]}"; do
        IFS=: read -r hostname ip role <<< "$entry"
        total_hosts=$((total_hosts + 1))

        local reachable="yes"
        local ssh_status="yes"
        local services="ok"

        if ! check_host_reachable "$ip"; then
            reachable="UNREACHABLE"
            ssh_status="-"
            services="-"
            failures=$((failures + 1))
        else
            if ! check_ssh_port "$ip"; then
                ssh_status="no"
                failures=$((failures + 1))
            fi
            healthy_count=$((healthy_count + 1))
        fi

        printf "%-18s%-18s%-12s%-7s%s\n" "$hostname" "$role" "$reachable" "$ssh_status" "$services"
    done

    printf "\n=== Network Devices ===\n"
    printf "%-18s%-18s%s\n" "DEVICE" "IP" "REACHABLE"

    local router_reachable="yes"
    if ! check_device_reachable "$ROUTER_IP" "Router"; then
        router_reachable="UNREACHABLE"
        network_ok="no"
        failures=$((failures + 1))
    fi
    printf "%-18s%-18s%s\n" "Router" "$ROUTER_IP" "$router_reachable"

    local modem_reachable="yes"
    if ! check_device_reachable "$MODEM_IP" "Modem"; then
        modem_reachable="UNREACHABLE"
        network_ok="no"
        failures=$((failures + 1))
    fi
    printf "%-18s%-18s%s\n" "Modem" "$MODEM_IP" "$modem_reachable"

    printf "\n=== DNS ===\n"

    local internal_dns="ok"
    if ! check_dns_internal; then
        internal_dns="FAIL"
        dns_ok="no"
        failures=$((failures + 1))
    fi
    printf "Internal resolution: %s\n" "$internal_dns"

    local external_dns="ok"
    if ! check_dns_external; then
        external_dns="FAIL"
        dns_ok="no"
        failures=$((failures + 1))
    fi
    printf "External forwarding: %s\n" "$external_dns"

    printf "\n"
    if [ "$failures" -eq 0 ]; then
        printf "%d hosts healthy. Network ok. DNS ok.\n" "$healthy_count"
        return 0
    else
        local net_msg="ok"
        local dns_msg="ok"
        [ "$network_ok" = "no" ] && net_msg="DEGRADED"
        [ "$dns_ok" = "no" ] && dns_msg="DEGRADED"
        printf "%d/%d hosts healthy. Network %s. DNS %s.\n" "$healthy_count" "$total_hosts" "$net_msg" "$dns_msg"
        return 1
    fi
}

# --- Main (only runs when executed directly, not when sourced) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    print_status_table
fi
