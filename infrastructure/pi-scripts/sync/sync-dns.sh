#!/usr/bin/env bash
set -euo pipefail

# infrastructure/pi-scripts/sync/sync-dns.sh
# Sync Pi2 (dns) config to Pi4 (dns-backup).
# Uses overridable RSYNC and SSH for testability.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../inventory.sh"

RSYNC="${RSYNC:-rsync}"
SSH="${SSH:-ssh}"
SYNC_LOG_FILE="${SYNC_LOG_FILE:-/var/log/sync-dns.log}"

# Log a message with ISO-8601 timestamp.
_sync_log() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $msg" >> "$SYNC_LOG_FILE"
}

# Sync a single path from Pi2 to Pi4 via rsync over SSH.
# Args: $1 = source path on Pi2
_sync_path() {
    local src="$1"
    $RSYNC -avz --delete -e "$SSH" \
        "$src" \
        "${DEPLOY_USER}@${PI4_IP}:${src}"
}

# Sync all DNS config from Pi2 to Pi4.
# Returns 0 on success, 1 on failure.
sync_dns() {
    local paths=(
        "/etc/coredns/"
        "/etc/ssh/sshd_config"
        "/var/spool/cron/crontabs/${DEPLOY_USER}"
        "/opt/pi-setup/"
    )

    _sync_log "Starting DNS sync to ${PI4_IP}"

    for path in "${paths[@]}"; do
        if ! _sync_path "$path"; then
            _sync_log "FAILED: sync of ${path} to ${PI4_IP}"
            return 1
        fi
    done

    _sync_log "SUCCESS: DNS sync to ${PI4_IP} complete"
    return 0
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Syncing DNS (Pi2 -> Pi4) ==="
    sync_dns
    echo "Done."
fi
