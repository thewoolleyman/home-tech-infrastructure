#!/usr/bin/env bash
set -euo pipefail

# infrastructure/pi-scripts/dns/generate-hosts.sh
# Generate a CoreDNS hosts file from inventory.sh.
# The COREDNS_HOSTS path is overridable for testing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COREDNS_HOSTS="${COREDNS_HOSTS:-/etc/coredns/hosts}"

# Source inventory if not already sourced
if [ -z "${DOMAIN:-}" ]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/../inventory.sh"
fi

# Generate the hosts file at $COREDNS_HOSTS.
# Reads all host data from inventory.sh environment variables.
generate_hosts_file() {
    mkdir -p "$(dirname "$COREDNS_HOSTS")"

    cat > "$COREDNS_HOSTS" <<EOF
# CoreDNS hosts file for ${DOMAIN}
# Auto-generated from inventory.sh -- do not edit manually.
${PI1_IP}	${PI1_HOSTNAME}.${DOMAIN}
${PI2_IP}	${PI2_HOSTNAME}.${DOMAIN}
${PI3_IP}	${PI3_HOSTNAME}.${DOMAIN}
${PI4_IP}	${PI4_HOSTNAME}.${DOMAIN}
${ROUTER_IP}	router.${DOMAIN}
${POWEREDGE_IP}	server.${DOMAIN}
EOF
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Generating CoreDNS hosts file at $COREDNS_HOSTS..."
    generate_hosts_file
    echo "Done. $(grep -c '^[0-9]' "$COREDNS_HOSTS") entries written."
fi
