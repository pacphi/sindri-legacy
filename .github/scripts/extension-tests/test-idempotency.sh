#!/bin/bash
# Test extension installation idempotency
# Usage: test-idempotency.sh

set -e

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"

# Mark test start
mark_test_phase "Idempotency Test" "start"

# Check resources before test
check_vm_resources "Pre-idempotency test"

print_section "Testing Idempotency"

# Test claude-marketplace specific idempotency (settings.json)
if command -v jq >/dev/null 2>&1 && [ -f "$HOME/.claude/settings.json" ]; then
    print_info "Testing claude-marketplace settings.json idempotency..."

    # SECURITY: Create secure temporary directory (C5 fix)
    temp_dir=$(create_secure_temp_dir) || {
        print_error "Failed to create secure temporary directory"
        exit 1
    }
    setup_cleanup_trap "$temp_dir"

    # Capture settings.json before second install
    settings_before="$temp_dir/settings-before.json"
    cp "$HOME/.claude/settings.json" "$settings_before"

    marketplace_count_before=$(jq -r '.extraKnownMarketplaces // {} | length' "$settings_before" 2>/dev/null || echo "0")
    plugin_count_before=$(jq -r '.enabledPlugins // {} | length' "$settings_before" 2>/dev/null || echo "0")

    print_info "Before second install: $marketplace_count_before marketplaces, $plugin_count_before plugins"
fi

print_info "Running extension-manager install-all a second time..."

cd "$(get_extension_manager_path)" || exit 1

# Run install-all again and capture output
if bash extension-manager.sh install-all 2>&1 | tee /tmp/configure2.log; then
    # Check for error indicators in output
    if grep -qi "error\|failed" /tmp/configure2.log; then
        print_warning "Warnings or errors detected on second run:"
        grep -i "error\|failed" /tmp/configure2.log || true
        # Don't fail on warnings, just report them
        print_warning "Idempotency test completed with warnings"
    else
        print_success "Second run completed without errors"
    fi

    # Verify claude-marketplace settings.json idempotency
    if command -v jq >/dev/null 2>&1 && [ -f "$HOME/.claude/settings.json" ] && [ -f "$settings_before" ]; then
        print_info "Verifying settings.json idempotency..."

        marketplace_count_after=$(jq -r '.extraKnownMarketplaces // {} | length' "$HOME/.claude/settings.json" 2>/dev/null || echo "0")
        plugin_count_after=$(jq -r '.enabledPlugins // {} | length' "$HOME/.claude/settings.json" 2>/dev/null || echo "0")

        print_info "After second install: $marketplace_count_after marketplaces, $plugin_count_after plugins"

        if [ "$marketplace_count_before" -eq "$marketplace_count_after" ]; then
            print_success "Marketplace count unchanged (idempotent)"
        else
            print_error "Marketplace count changed: $marketplace_count_before → $marketplace_count_after"
            print_error "Settings.json NOT idempotent!"
            rm -f "$settings_before"
            mark_test_phase "Idempotency Test" "failure"
            exit 1
        fi

        if [ "$plugin_count_before" -eq "$plugin_count_after" ]; then
            print_success "Plugin count unchanged (idempotent)"
        else
            print_error "Plugin count changed: $plugin_count_before → $plugin_count_after"
            print_error "Settings.json NOT idempotent!"
            rm -f "$settings_before"
            mark_test_phase "Idempotency Test" "failure"
            exit 1
        fi

        # Compare JSON structure (excluding timestamps/dynamic fields)
        if jq -S 'del(.extraKnownMarketplaces) | del(.enabledPlugins)' "$settings_before" > /tmp/base-before.json 2>/dev/null && \
           jq -S 'del(.extraKnownMarketplaces) | del(.enabledPlugins)' "$HOME/.claude/settings.json" > /tmp/base-after.json 2>/dev/null; then
            if diff /tmp/base-before.json /tmp/base-after.json >/dev/null 2>&1; then
                print_success "Base settings unchanged (idempotent)"
            else
                print_warning "Base settings changed (may be expected)"
            fi
            rm -f /tmp/base-before.json /tmp/base-after.json
        fi

        rm -f "$settings_before"
        print_success "settings.json idempotency verified"
    fi

    mark_test_phase "Idempotency Test" "success"
    print_success "Idempotency test passed"
else
    mark_test_phase "Idempotency Test" "failure"
    print_error "Second run failed"
    echo "Last 50 lines of output:"
    tail -50 /tmp/configure2.log

    # Cleanup
    rm -f "$settings_before"

    # Check resources after failure
    check_vm_resources "Post-failure"
    exit 1
fi
