#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Mock apt/dpkg commands
    export APT_CMD="echo"
    export DPKG_QUERY_CMD="$TEST_TMP/mock-dpkg-query"
    export UNATTENDED_UPGRADES_CONF="$TEST_TMP/50unattended-upgrades"
    export AUTO_UPGRADES_CONF="$TEST_TMP/20auto-upgrades"

    # Default: package not installed
    cat > "$DPKG_QUERY_CMD" <<'MOCK'
#!/usr/bin/env bash
echo "no packages found"
exit 1
MOCK
    chmod +x "$DPKG_QUERY_CMD"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "unattended-upgrades.sh exists" {
    [ -f "$PROJECT_ROOT/infrastructure/pi-scripts/common/unattended-upgrades.sh" ]
}

@test "unattended-upgrades.sh is executable" {
    [ -x "$PROJECT_ROOT/infrastructure/pi-scripts/common/unattended-upgrades.sh" ]
}

@test "unattended-upgrades.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/infrastructure/pi-scripts/common/unattended-upgrades.sh"
}

# ---- Configuration ----

@test "configure_unattended_upgrades creates 50unattended-upgrades config" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/unattended-upgrades.sh"
    configure_unattended_upgrades
    [ -f "$UNATTENDED_UPGRADES_CONF" ]
}

@test "config enables security updates" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/unattended-upgrades.sh"
    configure_unattended_upgrades
    grep -q 'origin=Debian,codename=.*-security' "$UNATTENDED_UPGRADES_CONF" || \
    grep -q 'Debian-Security' "$UNATTENDED_UPGRADES_CONF"
}

@test "configure_auto_upgrades creates 20auto-upgrades config" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/unattended-upgrades.sh"
    configure_auto_upgrades
    [ -f "$AUTO_UPGRADES_CONF" ]
}

@test "auto-upgrades enables daily updates" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/unattended-upgrades.sh"
    configure_auto_upgrades
    grep -q 'APT::Periodic::Update-Package-Lists "1"' "$AUTO_UPGRADES_CONF"
    grep -q 'APT::Periodic::Unattended-Upgrade "1"' "$AUTO_UPGRADES_CONF"
}

# ---- Idempotency ----

@test "configure_unattended_upgrades is idempotent" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/unattended-upgrades.sh"
    configure_unattended_upgrades
    cp "$UNATTENDED_UPGRADES_CONF" "$TEST_TMP/first.conf"
    configure_unattended_upgrades
    diff "$TEST_TMP/first.conf" "$UNATTENDED_UPGRADES_CONF"
}

@test "configure_auto_upgrades is idempotent" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/unattended-upgrades.sh"
    configure_auto_upgrades
    cp "$AUTO_UPGRADES_CONF" "$TEST_TMP/first.conf"
    configure_auto_upgrades
    diff "$TEST_TMP/first.conf" "$AUTO_UPGRADES_CONF"
}
