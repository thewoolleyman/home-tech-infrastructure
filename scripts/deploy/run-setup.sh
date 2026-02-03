#!/usr/bin/env bash
set -euo pipefail

# scripts/deploy/run-setup.sh
# Phase 3 of the deploy pipeline: execute setup scripts on Pi via SSH.
# Sourced by tests (for function access) or run directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Overridable commands for testing
SSH="${SSH:-ssh}"

# Source inventory for DEPLOY_USER
# shellcheck disable=SC1091
source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"

# Source decrypt.sh for shred_secrets (cleanup after deploy)
# shellcheck disable=SC1091
source "$PROJECT_ROOT/scripts/deploy/decrypt.sh"

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

# Build the list of setup scripts for a given role.
# Outputs one script path per line (remote paths).
_setup_scripts_for_role() {
    local role="$1"

    echo "${REMOTE_BASE}/common/harden.sh"
    echo "${REMOTE_BASE}/common/unattended-upgrades.sh"

    case "$role" in
        bastion)
            echo "${REMOTE_BASE}/bastion/setup-bastion.sh"
            echo "${REMOTE_BASE}/bastion/setup-ddns.sh"
            ;;
        dns)
            echo "${REMOTE_BASE}/dns/setup-coredns.sh"
            ;;
    esac
}

# Execute setup scripts on a target Pi via SSH.
# Usage: run_setup <role> <target_ip> <decrypt_dir>
run_setup() {
    local role="$1"
    local target_ip="$2"
    local decrypt_dir="$3"

    if ! _validate_role "$role"; then
        echo "ERROR: Invalid role '$role'. Valid roles: ${VALID_ROLES[*]}" >&2
        return 1
    fi

    local target="${DEPLOY_USER}@${target_ip}"
    local scripts
    scripts="$(_setup_scripts_for_role "$role")"

    # Build a remote command that sources inventory then runs each script
    local remote_cmd="source ${REMOTE_BASE}/inventory.sh"
    while IFS= read -r script; do
        remote_cmd="${remote_cmd} && bash ${script}"
    done <<< "$scripts"

    $SSH "$target" "$remote_cmd"

    # Clean up local decrypted secrets after successful remote execution
    if [ -n "${SHRED_SECRETS_OVERRIDE:-}" ]; then
        # Test mode: just remove the directory directly
        rm -rf "$decrypt_dir"
    else
        shred_secrets "$decrypt_dir"
    fi
}

# --- Main (only runs when executed directly, not when sourced) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
        echo "ERROR: Missing role argument." >&2
        echo "Usage: run-setup.sh <role> <target_ip> [decrypt_dir]" >&2
        exit 1
    fi

    ROLE="$1"

    if ! _validate_role "$ROLE"; then
        echo "ERROR: Invalid role '$ROLE'. Valid roles: ${VALID_ROLES[*]}" >&2
        exit 1
    fi

    if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
        echo "ERROR: Missing target_ip argument." >&2
        echo "Usage: run-setup.sh <role> <target_ip> [decrypt_dir]" >&2
        exit 1
    fi

    TARGET_IP="$2"
    DECRYPT_DIR_ARG="${3:-}"

    echo "=== Run Setup (Phase 3) ==="
    echo "Role: $ROLE"
    echo "Target: $TARGET_IP"

    if [ -n "$DECRYPT_DIR_ARG" ]; then
        run_setup "$ROLE" "$TARGET_IP" "$DECRYPT_DIR_ARG"
    else
        echo "WARNING: No decrypt_dir provided, skipping secrets cleanup." >&2
        run_setup "$ROLE" "$TARGET_IP" ""
    fi

    echo "Setup complete on $TARGET_IP."
fi
