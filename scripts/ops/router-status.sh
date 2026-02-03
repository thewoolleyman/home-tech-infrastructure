#!/usr/bin/env bash
set -euo pipefail

# scripts/ops/router-status.sh
# Router status reader: pings router, reads basic status via curl.
# Overridable commands for testing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${INVENTORY:-$(cd "$SCRIPT_DIR/../.." && pwd)/infrastructure/pi-scripts/inventory.sh}"

# shellcheck disable=SC1090,SC1091
source "$INVENTORY"

CURL="${CURL:-curl}"
PING="${PING:-ping}"

# Check if router is reachable via ping.
# Returns 0 if reachable, 1 if not.
check_router_reachable() {
    if $PING -c 1 -W 2 "$ROUTER_IP" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Read router status and output key-value pairs.
# Attempts to detect model from web admin page via curl.
# Returns 0 on success, 1 if unreachable.
get_router_status() {
    local reachable="no"
    local model="unknown"
    local wan_status="unknown"

    if check_router_reachable; then
        reachable="yes"
    else
        echo "Router IP: $ROUTER_IP"
        echo "Reachable: no"
        echo "Expected SSID: $WIFI_SSID"
        return 1
    fi

    # Attempt to read model and WAN status from router web admin
    local page
    page="$($CURL -s -m 5 "http://${ROUTER_IP}/" 2>/dev/null)" || true

    if [ -n "$page" ]; then
        # Try to extract model from title or body
        local detected
        detected="$(echo "$page" | grep -oiE 'Archer [A-Z0-9]+' | head -1)" || true
        if [ -n "$detected" ]; then
            model="$detected"
        fi

        # Try to detect WAN status
        if echo "$page" | grep -qi 'WAN.*Connected\|Connected.*WAN'; then
            wan_status="Connected"
        fi
    fi

    echo "Router IP: $ROUTER_IP"
    echo "Reachable: $reachable"
    echo "Model: $model"
    echo "WAN Status: $wan_status"
    echo "Expected SSID: $WIFI_SSID"
    return 0
}

# Main function: check reachability and display status.
# Outputs clear error if router is unreachable.
router_status() {
    if ! check_router_reachable; then
        echo "ERROR: Router at $ROUTER_IP is unreachable"
        return 1
    fi

    get_router_status
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    router_status
fi
