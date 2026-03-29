#!/bin/bash
# Test suite for verso-init.sh
# Requires: expect, git
# Usage: bash test/test-verso-init.sh [--branch BRANCH]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SETUP_SH="$REPO_ROOT/verso-init.sh"

# Allow overriding the branch (for CI testing against the current PR branch)
TEST_BRANCH="${1:-main}"
if [ "$1" = "--branch" ] 2>/dev/null; then
    TEST_BRANCH="${2:-main}"
fi

WORK_DIR=""
FAKE_BIN=""
PASSED=0
FAILED=0
ERRORS=""

setup_test_env() {
    WORK_DIR=$(mktemp -d)
    FAKE_BIN=$(mktemp -d)
    # Create a fake elan so prerequisite checks pass
    printf '#!/bin/sh\necho "elan mock"\n' > "$FAKE_BIN/elan"
    chmod +x "$FAKE_BIN/elan"
    export PATH="$FAKE_BIN:$PATH"
}

cleanup_test_env() {
    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
    if [ -n "$FAKE_BIN" ] && [ -d "$FAKE_BIN" ]; then
        rm -rf "$FAKE_BIN"
    fi
}
trap cleanup_test_env EXIT

pass() {
    PASSED=$((PASSED + 1))
    printf "  PASS: %s\n" "$1"
}

fail() {
    FAILED=$((FAILED + 1))
    ERRORS="$ERRORS\n  FAIL: $1"
    printf "  FAIL: %s\n" "$1"
}

assert_file_exists() {
    if [ -f "$1" ]; then
        return 0
    else
        return 1
    fi
}

assert_dir_not_exists() {
    if [ ! -d "$1" ]; then
        return 0
    else
        return 1
    fi
}

# --- Tests ---

test_help() {
    echo "Test: --help flag"
    output=$("$SETUP_SH" --help 2>&1)
    if echo "$output" | grep -q "Usage:"; then
        pass "--help prints usage"
    else
        fail "--help prints usage"
    fi
}

test_list() {
    echo "Test: --list flag"
    output=$("$SETUP_SH" --list --branch "$TEST_BRANCH" 2>&1)
    if echo "$output" | grep -q "basic-blog"; then
        pass "--list shows basic-blog template"
    else
        fail "--list shows basic-blog template"
    fi
    if echo "$output" | grep -q "textbook"; then
        pass "--list shows textbook template"
    else
        fail "--list shows textbook template"
    fi
    if echo "$output" | grep -q "package-docs"; then
        pass "--list shows package-docs template"
    else
        fail "--list shows package-docs template"
    fi
}

test_batch_blog() {
    echo "Test: batch mode with blog template"
    target="$WORK_DIR/test-blog"
    "$SETUP_SH" --branch "$TEST_BRANCH" basic-blog "$target" 2>&1

    if assert_file_exists "$target/lakefile.toml"; then
        pass "basic-blog: lakefile.toml exists"
    else
        fail "basic-blog: lakefile.toml exists"
    fi
    if assert_file_exists "$target/lean-toolchain"; then
        pass "basic-blog: lean-toolchain exists"
    else
        fail "basic-blog: lean-toolchain exists"
    fi
    if assert_file_exists "$target/README.md"; then
        pass "basic-blog: README.md exists"
    else
        fail "basic-blog: README.md exists"
    fi
    if assert_dir_not_exists "$target/.lake"; then
        pass "basic-blog: no .lake directory"
    else
        fail "basic-blog: no .lake directory"
    fi

    # Check git history
    commit_count=$(git -C "$target" rev-list --count HEAD)
    if [ "$commit_count" = "1" ]; then
        pass "basic-blog: exactly one commit"
    else
        fail "basic-blog: exactly one commit (got $commit_count)"
    fi

    commit_msg=$(git -C "$target" log --oneline -1)
    if echo "$commit_msg" | grep -q "verso-templates/basic-blog"; then
        pass "basic-blog: commit message mentions template"
    else
        fail "basic-blog: commit message mentions template (got: $commit_msg)"
    fi
}

test_batch_textbook() {
    echo "Test: batch mode with textbook template"
    target="$WORK_DIR/test-textbook"
    "$SETUP_SH" --branch "$TEST_BRANCH" textbook "$target" 2>&1

    if assert_file_exists "$target/lakefile.toml"; then
        pass "textbook: lakefile.toml exists"
    else
        fail "textbook: lakefile.toml exists"
    fi
    commit_count=$(git -C "$target" rev-list --count HEAD)
    if [ "$commit_count" = "1" ]; then
        pass "textbook: exactly one commit"
    else
        fail "textbook: exactly one commit (got $commit_count)"
    fi
}

test_batch_package_docs() {
    echo "Test: batch mode with package-docs template"
    target="$WORK_DIR/test-docs"
    "$SETUP_SH" --branch "$TEST_BRANCH" package-docs "$target" 2>&1

    if assert_file_exists "$target/manual/lakefile.toml"; then
        pass "package-docs: manual/lakefile.toml exists"
    else
        fail "package-docs: manual/lakefile.toml exists"
    fi
    if assert_file_exists "$target/manual/Main.lean"; then
        pass "package-docs: manual/Main.lean exists"
    else
        fail "package-docs: manual/Main.lean exists"
    fi
    commit_count=$(git -C "$target" rev-list --count HEAD)
    if [ "$commit_count" = "1" ]; then
        pass "package-docs: exactly one commit"
    else
        fail "package-docs: exactly one commit (got $commit_count)"
    fi
}

test_error_existing_directory() {
    echo "Test: error when directory exists"
    target="$WORK_DIR/test-exists"
    mkdir -p "$target"
    if "$SETUP_SH" --branch "$TEST_BRANCH" basic-blog "$target" 2>&1; then
        fail "should fail when directory exists"
    else
        pass "fails when directory exists"
    fi
}

test_error_bad_template() {
    echo "Test: error with nonexistent template"
    target="$WORK_DIR/test-bad"
    if "$SETUP_SH" --branch "$TEST_BRANCH" nonexistent "$target" 2>&1; then
        fail "should fail with bad template name"
    else
        pass "fails with bad template name"
    fi
}

test_error_missing_args() {
    echo "Test: error with only one positional arg"
    if "$SETUP_SH" --branch "$TEST_BRANCH" basic-blog 2>&1; then
        fail "should fail with only template arg"
    else
        pass "fails with only template arg"
    fi
}

test_error_no_elan() {
    echo "Test: error when elan is not installed"
    # Run with a PATH that has no elan
    output=$(PATH="/usr/bin:/bin" "$SETUP_SH" --help 2>&1 || true)
    # --help shouldn't need elan, but running without --help should fail
    output=$(PATH="/usr/bin:/bin" "$SETUP_SH" --branch "$TEST_BRANCH" basic-blog "$WORK_DIR/no-elan" 2>&1 || true)
    if echo "$output" | grep -qi "elan.*not installed"; then
        pass "fails with helpful message when elan missing"
    else
        fail "fails with helpful message when elan missing (got: $output)"
    fi
}

test_interactive() {
    echo "Test: interactive mode with expect"
    if ! command -v expect >/dev/null 2>&1; then
        echo "  SKIP: expect not installed"
        return
    fi

    target="$WORK_DIR/test-interactive"

    expect <<EXPECT_EOF
set timeout 120
spawn $SETUP_SH --branch $TEST_BRANCH
expect "Select a template"
send "1\r"
expect "Directory name"
send "$target\r"
expect "Created new Verso project"
expect eof
EXPECT_EOF

    if [ -d "$target" ] && assert_file_exists "$target/lakefile.toml"; then
        pass "interactive: project created successfully"
    else
        fail "interactive: project created successfully"
    fi

    if [ -d "$target" ]; then
        commit_count=$(git -C "$target" rev-list --count HEAD)
        if [ "$commit_count" = "1" ]; then
            pass "interactive: exactly one commit"
        else
            fail "interactive: exactly one commit (got $commit_count)"
        fi
    fi
}

test_curl_pipe() {
    echo "Test: simulated curl | sh (batch mode)"
    target="$WORK_DIR/test-pipe"
    sh -s -- --branch "$TEST_BRANCH" basic-blog "$target" < "$SETUP_SH" 2>&1

    if assert_file_exists "$target/lakefile.toml"; then
        pass "pipe: project created via stdin"
    else
        fail "pipe: project created via stdin"
    fi
}

# --- Run ---

echo "=== verso-init.sh test suite ==="
echo "Using branch: $TEST_BRANCH"
echo ""

setup_test_env

test_help
test_list
test_batch_blog
test_batch_textbook
test_batch_package_docs
test_error_existing_directory
test_error_bad_template
test_error_missing_args
test_error_no_elan
test_interactive
test_curl_pipe

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
    printf "%b\n" "$ERRORS"
    exit 1
fi
