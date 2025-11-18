#!/bin/bash
# Test assertion functions for extension testing
# Usage: source this file in test scripts

# Source test helpers if not already loaded
if [ -z "$(type -t print_success)" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/test-helpers.sh"
fi

# Track test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Assert command exists
assert_command_exists() {
    local cmd="$1"
    local message="${2:-Command $cmd should exist}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if command_exists "$cmd"; then
        print_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$message (FAILED)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Assert file exists
assert_file_exists() {
    local file="$1"
    local message="${2:-File $file should exist}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ -f "$file" ]; then
        print_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$message (FAILED)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Assert directory exists
assert_directory_exists() {
    local dir="$1"
    local message="${2:-Directory $dir should exist}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ -d "$dir" ]; then
        print_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$message (FAILED)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Assert string contains substring
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain \"$needle\"}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if echo "$haystack" | grep -q "$needle"; then
        print_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$message (FAILED)"
        echo "Expected to find: $needle"
        echo "In string: $haystack"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Assert string equals
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$expected" = "$actual" ]; then
        print_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$message (FAILED)"
        echo "Expected: $expected"
        echo "Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Assert command succeeds
assert_success() {
    local cmd="$*"
    local message="Command should succeed: $cmd"

    TESTS_RUN=$((TESTS_RUN + 1))

    if eval "$cmd" >/dev/null 2>&1; then
        print_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$message (FAILED)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Assert command fails
assert_failure() {
    local cmd="$*"
    local message="Command should fail: $cmd"

    TESTS_RUN=$((TESTS_RUN + 1))

    if eval "$cmd" >/dev/null 2>&1; then
        print_error "$message (FAILED - command succeeded)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    else
        print_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    fi
}

# Assert exit code equals
assert_exit_code() {
    local expected_code="$1"
    shift
    local cmd="$*"
    local message="Command exit code should be $expected_code: $cmd"

    TESTS_RUN=$((TESTS_RUN + 1))

    eval "$cmd" >/dev/null 2>&1
    local actual_code=$?

    if [ "$actual_code" -eq "$expected_code" ]; then
        print_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$message (FAILED)"
        echo "Expected exit code: $expected_code"
        echo "Actual exit code: $actual_code"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Assert not empty
assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ -n "$value" ]; then
        print_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$message (FAILED)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Assert output contains pattern
assert_output_contains() {
    local cmd="$1"
    local pattern="$2"
    local message="${3:-Output should contain pattern: $pattern}"

    TESTS_RUN=$((TESTS_RUN + 1))

    local output
    output=$(eval "$cmd" 2>&1)
    if echo "$output" | grep -q "$pattern"; then
        print_success "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$message (FAILED)"
        echo "Pattern: $pattern"
        echo "Output: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Print test summary
print_test_summary() {
    print_section "Test Summary"
    echo "Tests run: $TESTS_RUN"
    print_success "Passed: $TESTS_PASSED"
    if [ $TESTS_FAILED -gt 0 ]; then
        print_error "Failed: $TESTS_FAILED"
        return 1
    else
        print_success "All tests passed!"
        return 0
    fi
}

# Reset test counters
reset_test_counters() {
    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0
}

# Export assertion functions
export -f assert_command_exists assert_file_exists assert_directory_exists
export -f assert_contains assert_equals assert_success assert_failure
export -f assert_exit_code assert_not_empty assert_output_contains
export -f print_test_summary reset_test_counters
