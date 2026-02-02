#!/usr/bin/env bash
set -euo pipefail

# infrastructure/pi-scripts/common/unattended-upgrades.sh
# Configure automatic security updates on a Pi.
# Paths are overridable for testing.

APT_CMD="${APT_CMD:-apt-get}"
DPKG_QUERY_CMD="${DPKG_QUERY_CMD:-dpkg-query}"
UNATTENDED_UPGRADES_CONF="${UNATTENDED_UPGRADES_CONF:-/etc/apt/apt.conf.d/50unattended-upgrades}"
AUTO_UPGRADES_CONF="${AUTO_UPGRADES_CONF:-/etc/apt/apt.conf.d/20auto-upgrades}"

# Install the unattended-upgrades package if not present.
install_unattended_upgrades() {
    # shellcheck disable=SC2016
    if $DPKG_QUERY_CMD -W -f='${Status}' unattended-upgrades 2>/dev/null | grep -q "install ok installed"; then
        return 0
    fi
    $APT_CMD install -y unattended-upgrades
}

# Write the 50unattended-upgrades config (idempotent -- overwrites with same content).
configure_unattended_upgrades() {
    cat > "$UNATTENDED_UPGRADES_CONF" <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "Debian:stable";
    "Debian:stable-updates";
    "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF
}

# Write the 20auto-upgrades config (idempotent -- overwrites with same content).
configure_auto_upgrades() {
    cat > "$AUTO_UPGRADES_CONF" <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Configuring Unattended Upgrades ==="
    install_unattended_upgrades
    configure_unattended_upgrades
    configure_auto_upgrades
    echo "Done."
fi
