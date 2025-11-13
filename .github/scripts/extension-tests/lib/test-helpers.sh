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
        # Activate mise for current shell with timeout protection
        if mise_activation=$(timeout 3 mise activate bash 2>/dev/null); then
            eval "$mise_activation"
        fi
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
    # Extension manager is at /docker/lib/extension-manager.sh
    echo "/docker/lib"
}

# Get manifest path
get_manifest_path() {
    # Manifest is at /workspace/.system/manifest/active-extensions.conf
    echo "/workspace/.system/manifest/active-extensions.conf"
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

# Check VM resources (disk, memory, processes)
check_vm_resources() {
    local context="${1:-Current}"
    print_section "$context VM Resource Status"

    echo "📊 Disk Usage:"
    df -h / /workspace 2>/dev/null | tail -n +2 || echo "  ⚠️  Could not check disk usage"
    echo ""

    echo "💾 Memory Usage:"
    free -h 2>/dev/null || echo "  ⚠️  Could not check memory usage"
    echo ""

    echo "🔝 Top Processes by Memory (top 10):"
    ps aux --sort=-%mem 2>/dev/null | head -11 | tail -n +2 || echo "  ⚠️  Could not list processes"
    echo ""

    echo "⚡ CPU Load:"
    uptime 2>/dev/null || echo "  ⚠️  Could not check load"
    echo ""
}

# Verify SSH connection is responsive
verify_ssh_connection() {
    local max_attempts="${1:-3}"
    local attempt=1

    print_info "Verifying SSH connection responsiveness..."

    while [ $attempt -le $max_attempts ]; do
        if timeout 5 echo "SSH connection test" >/dev/null 2>&1; then
            print_success "SSH connection is responsive (attempt $attempt/$max_attempts)"
            return 0
        else
            print_warning "SSH connection test failed (attempt $attempt/$max_attempts)"
            if [ $attempt -lt $max_attempts ]; then
                sleep 2
                attempt=$((attempt + 1))
            else
                print_error "SSH connection appears unresponsive after $max_attempts attempts"
                return 1
            fi
        fi
    done
}

# Run command with enhanced error capture
run_with_error_capture() {
    local cmd="$*"
    local stdout_file="/tmp/cmd_stdout_$$.log"
    local stderr_file="/tmp/cmd_stderr_$$.log"
    local exit_code

    print_info "Running: $cmd"

    # Run command, capture stdout and stderr separately
    eval "$cmd" >"$stdout_file" 2>"$stderr_file"
    exit_code=$?

    # Display stdout
    if [ -s "$stdout_file" ]; then
        cat "$stdout_file"
    fi

    # Display stderr if present
    if [ -s "$stderr_file" ]; then
        echo ""
        print_warning "Error output:"
        sed 's/^/  /' < "$stderr_file"
    fi

    # Cleanup
    rm -f "$stdout_file" "$stderr_file"

    return $exit_code
}

# Enhanced extension-manager runner with error capture
run_extension_manager_verbose() {
    local cmd="$*"
    local stderr_file="/tmp/ext_mgr_stderr_$$.log"
    local exit_code

    cd "$(get_extension_manager_path)" || return 1

    print_info "Running extension-manager: $cmd"
    print_info "Working directory: $(pwd)"

    # Run with stderr captured separately
    bash extension-manager.sh $cmd 2> >(tee "$stderr_file" >&2)
    exit_code=$?

    # Show stderr summary if errors occurred
    if [ $exit_code -ne 0 ] && [ -s "$stderr_file" ]; then
        print_error "Extension manager failed with exit code $exit_code"
        print_warning "Error summary:"
        tail -20 "$stderr_file" | sed 's/^/  /'
    fi

    rm -f "$stderr_file"
    return $exit_code
}

# Check mise health for mise-powered extensions
check_mise_health() {
    if ! command -v mise >/dev/null 2>&1; then
        print_warning "mise not available - skipping mise health check"
        return 0
    fi

    print_section "Mise Health Check"

    # Run mise doctor with timeout
    if timeout 30 mise doctor 2>&1; then
        print_success "mise doctor check passed"
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            print_error "mise doctor timed out after 30 seconds"
        else
            print_warning "mise doctor reported issues (exit code: $exit_code)"
        fi

        # Still show mise status even if doctor fails
        print_info "Current mise tools:"
        timeout 10 mise ls --current 2>/dev/null | head -10 || echo "  (could not list tools)"

        return 1
    fi
}

# Mark test phase with unique identifier
mark_test_phase() {
    local phase="$1"
    local status="${2:-start}"  # start, success, failure
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    echo ""
    echo "█████████████████████████████████████████████████"
    case "$status" in
        start)
            echo "▶️  TEST PHASE START: $phase"
            ;;
        success)
            echo "✅ TEST PHASE SUCCESS: $phase"
            ;;
        failure)
            echo "❌ TEST PHASE FAILURE: $phase"
            ;;
        *)
            echo "📍 TEST PHASE: $phase ($status)"
            ;;
    esac
    echo "⏰ Timestamp: $timestamp"
    echo "█████████████████████████████████████████████████"
    echo ""
}

# Export functions for use in subshells
export -f print_success print_error print_warning print_info print_section
export -f source_environment command_exists check_command_with_version
export -f wait_for_condition retry_command
export -f get_extension_manager_path get_manifest_path
export -f is_extension_in_manifest
export -f run_extension_manager verify_extension_installed get_extension_status
export -f dump_environment dump_manifest
export -f check_vm_resources verify_ssh_connection
export -f run_with_error_capture run_extension_manager_verbose
export -f check_mise_health mark_test_phase
