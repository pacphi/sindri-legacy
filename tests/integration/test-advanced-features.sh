#!/bin/bash
# Integration tests for advanced upgrade features

set -euo pipefail

test_upgrade_history() {
    print_status "Testing upgrade history tracking..."

    # Perform upgrade
    if ! extension-manager upgrade nodejs; then
        print_error "Upgrade failed"
        return 1
    fi

    # Check history
    local history_file="$HOME/.local/share/extension-manager/upgrade-history.log"
    if [[ ! -f "$history_file" ]]; then
        print_error "History file not created"
        return 1
    fi

    if ! grep -q "nodejs" "$history_file"; then
        print_error "Upgrade not recorded in history"
        return 1
    fi

    print_success "Upgrade history test passed"
}

test_rollback() {
    print_status "Testing rollback functionality..."

    # This is a basic test - just verify command works
    if ! extension-manager rollback nodejs; then
        print_error "Rollback failed"
        return 1
    fi

    print_success "Rollback test passed"
}

main() {
    print_status "Testing advanced upgrade features..."
    echo ""

    test_upgrade_history
    test_rollback

    echo ""
    print_success "All advanced feature tests passed!"
}

main "$@"
