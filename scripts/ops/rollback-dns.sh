#!/usr/bin/env bash
set -euo pipefail

# scripts/ops/rollback-dns.sh
# DNS rollback script: provides manual instructions to revert DHCP DNS pointer
# from Pi2 (CoreDNS) back to upstream defaults via the router admin UI.
# Verifies DNS resolution after rollback.
# When router API (Epic 5) is available, automated rollback can be added.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${INVENTORY:-$(cd "$SCRIPT_DIR/../.." && pwd)/infrastructure/pi-scripts/inventory.sh}"

# shellcheck disable=SC1090,SC1091
source "$INVENTORY"

DIG="${DIG:-dig}"
CURL="${CURL:-curl}"
OPEN="${OPEN:-open}"

# Display numbered steps for manually reverting DNS via router admin UI.
display_manual_rollback_steps() {
    echo "=== DNS Rollback: Manual Steps ==="
    echo ""
    echo "Revert DHCP DNS from Pi2 (${PI2_IP}) to upstream defaults."
    echo ""
    echo "  1. Open router admin at http://${ROUTER_IP}"
    echo "  2. Navigate to DHCP settings"
    echo "  3. Change DNS from ${PI2_IP} to upstream defaults:"
    echo "       Primary:   ${DNS_UPSTREAM_1}"
    echo "       Secondary: ${DNS_UPSTREAM_2}"
    echo "  4. Save and apply changes"
    echo ""
    echo "After completing these steps, clients will receive upstream DNS"
    echo "servers (${DNS_UPSTREAM_1}, ${DNS_UPSTREAM_2}) via DHCP instead of Pi2."
}

# Verify DNS resolution works via upstream servers (not via Pi2).
# Tests dig against both configured upstreams.
# Returns 0 if both resolve, 1 if either fails.
verify_dns_rollback() {
    local domain="example.com"

    if ! $DIG "@${DNS_UPSTREAM_1}" "$domain" +short +time=5 +tries=1 >/dev/null 2>&1; then
        echo "FAIL: DNS resolution via ${DNS_UPSTREAM_1} failed"
        return 1
    fi

    if ! $DIG "@${DNS_UPSTREAM_2}" "$domain" +short +time=5 +tries=1 >/dev/null 2>&1; then
        echo "FAIL: DNS resolution via ${DNS_UPSTREAM_2} failed"
        return 1
    fi

    echo "OK: DNS resolution via upstream servers (${DNS_UPSTREAM_1}, ${DNS_UPSTREAM_2}) working"
    return 0
}

# Open the router admin page in the default browser (macOS).
# Returns 0.
open_router_admin() {
    $OPEN "http://${ROUTER_IP}"
    return 0
}

# Main rollback function.
# 1. Displays manual rollback steps
# 2. Opens router admin if AUTO_OPEN=1
# 3. Verifies DNS resolution via upstreams
# 4. Reports result
rollback_dns() {
    display_manual_rollback_steps

    if [ "${AUTO_OPEN:-0}" = "1" ]; then
        echo ""
        echo "Opening router admin page..."
        open_router_admin
    fi

    echo ""
    echo "Verifying upstream DNS resolution..."

    if verify_dns_rollback; then
        echo ""
        echo "DNS rollback verified: upstream DNS servers are responding."
        return 0
    else
        echo ""
        echo "DNS rollback verification failed: one or more upstream DNS servers not responding."
        echo "Complete the manual steps above, then re-run this script to verify."
        return 1
    fi
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    rollback_dns
fi
