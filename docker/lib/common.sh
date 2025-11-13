#!/bin/bash
# common.sh - Shared utilities for all scripts
# This library provides common functions, colors, and utilities used across the project

# Prevent multiple sourcing
if [[ "${COMMON_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
COMMON_SH_LOADED="true"

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Common directories
# WORKSPACE_DIR is where extensions install and configure their artifacts
# - Avoids permission issues (developer user owns /workspace/developer)
# - Compartmentalizes extension artifacts (cleaner organization)
# - Maintains security (/workspace/.system remains root-owned and protected)
export WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace/developer/extensions}"
export SCRIPTS_DIR="${SCRIPTS_DIR:-$WORKSPACE_DIR/scripts}"
export PROJECTS_DIR="${PROJECTS_DIR:-$WORKSPACE_DIR/projects}"
export BACKUPS_DIR="${BACKUPS_DIR:-$WORKSPACE_DIR/backups}"
export CONFIG_DIR="${CONFIG_DIR:-$WORKSPACE_DIR/.config}"
export EXTENSIONS_DIR="${EXTENSIONS_DIR:-$SCRIPTS_DIR/lib/extensions.d}"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

print_header() {
    echo -e "${CYAN}==>${NC} ${1}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running in Docker/VM environment
is_in_vm() {
    # Check for workspace directory and Fly.io specific markers
    [[ -d "/workspace" ]] && \
    ( [[ -d "/.fly" ]] || \
      [[ -d "/.fly-upper-layer" ]] || \
      [[ -f "/health.sh" ]] || \
      [[ -n "${FLY_APP_NAME:-}" ]] || \
      [[ -n "${FLY_ALLOC_ID:-}" ]] )
}

# Function to ensure script is run with proper permissions
ensure_permissions() {
    local required_user="${1:-developer}"
    if [[ "$USER" != "$required_user" ]] && [[ "$USER" != "root" ]]; then
        print_error "This script should be run as $required_user or root"
        return 1
    fi
    return 0
}

# Function to create directory with proper ownership
create_directory() {
    local dir="$1"
    local owner="${2:-developer:developer}"

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        if [[ "$USER" == "root" ]]; then
            chown "$owner" "$dir"
        fi
        print_debug "Created directory: $dir"
    fi
}

# Function to safely copy files
safe_copy() {
    local src="$1"
    local dest="$2"
    local owner="${3:-developer:developer}"

    if [[ -f "$src" ]]; then
        cp "$src" "$dest"
        if [[ "$USER" == "root" ]]; then
            chown "$owner" "$dest"
        fi
        chmod +x "$dest" 2>/dev/null || true
        print_debug "Copied $src to $dest"
        return 0
    else
        print_warning "Source file not found: $src"
        return 1
    fi
}

# Function to check for required environment variables
check_env_var() {
    local var_name="$1"
    local var_value="${!var_name}"

    if [[ -z "$var_value" ]]; then
        print_warning "Environment variable $var_name is not set"
        return 1
    fi
    return 0
}

# Function to prompt for user confirmation
confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"

    local yn_prompt="y/N"
    if [[ "${default,,}" == "y" ]]; then
        yn_prompt="Y/n"
    fi

    read -p "$prompt ($yn_prompt): " -n 1 -r
    echo

    if [[ -z "$REPLY" ]]; then
        REPLY="$default"
    fi

    [[ "$REPLY" =~ ^[Yy]$ ]]
}

# Function to run command with error handling
run_command() {
    local cmd="$1"
    local error_msg="${2:-Command failed}"

    print_debug "Running: $cmd"

    if eval "$cmd"; then
        return 0
    else
        print_error "$error_msg"
        return 1
    fi
}

# Function to get timestamp
get_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# Function to create backup filename
get_backup_filename() {
    local prefix="${1:-backup}"
    echo "${prefix}_$(get_timestamp).tar.gz"
}

# Function to load configuration file
load_config() {
    local config_file="$1"

    if [[ -f "$config_file" ]]; then
        # shellcheck source=/dev/null
        source "$config_file"
        print_debug "Loaded configuration from $config_file"
        return 0
    else
        print_debug "Configuration file not found: $config_file"
        return 1
    fi
}

# Function to write configuration file
save_config() {
    local config_file="$1"
    shift

    {
        echo "# Configuration saved on $(date)"
        for var in "$@"; do
            echo "export $var=\"${!var}\""
        done
    } > "$config_file"

    print_debug "Saved configuration to $config_file"
}

# Function to check network connectivity
check_network() {
    local test_host="${1:-8.8.8.8}"
    local timeout="${2:-5}"

    if ping -c 1 -W "$timeout" "$test_host" >/dev/null 2>&1; then
        print_debug "Network connectivity check passed"
        return 0
    else
        print_warning "Network connectivity check failed"
        return 1
    fi
}

# Function to retry command with backoff
# NOTE: This is the VM/development version optimized for interactive use.
#       A similar function exists in .github/scripts/common/retry-utils.sh
#       for CI/automation with different defaults (5s delay, 60s cap).
#       These are intentionally separate to suit different environments:
#       - VM: Flexible retries for unreliable networks (unlimited exponential backoff)
#       - CI: Bounded retries for workflow timeouts (max 60s delay cap)
retry_with_backoff() {
    local max_attempts="${1:-3}"
    local initial_delay="${2:-1}"
    shift 2
    local cmd="$*"

    local attempt=1
    local delay="$initial_delay"

    while [[ $attempt -le $max_attempts ]]; do
        print_debug "Attempt $attempt of $max_attempts: $cmd"

        if eval "$cmd"; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            print_warning "Command failed, retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
        fi

        attempt=$((attempt + 1))
    done

    print_error "Command failed after $max_attempts attempts"
    return 1
}

#============================================================================
# SSH ENVIRONMENT CONFIGURATION
# Functions to configure PATH for both interactive and non-interactive sessions
#============================================================================

# SSH environment file that works for non-interactive sessions
SSH_ENV_FILE="/etc/profile.d/00-ssh-environment.sh"

# Function to add environment configuration that works in SSH non-interactive sessions
# Usage: add_to_ssh_environment "export PATH=\"/some/path:\$PATH\""
#        add_to_ssh_environment "source /some/script.sh"
add_to_ssh_environment() {
    local env_config="$1"
    local component_name="${2:-custom}"

    print_debug "Adding SSH environment for $component_name"

    # Create SSH environment file if it doesn't exist
    if [[ ! -f "$SSH_ENV_FILE" ]]; then
        sudo tee "$SSH_ENV_FILE" > /dev/null << 'EOF'
#!/bin/bash
# SSH Environment Configuration
# This file is sourced for both interactive and non-interactive SSH sessions
# via BASH_ENV mechanism configured in /etc/ssh/sshd_config

# If not running interactively, set up environment
if [[ $- != *i* ]]; then
    # Source all profile.d scripts for non-interactive sessions
    if [ -d /etc/profile.d ]; then
        for script in /etc/profile.d/*.sh; do
            if [ -r "$script" ] && [ "$script" != "/etc/profile.d/00-ssh-environment.sh" ]; then
                . "$script" >/dev/null 2>&1
            fi
        done
    fi
fi
EOF
        sudo chmod +x "$SSH_ENV_FILE"
        print_success "Created SSH environment file: $SSH_ENV_FILE"
    fi

    # Add configuration to SSH environment file (prevent duplicates)
    if ! sudo grep -qF "$env_config" "$SSH_ENV_FILE" 2>/dev/null; then
        echo "$env_config" | sudo tee -a "$SSH_ENV_FILE" > /dev/null
        print_debug "Added to SSH environment: $env_config"
    else
        print_debug "Already in SSH environment: $env_config"
    fi

    # Also add to bashrc for interactive sessions (prevent duplicates)
    if [[ -f "$HOME/.bashrc" ]]; then
        if ! grep -qF "$env_config" "$HOME/.bashrc" 2>/dev/null; then
            echo "$env_config" >> "$HOME/.bashrc"
            print_debug "Added to bashrc: $env_config"
        fi
    fi

    # Evaluate in current session
    eval "$env_config" 2>/dev/null || print_debug "Could not evaluate in current session: $env_config"
}


# Function to setup PATH for a tool/language (handles both interactive and non-interactive sessions)
# Usage: setup_tool_path "nodejs" 'eval "$(mise activate bash --shims)"'
setup_tool_path() {
    local tool_name="$1"
    local path_export="$2"
    local init_command="${3:-}"

    print_debug "Setting up PATH for $tool_name"

    # Create /etc/profile.d/ script for login shells (skip in CI mode)
    if ! is_ci_mode; then
        local profile_script="/etc/profile.d/${tool_name,,}.sh"
        if [[ ! -f "$profile_script" ]]; then
            if {
                echo "#!/bin/bash"
                echo "# $tool_name environment configuration"
                echo "$path_export"
                [[ -n "$init_command" ]] && echo "$init_command"
            } | sudo tee "$profile_script" > /dev/null 2>&1; then
                if sudo chmod +x "$profile_script" 2>/dev/null; then
                    print_debug "Created profile.d script: $profile_script"
                else
                    print_warning "Failed to make profile.d script executable (non-critical)"
                fi
            else
                print_warning "Failed to create profile.d script (non-critical in CI mode)"
            fi
        fi
    else
        print_debug "CI mode - skipping profile.d script creation for $tool_name"
    fi

    # Add to SSH environment
    add_to_ssh_environment "$path_export" "$tool_name"
    [[ -n "$init_command" ]] && add_to_ssh_environment "$init_command" "$tool_name"

    # Add to ~/.bashrc if not already there (prevent duplicates)
    if ! grep -q "$tool_name environment configuration" "$HOME/.bashrc" 2>/dev/null; then
        {
            echo ""
            echo "# $tool_name environment configuration"
            echo "$path_export"
            [[ -n "$init_command" ]] && echo "$init_command"
        } >> "$HOME/.bashrc"
        print_debug "Added to ~/.bashrc"
    fi
}

# Function to create wrapper script for tools that need environment sourcing
# This ensures tools work in non-interactive SSH sessions
# Usage: create_tool_wrapper "go" "/usr/local/go/bin/go"
#        create_tool_wrapper "cargo" "$HOME/.cargo/bin/cargo"
#        create_tool_wrapper "sdk" "" "dynamic"  # For commands resolved via PATH/init
create_tool_wrapper() {
    local tool_name="$1"
    local actual_path="$2"
    local mode="${3:-static}"  # "static" (with path) or "dynamic" (via PATH)
    local env_file="/etc/profile.d/00-ssh-environment.sh"
    local wrapper_path="/usr/local/bin/$tool_name"

    print_debug "Creating wrapper for $tool_name (mode: $mode)"

    # In CI mode, skip wrapper creation (tools work via PATH and mise activation)
    if is_ci_mode; then
        print_debug "CI mode - skipping wrapper creation for $tool_name"
        return 0
    fi

    # Skip if wrapper already exists
    if [[ -f "$wrapper_path" ]] && [[ -L "$wrapper_path" || $(head -1 "$wrapper_path" 2>/dev/null | grep -c "Wrapper for") -gt 0 ]]; then
        print_debug "Wrapper already exists: $wrapper_path"
        return 0
    fi

    if [[ "$mode" == "dynamic" ]]; then
        # Create dynamic wrapper that resolves command via PATH after sourcing environment
        # This handles cases where commands are in PATH but not at fixed locations
        if sudo tee "$wrapper_path" > /dev/null 2>&1 << EOF
#!/bin/bash
# Wrapper for $tool_name - ensures environment is loaded for non-interactive SSH
# Created by extension system to support 'flyctl ssh console --command' usage
# Mode: dynamic (resolves command via PATH)

# Source environment if available (for non-interactive sessions)
[[ -f "$env_file" ]] && source "$env_file" 2>/dev/null

# Find and execute command via PATH
exec $tool_name "\$@"
EOF
        then
            if sudo chmod +x "$wrapper_path" 2>/dev/null; then
                print_success "Created dynamic wrapper: $wrapper_path"
                return 0
            else
                print_error "Failed to make wrapper executable: $wrapper_path"
                print_debug "Check sudo permissions in /etc/sudoers.d/developer"
                return 1
            fi
        else
            print_error "Failed to create wrapper: $wrapper_path"
            print_debug "Check sudo permissions in /etc/sudoers.d/developer"
            return 1
        fi
    else
        # Static mode: use explicit path
        # Expand actual_path if it contains variables like $HOME
        actual_path=$(eval echo "$actual_path")

        # Warn if command doesn't exist, but still create wrapper for delayed availability
        if [[ ! -f "$actual_path" ]] && [[ ! -x "$actual_path" ]]; then
            print_warning "Command not yet available: $actual_path (creating wrapper anyway)"
        fi

        # Create wrapper that sources environment before executing
        if sudo tee "$wrapper_path" > /dev/null 2>&1 << EOF
#!/bin/bash
# Wrapper for $tool_name - ensures environment is loaded for non-interactive SSH
# Created by extension system to support 'flyctl ssh console --command' usage
# Mode: static (uses explicit path)

# Source environment if available (for non-interactive sessions)
[[ -f "$env_file" ]] && source "$env_file" 2>/dev/null

# Execute actual command with all arguments
exec "$actual_path" "\$@"
EOF
        then
            if sudo chmod +x "$wrapper_path" 2>/dev/null; then
                print_debug "Created static wrapper: $wrapper_path -> $actual_path"
                return 0
            else
                print_error "Failed to make wrapper executable: $wrapper_path"
                print_debug "Check sudo permissions in /etc/sudoers.d/developer"
                return 1
            fi
        else
            print_error "Failed to create wrapper: $wrapper_path"
            print_debug "Check sudo permissions in /etc/sudoers.d/developer"
            return 1
        fi
    fi
}

# ============================================================================
# MISE ENVIRONMENT MANAGEMENT
# ============================================================================

# Activate mise environment with timeout protection
# Usage: activate_mise_environment
# This function evaluates mise activation and adds shims/installs to PATH
activate_mise_environment() {
    if command_exists mise; then
        # SECURITY: Set PROMPT_COMMAND to avoid unbound variable error with set -u
        # mise activate bash generates code that references PROMPT_COMMAND before using :-
        # This is consumed by bash itself (not Sindri code) for automatic environment updates
        export PROMPT_COMMAND="${PROMPT_COMMAND:-}"

        # Activate mise with error capture and timeout protection
        local activation_output
        if activation_output=$(timeout 3 mise activate bash 2>&1); then
            eval "$activation_output"
            print_debug "mise activated successfully"
        else
            print_warning "mise activation returned non-zero or timed out: $activation_output"
            # Continue anyway as activation might still work
        fi

        # Ensure shims directory is in PATH
        if [[ -d "$HOME/.local/share/mise/shims" ]]; then
            # Only add if not already in PATH
            if [[ ":$PATH:" != *":$HOME/.local/share/mise/shims:"* ]]; then
                export PATH="$HOME/.local/share/mise/shims:$PATH"
                print_debug "Added mise shims to PATH"
            fi
        fi

        # Also add installs directories for tools that don't use shims
        if [[ -d "$HOME/.local/share/mise/installs" ]]; then
            for bin_dir in "$HOME/.local/share/mise/installs/"*/*/bin; do
                if [[ -d "$bin_dir" ]] && [[ ":$PATH:" != *":$bin_dir:"* ]]; then
                    export PATH="$bin_dir:$PATH"
                fi
            done
        fi
    else
        print_debug "mise not available - skipping activation"
    fi
}

# Export all functions so they're available to subshells
export -f print_status print_success print_warning print_error print_debug
export -f command_exists is_in_vm ensure_permissions create_directory
export -f safe_copy check_env_var confirm run_command
export -f get_timestamp get_backup_filename load_config save_config
export -f check_network retry_with_backoff
export -f add_to_ssh_environment setup_tool_path
export -f create_tool_wrapper activate_mise_environment