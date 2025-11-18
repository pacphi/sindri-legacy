#!/bin/bash
# Test settings.json validation for claude-marketplace extension
# Tests validation logic for marketplace configuration

set -e

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"
source "$SCRIPT_DIR/lib/assertions.sh"

# Mark test start
mark_test_phase "Settings Validation Test" "start"

print_section "Testing Settings.json Validation"

settings_json="$HOME/.claude/settings.json"

# Test 1: Verify settings.json exists
print_info "Test 1: Checking settings.json exists..."
assert_file_exists "$settings_json" "settings.json should exist after installation"
print_success "settings.json exists"

# Test 2: Validate JSON syntax
print_info "Test 2: Validating JSON syntax..."
assert_command_exists "jq" "jq should be installed"

if jq empty "$settings_json" 2>/dev/null; then
    print_success "JSON syntax is valid"
else
    print_error "JSON syntax is invalid"
    exit 1
fi

# Test 3: Check required Claude settings keys
print_info "Test 3: Checking base Claude settings..."

# Check for standard Claude settings (may or may not be present)
for key in '$schema' 'model' 'alwaysThinkingEnabled'; do
    if jq -e ".$key" "$settings_json" >/dev/null 2>&1; then
        print_info "Found optional setting: $key"
    fi
done
print_success "Base settings check complete"

# Test 4: Validate extraKnownMarketplaces structure
print_info "Test 4: Validating extraKnownMarketplaces structure..."

if jq -e '.extraKnownMarketplaces' "$settings_json" >/dev/null 2>&1; then
    marketplace_type=$(jq -r '.extraKnownMarketplaces | type' "$settings_json")

    if [ "$marketplace_type" = "object" ]; then
        print_success "extraKnownMarketplaces is valid object type"
    else
        print_error "extraKnownMarketplaces is not object type (found: $marketplace_type)"
        exit 1
    fi

    marketplace_count=$(jq -r '.extraKnownMarketplaces | length' "$settings_json")
    print_info "Found $marketplace_count configured marketplaces"

    # Validate each marketplace has required structure
    marketplace_names=$(jq -r '.extraKnownMarketplaces | keys[]' "$settings_json" 2>/dev/null || echo "")

    for marketplace in $marketplace_names; do
        print_info "Validating marketplace: $marketplace"

        # Check source exists
        if ! jq -e ".extraKnownMarketplaces[\"$marketplace\"].source" "$settings_json" >/dev/null 2>&1; then
            print_error "Marketplace '$marketplace' missing source"
            exit 1
        fi

        # Check source.source exists
        source_type=$(jq -r ".extraKnownMarketplaces[\"$marketplace\"].source.source" "$settings_json" 2>/dev/null || echo "null")
        if [ "$source_type" = "null" ]; then
            print_error "Marketplace '$marketplace' missing source.source"
            exit 1
        fi

        # Validate source type is one of: github, git, directory
        if [[ "$source_type" =~ ^(github|git|directory)$ ]]; then
            print_info "  Source type: $source_type ✓"
        else
            print_error "Invalid source type for '$marketplace': $source_type"
            exit 1
        fi

        # Check source.repo for github sources
        if [ "$source_type" = "github" ]; then
            repo=$(jq -r ".extraKnownMarketplaces[\"$marketplace\"].source.repo" "$settings_json" 2>/dev/null || echo "null")
            if [ "$repo" != "null" ] && [ -n "$repo" ]; then
                print_info "  Repo: $repo ✓"
            else
                print_error "Marketplace '$marketplace' with source 'github' missing source.repo"
                exit 1
            fi
        fi
    done

    print_success "All marketplaces have valid structure"
else
    print_warning "extraKnownMarketplaces not found (optional)"
fi

# Test 5: Validate enabledPlugins structure
print_info "Test 5: Validating enabledPlugins structure..."

if jq -e '.enabledPlugins' "$settings_json" >/dev/null 2>&1; then
    plugins_type=$(jq -r '.enabledPlugins | type' "$settings_json")

    if [ "$plugins_type" = "object" ]; then
        print_success "enabledPlugins is valid object type"
    else
        print_error "enabledPlugins is not object type (found: $plugins_type)"
        exit 1
    fi

    plugin_count=$(jq -r '.enabledPlugins | length' "$settings_json")
    print_info "Found $plugin_count enabled plugins"

    # Test 6: Validate plugin references
    print_info "Test 6: Validating plugin references..."

    # Get list of known marketplace names
    marketplace_names=$(jq -r '.extraKnownMarketplaces // {} | keys[]' "$settings_json" 2>/dev/null || echo "")

    invalid_count=0
    while IFS= read -r plugin; do
        if [ -z "$plugin" ]; then
            continue
        fi

        # Check if plugin follows plugin@marketplace format
        if [[ "$plugin" =~ @ ]]; then
            marketplace="${plugin##*@}"
            plugin_name="${plugin%%@*}"

            # Check if marketplace is known
            if echo "$marketplace_names" | grep -q "^${marketplace}$"; then
                print_info "  $plugin_name → $marketplace ✓"
            else
                print_warning "Plugin '$plugin' references unknown marketplace: $marketplace"
                invalid_count=$((invalid_count + 1))
            fi
        else
            print_warning "Plugin '$plugin' does not follow plugin@marketplace format"
            invalid_count=$((invalid_count + 1))
        fi
    done < <(jq -r '.enabledPlugins | to_entries[] | select(.value == true) | .key' "$settings_json" 2>/dev/null)

    if [ $invalid_count -eq 0 ]; then
        print_success "All plugin references are valid"
    else
        print_warning "$invalid_count plugin(s) have invalid references"
    fi
else
    print_warning "enabledPlugins not found (optional)"
fi

# Test 7: Test validation with corrupt JSON
print_info "Test 7: Testing validation with corrupt JSON..."

# Create a backup
backup_file="/tmp/settings-backup-$$.json"
cp "$settings_json" "$backup_file"

# Create corrupt JSON
echo "{ invalid json" > "$settings_json"

# Run extension validation (should fail)
if /workspace/docker/lib/extensions.d/claude-marketplace/claude-marketplace.extension validate 2>/dev/null; then
    print_error "Validation should have failed for corrupt JSON"
    cp "$backup_file" "$settings_json"
    rm -f "$backup_file"
    exit 1
else
    print_success "Validation correctly failed for corrupt JSON"
fi

# Restore backup
cp "$backup_file" "$settings_json"
rm -f "$backup_file"

# Test 8: Verify validation passes with good JSON
print_info "Test 8: Testing validation with valid JSON..."

if /workspace/docker/lib/extensions.d/claude-marketplace/claude-marketplace.extension validate 2>&1 | grep -q "Validation passed"; then
    print_success "Validation passes with valid JSON"
else
    print_error "Validation failed with valid JSON"
    exit 1
fi

# Test 9: Check backup creation
print_info "Test 9: Checking backup functionality..."

backup_dir="$HOME/.claude/backups"
if [ -d "$backup_dir" ]; then
    backup_count=$(find "$backup_dir" -name "settings-*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
    print_success "Backup directory exists with $backup_count backup(s)"

    # Verify backup files are valid JSON
    for backup in "$backup_dir"/settings-*.json; do
        if [ -f "$backup" ]; then
            if jq empty "$backup" 2>/dev/null; then
                print_info "  Backup is valid JSON: $(basename "$backup")"
            else
                print_warning "  Backup has invalid JSON: $(basename "$backup")"
            fi
        fi
    done
else
    print_info "No backup directory found (backups created on first modification)"
fi

# Mark test success
mark_test_phase "Settings Validation Test" "success"
print_success "All settings validation tests passed"
