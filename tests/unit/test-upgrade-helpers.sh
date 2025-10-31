#!/bin/bash
# Unit tests for upgrade helper functions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../../docker/lib"

# Source common and extensions-common
source "$LIB_DIR/common.sh"
source "$LIB_DIR/extensions-common.sh"

test_is_dry_run() {
    print_status "Testing is_dry_run()..."

    # Test default (not dry-run)
    if is_dry_run; then
        print_error "is_dry_run() should return false by default"
        return 1
    fi

    # Test dry-run mode
    DRY_RUN=true
    if ! is_dry_run; then
        print_error "is_dry_run() should return true when DRY_RUN=true"
        return 1
    fi

    unset DRY_RUN
    print_success "is_dry_run() tests passed"
}

test_dry_run_prefix() {
    print_status "Testing dry_run_prefix()..."

    # Test default (no prefix)
    local prefix
    prefix=$(dry_run_prefix)
    if [[ -n "$prefix" ]]; then
        print_error "dry_run_prefix() should return empty string by default"
        return 1
    fi

    # Test dry-run mode
    DRY_RUN=true
    prefix=$(dry_run_prefix)
    if [[ "$prefix" != "[DRY-RUN] " ]]; then
        print_error "dry_run_prefix() should return '[DRY-RUN] ' when DRY_RUN=true"
        return 1
    fi

    unset DRY_RUN
    print_success "dry_run_prefix() tests passed"
}

test_version_gt() {
    print_status "Testing version_gt()..."

    # Test: 2.0.0 > 1.9.0
    if ! version_gt "2.0.0" "1.9.0"; then
        print_error "version_gt('2.0.0', '1.9.0') should return true"
        return 1
    fi

    # Test: 1.9.0 < 2.0.0
    if version_gt "1.9.0" "2.0.0"; then
        print_error "version_gt('1.9.0', '2.0.0') should return false"
        return 1
    fi

    # Test: 1.0.0 == 1.0.0
    if version_gt "1.0.0" "1.0.0"; then
        print_error "version_gt('1.0.0', '1.0.0') should return false"
        return 1
    fi

    print_success "version_gt() tests passed"
}

# Run tests
main() {
    print_status "Running upgrade helper unit tests..."
    echo ""

    test_is_dry_run
    test_dry_run_prefix
    test_version_gt

    echo ""
    print_success "All upgrade helper tests passed!"
}

main "$@"
