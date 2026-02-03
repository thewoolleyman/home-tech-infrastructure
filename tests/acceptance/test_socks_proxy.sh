#!/usr/bin/env bash
set -euo pipefail

# test_socks_proxy.sh -- Acceptance test for SSH SOCKS proxy through bastion
# Opens an SSH SOCKS tunnel, curls through it, then cleans up.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source inventory for bastion IP and deploy user
# shellcheck disable=SC1090,SC1091
source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"

# Overridable commands (for testing with mocks)
SSH="${SSH:-ssh}"
CURL="${CURL:-curl}"

# Local port for SOCKS proxy
SOCKS_PORT="${SOCKS_PORT:-1080}"

# --- Functions ---

# Test SSH SOCKS proxy through bastion.
# Opens tunnel, curls an external URL, cleans up.
# Returns 0 if request succeeds, 1 if not.
test_socks_proxy() {
    local ssh_pid=0
    local exit_code=1

    # Start SSH SOCKS proxy in background
    $SSH -f -N -D "$SOCKS_PORT" \
        -o "ConnectTimeout=10" \
        -o "StrictHostKeyChecking=no" \
        -o "ExitOnForwardFailure=yes" \
        -p "$SSH_EXTERNAL_PORT" \
        "${DEPLOY_USER}@${PI1_IP}" 2>/dev/null

    # Give the tunnel a moment to establish
    sleep 2

    # Find the SSH tunnel PID
    ssh_pid=$(pgrep -f "ssh.*-D $SOCKS_PORT.*${PI1_IP}" 2>/dev/null || true)

    if [[ -z "$ssh_pid" ]]; then
        echo "[FAIL] SOCKS proxy: SSH tunnel failed to start"
        return 1
    fi

    # Curl through the SOCKS proxy
    if $CURL -s --max-time 15 \
        --socks5 "localhost:$SOCKS_PORT" \
        "https://ifconfig.me" > /dev/null 2>&1; then
        echo "[PASS] SOCKS proxy: Successfully curled through SSH tunnel on port $SOCKS_PORT"
        exit_code=0
    else
        echo "[FAIL] SOCKS proxy: curl through SOCKS tunnel failed"
        exit_code=1
    fi

    # Clean up: kill the SSH tunnel
    if [[ -n "$ssh_pid" ]]; then
        kill "$ssh_pid" 2>/dev/null || true
    fi

    return "$exit_code"
}

# --- Main guard ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_socks_proxy
fi
