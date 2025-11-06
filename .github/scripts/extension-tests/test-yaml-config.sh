#!/bin/bash
# Test YAML configuration processing for claude-marketplace extension
# Tests YAML→JSON→settings.json workflow

set -e

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"
source "$SCRIPT_DIR/lib/assertions.sh"

# Mark test start
mark_test_phase "YAML Configuration Test" "start"

print_section "Testing YAML Configuration Processing"

# Test 1: Verify YAML template exists
print_info "Test 1: Checking YAML template..."
if [ -n "$CI_MODE" ]; then
    yaml_template="/workspace/marketplaces.ci.yml.example"
else
    yaml_template="/workspace/marketplaces.yml.example"
fi

assert_file_exists "$yaml_template" "YAML template should exist"
print_success "YAML template found: $yaml_template"

# Test 2: Verify YAML working file exists
print_info "Test 2: Checking YAML working file..."
if [ -n "$CI_MODE" ]; then
    yaml_file="/workspace/marketplaces.ci.yml"
else
    yaml_file="/workspace/marketplaces.yml"
fi

assert_file_exists "$yaml_file" "YAML working file should exist after installation"
print_success "YAML working file found: $yaml_file"

# Test 3: Validate YAML syntax
print_info "Test 3: Validating YAML syntax..."
assert_command_exists "yq" "yq should be installed"

if yq eval '.' "$yaml_file" >/dev/null 2>&1; then
    print_success "YAML syntax is valid"
else
    print_error "YAML syntax validation failed"
    exit 1
fi

# Test 4: Check YAML structure
print_info "Test 4: Checking YAML structure..."

# Check for extraKnownMarketplaces
if yq eval '.extraKnownMarketplaces' "$yaml_file" >/dev/null 2>&1; then
    print_success "extraKnownMarketplaces section exists"
else
    print_error "extraKnownMarketplaces section missing"
    exit 1
fi

# Check for enabledPlugins
if yq eval '.enabledPlugins' "$yaml_file" >/dev/null 2>&1; then
    print_success "enabledPlugins section exists"
else
    print_error "enabledPlugins section missing"
    exit 1
fi

# Count marketplaces and plugins
marketplace_count=$(yq eval '.extraKnownMarketplaces | length' "$yaml_file" 2>/dev/null || echo "0")
plugin_count=$(yq eval '.enabledPlugins | length' "$yaml_file" 2>/dev/null || echo "0")

print_info "Found $marketplace_count marketplaces and $plugin_count plugins in YAML"

# Test 5: Convert YAML to JSON
print_info "Test 5: Testing YAML to JSON conversion..."
temp_json="/tmp/test-marketplaces-$$.json"

if yq eval -o=json "$yaml_file" > "$temp_json" 2>/dev/null; then
    print_success "YAML converted to JSON successfully"
else
    print_error "YAML to JSON conversion failed"
    rm -f "$temp_json"
    exit 1
fi

# Test 6: Validate generated JSON
print_info "Test 6: Validating generated JSON..."
assert_command_exists "jq" "jq should be installed"

if jq empty "$temp_json" 2>/dev/null; then
    print_success "Generated JSON is valid"
else
    print_error "Generated JSON is invalid"
    rm -f "$temp_json"
    exit 1
fi

# Test 7: Verify JSON structure
print_info "Test 7: Verifying JSON structure..."

# Check extraKnownMarketplaces is object
marketplace_type=$(jq -r '.extraKnownMarketplaces | type' "$temp_json" 2>/dev/null || echo "null")
if [ "$marketplace_type" = "object" ]; then
    print_success "extraKnownMarketplaces is object type"
else
    print_error "extraKnownMarketplaces is not object type (found: $marketplace_type)"
    rm -f "$temp_json"
    exit 1
fi

# Check enabledPlugins is array
plugins_type=$(jq -r '.enabledPlugins | type' "$temp_json" 2>/dev/null || echo "null")
if [ "$plugins_type" = "array" ]; then
    print_success "enabledPlugins is array type"
else
    print_error "enabledPlugins is not array type (found: $plugins_type)"
    rm -f "$temp_json"
    exit 1
fi

# Verify counts match
json_marketplace_count=$(jq -r '.extraKnownMarketplaces | length' "$temp_json" 2>/dev/null || echo "0")
json_plugin_count=$(jq -r '.enabledPlugins | length' "$temp_json" 2>/dev/null || echo "0")

if [ "$marketplace_count" -eq "$json_marketplace_count" ]; then
    print_success "Marketplace count matches ($marketplace_count)"
else
    print_error "Marketplace count mismatch (YAML: $marketplace_count, JSON: $json_marketplace_count)"
    rm -f "$temp_json"
    exit 1
fi

if [ "$plugin_count" -eq "$json_plugin_count" ]; then
    print_success "Plugin count matches ($plugin_count)"
else
    print_error "Plugin count mismatch (YAML: $plugin_count, JSON: $json_plugin_count)"
    rm -f "$temp_json"
    exit 1
fi

# Test 8: Verify settings.json was created
print_info "Test 8: Checking settings.json creation..."
settings_json="$HOME/.claude/settings.json"

assert_file_exists "$settings_json" "settings.json should be created"
print_success "settings.json exists: $settings_json"

# Test 9: Validate settings.json
print_info "Test 9: Validating settings.json..."

if jq empty "$settings_json" 2>/dev/null; then
    print_success "settings.json has valid JSON syntax"
else
    print_error "settings.json has invalid JSON syntax"
    rm -f "$temp_json"
    exit 1
fi

# Test 10: Verify marketplace config was merged
print_info "Test 10: Verifying marketplace configuration in settings.json..."

settings_marketplace_count=$(jq -r '.extraKnownMarketplaces // {} | length' "$settings_json" 2>/dev/null || echo "0")
settings_plugin_count=$(jq -r '.enabledPlugins // [] | length' "$settings_json" 2>/dev/null || echo "0")

if [ "$settings_marketplace_count" -ge "$marketplace_count" ]; then
    print_success "Marketplaces merged into settings.json ($settings_marketplace_count)"
else
    print_error "Expected at least $marketplace_count marketplaces, found $settings_marketplace_count"
    rm -f "$temp_json"
    exit 1
fi

if [ "$settings_plugin_count" -ge "$plugin_count" ]; then
    print_success "Plugins merged into settings.json ($settings_plugin_count)"
else
    print_error "Expected at least $plugin_count plugins, found $settings_plugin_count"
    rm -f "$temp_json"
    exit 1
fi

# Cleanup
rm -f "$temp_json"

# Mark test success
mark_test_phase "YAML Configuration Test" "success"
print_success "All YAML configuration tests passed"
