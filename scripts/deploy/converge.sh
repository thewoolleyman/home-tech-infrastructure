#!/usr/bin/env bash
set -euo pipefail

# scripts/deploy/converge.sh
# Fleet convergence orchestrator: converges all hosts to declared state.
# Iterates CONVERGE_ORDER, applies filters, pushes scripts, runs setup.
# Sourced by tests (for function access) or run directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Overridable commands for testability
SSH="${SSH:-ssh}"
DRY_RUN="${DRY_RUN:-0}"

# Overridable encrypted file location
ENCRYPTED_FILE="${ENCRYPTED_FILE:-$PROJECT_ROOT/infrastructure/pi-scripts/secrets.enc.yaml}"

# Source inventory for HOSTS, CONVERGE_ORDER, helper functions, role mappings
# shellcheck disable=SC1091
source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"

# Source deploy pipeline scripts (unless in test mode, where mocks replace them)
if [ -z "${CONVERGE_TEST_MODE:-}" ]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/decrypt.sh"
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/push.sh"
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/run-setup.sh"
fi

# Build the list of scripts for a given role (for dry-run display).
# Outputs the script list as a single line.
_scripts_for_role() {
    local role="$1"
    local scripts="$ROLE_COMMON"
    case "$role" in
        bastion) scripts="$scripts $ROLE_BASTION" ;;
        dns)     scripts="$scripts $ROLE_DNS" ;;
    esac
    echo "$scripts"
}

# Check if a host is reachable via SSH with a short timeout.
# Usage: check_host_reachable <ip>
# Returns: 0 if reachable, 1 if not
check_host_reachable() {
    local ip="$1"
    if $SSH -o ConnectTimeout=3 -o BatchMode=yes "$ip" true >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Converge a single host through the deploy pipeline.
# Usage: converge_host <hostname> <ip> <role> <decrypt_dir>
# Returns: 0 on success, 1 on failure
# Sets HOST_STATUS to: ok, FAIL, or UNREACHABLE
converge_host() {
    local hostname="$1"
    local ip="$2"
    local role="$3"
    local decrypt_dir="$4"

    # Check reachability
    if ! check_host_reachable "$ip"; then
        HOST_STATUS="UNREACHABLE"
        echo "  UNREACHABLE: $hostname ($ip)" >&2
        return 1
    fi

    # Dry-run mode: report what would happen without doing it
    if [ "$DRY_RUN" = "1" ]; then
        local scripts
        scripts="$(_scripts_for_role "$role")"
        echo "[DRY RUN] Would converge $hostname ($ip, role=$role)"
        echo "  Scripts: $scripts"
        HOST_STATUS="ok"
        return 0
    fi

    # Push scripts
    if ! push_scripts "$role" "$ip" "$decrypt_dir"; then
        HOST_STATUS="FAIL"
        return 1
    fi

    # Run setup
    if ! run_setup "$role" "$ip" "$decrypt_dir"; then
        HOST_STATUS="FAIL"
        return 1
    fi

    HOST_STATUS="ok"
    return 0
}

# Main fleet convergence orchestrator.
# Decrypts secrets, iterates hosts in CONVERGE_ORDER, applies filters,
# converges each host, prints summary table, shreds secrets.
# Returns: 0 if all hosts ok, 1 if any failures
converge_fleet() {
    # Re-source inventory inside function so arrays survive subshells (bats run).
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"

    local decrypt_dir
    decrypt_dir="$(mktemp -d)"

    # Phase 1: Decrypt secrets
    echo "=== Phase 1: Decrypt Secrets ==="
    decrypt_secrets "$ENCRYPTED_FILE" "$decrypt_dir"

    # Track results for summary
    local -a result_hostnames=()
    local -a result_roles=()
    local -a result_statuses=()
    local -a result_durations=()
    local failures=0
    local ok_count=0

    echo ""
    echo "=== Phase 2: Converge Hosts ==="

    local hostname ip role
    for hostname in "${CONVERGE_ORDER[@]}"; do
        ip="$(pi_ip "$hostname")"
        role="$(pi_role "$hostname")"

        # Apply HOST filter
        if [ -n "${HOST:-}" ] && [ "$hostname" != "$HOST" ]; then
            continue
        fi

        # Apply ROLE filter
        if [ -n "${ROLE:-}" ] && [ "$role" != "$ROLE" ]; then
            continue
        fi

        # Apply SKIP filter
        if [ -n "${SKIP:-}" ] && [ "$hostname" = "$SKIP" ]; then
            continue
        fi

        echo "--- Converging: $hostname ($ip, role=$role) ---"

        HOST_STATUS="ok"
        local start_time
        start_time="$(date +%s)"

        converge_host "$hostname" "$ip" "$role" "$decrypt_dir" || true

        local end_time
        end_time="$(date +%s)"
        local duration=$(( end_time - start_time ))

        result_hostnames+=("$hostname")
        result_roles+=("$role")
        result_statuses+=("$HOST_STATUS")
        result_durations+=("${duration}s")

        if [ "$HOST_STATUS" = "FAIL" ] || [ "$HOST_STATUS" = "UNREACHABLE" ]; then
            failures=$((failures + 1))
        else
            ok_count=$((ok_count + 1))
        fi
    done

    # Phase 3: Shred secrets
    echo ""
    echo "=== Phase 3: Cleanup ==="
    shred_secrets "$decrypt_dir"

    # Print summary table
    echo ""
    echo "=== Convergence Summary ==="
    printf "%-18s%-12s%-14s%s\n" "HOSTNAME" "ROLE" "STATUS" "DURATION"

    local i
    for (( i=0; i<${#result_hostnames[@]}; i++ )); do
        printf "%-18s%-12s%-14s%s\n" \
            "${result_hostnames[$i]}" \
            "${result_roles[$i]}" \
            "${result_statuses[$i]}" \
            "${result_durations[$i]}"
    done

    local fail_count=$failures
    echo ""
    echo "$ok_count ok, 0 changed, $fail_count FAIL"

    if [ "$failures" -gt 0 ]; then
        return 1
    fi
    return 0
}

# --- Main (only runs when executed directly, not when sourced) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    converge_fleet
fi
