#!/bin/bash
# Shared test helper functions for extension testing
# Usage: source this file in test scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print functions
print_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

print_error() {
    echo -e "${RED}❌ $*${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

print_info() {
    echo "ℹ️  $*"
}

print_section() {
    echo ""
    echo "=== $* ==="
    echo ""
}

# Source environment files for non-interactive sessions
source_environment() {
    print_info "Loading environment for non-interactive session..."

    # Capture PATH before sourcing
    local path_before="$PATH"

    # Source SSH environment (critical for mise and other tools)
    if [ -f /etc/profile.d/00-ssh-environment.sh ]; then
        print_info "Sourcing /etc/profile.d/00-ssh-environment.sh"
        source /etc/profile.d/00-ssh-environment.sh
    else
        print_warning "/etc/profile.d/00-ssh-environment.sh not found"
    fi

    # Source bashrc for user-specific configurations
    if [ -f ~/.bashrc ]; then
        print_info "Sourcing ~/.bashrc"
        source ~/.bashrc
    fi

    # Explicitly activate mise if available
    if command -v mise >/dev/null 2>&1; then
        print_info "Activating mise environment"
        # Activate mise for current shell
        eval "$(mise activate bash)"
        # Show mise status
        print_info "mise version: $(mise --version 2>/dev/null || echo 'version check failed')"
        print_info "mise tools: $(mise ls --current 2>/dev/null | head -5 || echo 'no tools configured')"
    else
        print_warning "mise command not available"
    fi

    # Show PATH changes
    if [ "$path_before" != "$PATH" ]; then
        print_success "PATH updated after environment sourcing"
        print_info "Added to PATH: $(echo "$PATH" | tr ':' '\n' | grep -v "$(echo "$path_before" | tr ':' '\n')" | head -5)"
    else
        print_warning "PATH unchanged after environment sourcing"
    fi

    # Show current PATH summary
    print_info "Current PATH (first 5 entries):"
    echo "$PATH" | tr ':' '\n' | head -5 | sed 's/^/  /'
    echo ""
}

# Check if a command is available
command_exists() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

# Check if a command is available with version check
check_command_with_version() {
    local cmd="$1"

    if command_exists "$cmd"; then
        print_success "$cmd available at: $(command -v "$cmd")"
        timeout 5 "$cmd" --version 2>/dev/null || \
        timeout 5 "$cmd" version 2>/dev/null || \
        echo "  (version check not supported)"
        return 0
    else
        print_error "$cmd not found in PATH"
        return 1
    fi
}

# Wait for a condition with timeout
wait_for_condition() {
    local condition_cmd="$1"
    local timeout="${2:-60}"
    local interval="${3:-5}"
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        if eval "$condition_cmd" 2>/dev/null; then
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    return 1
}

# Retry a command with exponential backoff
retry_command() {
    local max_attempts="${1:-3}"
    shift
    local cmd="$*"
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        print_info "Attempt $attempt/$max_attempts: $cmd"
        if eval "$cmd"; then
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                local wait_time=$((10 * attempt))
                print_warning "Command failed, retrying in ${wait_time}s..."
                sleep $wait_time
                attempt=$((attempt + 1))
            else
                print_error "Command failed after $max_attempts attempts"
                return 1
            fi
        fi
    done
}

# Get extension manager path
get_extension_manager_path() {
    echo "/workspace/scripts/lib"
}

# Get manifest path
get_manifest_path() {
    echo "$(get_extension_manager_path)/extensions.d/active-extensions.conf"
}

# Check if extension is in manifest
is_extension_in_manifest() {
    local extension="$1"
    local manifest="$(get_manifest_path)"

    if [ ! -f "$manifest" ]; then
        return 1
    fi

    grep -q "^${extension}$" "$manifest"
}

# Check if extension is protected
is_protected_extension() {
    local extension="$1"
    case "$extension" in
        workspace-structure|mise-config|ssh-environment)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Run extension-manager command
run_extension_manager() {
    local cmd="$*"
    cd "$(get_extension_manager_path)" || return 1
    bash extension-manager.sh $cmd
}

# Verify extension installation
verify_extension_installed() {
    local extension="$1"

    print_section "Verifying $extension installation"

    if run_extension_manager validate "$extension"; then
        print_success "$extension is properly installed"
        return 0
    else
        print_error "$extension failed validation"
        return 1
    fi
}

# Get extension status
get_extension_status() {
    local extension="$1"
    run_extension_manager status "$extension"
}

# Dump environment for debugging
dump_environment() {
    print_section "Environment Information"
    echo "USER: $USER"
    echo "HOME: $HOME"
    echo "PWD: $PWD"
    echo "SHELL: $SHELL"
    echo ""
    echo "PATH (full):"
    echo "$PATH" | tr ':' '\n' | nl
    echo ""
    echo "mise status:"
    if command -v mise >/dev/null 2>&1; then
        mise --version || echo "  (version check failed)"
        mise ls --current 2>/dev/null || echo "  (no tools configured)"
        mise doctor 2>/dev/null | head -20 || echo "  (doctor check failed)"
    else
        echo "  mise not available"
    fi
    echo ""
    echo "Common tool locations:"
    for tool in node npm python3 rustc cargo go mise; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "  $tool: $(command -v "$tool")"
        else
            echo "  $tool: NOT FOUND"
        fi
    done
    echo ""
    echo "Environment files:"
    [ -f /etc/profile.d/00-ssh-environment.sh ] && echo "  ✓ /etc/profile.d/00-ssh-environment.sh" || echo "  ✗ /etc/profile.d/00-ssh-environment.sh"
    [ -f ~/.bashrc ] && echo "  ✓ ~/.bashrc" || echo "  ✗ ~/.bashrc"
    [ -f ~/.bash_profile ] && echo "  ✓ ~/.bash_profile" || echo "  ✗ ~/.bash_profile"
}

# Dump manifest for debugging
dump_manifest() {
    local manifest="$(get_manifest_path)"
    print_section "Active Extensions Manifest"
    if [ -f "$manifest" ]; then
        cat "$manifest"
    else
        print_error "Manifest not found: $manifest"
    fi
}

# Export functions for use in subshells
export -f print_success print_error print_warning print_info print_section
export -f source_environment command_exists check_command_with_version
export -f wait_for_condition retry_command
export -f get_extension_manager_path get_manifest_path
export -f is_extension_in_manifest is_protected_extension
export -f run_extension_manager verify_extension_installed get_extension_status
export -f dump_environment dump_manifest
