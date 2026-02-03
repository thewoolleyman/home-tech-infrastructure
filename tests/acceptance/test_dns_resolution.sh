#!/usr/bin/env bash
set -euo pipefail

# test_dns_resolution.sh -- Acceptance test for internal + upstream DNS resolution
# Runs against live network: queries Pi2 (dns) for internal and upstream records.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source inventory for IPs and domain
# shellcheck disable=SC1090,SC1091
source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"

# Overridable commands (for testing with mocks)
DIG="${DIG:-dig}"

# --- Functions ---

# Resolve bastion.<DOMAIN> via Pi2 and verify it returns PI1_IP.
# Returns 0 on correct resolution, 1 otherwise.
test_internal_resolution() {
    local result
    result=$($DIG +short "bastion.${DOMAIN}" "@${PI2_IP}" 2>/dev/null || true)

    if [[ "$result" == "$PI1_IP" ]]; then
        return 0
    else
        return 1
    fi
}

# Resolve google.com via Pi2 and verify it returns any A record.
# Returns 0 if resolves, 1 if not.
test_upstream_forwarding() {
    local result
    result=$($DIG +short "google.com" "@${PI2_IP}" 2>/dev/null || true)

    if [[ -n "$result" ]]; then
        return 0
    else
        return 1
    fi
}

# Run both DNS tests, output PASS/FAIL with descriptions.
# Returns 0 if all pass, 1 if any fail.
run_dns_tests() {
    local failures=0

    if test_internal_resolution; then
        echo "[PASS] Internal DNS: bastion.${DOMAIN} resolves to ${PI1_IP} via Pi2"
    else
        echo "[FAIL] Internal DNS: bastion.${DOMAIN} did not resolve to ${PI1_IP} via Pi2"
        failures=$((failures + 1))
    fi

    if test_upstream_forwarding; then
        echo "[PASS] Upstream DNS: google.com resolves via Pi2"
    else
        echo "[FAIL] Upstream DNS: google.com did not resolve via Pi2"
        failures=$((failures + 1))
    fi

    if [[ "$failures" -gt 0 ]]; then
        return 1
    fi
    return 0
}

# --- Main guard ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_dns_tests
fi
