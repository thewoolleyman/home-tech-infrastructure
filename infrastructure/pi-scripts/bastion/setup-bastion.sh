#!/usr/bin/env bash
set -euo pipefail

# infrastructure/pi-scripts/bastion/setup-bastion.sh
# Configure a Pi as an SSH bastion (jump host).
# Sources common hardening, then applies bastion-specific config.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_USER_HOME="${DEPLOY_USER_HOME:-/home/deploy}"

# Source common hardening (uses same overridable env vars)
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../common/harden.sh"

# Apply common SSH hardening plus bastion-specific settings.
setup_bastion_ssh() {
    harden_ssh
    _sshd_set "AllowTcpForwarding" "yes"
    _sshd_set "GatewayPorts" "no"
    _sshd_set "X11Forwarding" "no"
}

# Add a public key to the deploy user's authorized_keys (idempotent).
setup_authorized_keys() {
    local pubkey="$1"
    local ssh_dir="$DEPLOY_USER_HOME/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"

    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    if [ ! -f "$auth_keys" ] || ! grep -qF "$pubkey" "$auth_keys"; then
        echo "$pubkey" >> "$auth_keys"
    fi

    chmod 600 "$auth_keys"
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Setting up Bastion ==="
    setup_bastion_ssh
    $SYSTEMCTL_CMD reload sshd 2>/dev/null || true
    echo "Bastion SSH configured."
    echo "Done."
fi
