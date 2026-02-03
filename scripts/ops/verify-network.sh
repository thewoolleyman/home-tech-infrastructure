#!/usr/bin/env bash
set -euo pipefail

# scripts/ops/verify-network.sh
# Network cutover verification: internet, router, modem, WiFi SSID, DHCP.
# Overridable commands for testing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${INVENTORY:-$(cd "$SCRIPT_DIR/../.." && pwd)/infrastructure/pi-scripts/inventory.sh}"

# shellcheck disable=SC1090,SC1091
source "$INVENTORY"

PING="${PING:-ping}"
DIG="${DIG:-dig}"
NMCLI="${NMCLI:-nmcli}"
IP_CMD="${IP_CMD:-ip}"

# Verify internet connectivity by resolving an external domain via upstream DNS.
# Returns 0 if resolves, 1 if not.
check_internet() {
    $DIG @"${DNS_UPSTREAM_1}" google.com +short +time=5 +tries=1 >/dev/null 2>&1
}

# Verify router is reachable.
# Returns 0 if reachable, 1 if not.
check_router() {
    $PING -c 1 -W 2 "$ROUTER_IP" >/dev/null 2>&1
}

# Verify modem is reachable.
# Returns 0 if reachable, 1 if not.
check_modem() {
    $PING -c 1 -W 2 "$MODEM_IP" >/dev/null 2>&1
}

# Verify connected to correct WiFi SSID.
# Returns 0 if matches, 1 if not (or if no WiFi).
check_wifi_ssid() {
    local current_ssid
    current_ssid="$($NMCLI -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2)" || true
    if [ "$current_ssid" = "$WIFI_SSID" ]; then
        return 0
    fi
    return 1
}

# Verify DHCP is serving IPs (WiFi interface has an IP address).
# Returns 0 if has IP, 1 if not.
check_dhcp() {
    $IP_CMD addr show "$WIFI_IFACE" 2>/dev/null | grep -q 'inet '
}

# Run all checks and report results.
# Returns 0 if all pass, 1 if any fail.
verify_network() {
    local passed=0
    local total=5

    _report() {
        local label="$1"
        local description="$2"
        echo "[$label] $description"
    }

    if check_internet; then
        _report "PASS" "Internet connectivity (DNS resolution)"
        passed=$((passed + 1))
    else
        _report "FAIL" "Internet connectivity (DNS resolution)"
    fi

    if check_router; then
        _report "PASS" "Router reachable ($ROUTER_IP)"
        passed=$((passed + 1))
    else
        _report "FAIL" "Router reachable ($ROUTER_IP)"
    fi

    if check_modem; then
        _report "PASS" "Modem reachable ($MODEM_IP)"
        passed=$((passed + 1))
    else
        _report "FAIL" "Modem reachable ($MODEM_IP)"
    fi

    if check_wifi_ssid; then
        _report "PASS" "WiFi SSID matches ($WIFI_SSID)"
        passed=$((passed + 1))
    else
        _report "FAIL" "WiFi SSID matches ($WIFI_SSID)"
    fi

    if check_dhcp; then
        _report "PASS" "DHCP serving IPs on $WIFI_IFACE"
        passed=$((passed + 1))
    else
        _report "FAIL" "DHCP serving IPs on $WIFI_IFACE"
    fi

    echo "${passed}/${total} checks passed"

    if [ "$passed" -eq "$total" ]; then
        return 0
    fi
    return 1
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    verify_network
fi
