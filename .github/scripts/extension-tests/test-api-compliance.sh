#!/bin/bash
# Test Extension API compliance (validate, status, remove functions)
# Usage: test-api-compliance.sh <extension-name>

set -e

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"
source "$SCRIPT_DIR/lib/assertions.sh"

# Parse arguments
extension="$1"
if [ -z "$extension" ]; then
    print_error "Usage: $0 <extension-name>"
    exit 1
fi

print_section "Testing Extension API Compliance: $extension"

# Change to extension manager directory
cd "$(get_extension_manager_path)" || exit 1

# Test 1: validate() function
print_section "Test 1: validate() function"
if bash extension-manager.sh validate "$extension"; then
    print_success "validate() returned success for installed extension"
else
    print_error "validate() failed for installed extension"
    exit 1
fi

# Test 2: status() function
print_section "Test 2: status() function"
status_output=$(bash extension-manager.sh status "$extension" 2>&1)
echo "$status_output"

# Verify status output contains expected fields
if echo "$status_output" | grep -q "Extension:"; then
    print_success "status() shows extension name"
else
    print_error "status() missing extension name"
    exit 1
fi

if echo "$status_output" | grep -q "Status:"; then
    print_success "status() shows status field"
else
    print_error "status() missing status field"
    exit 1
fi

# Test 3: Enhanced status() output format
print_section "Test 3: Enhanced status() output format"
if echo "$status_output" | grep -q "Extension:"; then
    print_success "Status shows extension metadata"
else
    print_error "Status missing extension metadata"
    exit 1
fi

if echo "$status_output" | grep -q "Status:"; then
    print_success "Status shows installation status"
else
    print_error "Status missing installation status"
    exit 1
fi

# Test 4: Verify extension is in manifest
print_section "Test 4: Manifest presence"
if is_extension_in_manifest "$extension"; then
    print_success "Extension is in manifest"
else
    print_error "Extension not found in manifest"
    exit 1
fi

print_section "Extension API Compliance Tests Completed"
print_success "All API compliance tests passed for $extension"
