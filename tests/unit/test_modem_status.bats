#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_TMP="$(mktemp -d)"
    export TEST_TMP

    mkdir -p "$TEST_TMP/bin"

    # Mock curl - succeeds by default, returns status page for at_a_glance
    cat > "$TEST_TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/curl_calls.log"
if [[ "$*" == *"at_a_glance"* ]]; then
    cat <<'HTML'
<html>
<head><title>Xfinity Gateway</title></head>
<body>
<h1>At a Glance</h1>
<table>
<tr><td>Bridge Mode</td><td>Enable</td></tr>
<tr><td>Model</td><td>Technicolor CGM4981COM</td></tr>
<tr><td>Firmware</td><td>CGM4981COM_7.1p7s1_PROD_sey</td></tr>
<tr><td>Connection Status</td><td>online</td></tr>
</table>
</body>
</html>
HTML
    exit 0
fi
if [[ "$*" == *"check_login"* ]] || [[ "$*" == *"POST"* ]]; then
    echo "login_success"
    exit 0
fi
echo "<html><title>Xfinity Gateway</title></html>"
exit 0
MOCK
    chmod +x "$TEST_TMP/bin/curl"

    export CURL="$TEST_TMP/bin/curl"
    export MODEM_COOKIE="$TEST_TMP/modem_cookie.txt"

    # Source inventory
    source "$PROJECT_ROOT/infrastructure/pi-scripts/inventory.sh"
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ---- Script exists and is well-formed ----

@test "modem-status.sh exists" {
    [ -f "$PROJECT_ROOT/scripts/ops/modem-status.sh" ]
}

@test "modem-status.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/ops/modem-status.sh" ]
}

@test "modem-status.sh passes shellcheck" {
    shellcheck "$PROJECT_ROOT/scripts/ops/modem-status.sh"
}

# ---- check_modem_reachable ----

@test "check_modem_reachable returns 0 when curl succeeds" {
    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    run check_modem_reachable
    [ "$status" -eq 0 ]
}

@test "check_modem_reachable returns 1 when curl fails (timeout)" {
    cat > "$TEST_TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/curl_calls.log"
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/curl"

    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    run check_modem_reachable
    [ "$status" -eq 1 ]
}

@test "check_modem_reachable uses MODEM_IP from inventory" {
    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    check_modem_reachable
    grep -q '10.0.0.1' "$TEST_TMP/curl_calls.log"
}

# ---- login_modem ----

@test "login_modem returns 0 on successful login" {
    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    run login_modem "admin" "password"
    [ "$status" -eq 0 ]
}

@test "login_modem returns 1 when login fails" {
    cat > "$TEST_TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/curl_calls.log"
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/curl"

    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    run login_modem "admin" "badpass"
    [ "$status" -eq 1 ]
}

@test "login_modem uses cookie jar" {
    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    login_modem "admin" "password"
    grep -q -- '-c' "$TEST_TMP/curl_calls.log" || grep -q 'cookie-jar\|cookie' "$TEST_TMP/curl_calls.log"
}

# ---- get_modem_status ----

@test "get_modem_status returns 0 on success" {
    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    run get_modem_status
    [ "$status" -eq 0 ]
}

@test "get_modem_status returns 1 when curl fails" {
    cat > "$TEST_TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/curl_calls.log"
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/curl"

    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    run get_modem_status
    [ "$status" -eq 1 ]
}

@test "get_modem_status output contains Bridge Mode" {
    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    run get_modem_status
    [[ "$output" == *"Bridge Mode"* ]]
}

@test "get_modem_status output contains Model" {
    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    run get_modem_status
    [[ "$output" == *"Model"* ]]
}

@test "get_modem_status output contains Firmware" {
    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    run get_modem_status
    [[ "$output" == *"Firmware"* ]]
}

@test "get_modem_status output contains Status" {
    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    run get_modem_status
    [[ "$output" == *"Status"* ]]
}

# ---- modem_status (main function) ----

@test "modem_status outputs error message when modem unreachable" {
    cat > "$TEST_TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/curl_calls.log"
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/curl"

    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    run modem_status
    [[ "$output" == *"not reachable"* ]] || [[ "$output" == *"unreachable"* ]]
}

@test "modem_status error mentions Xfinity app" {
    cat > "$TEST_TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
echo "$@" >> "$TEST_TMP/curl_calls.log"
exit 1
MOCK
    chmod +x "$TEST_TMP/bin/curl"

    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    run modem_status
    [[ "$output" == *"Xfinity app"* ]]
}

@test "modem_status outputs status when reachable" {
    source "$PROJECT_ROOT/scripts/ops/modem-status.sh"
    run modem_status
    [[ "$output" == *"Bridge Mode"* ]]
    [[ "$output" == *"Model"* ]]
}
