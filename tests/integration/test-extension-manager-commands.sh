#!/bin/bash
# Integration tests for extension-manager upgrade commands

set -euo pipefail

test_upgrade_single_extension() {
    print_status "Testing 'extension-manager upgrade <name>'..."

    # Test upgrade nodejs
    if ! extension-manager upgrade nodejs; then
        print_error "upgrade nodejs failed"
        return 1
    fi

    print_success "upgrade <name> command passed"
}

test_upgrade_all_dry_run() {
    print_status "Testing 'extension-manager upgrade-all --dry-run'..."

    if ! extension-manager upgrade-all --dry-run; then
        print_error "upgrade-all --dry-run failed"
        return 1
    fi

    print_success "upgrade-all --dry-run command passed"
}

test_upgrade_all() {
    print_status "Testing 'extension-manager upgrade-all'..."

    if ! extension-manager upgrade-all; then
        print_error "upgrade-all failed"
        return 1
    fi

    print_success "upgrade-all command passed"
}

test_check_updates() {
    print_status "Testing 'extension-manager check-updates'..."

    if ! extension-manager check-updates; then
        print_error "check-updates failed"
        return 1
    fi

    print_success "check-updates command passed"
}

test_help_text() {
    print_status "Testing help text includes new commands..."

    local help_output
    help_output=$(extension-manager --help)

    if ! echo "$help_output" | grep -q "upgrade <name>"; then
        print_error "Help text missing 'upgrade <name>'"
        return 1
    fi

    if ! echo "$help_output" | grep -q "upgrade-all"; then
        print_error "Help text missing 'upgrade-all'"
        return 1
    fi

    if ! echo "$help_output" | grep -q "check-updates"; then
        print_error "Help text missing 'check-updates'"
        return 1
    fi

    print_success "Help text validation passed"
}

main() {
    print_status "Testing extension-manager upgrade commands..."
    echo ""

    test_help_text
    test_upgrade_single_extension
    test_upgrade_all_dry_run
    test_check_updates
    test_upgrade_all

    echo ""
    print_success "All extension-manager command tests passed!"
}

main "$@"
