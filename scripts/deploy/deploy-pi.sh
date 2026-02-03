#!/usr/bin/env bash
set -euo pipefail

# scripts/deploy/deploy-pi.sh
# Orchestrates the 3-phase deploy pipeline: decrypt, push, execute.
# Sourced by tests (for function access) or run directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Overridable defaults
SOPS="${SOPS:-sops}"
ENCRYPTED_FILE="${ENCRYPTED_FILE:-$PROJECT_ROOT/infrastructure/pi-scripts/secrets.enc.yaml}"

VALID_ROLES=("bastion" "dns")

# Source phase scripts (unless in test mode, where mocks replace them)
if [ -z "${DEPLOY_PI_TEST_MODE:-}" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/decrypt.sh"
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/push.sh"
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/run-setup.sh"
fi

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

# Orchestrate the full deploy pipeline for a single Pi.
# Usage: deploy_pi <role> <target_ip>
deploy_pi() {
    local role="${1:-}"
    local target_ip="${2:-}"

    # --- Argument validation ---
    if [ -z "$role" ]; then
        echo "ERROR: Missing role argument." >&2
        echo "Usage: deploy-pi.sh <role> <target_ip>" >&2
        return 1
    fi

    if [ -z "$target_ip" ]; then
        echo "ERROR: Missing target_ip argument." >&2
        echo "Usage: deploy-pi.sh <role> <target_ip>" >&2
        return 1
    fi

    if ! _validate_role "$role"; then
        echo "ERROR: Invalid role '$role'. Valid roles: ${VALID_ROLES[*]}" >&2
        return 1
    fi

    # --- Create temp dir for decrypted secrets ---
    local temp_dir
    temp_dir="$(mktemp -d)"

    # --- Trap: ensure secrets are shredded on any exit ---
    local failed_phase=""
    # shellcheck disable=SC2064
    trap "shred_secrets '$temp_dir'" EXIT

    # --- Phase 1: Decrypt ---
    echo "=== Phase 1: Decrypt ==="
    if ! decrypt_secrets "$ENCRYPTED_FILE" "$temp_dir"; then
        failed_phase="Phase 1: Decrypt"
        echo "FAILED: $failed_phase" >&2
        return 1
    fi

    # --- Phase 2: Push ---
    echo "=== Phase 2: Push ==="
    if ! push_scripts "$role" "$target_ip" "$temp_dir"; then
        failed_phase="Phase 2: Push"
        echo "FAILED: $failed_phase" >&2
        return 1
    fi

    # --- Phase 3: Execute ---
    echo "=== Phase 3: Execute ==="
    if ! run_setup "$role" "$target_ip" "$temp_dir"; then
        failed_phase="Phase 3: Execute"
        echo "FAILED: $failed_phase" >&2
        return 1
    fi

    echo "Deploy complete for role '$role' on $target_ip."
    return 0
}

# --- Main (only runs when executed directly, not when sourced) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
        echo "ERROR: Missing role argument." >&2
        echo "Usage: deploy-pi.sh <role> <target_ip>" >&2
        exit 1
    fi

    ROLE="$1"

    if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
        echo "ERROR: Missing target_ip argument." >&2
        echo "Usage: deploy-pi.sh <role> <target_ip>" >&2
        exit 1
    fi

    TARGET_IP="$2"

    deploy_pi "$ROLE" "$TARGET_IP"
fi
