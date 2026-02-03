#!/usr/bin/env bash
set -euo pipefail

# test_ddns_propagation.sh -- Acceptance test for Namecheap DDNS record propagation
# Compares public IP with DNS record for bastion.<DOMAIN> via public DNS.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source inventory for domain and upstream DNS
# shellcheck disable=SC1090,SC1091
source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"

# Overridable commands (for testing with mocks)
DIG="${DIG:-dig}"
CURL="${CURL:-curl}"

# --- Functions ---

# Fetch current public IP via an external service.
get_public_ip() {
    $CURL -s --max-time 10 "https://ifconfig.me"
}

# Resolve bastion.<DOMAIN> via public DNS (1.1.1.1).
get_ddns_record() {
    $DIG +short "bastion.${DOMAIN}" "@${DNS_UPSTREAM_1}" 2>/dev/null || true
}

# Compare public IP with DDNS record.
# Returns 0 if they match, 1 if not.
test_ddns_matches() {
    local public_ip ddns_ip

    public_ip=$(get_public_ip)
    ddns_ip=$(get_ddns_record)

    if [[ -z "$public_ip" ]]; then
        echo "[FAIL] DDNS: Could not determine public IP"
        return 1
    fi

    if [[ -z "$ddns_ip" ]]; then
        echo "[FAIL] DDNS: Could not resolve bastion.${DOMAIN} via ${DNS_UPSTREAM_1}"
        return 1
    fi

    if [[ "$public_ip" == "$ddns_ip" ]]; then
        echo "[PASS] DDNS: bastion.${DOMAIN} = ${ddns_ip} matches public IP ${public_ip}"
        return 0
    else
        echo "[FAIL] DDNS: bastion.${DOMAIN} = ${ddns_ip} does not match public IP ${public_ip}"
        return 1
    fi
}

# --- Main guard ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_ddns_matches
fi
