#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    # Create a mock curl that records its arguments and writes a fake binary
    export CURL="$TEST_TMP/mock_curl"
    cat > "$CURL" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/curl_calls.log"
# Write a fake goss binary to the output path
for i in "${!@}"; do
    if [ "${!i}" = "-o" ]; then
        next=$((i + 1))
        echo "goss-fake-binary" > "${!next}"
    fi
done
MOCK
    chmod +x "$CURL"

    # Create a mock chmod that records its arguments
    export CHMOD="$TEST_TMP/mock_chmod"
    cat > "$CHMOD" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/chmod_calls.log"
MOCK
    chmod +x "$CHMOD"

    # Ensure /usr/local/bin/goss does not exist in our test
    export GOSS_BIN="$TEST_TMP/goss"
    export GOSS_VERSION="v0.4.9"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists ----

@test "setup-goss.sh exists" {
    [ -f "$PROJECT_ROOT/infrastructure/pi-scripts/common/setup-goss.sh" ]
}

@test "setup-goss.sh is executable" {
    [ -x "$PROJECT_ROOT/infrastructure/pi-scripts/common/setup-goss.sh" ]
}

@test "setup-goss.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/infrastructure/pi-scripts/common/setup-goss.sh"
}

# ---- install_goss function ----

@test "install_goss downloads goss binary" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/setup-goss.sh"
    install_goss
    [ -f "$TEST_TMP/curl_calls.log" ]
    grep -q "goss" "$TEST_TMP/curl_calls.log"
}

@test "install_goss makes binary executable" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/setup-goss.sh"
    install_goss
    [ -f "$TEST_TMP/chmod_calls.log" ]
    grep -q "+x" "$TEST_TMP/chmod_calls.log"
}

@test "install_goss skips download when already installed" {
    # Pre-create the fake goss binary with correct version output
    cat > "$GOSS_BIN" <<MOCK
#!/usr/bin/env bash
echo "goss version $GOSS_VERSION"
MOCK
    chmod +x "$GOSS_BIN"

    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/setup-goss.sh"
    install_goss
    # curl should NOT have been called
    [ ! -f "$TEST_TMP/curl_calls.log" ]
}

@test "install_goss uses GOSS_VERSION for download URL" {
    source "$PROJECT_ROOT/infrastructure/pi-scripts/common/setup-goss.sh"
    install_goss
    grep -q "$GOSS_VERSION" "$TEST_TMP/curl_calls.log"
}
