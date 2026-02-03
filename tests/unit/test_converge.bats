#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Track which functions were called and in what order
    export CONVERGE_LOG="$TEST_TMP/converge_calls.log"
    touch "$CONVERGE_LOG"

    # Enable test mode so converge.sh uses mock functions
    export CONVERGE_TEST_MODE=1

    # Mock SSH for reachability checks -- succeeds by default
    export SSH="$TEST_TMP/mock_ssh"
    cat > "$SSH" <<'MOCK'
#!/usr/bin/env bash
echo "ssh $*" >> "$CONVERGE_LOG"
MOCK
    chmod +x "$SSH"

    # Dry-run off by default
    export DRY_RUN=0

    # No filters by default
    unset ROLE HOST SKIP 2>/dev/null || true

    # No fail/unreachable hosts by default
    export MOCK_FAIL_HOST=""
    export MOCK_UNREACHABLE_IP=""
}

teardown() {
    rm -rf "$TEST_TMP"
}

# Helper: source converge.sh then override phase functions with mocks.
# Uses env vars MOCK_FAIL_HOST and MOCK_UNREACHABLE_IP for control.
_source_converge_with_mocks() {
    source "$PROJECT_ROOT/scripts/deploy/converge.sh"

    # Override phase functions with mocks
    decrypt_secrets() {
        echo "decrypt_secrets $*" >> "$CONVERGE_LOG"
    }

    push_scripts() {
        echo "push_scripts $*" >> "$CONVERGE_LOG"
    }

    run_setup() {
        echo "run_setup $*" >> "$CONVERGE_LOG"
        if [ -n "$MOCK_FAIL_HOST" ]; then
            local target_ip="$2"
            local fail_ip
            fail_ip="$(pi_ip "$MOCK_FAIL_HOST")" || true
            if [ "$target_ip" = "$fail_ip" ]; then
                return 1
            fi
        fi
    }

    shred_secrets() {
        echo "shred_secrets $*" >> "$CONVERGE_LOG"
    }

    # Override check_host_reachable if we need an unreachable host
    if [ -n "$MOCK_UNREACHABLE_IP" ]; then
        check_host_reachable() {
            local ip="$1"
            if [ "$ip" = "$MOCK_UNREACHABLE_IP" ]; then
                return 1
            fi
            return 0
        }
    fi
}

# ---- Script exists and is well-formed ----

@test "converge.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/deploy/converge.sh" ]
}

@test "converge.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/deploy/converge.sh" ]
}

@test "converge.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/deploy/converge.sh"
}

# ---- Iterates over CONVERGE_ORDER ----

@test "converge_fleet iterates over all CONVERGE_ORDER hosts" {
    _source_converge_with_mocks
    run converge_fleet
    [[ "$output" == *"bastion"* ]]
    [[ "$output" == *"dns"* ]]
    [[ "$output" == *"bastion-backup"* ]]
    [[ "$output" == *"dns-backup"* ]]
}

# ---- Filtering by ROLE ----

@test "ROLE filter only converges hosts with matching role" {
    export ROLE="bastion"
    _source_converge_with_mocks
    run converge_fleet
    local push_count
    push_count="$(grep -c "push_scripts" "$CONVERGE_LOG")"
    [ "$push_count" -eq 2 ]
}

@test "ROLE filter skips hosts with non-matching role" {
    export ROLE="bastion"
    _source_converge_with_mocks
    run converge_fleet
    ! grep "push_scripts.*192.168.1.11" "$CONVERGE_LOG"
    ! grep "push_scripts.*192.168.1.13" "$CONVERGE_LOG"
}

# ---- Filtering by HOST ----

@test "HOST filter only converges the specified hostname" {
    export HOST="bastion"
    _source_converge_with_mocks
    run converge_fleet
    local push_count
    push_count="$(grep -c "push_scripts" "$CONVERGE_LOG")"
    [ "$push_count" -eq 1 ]
}

@test "HOST filter converges correct host" {
    export HOST="dns"
    _source_converge_with_mocks
    run converge_fleet
    grep -q "push_scripts.*192.168.1.11" "$CONVERGE_LOG"
}

# ---- SKIP filter ----

@test "SKIP excludes the specified hostname" {
    export SKIP="bastion-backup"
    _source_converge_with_mocks
    run converge_fleet
    ! grep "push_scripts.*192.168.1.12" "$CONVERGE_LOG"
}

@test "SKIP still converges other hosts" {
    export SKIP="bastion-backup"
    _source_converge_with_mocks
    run converge_fleet
    local push_count
    push_count="$(grep -c "push_scripts" "$CONVERGE_LOG")"
    [ "$push_count" -eq 3 ]
}

# ---- DRY_RUN ----

@test "DRY_RUN=1 outputs DRY RUN marker" {
    export DRY_RUN=1
    _source_converge_with_mocks
    run converge_fleet
    [[ "$output" == *"DRY RUN"* ]]
}

@test "DRY_RUN=1 lists scripts that would run" {
    export DRY_RUN=1
    _source_converge_with_mocks
    run converge_fleet
    [[ "$output" == *"harden.sh"* ]]
    [[ "$output" == *"setup-bastion.sh"* ]]
}

@test "DRY_RUN=1 does not call push_scripts" {
    export DRY_RUN=1
    _source_converge_with_mocks
    run converge_fleet
    ! grep -q "push_scripts" "$CONVERGE_LOG"
}

@test "DRY_RUN=1 does not call run_setup" {
    export DRY_RUN=1
    _source_converge_with_mocks
    run converge_fleet
    ! grep -q "run_setup" "$CONVERGE_LOG"
}

# ---- Summary table ----

@test "summary table contains all hostnames" {
    _source_converge_with_mocks
    run converge_fleet
    [[ "$output" == *"Convergence Summary"* ]]
    [[ "$output" == *"bastion"* ]]
    [[ "$output" == *"dns"* ]]
    [[ "$output" == *"bastion-backup"* ]]
    [[ "$output" == *"dns-backup"* ]]
}

@test "summary table contains HOSTNAME header" {
    _source_converge_with_mocks
    run converge_fleet
    [[ "$output" == *"HOSTNAME"* ]]
}

@test "summary table contains ROLE header" {
    _source_converge_with_mocks
    run converge_fleet
    [[ "$output" == *"ROLE"* ]]
}

@test "summary table contains STATUS header" {
    _source_converge_with_mocks
    run converge_fleet
    [[ "$output" == *"STATUS"* ]]
}

# ---- Return codes ----

@test "converge_fleet returns 0 when all hosts succeed" {
    _source_converge_with_mocks
    run converge_fleet
    [ "$status" -eq 0 ]
}

@test "converge_fleet returns 1 when any host fails" {
    export MOCK_FAIL_HOST="dns"
    _source_converge_with_mocks
    run converge_fleet
    [ "$status" -eq 1 ]
}

# ---- Unreachable host ----

@test "unreachable host is marked as UNREACHABLE in summary" {
    export MOCK_UNREACHABLE_IP="192.168.1.12"
    _source_converge_with_mocks
    run converge_fleet
    [[ "$output" == *"UNREACHABLE"* ]]
}

@test "unreachable host does not stop other hosts from converging" {
    export MOCK_UNREACHABLE_IP="192.168.1.12"
    _source_converge_with_mocks
    run converge_fleet
    local push_count
    push_count="$(grep -c "push_scripts" "$CONVERGE_LOG")"
    [ "$push_count" -eq 3 ]
}

# ---- Summary counts ----

@test "summary shows correct counts when all succeed" {
    _source_converge_with_mocks
    run converge_fleet
    [[ "$output" == *"4 ok"* ]]
    [[ "$output" == *"0 FAIL"* ]]
}

@test "summary shows correct counts when one host fails" {
    export MOCK_FAIL_HOST="dns"
    _source_converge_with_mocks
    run converge_fleet
    [[ "$output" == *"1 FAIL"* ]]
}

@test "summary shows correct counts when one host unreachable" {
    export MOCK_UNREACHABLE_IP="192.168.1.13"
    _source_converge_with_mocks
    run converge_fleet
    [[ "$output" == *"1 FAIL"* ]] || [[ "$output" == *"1 UNREACHABLE"* ]]
}

# ---- Secrets lifecycle ----

@test "converge_fleet calls decrypt_secrets" {
    _source_converge_with_mocks
    run converge_fleet
    grep -q "decrypt_secrets" "$CONVERGE_LOG"
}

@test "converge_fleet calls shred_secrets" {
    _source_converge_with_mocks
    run converge_fleet
    grep -q "shred_secrets" "$CONVERGE_LOG"
}
