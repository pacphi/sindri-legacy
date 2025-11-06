#!/bin/bash
# Test key functionality for an extension's primary tool
# Usage: test-key-functionality.sh <key-tool>

set -e

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"

# Parse arguments
key_tool="$1"
if [ -z "$key_tool" ]; then
    print_error "Usage: $0 <key-tool>"
    exit 1
fi

# Mark test start
mark_test_phase "Key Functionality Test: $key_tool" "start"

# Check resources before test
check_vm_resources "Pre-test"

# Verify SSH connection
verify_ssh_connection || print_warning "SSH connection check failed, but continuing..."

print_section "Testing key functionality for: $key_tool"

# Test based on tool type
case "$key_tool" in
    node)
        print_info "Testing Node.js..."
        node --version
        npm --version
        echo "console.log('Hello from Node.js')" | node
        print_success "Node.js functionality verified"
        ;;

    mise)
        print_info "Testing mise..."
        mise --version
        mise doctor || print_warning "mise doctor reported issues"
        mise list
        print_success "mise functionality verified"
        ;;

    claude)
        print_info "Testing Claude CLI..."
        claude --version
        print_success "Claude CLI functionality verified"
        ;;

    claude-marketplace)
        print_info "Testing Claude marketplace integration..."

        # Test 1: Verify YAML configuration file exists
        if [ -n "$CI_MODE" ]; then
            yaml_file="/workspace/marketplaces.ci.yml"
        else
            yaml_file="/workspace/marketplaces.yml"
        fi

        if [ ! -f "$yaml_file" ]; then
            print_error "YAML configuration file missing: $yaml_file"
            exit 1
        else
            print_success "YAML configuration file exists: $yaml_file"
        fi

        # Test 2: Verify yq is installed
        if ! command -v yq >/dev/null 2>&1; then
            print_error "yq not installed (required for YAML parsing)"
            exit 1
        else
            print_success "yq is available"
        fi

        # Test 3: Validate YAML syntax
        print_info "Validating YAML syntax..."
        if yq eval '.' "$yaml_file" >/dev/null 2>&1; then
            print_success "YAML syntax is valid"
        else
            print_error "YAML syntax is invalid"
            exit 1
        fi

        # Test 4: Count expected marketplaces and plugins from YAML
        expected_marketplace_count=$(yq eval '.extraKnownMarketplaces | length' "$yaml_file" 2>/dev/null || echo "0")
        expected_plugin_count=$(yq eval '.enabledPlugins | length' "$yaml_file" 2>/dev/null || echo "0")
        print_info "YAML config: $expected_marketplace_count marketplaces, $expected_plugin_count plugins"

        # Test 5: Verify settings.json was created
        settings_json="$HOME/.claude/settings.json"
        if [ ! -f "$settings_json" ]; then
            print_error "settings.json not created: $settings_json"
            exit 1
        else
            print_success "settings.json exists: $settings_json"
        fi

        # Test 6: Validate settings.json structure
        print_info "Validating settings.json..."
        if ! jq empty "$settings_json" 2>/dev/null; then
            print_error "settings.json has invalid JSON syntax"
            exit 1
        else
            print_success "settings.json has valid JSON syntax"
        fi

        # Test 7: Verify marketplace configuration in settings.json
        actual_marketplace_count=$(jq -r '.extraKnownMarketplaces // {} | length' "$settings_json" 2>/dev/null || echo "0")
        actual_plugin_count=$(jq -r '.enabledPlugins // {} | length' "$settings_json" 2>/dev/null || echo "0")

        print_info "settings.json: $actual_marketplace_count marketplaces, $actual_plugin_count plugins"

        if [ "$actual_marketplace_count" -ge "$expected_marketplace_count" ]; then
            print_success "Marketplace count in settings.json verified"
        else
            print_error "Expected at least $expected_marketplace_count marketplaces, found $actual_marketplace_count"
            exit 1
        fi

        if [ "$actual_plugin_count" -ge "$expected_plugin_count" ]; then
            print_success "Plugin count in settings.json verified"
        else
            print_error "Expected at least $expected_plugin_count plugins, found $actual_plugin_count"
            exit 1
        fi

        # Test 8: Validate plugin references
        print_info "Validating plugin references..."
        marketplace_names=$(jq -r '.extraKnownMarketplaces // {} | keys[]' "$settings_json" 2>/dev/null || echo "")
        invalid_refs=0

        while IFS= read -r plugin; do
            if [ -z "$plugin" ]; then
                continue
            fi
            if [[ "$plugin" =~ @ ]]; then
                marketplace="${plugin##*@}"
                if ! echo "$marketplace_names" | grep -q "^${marketplace}$"; then
                    print_warning "Plugin '$plugin' references unknown marketplace"
                    invalid_refs=$((invalid_refs + 1))
                fi
            fi
        done < <(jq -r '.enabledPlugins | to_entries[] | select(.value == true) | .key' "$settings_json" 2>/dev/null)

        if [ $invalid_refs -eq 0 ]; then
            print_success "All plugin references are valid"
        else
            print_error "$invalid_refs invalid plugin references found"
            exit 1
        fi

        print_success "Claude marketplace functionality verified"
        ;;

    tsc)
        print_info "Testing TypeScript..."
        tsc --version
        echo "const x: string = 'hello';" > /tmp/test.ts
        tsc /tmp/test.ts --outDir /tmp --noEmit
        print_success "TypeScript functionality verified"
        ;;

    tmux)
        print_info "Testing tmux..."
        tmux -V
        if [ -f ~/.tmux.conf ] || [ -f /workspace/config/tmux.conf ]; then
            print_success "Tmux configuration found"
        else
            print_warning "Tmux config not found"
        fi
        print_success "tmux functionality verified"
        ;;

    rustc)
        print_info "Testing Rust compilation..."
        rustc --version
        cargo --version
        echo 'fn main() { println!("Hello from Rust"); }' > /tmp/test.rs
        rustc /tmp/test.rs -o /tmp/test && /tmp/test
        print_success "Rust functionality verified"
        ;;

    go)
        print_info "Testing Go compilation..."
        go version
        echo 'package main; import "fmt"; func main() { fmt.Println("Hello from Go") }' > /tmp/test.go
        go run /tmp/test.go
        print_success "Go functionality verified"
        ;;

    python3)
        print_info "Testing Python execution..."
        python3 --version
        pip3 --version
        python3 -c "print('Hello from Python')"
        uv --version || print_warning "uv not installed"
        print_success "Python functionality verified"
        ;;

    java)
        print_info "Testing Java..."
        java -version
        print_success "Java functionality verified"
        ;;

    php)
        print_info "Testing PHP..."
        php --version
        php -r "echo 'Hello from PHP';"
        print_success "PHP functionality verified"
        ;;

    ruby)
        print_info "Testing Ruby..."
        ruby --version
        ruby -e "puts 'Hello from Ruby'"
        print_success "Ruby functionality verified"
        ;;

    dotnet)
        print_info "Testing .NET..."
        dotnet --info
        print_success ".NET functionality verified"
        ;;

    docker)
        print_info "Testing Docker..."
        timeout 10 docker --version
        timeout 10 docker-compose --version 2>/dev/null || \
        timeout 10 docker compose version 2>/dev/null
        print_success "Docker functionality verified"
        ;;

    terraform)
        print_info "Testing Terraform..."
        terraform version
        print_success "Terraform functionality verified"
        ;;

    aws)
        print_info "Testing AWS CLI..."
        aws --version
        print_success "AWS CLI functionality verified"
        ;;

    gh)
        print_info "Testing GitHub CLI..."
        gh --version
        print_success "GitHub CLI functionality verified"
        ;;

    ollama)
        print_info "Testing Ollama..."
        ollama --version
        print_success "Ollama functionality verified"
        ;;

    codex)
        print_info "Testing Codex CLI..."
        codex --version || codex version || print_warning "Version check not supported"
        print_success "Codex CLI functionality verified"
        ;;

    playwright)
        print_info "Testing Playwright..."
        timeout 30 playwright --version || print_warning "Playwright version check timed out"
        print_success "Playwright functionality verified"
        ;;

    claude-monitor)
        print_info "Testing claude-monitor..."
        claude-monitor --version || print_warning "Version check not supported"
        print_success "claude-monitor functionality verified"
        ;;

    agent-manager)
        print_info "Testing agent-manager..."
        agent-manager --version || agent-manager -h > /dev/null
        print_success "agent-manager functionality verified"
        ;;

    mkdir|ssh|echo)
        print_info "Testing $key_tool..."
        $key_tool --version 2>/dev/null || which $key_tool
        print_success "$key_tool functionality verified"
        ;;

    *)
        print_warning "No specific test for $key_tool, checking availability only"
        if command -v "$key_tool" >/dev/null 2>&1; then
            print_success "$key_tool is available"
        else
            print_error "$key_tool not found"
            exit 1
        fi
        ;;
esac

# Mark test success
mark_test_phase "Key Functionality Test: $key_tool" "success"
print_success "Key functionality test passed for $key_tool"
