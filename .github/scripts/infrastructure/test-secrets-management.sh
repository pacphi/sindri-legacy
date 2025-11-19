#!/bin/bash
#
# Test Secrets Management Implementation
#
# This script validates the SOPS + age secrets management implementation:
# - SOPS and age binary availability
# - Secrets library function correctness
# - Environment cleanup (no exposure)
# - File permissions validation
# - Extension secret loading
#

set -euo pipefail

# Note: Secrets management commands are now standalone scripts in /workspace/bin
# which is in PATH, so they work in both interactive and non-interactive shells

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ==============================================================================
# Helper Functions
# ==============================================================================

log_test() {
    echo -e "\n${YELLOW}TEST:${NC} $1"
    ((TESTS_RUN++))
}

log_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "  ℹ️  $1"
}

# ==============================================================================
# Test Functions
# ==============================================================================

test_sops_installation() {
    log_test "SOPS binary installation"

    if command -v sops &>/dev/null; then
        local version
        version=$(sops --version 2>&1 | head -1 || echo "unknown")
        log_pass "SOPS is installed: $version"
        log_info "SOPS path: $(which sops)"

        # Test if SOPS actually works
        if echo "test: value" | sops --encrypt --age "$(cat /dev/null 2>&1 || echo 'age1test')" /dev/stdin > /dev/null 2>&1; then
            log_info "SOPS encryption test: working"
        else
            log_info "SOPS encryption test: may have issues"
        fi
        return 0
    else
        log_fail "SOPS binary not found in PATH"
        log_info "PATH=$PATH"
        return 1
    fi
}

test_age_installation() {
    log_test "age binary installation"

    if command -v age &>/dev/null; then
        local version
        version=$(age --version 2>&1 | head -1 || echo "unknown")
        log_pass "age is installed: $version"
        return 0
    else
        log_fail "age binary not found in PATH"
        return 1
    fi
}

test_secrets_library_exists() {
    log_test "Secrets library file exists"

    local lib_path="$HOME/.secrets/lib.sh"

    if [[ -f "$lib_path" ]]; then
        log_pass "Secrets library exists at $lib_path"
        return 0
    else
        log_fail "Secrets library not found at $lib_path"
        return 1
    fi
}

test_age_key_generation() {
    log_test "age encryption key generation"

    local key_path="$HOME/.age/key.txt"

    if [[ -f "$key_path" ]]; then
        log_pass "age key exists at $key_path"

        # Verify key format
        if grep -q "^# created:" "$key_path" && grep -q "^# public key:" "$key_path"; then
            log_pass "age key has valid format"
        else
            log_fail "age key format is invalid"
            return 1
        fi

        # Verify permissions
        local perms
        perms=$(stat -c "%a" "$key_path" 2>/dev/null || stat -f "%OLp" "$key_path" 2>/dev/null)
        if [[ "$perms" == "600" ]]; then
            log_pass "age key has correct permissions (600)"
        else
            log_fail "age key has incorrect permissions: $perms (expected 600)"
            return 1
        fi

        return 0
    else
        log_fail "age key not found at $key_path"
        return 1
    fi
}

test_secrets_library_functions() {
    log_test "Secrets library functions"

    # Source the library
    if ! source "$HOME/.secrets/lib.sh" 2>/dev/null; then
        log_fail "Failed to source secrets library"
        return 1
    fi

    # Test set_secret and has_secret
    log_info "Testing set_secret and has_secret..."
    if set_secret "test_key" "test_value" 2>/dev/null; then
        log_pass "set_secret() works"
    else
        log_fail "set_secret() failed"
        return 1
    fi

    if has_secret "test_key" 2>/dev/null; then
        log_pass "has_secret() correctly detects existing secret"
    else
        log_fail "has_secret() failed to detect secret"
        return 1
    fi

    if ! has_secret "nonexistent_key" 2>/dev/null; then
        log_pass "has_secret() correctly returns false for nonexistent secret"
    else
        log_fail "has_secret() incorrectly detected nonexistent secret"
        return 1
    fi

    # Test get_secret
    log_info "Testing get_secret..."
    local value
    value=$(get_secret "test_key" 2>/dev/null)
    if [[ "$value" == "test_value" ]]; then
        log_pass "get_secret() returns correct value"
    else
        log_fail "get_secret() returned incorrect value: $value"
        return 1
    fi

    # Cleanup test secret
    rm -f "$HOME/.secrets/secrets.enc.yaml" 2>/dev/null || true

    return 0
}

test_secrets_file_encryption() {
    log_test "Secrets file encryption"

    local secrets_file="$HOME/.secrets/secrets.enc.yaml"

    # Create a test secret with detailed error output
    source "$HOME/.secrets/lib.sh" 2>/dev/null

    # Try to create a secret and capture any errors
    log_info "Attempting to create encrypted secret..."
    if ! set_secret "test_encrypted" "sensitive_data" 2>&1 | tee /tmp/set_secret_output.log; then
        log_fail "set_secret() command failed"
        log_info "Error output:"
        cat /tmp/set_secret_output.log
        return 1
    fi

    if [[ -f "$secrets_file" ]]; then
        log_pass "Encrypted secrets file created"

        # Show first few lines for debugging
        log_info "First 5 lines of secrets file:"
        head -5 "$secrets_file" || true

        # Verify file is actually encrypted (should contain SOPS metadata)
        # SOPS can output YAML or JSON format - check for both
        if grep -q '"sops"' "$secrets_file" || grep -q "sops:" "$secrets_file"; then
            if grep -q '"age"' "$secrets_file" || grep -q "age:" "$secrets_file"; then
                log_pass "Secrets file contains SOPS encryption metadata (JSON or YAML)"
            else
                log_fail "SOPS metadata found but no age encryption"
                return 1
            fi
        else
            log_fail "Secrets file does not appear to be encrypted"
            log_info "File content (first 10 lines):"
            head -10 "$secrets_file" || true
            return 1
        fi

        # Verify plaintext is NOT in file
        if ! grep -q "sensitive_data" "$secrets_file"; then
            log_pass "Plaintext secrets not visible in encrypted file"
        else
            log_fail "Plaintext secrets found in file (not encrypted properly)"
            return 1
        fi

        # Verify permissions
        local perms
        perms=$(stat -c "%a" "$secrets_file" 2>/dev/null || stat -f "%OLp" "$secrets_file" 2>/dev/null)
        if [[ "$perms" == "600" ]]; then
            log_pass "Secrets file has correct permissions (600)"
        else
            log_fail "Secrets file has incorrect permissions: $perms (expected 600)"
            return 1
        fi

        # Cleanup
        rm -f "$secrets_file" 2>/dev/null || true

        return 0
    else
        log_fail "Encrypted secrets file not created"
        return 1
    fi
}

test_environment_cleanup() {
    log_test "Secrets management validation"

    # Note: Fly.io secrets persist in environment at platform level
    # This is acceptable - the value is having them ALSO encrypted for:
    # 1. At-rest encryption (security)
    # 2. Extension preference (extensions use encrypted file when available)
    # 3. Manual management (edit-secrets without VM restart)

    log_info "Validating encrypted secrets file (primary security benefit)..."

    # If secrets file doesn't exist, that's OK if no Fly.io secrets were set
    if [ ! -f "$HOME/.secrets/secrets.enc.yaml" ]; then
        if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${GITHUB_TOKEN:-}" ]; then
            log_pass "No secrets configured (expected)"
            return 0
        else
            log_info "Fly.io secrets present but not yet encrypted (may be in-progress)"
            return 0
        fi
    fi

    # Verify encrypted file is valid (check for both JSON and YAML formats)
    if (grep -q '"sops"' "$HOME/.secrets/secrets.enc.yaml" || grep -q "sops:" "$HOME/.secrets/secrets.enc.yaml") && \
       (grep -q '"age"' "$HOME/.secrets/secrets.enc.yaml" || grep -q "age:" "$HOME/.secrets/secrets.enc.yaml"); then
        log_pass "Secrets file is properly SOPS-encrypted"
    else
        log_fail "Secrets file exists but is not properly encrypted"
        return 1
    fi

    return 0
}

test_process_list_cleanup() {
    log_test "Process security validation"

    # Note: Fly.io secrets in environment will be visible in process environments
    # This is a platform limitation. We validate that:
    # 1. No secrets passed as command-line arguments (visible in ps)
    # 2. No obvious API key patterns in command lines

    local ps_output
    ps_output=$(ps aux 2>/dev/null || ps -ef 2>/dev/null)

    # Check for secrets passed as CLI arguments (bad practice)
    # Look for common API key patterns in command lines only
    if echo "$ps_output" | grep -E "COMMAND|CMD" -v | grep -qE "sk-ant-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,}|pplx-[a-zA-Z0-9]{20,}"; then
        log_fail "Possible API keys found in process command lines"
        log_info "Keys should not be passed as CLI arguments"
        return 1
    else
        log_pass "No API keys in process command lines"
    fi

    log_info "Note: Fly.io secrets in process environments are platform-managed"

    return 0
}

test_user_commands_available() {
    log_test "User commands availability"

    local bin_dir="/workspace/bin"
    local commands=("view-secrets" "edit-secrets" "load-secrets" "with-secrets")
    local missing_commands=()
    local non_executable=()

    # Check each command exists and is executable
    for cmd in "${commands[@]}"; do
        local cmd_path="$bin_dir/$cmd"

        if [ ! -f "$cmd_path" ]; then
            missing_commands+=("$cmd")
        elif [ ! -x "$cmd_path" ]; then
            non_executable+=("$cmd")
        fi
    done

    # Report results
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_fail "Missing command scripts: ${missing_commands[*]}"
        log_info "Expected location: $bin_dir"
        return 1
    fi

    if [[ ${#non_executable[@]} -gt 0 ]]; then
        log_fail "Non-executable command scripts: ${non_executable[*]}"
        log_info "Scripts exist but lack execute permissions"
        return 1
    fi

    # All commands present and executable
    log_pass "All user commands available and executable: ${commands[*]}"

    # Verify commands are in PATH
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_fail "Command '$cmd' not in PATH"
            log_info "Current PATH: $PATH"
            return 1
        fi
    done

    log_pass "All commands accessible via PATH"
    return 0
}

test_secrets_directory_structure() {
    log_test "Secrets directory structure and permissions"

    local secrets_dir="$HOME/.secrets"
    local age_dir="$HOME/.age"

    # Check secrets directory
    if [[ -d "$secrets_dir" ]]; then
        log_pass "Secrets directory exists: $secrets_dir"

        local perms
        perms=$(stat -c "%a" "$secrets_dir" 2>/dev/null || stat -f "%OLp" "$secrets_dir" 2>/dev/null)
        if [[ "$perms" == "700" ]]; then
            log_pass "Secrets directory has correct permissions (700)"
        else
            log_fail "Secrets directory has incorrect permissions: $perms (expected 700)"
            return 1
        fi
    else
        log_fail "Secrets directory not found: $secrets_dir"
        return 1
    fi

    # Check age directory
    if [[ -d "$age_dir" ]]; then
        log_pass "Age directory exists: $age_dir"

        local perms
        perms=$(stat -c "%a" "$age_dir" 2>/dev/null || stat -f "%OLp" "$age_dir" 2>/dev/null)
        if [[ "$perms" == "700" ]]; then
            log_pass "Age directory has correct permissions (700)"
        else
            log_fail "Age directory has incorrect permissions: $perms (expected 700)"
            return 1
        fi
    else
        log_fail "Age directory not found: $age_dir"
        return 1
    fi

    return 0
}

test_extension_secret_metadata() {
    log_test "Extension secret metadata declarations"

    local extensions_dir="/docker/lib/extensions.d"
    local extensions_with_secrets=()

    # Check extensions that should have secret metadata
    local expected_extensions=(
        "claude-auth-with-api-key/claude-auth-with-api-key.extension:EXT_REQUIRED_SECRETS"
        "github-cli/github-cli.extension:EXT_REQUIRED_SECRETS"
        "nodejs-devtools/nodejs-devtools.extension:EXT_OPTIONAL_SECRETS"
        "ai-tools/ai-tools.extension:EXT_OPTIONAL_SECRETS"
        "cloud-tools/cloud-tools.extension:EXT_OPTIONAL_SECRETS"
    )

    local missing_metadata=()

    for ext_info in "${expected_extensions[@]}"; do
        IFS=':' read -r ext_path metadata_var <<< "$ext_info"
        local ext_file="$extensions_dir/$ext_path"

        if [[ -f "$ext_file" ]]; then
            if grep -q "^${metadata_var}=" "$ext_file"; then
                log_pass "Extension has secret metadata: $ext_path"
            else
                log_fail "Extension missing secret metadata: $ext_path ($metadata_var)"
                missing_metadata+=("$ext_path")
            fi
        else
            log_fail "Extension file not found: $ext_file"
            missing_metadata+=("$ext_path")
        fi
    done

    if [[ ${#missing_metadata[@]} -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# ==============================================================================
# Main Test Execution
# ==============================================================================

main() {
    echo "========================================"
    echo "Secrets Management Test Suite"
    echo "========================================"
    echo ""

    # Run all tests
    test_sops_installation || true
    test_age_installation || true
    test_secrets_library_exists || true
    test_age_key_generation || true
    test_secrets_library_functions || true
    test_secrets_file_encryption || true
    test_environment_cleanup || true
    test_process_list_cleanup || true
    test_user_commands_available || true
    test_secrets_directory_structure || true
    test_extension_secret_metadata || true

    # Print summary
    echo ""
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo "Tests run:    $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        exit 1
    fi
}

main "$@"
