#!/usr/bin/env bash
set -euo pipefail

# scripts/deploy/verify-pi.sh
# Run goss verification against a Pi.
# Usage: verify-pi.sh <target_ip> [role]
# If role is not provided, detects it from inventory.sh by matching IP.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Overridable commands for testing
SCP="${SCP:-scp}"
SSH="${SSH:-ssh}"

# Source inventory for DEPLOY_USER, HOSTS array, and helper functions
# shellcheck disable=SC1091
source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"

SPEC_DIR="$PROJECT_ROOT/tests/integration"
REMOTE_GOSS_DIR="/tmp/goss"

# Detect role for a given IP address by looking up inventory.
# Usage: detect_role <ip>
# Outputs the role name or returns 1 if not found.
detect_role() {
    local target_ip="$1"
    local _hostname ip role
    for entry in "${HOSTS[@]}"; do
        IFS=: read -r _hostname ip role <<< "$entry"
        if [ "$ip" = "$target_ip" ]; then
            echo "$role"
            return 0
        fi
    done
    echo "ERROR: IP $target_ip not found in inventory." >&2
    return 1
}

# Copy goss spec files to the Pi and run goss validate.
# Usage: verify_pi <target_ip> <role>
# Returns goss exit code (0 if all pass, non-zero if failures).
verify_pi() {
    local target_ip="$1"
    local role="$2"
    local target="${DEPLOY_USER}@${target_ip}"
    local role_spec="${SPEC_DIR}/${role}.yaml"
    local common_spec="${SPEC_DIR}/common.yaml"

    if [ ! -f "$role_spec" ]; then
        echo "ERROR: Spec file not found: $role_spec" >&2
        return 1
    fi

    # Copy spec files to the Pi
    $SCP "$common_spec" "$target:${REMOTE_GOSS_DIR}/common.yaml"
    $SCP "$role_spec" "$target:${REMOTE_GOSS_DIR}/${role}.yaml"

    # Run goss validate on the Pi
    $SSH "$target" "cd ${REMOTE_GOSS_DIR} && goss -g ${role}.yaml validate"
}

# --- Main (only runs when executed directly, not when sourced) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
        echo "ERROR: Missing target_ip argument." >&2
        echo "Usage: verify-pi.sh <target_ip> [role]" >&2
        exit 1
    fi

    TARGET_IP="$1"
    ROLE="${2:-}"

    # If role not provided, detect from inventory
    if [ -z "$ROLE" ]; then
        ROLE="$(detect_role "$TARGET_IP")"
    fi

    echo "=== Verify Pi ==="
    echo "Target: $TARGET_IP"
    echo "Role: $ROLE"

    verify_pi "$TARGET_IP" "$ROLE"
    echo "Verification complete."
fi
