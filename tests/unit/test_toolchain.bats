#!/usr/bin/env bats

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# ---- bats-core is available ----

@test "bats-core submodule exists" {
    [ -x "$PROJECT_ROOT/tests/libs/bats-core/bin/bats" ]
}

@test "bats-support submodule exists" {
    [ -f "$PROJECT_ROOT/tests/libs/bats-support/load.bash" ]
}

@test "bats-assert submodule exists" {
    [ -f "$PROJECT_ROOT/tests/libs/bats-assert/load.bash" ]
}

# ---- ShellCheck is available ----

@test "shellcheck is on PATH" {
    command -v shellcheck
}

# ---- make lint runs ShellCheck ----

@test "make lint runs successfully on inventory.sh" {
    cd "$PROJECT_ROOT"
    run make lint
    [ "$status" -eq 0 ]
}

# ---- make test-unit runs bats ----

@test "make test-unit runs bats and passes" {
    [[ "${BATS_RECURSIVE_GUARD:-}" == "1" ]] && skip "skipping recursive call"
    cd "$PROJECT_ROOT"
    export BATS_RECURSIVE_GUARD=1
    run make test-unit
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok"* ]]
}

# ---- make test runs lint + unit ----

@test "make test runs successfully" {
    [[ "${BATS_RECURSIVE_GUARD:-}" == "1" ]] && skip "skipping recursive call"
    cd "$PROJECT_ROOT"
    export BATS_RECURSIVE_GUARD=1
    run make test
    [ "$status" -eq 0 ]
}
