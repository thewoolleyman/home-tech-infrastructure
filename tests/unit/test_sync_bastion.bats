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

@test "sync-bastion.sh exists" {
    [ -f "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh" ]
}

@test "sync-bastion.sh is executable" {
    [ -x "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh" ]
}

@test "sync-bastion.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh"
}

# ---- Shell conventions ----

@test "sync-bastion.sh uses set -euo pipefail" {
    grep -q 'set -euo pipefail' "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh"
}

@test "sync-bastion.sh has main guard" {
    grep -q 'BASH_SOURCE\[0\]' "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh"
}

# ---- sync_bastion syncs sshd_config ----

@test "sync_bastion uses rsync to sync sshd_config" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh"
    sync_bastion
    grep -q '/etc/ssh/sshd_config' "$TEST_TMP/rsync_calls.log"
}

# ---- sync_bastion syncs cron jobs ----

@test "sync_bastion syncs cron jobs" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh"
    sync_bastion
    grep -q "/var/spool/cron/crontabs/$DEPLOY_USER" "$TEST_TMP/rsync_calls.log"
}

# ---- sync_bastion syncs /opt/pi-setup/ ----

@test "sync_bastion syncs /opt/pi-setup/" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh"
    sync_bastion
    grep -q '/opt/pi-setup/' "$TEST_TMP/rsync_calls.log"
}

# ---- sync_bastion targets Pi3 IP ----

@test "sync_bastion targets Pi3 IP (192.168.1.12)" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh"
    sync_bastion
    grep -q '192.168.1.12' "$TEST_TMP/rsync_calls.log"
}

# ---- sync_bastion uses DEPLOY_USER ----

@test "sync_bastion uses DEPLOY_USER for remote connection" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh"
    sync_bastion
    grep -q "${DEPLOY_USER}@" "$TEST_TMP/rsync_calls.log"
}

# ---- sync_bastion uses rsync flags ----

@test "sync_bastion uses rsync with -avz --delete" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh"
    sync_bastion
    grep -q '\-avz' "$TEST_TMP/rsync_calls.log"
    grep -q '\-\-delete' "$TEST_TMP/rsync_calls.log"
}

# ---- sync_bastion logs with timestamp ----

@test "sync_bastion logs timestamp with sync status" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh"
    sync_bastion
    [ -f "$SYNC_LOG_FILE" ]
    # Log should contain a date-like timestamp (YYYY-MM-DD or similar)
    grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$SYNC_LOG_FILE"
}

# ---- sync_bastion return codes ----

@test "sync_bastion returns 0 on success" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh"
    run sync_bastion
    [ "$status" -eq 0 ]
}

@test "sync_bastion returns 1 on rsync failure" {
    # Create a failing mock rsync
    cat > "$TEST_TMP/bin/rsync" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/rsync_calls.log"
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/rsync"

    source "$PROJECT_ROOT/infrastructure/pi-scripts/sync/sync-bastion.sh"
    run sync_bastion
    [ "$status" -eq 1 ]
}
