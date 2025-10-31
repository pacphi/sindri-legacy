#!/bin/bash
# Integration tests for mise-powered extension upgrades

set -euo pipefail

test_nodejs_upgrade() {
    print_status "Testing nodejs upgrade..."

    # Dry-run
    if ! DRY_RUN=true extension-manager upgrade nodejs; then
        print_error "nodejs dry-run failed"
        return 1
    fi

    # Actual upgrade
    if ! extension-manager upgrade nodejs; then
        print_error "nodejs upgrade failed"
        return 1
    fi

    # Validate
    if ! extension-manager validate nodejs; then
        print_error "nodejs validation failed after upgrade"
        return 1
    fi

    print_success "nodejs upgrade passed"
}

test_python_upgrade() {
    print_status "Testing python upgrade..."

    if ! extension-manager upgrade python; then
        print_error "python upgrade failed"
        return 1
    fi

    if ! extension-manager validate python; then
        print_error "python validation failed after upgrade"
        return 1
    fi

    print_success "python upgrade passed"
}

test_all_mise_extensions() {
    local -a mise_extensions=("nodejs" "python" "rust" "golang" "nodejs-devtools")

    for ext in "${mise_extensions[@]}"; do
        print_status "Testing ${ext} upgrade..."

        if ! extension-manager upgrade "$ext"; then
            print_error "${ext} upgrade failed"
            return 1
        fi

        if ! extension-manager validate "$ext"; then
            print_error "${ext} validation failed"
            return 1
        fi

        print_success "${ext} upgrade passed"
    done
}

main() {
    print_status "Testing mise-powered extensions upgrade workflow..."
    echo ""

    test_nodejs_upgrade
    test_python_upgrade
    test_all_mise_extensions

    echo ""
    print_success "All mise extension upgrade tests passed!"
}

main "$@"
