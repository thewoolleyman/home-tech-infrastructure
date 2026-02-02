#!/usr/bin/env bash
set -euo pipefail

# infrastructure/pi-scripts/common/harden.sh
# Common SSH and firewall hardening for all Pis.
# Paths are overridable via environment variables for testing.
# Sourced by tests (for function access) or run directly on a Pi.

SSHD_CONFIG="${SSHD_CONFIG:-/etc/ssh/sshd_config}"
IPTABLES_CMD="${IPTABLES_CMD:-iptables}"
SYSTEMCTL_CMD="${SYSTEMCTL_CMD:-systemctl}"

# Set or replace a key=value directive in sshd_config.
# Idempotent: if the directive already has the desired value, no change is made.
_sshd_set() {
    local key="$1"
    local value="$2"

    if grep -qE "^${key} ${value}$" "$SSHD_CONFIG"; then
        return 0
    fi

    if grep -qE "^#?${key} " "$SSHD_CONFIG"; then
        sed -i.bak "s/^#*${key} .*/${key} ${value}/" "$SSHD_CONFIG"
        rm -f "${SSHD_CONFIG}.bak"
    else
        echo "${key} ${value}" >> "$SSHD_CONFIG"
    fi
}

# Harden SSH configuration.
harden_ssh() {
    _sshd_set "PermitRootLogin" "no"
    _sshd_set "PasswordAuthentication" "no"
    _sshd_set "ChallengeResponseAuthentication" "no"
    _sshd_set "ClientAliveInterval" "300"
    _sshd_set "ClientAliveCountMax" "2"
    _sshd_set "Ciphers" "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr"
}

# Generate iptables rules as text output.
# Usage: generate_firewall_rules <ssh_port>
# Returns the iptables commands to stdout (not executed).
generate_firewall_rules() {
    local ssh_port="${1:-22}"

    cat <<EOF
# Flush existing rules
$IPTABLES_CMD -F
$IPTABLES_CMD -X

# Default policies: deny all inbound, allow outbound
$IPTABLES_CMD -P INPUT DROP
$IPTABLES_CMD -P FORWARD DROP
$IPTABLES_CMD -P OUTPUT ACCEPT

# Allow loopback
$IPTABLES_CMD -A INPUT -i lo -j ACCEPT

# Allow established and related connections
$IPTABLES_CMD -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH on port $ssh_port
$IPTABLES_CMD -A INPUT -p tcp --dport $ssh_port -j ACCEPT
EOF
}

# Apply firewall rules (only on a real Pi, not in tests).
apply_firewall_rules() {
    local ssh_port="${1:-22}"
    eval "$(generate_firewall_rules "$ssh_port")"
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Hardening Pi ==="
    echo "Hardening SSH..."
    harden_ssh
    $SYSTEMCTL_CMD reload sshd 2>/dev/null || true
    echo "SSH hardened."

    echo "Applying firewall rules..."
    apply_firewall_rules 22
    echo "Firewall configured."
    echo "Done."
fi
