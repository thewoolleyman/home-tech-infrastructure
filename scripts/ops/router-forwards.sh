#!/usr/bin/env bash
set -euo pipefail

# scripts/ops/router-forwards.sh
# Port forward checker: verifies expected port forwards are working.
# Overridable commands for testing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${INVENTORY:-$(cd "$SCRIPT_DIR/../.." && pwd)/infrastructure/pi-scripts/inventory.sh}"

# shellcheck disable=SC1090,SC1091
source "$INVENTORY"

NC="${NC:-nc}"
CURL="${CURL:-curl}"

# Test if a port forward is working by checking if the external port responds.
# Usage: check_port_forward <external_port> <expected_internal_ip> <expected_internal_port>
# Returns 0 if working, 1 if not.
check_port_forward() {
    local external_port="$1"
    local _expected_internal_ip="$2"
    local _expected_internal_port="$3"

    if $NC -z -w 2 "$ROUTER_IP" "$external_port" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# List expected port forwards from inventory.
# Output format: "ext:<port> -> <ip>:<port> (<description>)"
list_expected_forwards() {
    echo "ext:${SSH_EXTERNAL_PORT} -> ${PI1_IP}:22 (SSH bastion)"
}

# Verify all expected port forwards.
# Tests each expected forward and outputs PASS/FAIL per forward.
# Returns 0 if all pass, 1 if any fail.
verify_forwards() {
    local failures=0

    # SSH bastion forward: ext:4222 -> PI1:22
    if check_port_forward "$SSH_EXTERNAL_PORT" "$PI1_IP" 22; then
        echo "[PASS] ext:${SSH_EXTERNAL_PORT} -> ${PI1_IP}:22 (SSH bastion)"
    else
        echo "[FAIL] ext:${SSH_EXTERNAL_PORT} -> ${PI1_IP}:22 (SSH bastion)"
        failures=$((failures + 1))
    fi

    if [ "$failures" -gt 0 ]; then
        return 1
    fi
    return 0
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Expected Port Forwards ==="
    list_expected_forwards
    echo ""
    echo "=== Verification ==="
    verify_forwards
fi
