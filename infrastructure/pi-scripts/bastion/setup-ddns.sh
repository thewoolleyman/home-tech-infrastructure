#!/usr/bin/env bash
set -euo pipefail

# infrastructure/pi-scripts/bastion/setup-ddns.sh
# Install a cron job to run the DDNS update script every 5 minutes.

CRONTAB_CMD="${CRONTAB_CMD:-crontab}"

# Generate a cron entry for DDNS updates.
generate_cron_entry() {
    local script_path="$1"
    echo "*/5 * * * * ${script_path} >> /var/log/ddns-update.log 2>&1"
}

# Install the cron job (idempotent).
install_cron_job() {
    local script_path="$1"
    local cron_line
    cron_line=$(generate_cron_entry "$script_path")

    # Check if cron entry already exists
    if $CRONTAB_CMD -l 2>/dev/null | grep -qF "$script_path"; then
        return 0
    fi

    # Add to existing crontab
    ($CRONTAB_CMD -l 2>/dev/null || true; echo "$cron_line") | $CRONTAB_CMD -
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_PATH="/usr/local/bin/update-namecheap.sh"
    echo "=== Setting up DDNS Cron ==="
    install_cron_job "$SCRIPT_PATH"
    echo "Cron job installed for $SCRIPT_PATH"
    echo "Done."
fi
