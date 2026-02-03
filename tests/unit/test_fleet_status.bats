#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    mkdir -p "$TEST_TMP/bin"

    # Mock ping - succeeds by default
    cat > "$TEST_TMP/bin/ping" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/ping"

    # Mock ssh - succeeds
    cat > "$TEST_TMP/bin/ssh" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/ssh"

    # Mock nc - port open
    cat > "$TEST_TMP/bin/nc" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/nc"

    # Mock dig - resolves
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
echo "bastion.mindlikewater.net. 300 IN A 192.168.1.10"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    export PING="$TEST_TMP/bin/ping"
    export SSH="$TEST_TMP/bin/ssh"
    export NC="$TEST_TMP/bin/nc"
    export DIG="$TEST_TMP/bin/dig"

    # Source inventory for host definitions
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists and is well-formed ----

@test "fleet-status.sh exists and is executable" {
    [ -f "$PROJECT_ROOT/scripts/ops/fleet-status.sh" ]
    [ -x "$PROJECT_ROOT/scripts/ops/fleet-status.sh" ]
}

@test "fleet-status.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
}

# ---- check_host_reachable ----

@test "check_host_reachable returns 0 when ping succeeds" {
    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run check_host_reachable "192.168.1.10"
    [ "$status" -eq 0 ]
}

@test "check_host_reachable returns 1 when ping fails" {
    cat > "$TEST_TMP/bin/ping" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/ping"

    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run check_host_reachable "192.168.1.10"
    [ "$status" -eq 1 ]
}

# ---- check_ssh_port ----

@test "check_ssh_port returns 0 when port open" {
    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run check_ssh_port "192.168.1.10"
    [ "$status" -eq 0 ]
}

@test "check_ssh_port returns 1 when port closed" {
    cat > "$TEST_TMP/bin/nc" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/nc"

    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run check_ssh_port "192.168.1.10"
    [ "$status" -eq 1 ]
}

# ---- check_dns_internal ----

@test "check_dns_internal returns 0 when DNS resolves" {
    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run check_dns_internal
    [ "$status" -eq 0 ]
}

# ---- check_dns_external ----

@test "check_dns_external returns 0 when forwarding works" {
    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run check_dns_external
    [ "$status" -eq 0 ]
}

# ---- print_status_table output ----

@test "print_status_table output contains bastion hostname" {
    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run print_status_table
    [[ "$output" == *"bastion"* ]]
}

@test "print_status_table output contains dns hostname" {
    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run print_status_table
    [[ "$output" == *"dns"* ]]
}

@test "print_status_table output contains Router device" {
    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run print_status_table
    [[ "$output" == *"Router"* ]]
}

@test "print_status_table output contains Modem device" {
    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run print_status_table
    [[ "$output" == *"Modem"* ]]
}

# ---- print_status_table return codes ----

@test "print_status_table returns 0 when all healthy" {
    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run print_status_table
    [ "$status" -eq 0 ]
}

@test "print_status_table returns 1 when a host is unreachable" {
    # Make ping fail only for PI3 (bastion-backup at 192.168.1.12)
    cat > "$TEST_TMP/bin/ping" <<'MOCK'
#!/usr/bin/env bash
for arg in "$@"; do
    if [ "$arg" = "192.168.1.12" ]; then
        exit 1
    fi
done
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/ping"

    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run print_status_table
    [ "$status" -eq 1 ]
}

# ---- print_status_table summary lines ----

@test "output contains hosts healthy when all pass" {
    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run print_status_table
    [[ "$output" == *"hosts healthy"* ]]
}

@test "output contains UNREACHABLE when a host fails ping" {
    # Make ping fail for PI1 (bastion at 192.168.1.10)
    cat > "$TEST_TMP/bin/ping" <<'MOCK'
#!/usr/bin/env bash
for arg in "$@"; do
    if [ "$arg" = "192.168.1.10" ]; then
        exit 1
    fi
done
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/ping"

    source "$PROJECT_ROOT/scripts/ops/fleet-status.sh"
    run print_status_table
    [[ "$output" == *"UNREACHABLE"* ]]
}
