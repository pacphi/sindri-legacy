#!/bin/bash
# Integration tests for protected extension upgrades

set -euo pipefail

test_workspace_structure_upgrade() {
    print_status "Testing workspace-structure upgrade..."

    if ! extension-manager upgrade workspace-structure; then
        print_error "workspace-structure upgrade failed"
        return 1
    fi

    print_success "workspace-structure upgrade passed"
}

test_mise_config_upgrade() {
    print_status "Testing mise-config upgrade..."

    # Dry-run first
    if ! DRY_RUN=true extension-manager upgrade mise-config; then
        print_error "mise-config dry-run upgrade failed"
        return 1
    fi

    # Actual upgrade
    if ! extension-manager upgrade mise-config; then
        print_error "mise-config upgrade failed"
        return 1
    fi

    print_success "mise-config upgrade passed"
}

test_ssh_environment_upgrade() {
    print_status "Testing ssh-environment upgrade..."

    if ! extension-manager upgrade ssh-environment; then
        print_error "ssh-environment upgrade failed"
        return 1
    fi

    print_success "ssh-environment upgrade passed"
}

main() {
    print_status "Testing protected extensions upgrade workflow..."
    echo ""

    test_workspace_structure_upgrade
    test_mise_config_upgrade
    test_ssh_environment_upgrade

    echo ""
    print_success "All protected extension upgrade tests passed!"
}

main "$@"
