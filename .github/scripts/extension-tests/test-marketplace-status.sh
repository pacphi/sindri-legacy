#!/bin/bash
# Test status() function for claude-marketplace extension
# Tests status output and information display

set -e

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"
source "$SCRIPT_DIR/lib/assertions.sh"

# Mark test start
mark_test_phase "Marketplace Status Test" "start"

print_section "Testing Marketplace Status Output"

extension_script="/workspace/docker/lib/extensions.d/claude-marketplace/claude-marketplace.extension"
settings_json="$HOME/.claude/settings.json"

# Test 1: Verify extension script exists
print_info "Test 1: Checking extension script..."
assert_file_exists "$extension_script" "Extension script should exist"
print_success "Extension script found"

# Test 2: Test status command runs without error
print_info "Test 2: Running status command..."

if $extension_script status >/dev/null 2>&1; then
    print_success "Status command runs without error"
else
    print_error "Status command failed"
    exit 1
fi

# Test 3: Capture and parse status output
print_info "Test 3: Capturing status output..."

status_output=$($extension_script status 2>&1)

# Check for key sections in output
if echo "$status_output" | grep -q "Status:"; then
    print_success "Status output contains status indicator"
else
    print_error "Status output missing status indicator"
    exit 1
fi

# Test 4: Check installation status
print_info "Test 4: Checking installation status..."

if echo "$status_output" | grep -q "Status: ✓ INSTALLED"; then
    print_success "Extension shows as installed"
elif echo "$status_output" | grep -q "Status: ✗ NOT INSTALLED"; then
    print_error "Extension shows as not installed"
    exit 1
else
    print_warning "Status indicator unclear"
fi

# Test 5: Check settings file is mentioned
print_info "Test 5: Checking settings file reference..."

if echo "$status_output" | grep -q "Settings File:"; then
    print_success "Status output includes settings file section"
else
    print_error "Status output missing settings file section"
    exit 1
fi

if echo "$status_output" | grep -q "$settings_json"; then
    print_success "Settings path is shown: $settings_json"
else
    print_error "Settings path not shown in output"
    exit 1
fi

# Test 6: Check marketplace configuration is shown
print_info "Test 6: Checking marketplace configuration display..."

if echo "$status_output" | grep -q "Configured Marketplaces:"; then
    print_success "Status output includes marketplace configuration"
else
    print_error "Status output missing marketplace configuration"
    exit 1
fi

# Count displayed marketplaces
marketplace_count=$(jq -r '.extraKnownMarketplaces // {} | length' "$settings_json" 2>/dev/null || echo "0")
print_info "Expected marketplace count: $marketplace_count"

if [ "$marketplace_count" -gt 0 ]; then
    if echo "$status_output" | grep -q "Total: $marketplace_count"; then
        print_success "Marketplace count displayed correctly"
    else
        # Check if output shows any marketplace count
        if echo "$status_output" | grep -q "Total:"; then
            print_warning "Marketplace count shown but may not match"
        else
            print_error "Marketplace count not displayed"
            exit 1
        fi
    fi
fi

# Test 7: Check enabled plugins are shown
print_info "Test 7: Checking enabled plugins display..."

if echo "$status_output" | grep -q "Enabled Plugins:"; then
    print_success "Status output includes enabled plugins section"
else
    print_error "Status output missing enabled plugins section"
    exit 1
fi

# Count displayed plugins
plugin_count=$(jq -r '.enabledPlugins // [] | length' "$settings_json" 2>/dev/null || echo "0")
print_info "Expected plugin count: $plugin_count"

if [ "$plugin_count" -gt 0 ]; then
    if echo "$status_output" | grep -q "Total: $plugin_count"; then
        print_success "Plugin count displayed correctly"
    else
        # Check if output shows any plugin count
        if echo "$status_output" | grep -q "Total:"; then
            print_warning "Plugin count shown but may not match"
        else
            print_error "Plugin count not displayed"
            exit 1
        fi
    fi
fi

# Test 8: Check YAML configuration is mentioned
print_info "Test 8: Checking YAML configuration reference..."

if echo "$status_output" | grep -q "YAML Configuration:"; then
    print_success "Status output includes YAML configuration section"
else
    print_error "Status output missing YAML configuration section"
    exit 1
fi

# Test 9: Check management commands are shown
print_info "Test 9: Checking management commands display..."

if echo "$status_output" | grep -q "Management:"; then
    print_success "Status output includes management commands"
else
    print_error "Status output missing management commands"
    exit 1
fi

# Verify key management commands are mentioned
required_commands=("Edit YAML" "Reinstall" "View settings")
for cmd in "${required_commands[@]}"; do
    if echo "$status_output" | grep -q "$cmd"; then
        print_info "  Found command: $cmd ✓"
    else
        print_warning "  Missing command: $cmd"
    fi
done

# Test 10: Verify status shows marketplace details
print_info "Test 10: Verifying marketplace details..."

if [ "$marketplace_count" -gt 0 ]; then
    # Get first marketplace name
    first_marketplace=$(jq -r '.extraKnownMarketplaces // {} | keys[0]' "$settings_json" 2>/dev/null || echo "")

    if [ -n "$first_marketplace" ]; then
        if echo "$status_output" | grep -q "$first_marketplace"; then
            print_success "Marketplace name shown in output: $first_marketplace"
        else
            print_warning "Marketplace name not found in output: $first_marketplace"
        fi

        # Check if source repo is shown
        source_repo=$(jq -r ".extraKnownMarketplaces[\"$first_marketplace\"].source.repo // empty" "$settings_json" 2>/dev/null || echo "")
        if [ -n "$source_repo" ]; then
            if echo "$status_output" | grep -q "$source_repo"; then
                print_success "Source repo shown in output: $source_repo"
            else
                print_warning "Source repo not found in output: $source_repo"
            fi
        fi
    fi
fi

# Test 11: Test status with missing settings.json
print_info "Test 11: Testing status with missing settings.json..."

# Backup settings
backup_file="/tmp/settings-backup-$$.json"
if [ -f "$settings_json" ]; then
    mv "$settings_json" "$backup_file"
fi

# Run status (should indicate not installed)
status_output_missing=$($extension_script status 2>&1 || true)

if echo "$status_output_missing" | grep -q "NOT INSTALLED"; then
    print_success "Status correctly reports not installed when settings.json missing"
else
    print_error "Status did not report not installed when settings.json missing"
    # Restore backup
    if [ -f "$backup_file" ]; then
        mv "$backup_file" "$settings_json"
    fi
    exit 1
fi

# Restore backup
if [ -f "$backup_file" ]; then
    mv "$backup_file" "$settings_json"
fi

# Test 12: Verify status displays note about automatic installation
print_info "Test 12: Checking automatic installation note..."

if echo "$status_output" | grep -qi "automatic"; then
    print_success "Status mentions automatic installation"
else
    print_warning "Status doesn't mention automatic installation"
fi

# Mark test success
mark_test_phase "Marketplace Status Test" "success"
print_success "All marketplace status tests passed"

# Display sample output
print_section "Sample Status Output"
$extension_script status
