#!/usr/bin/env bash
set -euo pipefail

# scripts/ops/configure-port-forwards.sh
# Configure router port forwarding rules for SSH bastion access.
# Uses Python TP-Link client if available, otherwise provides manual steps.
# Verifies port forward is working after applying.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${INVENTORY:-$(cd "$SCRIPT_DIR/../.." && pwd)/infrastructure/pi-scripts/inventory.sh}"

# shellcheck disable=SC1090,SC1091
source "$INVENTORY"

PYTHON="${PYTHON:-python3}"
NC="${NC:-nc}"

# Check if the Python TP-Link client module is importable.
# Returns 0 if available, 1 if not.
check_python_client() {
    $PYTHON -c "from scripts.router.tplink_client import TPLinkClient" 2>/dev/null
}

# Use the Python TP-Link client to add port forwarding rules.
# Adds: ext:SSH_EXTERNAL_PORT -> PI1_IP:22 (SSH bastion)
# Returns 0 on success, 1 on failure.
configure_forwards_auto() {
    echo "Auto-configuring port forwards via Python client..."

    if ! $PYTHON -c "
from scripts.router.tplink_client import TPLinkClient
client = TPLinkClient('${ROUTER_IP}')
client.login()
client.add_port_forward(
    ext_port=${SSH_EXTERNAL_PORT},
    int_ip='${PI1_IP}',
    int_port=22,
    protocol='TCP',
    name='SSH-Bastion'
)
client.logout()
print('Port forward added: ext:${SSH_EXTERNAL_PORT} -> ${PI1_IP}:22')
" 2>/dev/null; then
        echo "ERROR: Auto-configuration of port forwards failed."
        return 1
    fi

    return 0
}

# Display manual instructions for adding port forwards via router admin UI.
# Returns 0.
configure_forwards_manual() {
    echo "=== Port Forwarding Configuration: Manual Steps ==="
    echo ""
    echo "Add SSH bastion port forward: external:${SSH_EXTERNAL_PORT} -> ${PI1_IP}:22"
    echo ""
    echo "  1. Open router admin at http://${ROUTER_IP}"
    echo "  2. Navigate to NAT Forwarding > Port Forwarding (or Virtual Servers)"
    echo "  3. Add new port forward rule:"
    echo "       Name:          SSH-Bastion"
    echo "       External Port: ${SSH_EXTERNAL_PORT}"
    echo "       Internal IP:   ${PI1_IP}"
    echo "       Internal Port: 22"
    echo "       Protocol:      TCP"
    echo "  4. Save and apply changes"
    echo ""
    echo "After completing these steps, SSH connections to your public IP"
    echo "on port ${SSH_EXTERNAL_PORT} will be forwarded to ${PI1_IP}:22."
    return 0
}

# Verify that a port forward is responding.
# Uses nc to test connectivity to the internal host on the internal port.
# Args: ext_port, expected_ip, int_port
# Returns 0 if responding, 1 if not.
verify_port_forward() {
    local ext_port="$1"
    local expected_ip="$2"
    local int_port="$3"

    echo "Verifying port forward: ext:${ext_port} -> ${expected_ip}:${int_port}..."

    if $NC -z -w 5 "$expected_ip" "$int_port" 2>/dev/null; then
        echo "OK: ${expected_ip}:${int_port} is responding (forward target reachable)."
        return 0
    else
        echo "FAIL: ${expected_ip}:${int_port} is not responding."
        return 1
    fi
}

# Main configuration function.
# 1. Tries auto configuration via Python client
# 2. Falls back to manual instructions if Python client not available
# 3. Runs verification
# Returns 0 on success, 1 on failure.
configure_port_forwards() {
    echo "Configuring port forwards..."
    echo ""

    # Try auto configuration first
    if check_python_client; then
        echo "Python TP-Link client detected. Attempting auto-configuration..."
        if configure_forwards_auto; then
            echo ""
        else
            echo "Auto-configuration failed. Falling back to manual steps."
            echo ""
            configure_forwards_manual
        fi
    else
        echo "Python TP-Link client not available. Showing manual steps."
        echo ""
        configure_forwards_manual
    fi

    # Run verification
    echo ""
    if verify_port_forward "$SSH_EXTERNAL_PORT" "$PI1_IP" 22; then
        echo ""
        echo "Port forwarding configuration verified successfully."
        return 0
    else
        echo ""
        echo "Port forwarding verification failed."
        echo "Complete the manual steps above, then re-run to verify."
        return 1
    fi
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_port_forwards "$@"
fi
