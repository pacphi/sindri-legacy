#!/bin/bash
# System-wide tests for all extensions upgrade

set -euo pipefail

test_all_extensions_have_upgrade() {
    print_status "Verifying all extensions implement upgrade()..."

    local -a extensions=()
    local manifest="/workspace/scripts/lib/extensions.d/active-extensions.conf"

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        extensions+=("$line")
    done < "$manifest"

    local missing_upgrade=0

    for ext in "${extensions[@]}"; do
        local ext_file="/workspace/scripts/lib/extensions.d/${ext}.extension"

        if [[ ! -f "$ext_file" ]]; then
            print_error "Extension file not found: ${ext_file}"
            ((missing_upgrade++))
            continue
        fi

        # Check if upgrade() function exists
        if ! grep -q "^upgrade()" "$ext_file"; then
            print_error "${ext} missing upgrade() function"
            ((missing_upgrade++))
        else
            print_success "${ext} has upgrade() function"
        fi
    done

    if [[ $missing_upgrade -eq 0 ]]; then
        print_success "All extensions have upgrade() function"
        return 0
    else
        print_error "${missing_upgrade} extensions missing upgrade()"
        return 1
    fi
}

test_all_extensions_have_metadata() {
    print_status "Verifying all extensions have required metadata..."

    local -a extensions=()
    local manifest="/workspace/scripts/lib/extensions.d/active-extensions.conf"

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        extensions+=("$line")
    done < "$manifest"

    local missing_metadata=0

    for ext in "${extensions[@]}"; do
        local ext_file="/workspace/scripts/lib/extensions.d/${ext}.extension"

        if [[ ! -f "$ext_file" ]]; then
            continue
        fi

        # Check for EXT_INSTALL_METHOD
        if ! grep -q "^EXT_INSTALL_METHOD=" "$ext_file"; then
            print_error "${ext} missing EXT_INSTALL_METHOD"
            ((missing_metadata++))
        fi

        # Check for EXT_UPGRADE_STRATEGY
        if ! grep -q "^EXT_UPGRADE_STRATEGY=" "$ext_file"; then
            print_error "${ext} missing EXT_UPGRADE_STRATEGY"
            ((missing_metadata++))
        fi
    done

    if [[ $missing_metadata -eq 0 ]]; then
        print_success "All extensions have required metadata"
        return 0
    else
        print_error "${missing_metadata} metadata fields missing"
        return 1
    fi
}

test_upgrade_all_dry_run() {
    print_status "Testing upgrade-all --dry-run..."

    if ! extension-manager upgrade-all --dry-run; then
        print_error "upgrade-all --dry-run failed"
        return 1
    fi

    print_success "Dry-run upgrade-all passed"
}

test_upgrade_all_actual() {
    print_status "Testing actual upgrade-all..."

    if ! extension-manager upgrade-all; then
        print_error "upgrade-all failed"
        return 1
    fi

    print_success "Actual upgrade-all passed"
}

test_validate_all_after_upgrade() {
    print_status "Validating all extensions after upgrade..."

    if ! extension-manager validate-all; then
        print_error "validate-all failed after upgrade"
        return 1
    fi

    print_success "All extensions validated successfully"
}

main() {
    print_status "Running system-wide extension upgrade tests..."
    echo ""

    test_all_extensions_have_upgrade
    echo ""

    test_all_extensions_have_metadata
    echo ""

    test_upgrade_all_dry_run
    echo ""

    test_upgrade_all_actual
    echo ""

    test_validate_all_after_upgrade
    echo ""

    print_success "All system-wide upgrade tests passed!"
}

main "$@"
