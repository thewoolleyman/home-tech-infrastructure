#!/usr/bin/env bash
set -euo pipefail

# scripts/deploy/push.sh
# Phase 2 of the deploy pipeline: copy scripts + secrets to Pi via scp.
# Sourced by tests (for function access) or run directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Overridable commands for testing
SCP="${SCP:-scp}"
SSH="${SSH:-ssh}"

# Source inventory for DEPLOY_USER
# shellcheck disable=SC1091
source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"

VALID_ROLES=("bastion" "dns")
REMOTE_BASE="/opt/pi-setup"

# Validate that a role is one of the valid roles.
# Returns 0 if valid, 1 if invalid.
_validate_role() {
    local role="$1"
    local valid
    for valid in "${VALID_ROLES[@]}"; do
        if [ "$role" = "$valid" ]; then
            return 0
        fi
    done
    return 1
}

# Copy scripts and secrets to a target Pi.
# Usage: push_scripts <role> <target_ip> <decrypt_dir>
push_scripts() {
    local role="$1"
    local target_ip="$2"
    local decrypt_dir="$3"

    if ! _validate_role "$role"; then
        echo "ERROR: Invalid role '$role'. Valid roles: ${VALID_ROLES[*]}" >&2
        return 1
    fi

    if [ ! -d "$decrypt_dir" ]; then
        echo "ERROR: Decrypt directory does not exist: $decrypt_dir" >&2
        return 1
    fi

    if [ ! -f "$decrypt_dir/secrets.dec.yaml" ]; then
        echo "ERROR: secrets.dec.yaml not found in $decrypt_dir" >&2
        return 1
    fi

    local pi_scripts="$PROJECT_ROOT/infrastructure/pi-scripts"
    local target="${DEPLOY_USER}@${target_ip}"

    # Create remote directory structure via ssh
    $SSH "$target" "mkdir -p ${REMOTE_BASE}/common ${REMOTE_BASE}/${role}"

    # Copy inventory.sh
    $SCP "$pi_scripts/inventory.sh" "$target:${REMOTE_BASE}/inventory.sh"

    # Copy common/ scripts
    $SCP -r "$pi_scripts/common/" "$target:${REMOTE_BASE}/common/"

    # Copy role-specific scripts
    $SCP -r "$pi_scripts/${role}/" "$target:${REMOTE_BASE}/${role}/"

    # Copy decrypted secrets (preserve permissions)
    $SCP -p "$decrypt_dir/secrets.dec.yaml" "$target:${REMOTE_BASE}/secrets.dec.yaml"
}

# --- Main (only runs when executed directly, not when sourced) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
        echo "ERROR: Missing role argument." >&2
        echo "Usage: push.sh <role> <target_ip> <decrypt_dir>" >&2
        exit 1
    fi

    ROLE="$1"

    if ! _validate_role "$ROLE"; then
        echo "ERROR: Invalid role '$ROLE'. Valid roles: ${VALID_ROLES[*]}" >&2
        exit 1
    fi

    if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
        echo "ERROR: Missing target_ip argument." >&2
        echo "Usage: push.sh <role> <target_ip> <decrypt_dir>" >&2
        exit 1
    fi

    TARGET_IP="$2"

    if [ $# -lt 3 ] || [ -z "${3:-}" ]; then
        echo "ERROR: Missing decrypt_dir argument." >&2
        echo "Usage: push.sh <role> <target_ip> <decrypt_dir>" >&2
        exit 1
    fi

    DECRYPT_DIR_ARG="$3"

    echo "=== Push Scripts (Phase 2) ==="
    echo "Role: $ROLE"
    echo "Target: $TARGET_IP"
    echo "Secrets: $DECRYPT_DIR_ARG"

    push_scripts "$ROLE" "$TARGET_IP" "$DECRYPT_DIR_ARG"

    echo "Scripts and secrets pushed to $TARGET_IP."
fi
