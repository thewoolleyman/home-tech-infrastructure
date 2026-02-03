#!/usr/bin/env bash
set -euo pipefail

# scripts/deploy/prep-pi-image.sh
# Display a first-boot preparation checklist for a fresh Raspberry Pi SD card.
# Resolves hostname and static IP from inventory.sh based on ROLE argument.
# Sourced by tests (for function access) or run directly.

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

VALID_ROLES=("bastion" "dns" "bastion-backup" "dns-backup")

# Source inventory for Pi configuration values.
# shellcheck disable=SC1091
source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"

# Resolve a ROLE to its hostname and static IP.
# Sets RESOLVED_HOSTNAME and RESOLVED_IP.
# Usage: resolve_role <role>
resolve_role() {
    local role="$1"

    case "$role" in
        bastion)
            RESOLVED_HOSTNAME="$PI1_HOSTNAME"
            RESOLVED_IP="$PI1_IP"
            ;;
        dns)
            RESOLVED_HOSTNAME="$PI2_HOSTNAME"
            RESOLVED_IP="$PI2_IP"
            ;;
        bastion-backup)
            RESOLVED_HOSTNAME="$PI3_HOSTNAME"
            RESOLVED_IP="$PI3_IP"
            ;;
        dns-backup)
            RESOLVED_HOSTNAME="$PI4_HOSTNAME"
            RESOLVED_IP="$PI4_IP"
            ;;
        *)
            echo "ERROR: Invalid role '$role'." >&2
            echo "Valid roles: ${VALID_ROLES[*]}" >&2
            return 1
            ;;
    esac
}

# Validate that a role argument was provided and is valid.
# Usage: validate_args <args...>
validate_args() {
    if [ $# -lt 1 ] || [ -z "$1" ]; then
        echo "ERROR: ROLE argument is required." >&2
        echo "Usage: prep-pi-image.sh <ROLE>" >&2
        echo "Valid roles: ${VALID_ROLES[*]}" >&2
        return 1
    fi

    resolve_role "$1"
}

# Display the numbered first-boot preparation checklist.
# Usage: display_checklist
display_checklist() {
    cat <<EOF

=== Pi Image Preparation Checklist ===
Role: ${1}  |  Hostname: ${RESOLVED_HOSTNAME}  |  IP: ${RESOLVED_IP}

1. Flash RPi OS Lite 64-bit with Raspberry Pi Imager
2. Set hostname to: ${RESOLVED_HOSTNAME}
3. Set username to: ${DEPLOY_USER}
4. Enable SSH (password auth, temporary)
5. Configure WiFi SSID: ${WIFI_SSID:-<not set>}
6. Boot Pi and find it on network
7. SSH in and set static IP to: ${RESOLVED_IP}

EOF
}

# --- Main (only runs when executed directly, not when sourced) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_args "${1:-}"
    display_checklist "$1"
fi
