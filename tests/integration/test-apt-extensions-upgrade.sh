#!/bin/bash
# Integration tests for APT-based extension upgrades

set -euo pipefail

test_docker_upgrade() {
    print_status "Testing docker upgrade (mixed method)..."

    # Dry-run
    if ! DRY_RUN=true extension-manager upgrade docker; then
        print_error "docker dry-run failed"
        return 1
    fi

    # Actual upgrade
    if ! extension-manager upgrade docker; then
        print_error "docker upgrade failed"
        return 1
    fi

    # Validate
    if ! extension-manager validate docker; then
        print_error "docker validation failed after upgrade"
        return 1
    fi

    print_success "docker upgrade passed"
}

test_ruby_upgrade() {
    print_status "Testing ruby upgrade (mixed method)..."

    if ! extension-manager upgrade ruby; then
        print_error "ruby upgrade failed"
        return 1
    fi

    if ! extension-manager validate ruby; then
        print_error "ruby validation failed after upgrade"
        return 1
    fi

    print_success "ruby upgrade passed"
}

test_monitoring_upgrade() {
    print_status "Testing monitoring upgrade (APT only)..."

    if ! extension-manager upgrade monitoring; then
        print_error "monitoring upgrade failed"
        return 1
    fi

    print_success "monitoring upgrade passed"
}

main() {
    print_status "Testing APT-based extensions upgrade workflow..."
    echo ""

    test_docker_upgrade
    test_ruby_upgrade
    test_monitoring_upgrade

    echo ""
    print_success "All APT extension upgrade tests passed!"
}

main "$@"
