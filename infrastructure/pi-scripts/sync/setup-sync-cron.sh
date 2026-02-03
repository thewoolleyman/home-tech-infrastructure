#!/usr/bin/env bash
set -euo pipefail

# infrastructure/pi-scripts/sync/setup-sync-cron.sh
# Install cron jobs for hot-backup sync scripts.
# Uses overridable CRONTAB for testability.

CRONTAB="${CRONTAB:-crontab}"

# Install a cron job that runs a sync script every N minutes (idempotent).
# Args: $1 = absolute path to sync script
#        $2 = interval in minutes (default: 15)
# Returns 0 on success, 1 on failure.
setup_sync_cron() {
    local sync_script="$1"
    local interval="${2:-15}"

    if [ ! -f "$sync_script" ]; then
        echo "ERROR: sync script not found: $sync_script" >&2
        return 1
    fi

    local cron_entry="*/${interval} * * * * ${sync_script}"

    # Check if entry already exists (idempotent)
    if $CRONTAB -l 2>/dev/null | grep -qF "$sync_script"; then
        echo "Cron entry already exists for ${sync_script}, skipping."
        return 0
    fi

    # Append new entry to existing crontab
    ( $CRONTAB -l 2>/dev/null || true; echo "$cron_entry" ) | $CRONTAB -

    echo "Installed cron: every ${interval} min -> ${sync_script}"
    return 0
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <sync-script-path> [interval_minutes]" >&2
        exit 1
    fi
    setup_sync_cron "$@"
fi
