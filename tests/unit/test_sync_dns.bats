#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Create mock rsync that records its arguments
    mkdir -p "$TEST_TMP/bin"
    cat > "$TEST_TMP/bin/rsync" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/rsync_calls.log"
MOCK
    chmod +x "$TEST_TMP/bin/rsync"
    export RSYNC="$TEST_TMP/bin/rsync"

    # Create mock ssh that records its arguments
    cat > "$TEST_TMP/bin/ssh" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/ssh_calls.log"
MOCK
    chmod +x "$TEST_TMP/bin/ssh"
    export SSH="$TEST_TMP/bin/ssh"

    # Override LOG_FILE so output goes to temp
    export SYNC_LOG_FILE="$TEST_TMP/sync.log"

    # Source inventory for IP addresses and DEPLOY_USER
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "sync-dns.sh exists" {
    [ -f "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh" ]
}

@test "sync-dns.sh is executable" {
    [ -x "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh" ]
}

@test "sync-dns.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh"
}

# ---- Shell conventions ----

@test "sync-dns.sh uses set -euo pipefail" {
    grep -q 'set -euo pipefail' "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh"
}

@test "sync-dns.sh has main guard" {
    grep -q 'BASH_SOURCE\[0\]' "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh"
}

# ---- sync_dns syncs /etc/coredns/ ----

@test "sync_dns syncs /etc/coredns/ directory" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh"
    sync_dns
    grep -q '/etc/coredns/' "$TEST_TMP/rsync_calls.log"
}

# ---- sync_dns syncs sshd_config ----

@test "sync_dns syncs sshd_config" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh"
    sync_dns
    grep -q '/etc/ssh/sshd_config' "$TEST_TMP/rsync_calls.log"
}

# ---- sync_dns syncs cron jobs ----

@test "sync_dns syncs cron jobs" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh"
    sync_dns
    grep -q "/var/spool/cron/crontabs/$DEPLOY_USER" "$TEST_TMP/rsync_calls.log"
}

# ---- sync_dns syncs /opt/pi-setup/ ----

@test "sync_dns syncs /opt/pi-setup/" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh"
    sync_dns
    grep -q '/opt/pi-setup/' "$TEST_TMP/rsync_calls.log"
}

# ---- sync_dns targets Pi4 IP ----

@test "sync_dns targets Pi4 IP (192.168.1.13)" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh"
    sync_dns
    grep -q '192.168.1.13' "$TEST_TMP/rsync_calls.log"
}

# ---- sync_dns uses DEPLOY_USER ----

@test "sync_dns uses DEPLOY_USER for remote connection" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh"
    sync_dns
    grep -q "${DEPLOY_USER}@" "$TEST_TMP/rsync_calls.log"
}

# ---- sync_dns uses rsync flags ----

@test "sync_dns uses rsync with -avz --delete" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh"
    sync_dns
    grep -q '\-avz' "$TEST_TMP/rsync_calls.log"
    grep -q '\-\-delete' "$TEST_TMP/rsync_calls.log"
}

# ---- sync_dns logs with timestamp ----

@test "sync_dns logs timestamp with sync status" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh"
    sync_dns
    [ -f "$SYNC_LOG_FILE" ]
    grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$SYNC_LOG_FILE"
}

# ---- sync_dns return codes ----

@test "sync_dns returns 0 on success" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh"
    run sync_dns
    [ "$status" -eq 0 ]
}

@test "sync_dns returns 1 on rsync failure" {
    # Create a failing mock rsync
    cat > "$TEST_TMP/bin/rsync" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/rsync_calls.log"
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/rsync"

    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-dns.sh"
    run sync_dns
    [ "$status" -eq 1 ]
}
