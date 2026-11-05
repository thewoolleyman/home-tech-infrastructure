#!/usr/bin/env bash
set -euo pipefail

# scripts/ops/configure-dhcp-reservations.sh [verify]
# Prints the router steps for every DHCP reservation declared in the
# inventory's DHCP_RESERVATIONS, or with "verify" checks that each reserved
# address answers and resolves to its declared MAC in the ARP table, and that
# each STATIC_ADDRESSES entry lies outside the DHCP pool and answers.
# Overridable commands for testing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${INVENTORY:-$(cd "$SCRIPT_DIR/../.." && pwd)/infrastructure/pi-scripts/inventory.sh}"

# shellcheck disable=SC1090,SC1091
source "$INVENTORY"

PING="${PING:-ping}"
ARP="${ARP:-arp}"

# Lower-case a MAC and drop leading zeros per octet, as macOS arp prints it.
normalize_mac() {
    local mac octet out=""
    mac="$(printf '%s' "$1" | tr 'A-F-' 'a-f:')"
    IFS=: read -r -a octets <<< "$mac"
    for octet in "${octets[@]}"; do
        octet="${octet#0}"
        out="${out:+$out:}${octet:-0}"
    done
    printf '%s\n' "$out"
}

print_reservation_steps() {
    local entry name mac ip
    echo "=== DHCP Reservations: Manual Steps ==="
    echo ""
    echo "  1. Open router admin at http://${ROUTER_IP}"
    echo "  2. Navigate to Advanced > Network > DHCP Server > Address Reservation"
    echo "  3. Add each reservation below that is not already present:"
    echo ""
    if [ "${#DHCP_RESERVATIONS[@]}" -eq 0 ]; then
        echo "     (none declared)"
    fi
    for entry in "${DHCP_RESERVATIONS[@]}"; do
        IFS='|' read -r name mac ip <<< "$entry"
        echo "     ${name}: MAC $(printf '%s' "$mac" | tr 'a-f:' 'A-F-') -> ${ip}"
    done
    echo ""
    echo "  4. Save. Each device takes its reserved address at its next DHCP"
    echo "     renewal; renew it on the device to take it at once."
    echo ""
    echo "Then run: $0 verify"
}

# verify_reservation <name> <mac> <ip>: 0 when <ip> answers with <mac>.
verify_reservation() {
    local name="$1" mac="$2" ip="$3" seen
    if ! $PING -c 1 -W 2 "$ip" >/dev/null 2>&1; then
        echo "FAIL: ${name}: ${ip} does not answer."
        return 1
    fi
    seen="$($ARP -n "$ip" 2>/dev/null | grep -oiE '([0-9a-f]{1,2}[:-]){5}[0-9a-f]{1,2}' | head -1)" || true
    if [ -z "$seen" ]; then
        echo "FAIL: ${name}: no ARP entry for ${ip}."
        return 1
    fi
    if [ "$(normalize_mac "$seen")" != "$(normalize_mac "$mac")" ]; then
        echo "FAIL: ${name}: ${ip} answers from ${seen}, not ${mac}."
        return 1
    fi
    echo "OK: ${name}: ${ip} answers from ${mac}."
    return 0
}

# last_octet <ip>: the host part of a 192.168.1.x address.
last_octet() {
    printf '%s\n' "${1##*.}"
}

# verify_static <name> <ip>: 0 when <ip> lies outside the pool and answers.
verify_static() {
    local name="$1" ip="$2" host
    host="$(last_octet "$ip")"
    if [ "$host" -ge "$(last_octet "$DHCP_POOL_START")" ] && [ "$host" -le "$(last_octet "$DHCP_POOL_END")" ]; then
        echo "FAIL: ${name}: ${ip} is inside the DHCP pool ${DHCP_POOL_START}-${DHCP_POOL_END}."
        return 1
    fi
    if ! $PING -c 1 -W 2 "$ip" >/dev/null 2>&1; then
        echo "FAIL: ${name}: ${ip} does not answer."
        return 1
    fi
    echo "OK: ${name}: static ${ip} is outside the pool and answers."
    return 0
}

verify_all() {
    local entry name mac ip failed=0
    for entry in "${DHCP_RESERVATIONS[@]}"; do
        IFS='|' read -r name mac ip <<< "$entry"
        verify_reservation "$name" "$mac" "$ip" || failed=1
    done
    for entry in "${STATIC_ADDRESSES[@]}"; do
        IFS='|' read -r name ip <<< "$entry"
        verify_static "$name" "$ip" || failed=1
    done
    return "$failed"
}

# --- Main ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        verify) verify_all ;;
        "") print_reservation_steps ;;
        *) echo "usage: $0 [verify]" >&2; exit 2 ;;
    esac
fi
