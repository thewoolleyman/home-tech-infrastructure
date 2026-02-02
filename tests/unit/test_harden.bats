#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Create a mock sshd_config
    cat > "$TEST_TMP/sshd_config" <<'EOF'
# Default sshd_config
#PermitRootLogin prohibit-password
#PasswordAuthentication yes
#ChallengeResponseAuthentication no
#ClientAliveInterval 0
#ClientAliveCountMax 3
Ciphers aes128-ctr,aes192-ctr,aes256-ctr
EOF

    # Override paths so harden.sh writes to temp instead of system
    export SSHD_CONFIG="$TEST_TMP/sshd_config"
    export IPTABLES_CMD="echo"
    export SYSTEMCTL_CMD="echo"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "harden.sh exists" {
    [ -f "$PROJECT_ROOT/infrastructure/pi-scripts/common/harden.sh" ]
}

@test "harden.sh is executable" {
    [ -x "$PROJECT_ROOT/infrastructure/pi-scripts/common/harden.sh" ]
}

@test "harden.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/infrastructure/pi-scripts/common/harden.sh"
}

# ---- SSH hardening ----

@test "harden_ssh disables password authentication" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/harden.sh"
    harden_ssh
    grep -qE '^PasswordAuthentication no$' "$SSHD_CONFIG"
}

@test "harden_ssh disables root login" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/harden.sh"
    harden_ssh
    grep -qE '^PermitRootLogin no$' "$SSHD_CONFIG"
}

@test "harden_ssh sets restricted ciphers" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/harden.sh"
    harden_ssh
    grep -qE '^Ciphers ' "$SSHD_CONFIG"
    # Must include only strong ciphers (chacha20 or aes256-gcm)
    grep -q 'chacha20-poly1305@openssh.com' "$SSHD_CONFIG" || \
    grep -q 'aes256-gcm@openssh.com' "$SSHD_CONFIG"
}

@test "harden_ssh sets idle timeout" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/harden.sh"
    harden_ssh
    grep -qE '^ClientAliveInterval [1-9]' "$SSHD_CONFIG"
    grep -qE '^ClientAliveCountMax [1-3]$' "$SSHD_CONFIG"
}

@test "harden_ssh disables challenge-response auth" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/harden.sh"
    harden_ssh
    grep -qE '^(ChallengeResponseAuthentication|KbdInteractiveAuthentication) no$' "$SSHD_CONFIG"
}

# ---- SSH idempotency ----

@test "harden_ssh is idempotent (second run produces same result)" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/harden.sh"
    harden_ssh
    cp "$SSHD_CONFIG" "$TEST_TMP/sshd_config.first"
    harden_ssh
    diff "$TEST_TMP/sshd_config.first" "$SSHD_CONFIG"
}

# ---- Firewall rules ----

@test "generate_firewall_rules outputs deny-all default policy" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/harden.sh"
    run generate_firewall_rules 22
    [ "$status" -eq 0 ]
    [[ "$output" == *"DROP"* ]]
}

@test "generate_firewall_rules allows SSH on specified port" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/harden.sh"
    run generate_firewall_rules 22
    [[ "$output" == *"22"* ]]
    [[ "$output" == *"ACCEPT"* ]]
}

@test "generate_firewall_rules allows established connections" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/harden.sh"
    run generate_firewall_rules 22
    [[ "$output" == *"ESTABLISHED"* ]]
}

@test "generate_firewall_rules allows loopback" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/harden.sh"
    run generate_firewall_rules 22
    [[ "$output" == *"lo"* ]]
}
