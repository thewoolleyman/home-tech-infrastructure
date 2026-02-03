#!/usr/bin/env bash
set -euo pipefail

# scripts/ops/modem-status.sh
# XB8 modem status: checks reachability, authenticates, fetches status page.
# The XB8 web admin at http://MODEM_IP must have "Admin Tool online access"
# enabled via the Xfinity app.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${INVENTORY:-$(cd "$SCRIPT_DIR/../.." && pwd)/infrastructure/pi-scripts/inventory.sh}"

# shellcheck disable=SC1090,SC1091
source "$INVENTORY"

# Overridable commands/paths for testability
CURL="${CURL:-curl}"
MODEM_COOKIE="${MODEM_COOKIE:-${TMPDIR:-/tmp}/modem_cookie.txt}"

# Check if the modem admin interface is accessible.
# Curls http://MODEM_IP with a timeout.
# Returns 0 if reachable, 1 if not.
check_modem_reachable() {
    if $CURL -s -o /dev/null --connect-timeout 5 --max-time 10 "http://${MODEM_IP}" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Authenticate with the modem admin interface.
# POSTs credentials to the login endpoint and stores the session cookie.
# Usage: login_modem <username> <password>
# Returns 0 on success, 1 on failure.
login_modem() {
    local username="$1"
    local password="$2"
    if $CURL -s -o /dev/null --connect-timeout 5 --max-time 10 \
        -c "$MODEM_COOKIE" \
        -d "username=${username}&password=${password}" \
        "http://${MODEM_IP}/check_login" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Fetch and parse the modem status page.
# Outputs structured status lines for bridge mode, model, firmware, connection.
# Returns 0 on success, 1 on failure.
get_modem_status() {
    local raw
    raw="$($CURL -s --connect-timeout 5 --max-time 10 \
        -b "$MODEM_COOKIE" \
        "http://${MODEM_IP}/at_a_glance.jst" 2>/dev/null)" || return 1

    if [ -z "$raw" ]; then
        return 1
    fi

    # Parse bridge mode (look for Enable/Disable near "Bridge Mode")
    local bridge_mode="unknown"
    if echo "$raw" | grep -qi "Bridge Mode.*Enable"; then
        bridge_mode="on"
    elif echo "$raw" | grep -qi "Bridge Mode.*Disable"; then
        bridge_mode="off"
    fi

    # Parse firmware version
    local firmware="unknown"
    local fw_line
    fw_line="$(echo "$raw" | grep -i "Firmware" | head -1)" || true
    if [ -n "$fw_line" ]; then
        # Extract version string after Firmware tag/cell
        firmware="$(echo "$fw_line" | sed 's/.*<td>//;s/<\/td>.*//' | xargs)" || true
        if [ -z "$firmware" ] || [ "$firmware" = "$fw_line" ]; then
            firmware="$(echo "$fw_line" | sed 's/.*Firmware[^A-Za-z0-9]*//' | xargs)" || true
        fi
    fi

    # Parse connection status
    local conn_status="unknown"
    if echo "$raw" | grep -qi "Connection Status.*online"; then
        conn_status="online"
    elif echo "$raw" | grep -qi "Connection Status.*offline"; then
        conn_status="offline"
    fi

    printf "Bridge Mode: %s\n" "$bridge_mode"
    printf "Model: %s\n" "$MODEM_MODEL"
    printf "Firmware: %s\n" "$firmware"
    printf "Status: %s\n" "$conn_status"
    return 0
}

# Main function: check reachability, then fetch and display modem status.
# Returns 0 on success, 1 on failure.
modem_status() {
    printf "=== Modem Status (%s) ===\n" "$MODEM_MODEL"

    if ! check_modem_reachable; then
        printf "ERROR: Modem at %s is not reachable.\n" "$MODEM_IP"
        printf "Ensure 'Admin Tool online access' is enabled via the Xfinity app.\n"
        printf "Steps: Xfinity app > WiFi > View Equipment > Advanced Settings > Admin Tool\n"
        return 1
    fi

    if ! get_modem_status; then
        printf "ERROR: Failed to retrieve modem status page.\n"
        return 1
    fi

    return 0
}

# --- Main (only runs when executed directly, not when sourced) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    modem_status
fi
