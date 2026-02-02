#!/usr/bin/env bash
set -euo pipefail

# scripts/ddns/update-namecheap.sh
# Update Namecheap DDNS A record when public IP changes.
# Overridable commands/paths for testing.

CURL_CMD="${CURL_CMD:-curl -s}"
DDNS_CURL_CMD="${DDNS_CURL_CMD:-curl -s}"
IP_CACHE_FILE="${IP_CACHE_FILE:-/var/lib/ddns/last_ip.txt}"
DDNS_LOG_FILE="${DDNS_LOG_FILE:-/var/log/ddns-update.log}"

# Get the current public IP address.
get_public_ip() {
    $CURL_CMD https://api.ipify.org 2>/dev/null || \
    $CURL_CMD https://ifconfig.me 2>/dev/null
}

# Check if the IP has changed since last check.
# Returns 0 (true) if changed or no cache exists, 1 (false) if same.
ip_has_changed() {
    local current_ip="$1"

    if [ ! -f "$IP_CACHE_FILE" ]; then
        return 0
    fi

    local cached_ip
    cached_ip=$(cat "$IP_CACHE_FILE")

    if [ "$current_ip" = "$cached_ip" ]; then
        return 1
    fi

    return 0
}

# Call Namecheap DDNS API and update cache.
# Requires: DOMAIN, NAMECHEAP_DDNS_PASSWORD env vars.
update_ddns() {
    local ip="$1"
    local host="${DDNS_HOST:-@}"
    local domain="${DOMAIN:-}"
    local password="${NAMECHEAP_DDNS_PASSWORD:-}"

    if [ -z "$domain" ] || [ -z "$password" ]; then
        echo "ERROR: DOMAIN and NAMECHEAP_DDNS_PASSWORD must be set" >&2
        return 1
    fi

    local url="https://dynamicdns.park-your-domain.com/update?host=${host}&domain=${domain}&password=${password}&ip=${ip}"
    $DDNS_CURL_CMD "$url" >> "$DDNS_LOG_FILE" 2>&1

    # Update cache
    mkdir -p "$(dirname "$IP_CACHE_FILE")"
    echo "$ip" > "$IP_CACHE_FILE"

    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') Updated DDNS to $ip" >> "$DDNS_LOG_FILE"
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    current_ip=$(get_public_ip)

    if ip_has_changed "$current_ip"; then
        echo "IP changed to $current_ip, updating DDNS..."
        update_ddns "$current_ip"
    else
        echo "IP unchanged ($current_ip), skipping."
    fi
fi
