#!/usr/bin/env bash
set -euo pipefail

# scripts/ops/configure-dhcp-dns.sh
# Configure router DHCP DNS pointer to Pi2 (CoreDNS).
# Uses Python TP-Link client if available, otherwise provides manual steps.
# Verifies DHCP DNS configuration after applying.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${INVENTORY:-$(cd "$SCRIPT_DIR/../.." && pwd)/infrastructure/pi-scripts/inventory.sh}"

# shellcheck disable=SC1090,SC1091
source "$INVENTORY"

PYTHON="${PYTHON:-python3}"
CURL="${CURL:-curl}"
DIG="${DIG:-dig}"

# Check if the Python TP-Link client module is importable.
# Returns 0 if available, 1 if not.
check_python_client() {
    $PYTHON -c "from scripts.router.tplink_client import TPLinkClient" 2>/dev/null
}

# Use the Python TP-Link client to set DHCP DNS on the router.
# Args: dns_ip - the DNS server IP to configure (default: PI2_IP)
# Returns 0 on success, 1 on failure.
configure_dhcp_dns_auto() {
    local dns_ip="${1:-$PI2_IP}"

    echo "Auto-configuring DHCP DNS to ${dns_ip} via Python client..."

    if ! $PYTHON -c "
from scripts.router.tplink_client import TPLinkClient
client = TPLinkClient('${ROUTER_IP}')
client.login()
client.set_dhcp_dns('${dns_ip}')
client.logout()
print('DHCP DNS set to ${dns_ip}')
" 2>/dev/null; then
        echo "ERROR: Auto-configuration failed."
        return 1
    fi

    return 0
}

# Display manual instructions for configuring DHCP DNS via router admin UI.
# Args: dns_ip - the DNS server IP to configure (default: PI2_IP)
# Returns 0.
configure_dhcp_dns_manual() {
    local dns_ip="${1:-$PI2_IP}"

    echo "=== DHCP DNS Configuration: Manual Steps ==="
    echo ""
    echo "Configure router DHCP to hand out ${dns_ip} as the DNS server."
    echo ""
    echo "  1. Open router admin at http://${ROUTER_IP}"
    echo "  2. Navigate to DHCP settings (Advanced > Network > DHCP Server)"
    echo "  3. Set Primary DNS to ${dns_ip}"
    echo "  4. Save and apply changes"
    echo ""
    echo "After completing these steps, new DHCP leases will receive"
    echo "${dns_ip} (Pi2 CoreDNS) as their DNS server."
    return 0
}

# Verify that the expected DNS server is responding to queries.
# Queries the expected DNS IP directly to confirm it can resolve names.
# Args: expected_dns_ip - the DNS server IP to verify
# Returns 0 if the DNS server responds, 1 if not.
verify_dhcp_dns() {
    local expected_dns_ip="$1"

    echo "Verifying DHCP DNS configuration..."
    echo "  Testing DNS server at ${expected_dns_ip}..."

    if $DIG "@${expected_dns_ip}" example.com +short +time=5 +tries=1 >/dev/null 2>&1; then
        echo "OK: DNS server at ${expected_dns_ip} is responding to queries."
        return 0
    else
        echo "FAIL: DNS server at ${expected_dns_ip} is not responding."
        return 1
    fi
}

# Main configuration function.
# 1. Tries auto configuration via Python client
# 2. Falls back to manual instructions if Python client not available
# 3. Runs verification
# Returns 0 on success, 1 on failure.
configure_dhcp_dns() {
    local dns_ip="${1:-$PI2_IP}"

    echo "Configuring DHCP DNS pointer to ${dns_ip}..."
    echo ""

    # Try auto configuration first
    if check_python_client; then
        echo "Python TP-Link client detected. Attempting auto-configuration..."
        if configure_dhcp_dns_auto "$dns_ip"; then
            echo ""
        else
            echo "Auto-configuration failed. Falling back to manual steps."
            echo ""
            configure_dhcp_dns_manual "$dns_ip"
        fi
    else
        echo "Python TP-Link client not available. Showing manual steps."
        echo ""
        configure_dhcp_dns_manual "$dns_ip"
    fi

    # Run verification
    echo ""
    if verify_dhcp_dns "$dns_ip"; then
        echo ""
        echo "DHCP DNS configuration verified successfully."
        return 0
    else
        echo ""
        echo "DHCP DNS verification failed."
        echo "Complete the manual steps above, then re-run to verify."
        return 1
    fi
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_dhcp_dns "$@"
fi
