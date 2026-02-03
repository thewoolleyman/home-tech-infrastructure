#!/usr/bin/env bash
set -euo pipefail

# scripts/deploy/deploy-with-backup.sh
# Backup-first deploy workflow: deploys to backup Pi first,
# then optionally deploys to primary when CONFIRM_PRIMARY=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source inventory for HOSTS array and helper functions
# shellcheck disable=SC1091
source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"

# Overridable commands for testability
DEPLOY_CMD="${DEPLOY_CMD:-deploy_pi}"
VERIFY_CMD="${VERIFY_CMD:-echo}"

VALID_ROLES=("bastion" "dns")

# Validate that a role is one of the valid roles.
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

# Resolve the backup target for a given role.
# Returns hostname:ip of the backup Pi.
resolve_backup_target() {
    local role="$1"
    local hostname ip entry_role
    for entry in "${HOSTS[@]}"; do
        IFS=: read -r hostname ip entry_role <<< "$entry"
        if [ "$entry_role" = "$role" ] && [[ "$hostname" == *"-backup" ]]; then
            echo "$hostname:$ip"
            return 0
        fi
    done
    echo "ERROR: No backup target found for role '$role'" >&2
    return 1
}

# Resolve the primary target for a given role.
# Returns hostname:ip of the primary Pi.
resolve_primary_target() {
    local role="$1"
    local hostname ip entry_role
    for entry in "${HOSTS[@]}"; do
        IFS=: read -r hostname ip entry_role <<< "$entry"
        if [ "$entry_role" = "$role" ] && [[ "$hostname" != *"-backup" ]]; then
            echo "$hostname:$ip"
            return 0
        fi
    done
    echo "ERROR: No primary target found for role '$role'" >&2
    return 1
}

# Deploy backup-first workflow.
# 1. Deploy to backup
# 2. Verify backup (optional)
# 3. If CONFIRM_PRIMARY=1, deploy to primary
deploy_backup_first() {
    local role="${1:-}"

    if [ -z "$role" ]; then
        echo "ERROR: Missing role argument." >&2
        echo "Usage: deploy-with-backup.sh <role>" >&2
        return 1
    fi

    if ! _validate_role "$role"; then
        echo "ERROR: Invalid role '$role'. Valid roles: ${VALID_ROLES[*]}" >&2
        return 1
    fi

    # --- Resolve targets ---
    local backup_target primary_target
    backup_target="$(resolve_backup_target "$role")"
    primary_target="$(resolve_primary_target "$role")"

    local backup_hostname backup_ip primary_hostname primary_ip
    IFS=: read -r backup_hostname backup_ip <<< "$backup_target"
    IFS=: read -r primary_hostname primary_ip <<< "$primary_target"

    # --- Step 1: Deploy to backup ---
    echo "=== Step 1: Deploy to backup ($backup_hostname @ $backup_ip) ==="
    if ! $DEPLOY_CMD "$role" "$backup_ip"; then
        echo "FAILED: Backup deployment to $backup_hostname ($backup_ip) failed." >&2
        return 1
    fi

    # --- Step 2: Verify backup ---
    echo "=== Step 2: Verify backup ==="
    $VERIFY_CMD "$role" "$backup_ip"

    # --- Report backup success ---
    echo "Backup deployed successfully. Deploy to primary? (use CONFIRM_PRIMARY=1)"

    # --- Step 3: Conditionally deploy to primary ---
    if [ "${CONFIRM_PRIMARY:-0}" = "1" ]; then
        echo "=== Step 3: Deploy to primary ($primary_hostname @ $primary_ip) ==="
        if ! $DEPLOY_CMD "$role" "$primary_ip"; then
            echo "FAILED: Primary deployment to $primary_hostname ($primary_ip) failed." >&2
            return 1
        fi
        echo "Primary deployed successfully."
    else
        echo "Skipping primary deployment. Set CONFIRM_PRIMARY=1 to deploy to primary."
    fi

    return 0
}

# --- Main (only runs when executed directly, not when sourced) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
        echo "ERROR: Missing role argument." >&2
        echo "Usage: deploy-with-backup.sh <role>" >&2
        exit 1
    fi

    ROLE="$1"

    if ! _validate_role "$ROLE"; then
        echo "ERROR: Invalid role '$ROLE'. Valid roles: ${VALID_ROLES[*]}" >&2
        exit 1
    fi

    # Source deploy-pi.sh for the deploy_pi function (when not overridden)
    if [ "$DEPLOY_CMD" = "deploy_pi" ] && [ -f "$SCRIPT_DIR/deploy-pi.sh" ]; then
        export DEPLOY_PI_TEST_MODE=1
        # shellcheck disable=SC1091
        source "$SCRIPT_DIR/deploy-pi.sh"
    fi

    deploy_backup_first "$ROLE"
fi
