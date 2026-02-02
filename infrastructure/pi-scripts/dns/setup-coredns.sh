#!/usr/bin/env bash
set -euo pipefail

# infrastructure/pi-scripts/dns/setup-coredns.sh
# Install and configure CoreDNS for split-horizon DNS.
# Paths are overridable for testing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COREDNS_DIR="${COREDNS_DIR:-/etc/coredns}"
COREDNS_COREFILE="${COREDNS_COREFILE:-${COREDNS_DIR}/Corefile}"
COREDNS_HOSTS="${COREDNS_HOSTS:-${COREDNS_DIR}/hosts}"
SYSTEMCTL_CMD="${SYSTEMCTL_CMD:-systemctl}"

# Source inventory if not already sourced
if [ -z "${DOMAIN:-}" ]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/../inventory.sh"
fi

# Generate the Corefile for split-horizon DNS.
generate_corefile() {
    mkdir -p "$COREDNS_DIR"

    cat > "$COREDNS_COREFILE" <<EOF
# CoreDNS Corefile for ${DOMAIN}
# Auto-generated -- do not edit manually.

${DOMAIN} {
    hosts ${COREDNS_HOSTS} {
        fallthrough
    }
    log
    errors
}

. {
    forward . ${DNS_UPSTREAM_1} ${DNS_UPSTREAM_2}
    cache 30
    log
    errors
}
EOF
}

# Generate a systemd service unit file for CoreDNS.
generate_systemd_unit() {
    local unit_file="$1"

    cat > "$unit_file" <<'EOF'
[Unit]
Description=CoreDNS DNS server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/coredns -conf /etc/coredns/Corefile
Restart=on-failure
RestartSec=5
LimitNOFILE=8192

[Install]
WantedBy=multi-user.target
EOF
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Setting up CoreDNS ==="

    echo "Generating Corefile..."
    generate_corefile

    echo "Generating hosts file..."
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/generate-hosts.sh"
    generate_hosts_file

    echo "Installing systemd unit..."
    generate_systemd_unit "/etc/systemd/system/coredns.service"
    $SYSTEMCTL_CMD daemon-reload
    $SYSTEMCTL_CMD enable coredns
    $SYSTEMCTL_CMD restart coredns

    echo "Done."
fi
