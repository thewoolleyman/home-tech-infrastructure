#!/usr/bin/env bash
set -euo pipefail

# scripts/ops/health-check.sh
# Health checks for Pi infrastructure: SSH, DNS, CoreDNS process.
# Overridable commands/paths for testing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${INVENTORY:-$(cd "$SCRIPT_DIR/../.." && pwd)/infrastructure/pi-scripts/inventory.sh}"

# shellcheck disable=SC1090,SC1091
source "$INVENTORY"

SSH="${SSH:-ssh}"
DIG="${DIG:-dig}"
PGREP="${PGREP:-pgrep}"
CRONTAB="${CRONTAB:-crontab}"
HEALTH_LOG="${HEALTH_LOG:-/var/log/health-check.log}"

# Test SSH connectivity to a Pi.
# Returns 0 if reachable, 1 if not.
check_ssh_reachable() {
    local host_ip="$1"
    $SSH -o ConnectTimeout=5 -o BatchMode=yes "${DEPLOY_USER}@${host_ip}" true 2>/dev/null
}

# Test DNS resolution via a specified DNS server.
# Returns 0 if resolves, 1 if not.
check_dns_resolution() {
    local dns_server_ip="$1"
    $DIG "@${dns_server_ip}" "bastion.${DOMAIN}" +short +time=5 +tries=1 >/dev/null 2>&1
}

# Test upstream DNS forwarding via Pi2.
# Returns 0 if resolves, 1 if not.
check_upstream_dns() {
    $DIG "@${PI2_IP}" google.com +short +time=5 +tries=1 >/dev/null 2>&1
}

# Check CoreDNS is running on a Pi.
# Returns 0 if running, 1 if not.
check_coredns_process() {
    local host_ip="$1"
    $SSH -o ConnectTimeout=5 -o BatchMode=yes "${DEPLOY_USER}@${host_ip}" \
        "$PGREP" -x coredns >/dev/null 2>&1
}

# Run all checks and report results.
# Returns 0 if all pass, 1 if any fail.
run_all_checks() {
    local failures=0
    local timestamp

    _report() {
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        local status_label="$1"
        local description="$2"
        echo "[$timestamp] [$status_label] $description"
    }

    # SSH to Pi1 (bastion)
    if check_ssh_reachable "$PI1_IP"; then
        _report "PASS" "SSH to Pi1 bastion ($PI1_IP)"
    else
        _report "FAIL" "SSH to Pi1 bastion ($PI1_IP)"
        failures=$((failures + 1))
    fi

    # SSH to Pi2 (dns)
    if check_ssh_reachable "$PI2_IP"; then
        _report "PASS" "SSH to Pi2 dns ($PI2_IP)"
    else
        _report "FAIL" "SSH to Pi2 dns ($PI2_IP)"
        failures=$((failures + 1))
    fi

    # DNS resolution via Pi2
    if check_dns_resolution "$PI2_IP"; then
        _report "PASS" "DNS resolution via Pi2 ($PI2_IP)"
    else
        _report "FAIL" "DNS resolution via Pi2 ($PI2_IP)"
        failures=$((failures + 1))
    fi

    # Upstream DNS forwarding via Pi2
    if check_upstream_dns; then
        _report "PASS" "Upstream DNS forwarding via Pi2"
    else
        _report "FAIL" "Upstream DNS forwarding via Pi2"
        failures=$((failures + 1))
    fi

    # CoreDNS process on Pi2
    if check_coredns_process "$PI2_IP"; then
        _report "PASS" "CoreDNS process on Pi2 ($PI2_IP)"
    else
        _report "FAIL" "CoreDNS process on Pi2 ($PI2_IP)"
        failures=$((failures + 1))
    fi

    if [ "$failures" -gt 0 ]; then
        return 1
    fi
    return 0
}

# Install cron job for health checks (idempotent).
setup_health_cron() {
    local interval="${1:-15}"
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/health-check.sh"
    local cron_line="*/${interval} * * * * ${script_path} >> ${HEALTH_LOG} 2>&1"

    # Check if entry already exists
    if $CRONTAB -l 2>/dev/null | grep -qF "$script_path"; then
        return 0
    fi

    # Add to existing crontab
    ($CRONTAB -l 2>/dev/null || true; echo "$cron_line") | $CRONTAB -
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_checks
fi
