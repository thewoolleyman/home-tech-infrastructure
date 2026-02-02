#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Override paths for testing
    export SSHD_CONFIG="$TEST_TMP/sshd_config"
    export IPTABLES_CMD="echo"
    export SYSTEMCTL_CMD="echo"
    export DEPLOY_USER_HOME="$TEST_TMP/home/deploy"
    export APT_CMD="echo"
    export DPKG_QUERY_CMD="echo"

    # Create mock sshd_config
    cat > "$SSHD_CONFIG" <<'EOF'
#PermitRootLogin prohibit-password
#PasswordAuthentication yes
EOF

    # Create deploy user home
    mkdir -p "$DEPLOY_USER_HOME/.ssh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "setup-bastion.sh exists" {
    [ -f "$PROJECT_ROOT/infrastructure/pi-scripts/bastion/setup-bastion.sh" ]
}

@test "setup-bastion.sh is executable" {
    [ -x "$PROJECT_ROOT/infrastructure/pi-scripts/bastion/setup-bastion.sh" ]
}

@test "setup-bastion.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/infrastructure/pi-scripts/bastion/setup-bastion.sh"
}

# ---- Shell conventions ----

@test "setup-bastion.sh uses set -euo pipefail" {
    grep -q 'set -euo pipefail' "$PROJECT_ROOT/infrastructure/pi-scripts/bastion/setup-bastion.sh"
}

@test "setup-bastion.sh has main guard" {
    grep -q 'BASH_SOURCE\[0\]' "$PROJECT_ROOT/infrastructure/pi-scripts/bastion/setup-bastion.sh"
}

# ---- Bastion setup ----

@test "setup_bastion_ssh applies common hardening" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/bastion/setup-bastion.sh"
    setup_bastion_ssh
    grep -q 'PermitRootLogin no' "$SSHD_CONFIG"
    grep -q 'PasswordAuthentication no' "$SSHD_CONFIG"
}

@test "setup_authorized_keys creates authorized_keys file" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/bastion/setup-bastion.sh"
    setup_authorized_keys "ssh-ed25519 AAAA_TEST_KEY deploy@ci"
    [ -f "$DEPLOY_USER_HOME/.ssh/authorized_keys" ]
    grep -q 'ssh-ed25519 AAAA_TEST_KEY' "$DEPLOY_USER_HOME/.ssh/authorized_keys"
}

@test "authorized_keys has strict permissions" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/bastion/setup-bastion.sh"
    setup_authorized_keys "ssh-ed25519 AAAA_TEST_KEY deploy@ci"
    local perms
    perms=$(stat -f '%Lp' "$DEPLOY_USER_HOME/.ssh/authorized_keys" 2>/dev/null || stat -c '%a' "$DEPLOY_USER_HOME/.ssh/authorized_keys" 2>/dev/null)
    [ "$perms" = "600" ]
}

@test "setup_authorized_keys is idempotent (no duplicate keys)" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/bastion/setup-bastion.sh"
    setup_authorized_keys "ssh-ed25519 AAAA_TEST_KEY deploy@ci"
    setup_authorized_keys "ssh-ed25519 AAAA_TEST_KEY deploy@ci"
    local count
    count=$(grep -c 'AAAA_TEST_KEY' "$DEPLOY_USER_HOME/.ssh/authorized_keys")
    [ "$count" -eq 1 ]
}

@test "setup_bastion_ssh configures AllowTcpForwarding" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/bastion/setup-bastion.sh"
    setup_bastion_ssh
    grep -q 'AllowTcpForwarding yes' "$SSHD_CONFIG"
}
