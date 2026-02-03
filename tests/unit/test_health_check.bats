#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Create mock commands
    mkdir -p "$TEST_TMP/bin"

    # Mock ssh - succeeds by default
    cat > "$TEST_TMP/bin/ssh" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/ssh_calls.log"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/ssh"

    # Mock dig - returns success by default
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/dig_calls.log"
echo "bastion.mindlikewater.net. 300 IN A 192.168.1.10"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    # Mock pgrep - succeeds by default
    cat > "$TEST_TMP/bin/pgrep" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/pgrep_calls.log"
echo "1234"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/pgrep"

    # Mock crontab
    cat > "$TEST_TMP/bin/crontab" <<MOCK
#!/usr/bin/env bash
echo "\$@" >> "$TEST_TMP/crontab_calls.log"
if [ "\$1" = "-l" ]; then
    if [ -f "$TEST_TMP/crontab_content" ]; then
        cat "$TEST_TMP/crontab_content"
    else
        exit 1
    fi
elif [ "\$1" = "-" ]; then
    cat > "$TEST_TMP/crontab_content"
fi
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/crontab"

    export SSH="$TEST_TMP/bin/ssh"
    export DIG="$TEST_TMP/bin/dig"
    export PGREP="$TEST_TMP/bin/pgrep"
    export CRONTAB="$TEST_TMP/bin/crontab"
    export HEALTH_LOG="$TEST_TMP/health.log"

    # Source inventory
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "health-check.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/ops/health-check.sh" ]
}

@test "health-check.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/ops/health-check.sh" ]
}

@test "health-check.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/ops/health-check.sh"
}

# ---- check_ssh_reachable ----

@test "check_ssh_reachable returns 0 when SSH succeeds" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    check_ssh_reachable "192.168.1.10"
}

@test "check_ssh_reachable returns 1 when SSH fails" {
    cat > "$TEST_TMP/bin/ssh" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/ssh"

    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    run check_ssh_reachable "192.168.1.10"
    [ "$status" -eq 1 ]
}

@test "check_ssh_reachable passes ConnectTimeout=5 to ssh" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    check_ssh_reachable "192.168.1.10"
    grep -q 'ConnectTimeout=5' "$TEST_TMP/ssh_calls.log"
}

# ---- check_dns_resolution ----

@test "check_dns_resolution returns 0 when dig succeeds" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    check_dns_resolution "192.168.1.11"
}

@test "check_dns_resolution returns 1 when dig fails" {
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    run check_dns_resolution "192.168.1.11"
    [ "$status" -eq 1 ]
}

@test "check_dns_resolution queries bastion.mindlikewater.net" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    check_dns_resolution "192.168.1.11"
    grep -q 'bastion.mindlikewater.net' "$TEST_TMP/dig_calls.log"
}

# ---- check_upstream_dns ----

@test "check_upstream_dns returns 0 when external resolution works" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    check_upstream_dns
}

@test "check_upstream_dns returns 1 when external resolution fails" {
    cat > "$TEST_TMP/bin/dig" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/dig"

    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    run check_upstream_dns
    [ "$status" -eq 1 ]
}

# ---- check_coredns_process ----

@test "check_coredns_process returns 0 when process is running" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    check_coredns_process "192.168.1.11"
}

@test "check_coredns_process returns 1 when process is not running" {
    cat > "$TEST_TMP/bin/ssh" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/ssh"

    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    run check_coredns_process "192.168.1.11"
    [ "$status" -eq 1 ]
}

# ---- run_all_checks ----

@test "run_all_checks outputs [PASS] when all checks succeed" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    run run_all_checks
    [[ "$output" == *"[PASS]"* ]]
}

@test "run_all_checks outputs [FAIL] when a check fails" {
    # Make ssh fail so SSH checks fail
    cat > "$TEST_TMP/bin/ssh" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/ssh"

    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    run run_all_checks
    [[ "$output" == *"[FAIL]"* ]]
}

@test "run_all_checks output includes timestamp format" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    run run_all_checks
    [[ "$output" =~ \[[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\] ]]
}

@test "run_all_checks returns 0 when all pass" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    run run_all_checks
    [ "$status" -eq 0 ]
}

@test "run_all_checks returns 1 when any fail" {
    cat > "$TEST_TMP/bin/ssh" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/ssh"

    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    run run_all_checks
    [ "$status" -eq 1 ]
}

@test "run_all_checks output includes SSH check description" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    run run_all_checks
    [[ "$output" == *"SSH"* ]]
}

@test "run_all_checks output includes DNS check description" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    run run_all_checks
    [[ "$output" == *"DNS"* ]]
}

@test "run_all_checks output includes CoreDNS check description" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    run run_all_checks
    [[ "$output" == *"CoreDNS"* ]]
}

# ---- setup_health_cron ----

@test "setup_health_cron installs cron entry" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    setup_health_cron 15
    [ -f "$TEST_TMP/crontab_content" ]
    grep -q 'health-check.sh' "$TEST_TMP/crontab_content"
}

@test "setup_health_cron uses specified interval" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    setup_health_cron 10
    grep -q '\*/10' "$TEST_TMP/crontab_content"
}

@test "setup_health_cron is idempotent" {
    source "$PROJECT_ROOT/scripts/ops/health-check.sh"
    setup_health_cron 15
    local first
    first=$(cat "$TEST_TMP/crontab_content")
    setup_health_cron 15
    local second
    second=$(cat "$TEST_TMP/crontab_content")
    [ "$first" = "$second" ]
}
