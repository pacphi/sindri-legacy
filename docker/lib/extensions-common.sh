#!/bin/bash
# extensions-common.sh - Shared utilities for extension scripts
# This library provides common functions used across all extension .example files

# Prevent multiple sourcing
if [[ "${EXTENSIONS_COMMON_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
EXTENSIONS_COMMON_SH_LOADED="true"

# ============================================================================
# CONSTANTS
# ============================================================================

# Protected extensions that cannot be removed or reordered
export PROTECTED_EXTENSIONS="workspace-structure mise-config ssh-environment"

# ============================================================================
# EXTENSION INITIALIZATION
# ============================================================================

# Initialize extension environment and load common utilities
# This function replaces the COMMON UTILITIES section in each extension
extension_init() {
    # Calculate script and library directories
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    LIB_DIR="$(dirname "$SCRIPT_DIR")"

    # Try to source common.sh from known locations
    if [[ -f "$LIB_DIR/common.sh" ]]; then
        source "$LIB_DIR/common.sh"
    elif [[ -f "/workspace/scripts/lib/common.sh" ]]; then
        source "/workspace/scripts/lib/common.sh"
    else
        # Fallback: define minimal required functions
        print_status() { echo "[INFO] $1"; }
        print_success() { echo "[SUCCESS] $1"; }
        print_error() { echo "[ERROR] $1" >&2; }
        print_warning() { echo "[WARNING] $1"; }
        print_debug() { [[ "${DEBUG:-}" == "true" ]] && echo "[DEBUG] $1"; }
        command_exists() { command -v "$1" >/dev/null 2>&1; }
    fi

    # Source registry retry helpers if available
    local registry_retry="$LIB_DIR/registry-retry.sh"
    if [[ -f "$registry_retry" ]]; then
        source "$registry_retry"
    fi

    # Export for use by extension functions
    export SCRIPT_DIR LIB_DIR
}

# ============================================================================
# DEPENDENCY CHECKING
# ============================================================================

# Check which active extensions depend on commands provided by this extension
# Usage: check_dependent_extensions "command1" "command2" ...
# Returns: List of extension names that reference any of the provided commands
check_dependent_extensions() {
    local provided_commands=("$@")
    local dependent_extensions=()

    # Get manifest file location
    local manifest_file="$SCRIPT_DIR/active-extensions.conf"
    [[ ! -f "$manifest_file" ]] && manifest_file="/workspace/scripts/lib/extensions.d/active-extensions.conf"

    if [[ ! -f "$manifest_file" ]]; then
        return 0
    fi

    # Read active extensions from manifest
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Extract extension name
        local ext_name=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ "$ext_name" == "${EXT_NAME:-}" ]] && continue

        # Find the extension file
        local ext_file="$SCRIPT_DIR/${ext_name}.sh"
        if [[ ! -f "$ext_file" ]]; then
            local -a matches=("$SCRIPT_DIR/"*"-${ext_name}.sh")
            [[ ${#matches[@]} -gt 0 ]] && ext_file="${matches[0]}"
        fi
        [[ ! -f "$ext_file" ]] && continue

        # Check if extension references any of the provided commands
        for cmd in "${provided_commands[@]}"; do
            if grep -q "$cmd" "$ext_file" 2>/dev/null; then
                dependent_extensions+=("$ext_name")
                break
            fi
        done
    done < "$manifest_file"

    printf '%s\n' "${dependent_extensions[@]}"
}

# ============================================================================
# ENVIRONMENT HELPERS
# ============================================================================

# Check if running in CI mode
# Usage: if is_ci_mode; then ... fi
# Returns: 0 if CI_MODE=true, 1 otherwise
is_ci_mode() {
    [[ "${CI_MODE:-false}" == "true" ]]
}

# Activate mise environment in current shell
# Usage: activate_mise_environment
# This function evaluates mise activation and adds shims to PATH
activate_mise_environment() {
    if command_exists mise; then
        eval "$(mise activate bash)" 2>/dev/null || true
        if [[ -d "$HOME/.local/share/mise/shims" ]]; then
            export PATH="$HOME/.local/share/mise/shims:$PATH"
        fi
    fi
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

# Check if mise is available
# Usage: check_mise_prerequisite || return 1
# Returns: 0 if mise exists, 1 with error message otherwise
check_mise_prerequisite() {
    if command_exists mise; then
        return 0
    fi

    print_error "mise is required but not installed"
    print_status "Install mise-config extension first: extension-manager install mise-config"
    return 1
}

# Check available disk space
# Usage: check_disk_space [required_mb]
# Default: 600MB required
# Returns: 0 if sufficient space, 1 with warning otherwise
check_disk_space() {
    local required_mb="${1:-600}"
    local available_mb
    available_mb=$(df -BM / | awk 'NR==2 {print $4}' | sed 's/M//')

    if [[ $available_mb -lt $required_mb ]]; then
        print_warning "Low disk space: ${available_mb}MB available (${required_mb}MB recommended)"
        return 1
    fi
    return 0
}

# ============================================================================
# STATUS HELPERS
# ============================================================================

# Print standard extension header
# Usage: print_extension_header
# Requires: EXT_NAME, EXT_VERSION, EXT_DESCRIPTION, EXT_CATEGORY environment variables
print_extension_header() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Extension: ${EXT_NAME} v${EXT_VERSION}"
    echo "Description: ${EXT_DESCRIPTION}"
    echo "Category: ${EXT_CATEGORY}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# ============================================================================
# VALIDATION HELPERS
# ============================================================================

# Validate multiple commands with version checks
# Usage:
#   declare -A checks=(
#       [command1]="--version"
#       [command2]="-v"
#   )
#   validate_commands checks
# Returns: 0 if all commands exist, 1 if any are missing
validate_commands() {
    local -n command_checks=$1
    local all_valid=true

    for cmd in "${!command_checks[@]}"; do
        local version_flag="${command_checks[$cmd]}"
        if ! command_exists "$cmd"; then
            print_error "$cmd not found"
            all_valid=false
        else
            local version
            version=$($cmd $version_flag 2>&1 | head -n1)
            print_success "$cmd: $version"
        fi
    done

    [[ "$all_valid" == "true" ]]
}

# ============================================================================
# MISE HELPERS
# ============================================================================

# Install mise configuration from TOML file
# Usage: install_mise_config "extension-name" ["script_dir"]
# Example: install_mise_config "nodejs"
# This function:
#   - Selects CI or dev TOML based on CI_MODE
#   - Copies TOML to mise config directory
#   - Runs mise install
# Returns: 0 on success, 1 on failure
install_mise_config() {
    local ext_name="$1"
    local script_dir="${2:-$SCRIPT_DIR}"

    # Determine which TOML to use (CI vs dev)
    local source_toml="${script_dir}/${ext_name}"
    if is_ci_mode; then
        source_toml+="-ci"
        print_status "CI mode detected - using minimal configuration"
    else
        print_status "Using full configuration"
    fi
    source_toml+=".toml"

    # Verify source file exists
    if [[ ! -f "$source_toml" ]]; then
        print_error "Configuration not found: $source_toml"
        return 1
    fi

    # Ensure mise config directory exists
    mkdir -p "$HOME/.config/mise/conf.d"

    # Copy TOML to mise config
    local dest_toml="$HOME/.config/mise/conf.d/${ext_name}.toml"
    if cp "$source_toml" "$dest_toml"; then
        print_success "Configuration copied to $dest_toml"
    else
        print_error "Failed to copy configuration"
        return 1
    fi

    # Install via mise
    print_status "Installing via mise..."
    if mise install; then
        print_success "Installed successfully"
        return 0
    else
        print_error "mise install failed"
        return 1
    fi
}

# Remove mise configuration for an extension
# Usage: remove_mise_config "extension-name"
# Example: remove_mise_config "nodejs"
remove_mise_config() {
    local ext_name="$1"
    local config_file="$HOME/.config/mise/conf.d/${ext_name}.toml"

    if [[ -f "$config_file" ]]; then
        print_status "Removing mise configuration..."
        if rm -f "$config_file"; then
            print_success "Removed $config_file"
        fi
    fi

    print_status "Note: Tools are still installed by mise"
    print_status "Run 'mise prune' to remove unused tools"
}

# ============================================================================
# MAIN EXECUTION WRAPPER
# ============================================================================

# Standard main execution wrapper for extensions
# Usage: extension_main "$@"
# This function replaces the MAIN EXECUTION section in each extension
extension_main() {
    # Only execute if script is run directly (not sourced)
    if [[ "${BASH_SOURCE[1]}" == "${0}" ]]; then
        local command="${1:-status}"

        case "$command" in
            prerequisites|install|configure|validate|status|remove)
                if "$command"; then
                    exit 0
                else
                    exit 1
                fi
                ;;
            *)
                echo "Usage: $0 {prerequisites|install|configure|validate|status|remove}"
                exit 1
                ;;
        esac
    fi
}

# ============================================================================
# CLEANUP HELPERS
# ============================================================================

# Remove extension entries from .bashrc
# Usage: cleanup_bashrc "marker-text"
cleanup_bashrc() {
    local marker="$1"
    local bashrc="$HOME/.bashrc"

    if [[ ! -f "$bashrc" ]]; then
        return 0
    fi

    if grep -q "$marker" "$bashrc" 2>/dev/null; then
        # Calculate number of lines to remove (find the section and remove until next empty line or next comment)
        local start_line=$(grep -n "$marker" "$bashrc" | head -1 | cut -d: -f1)
        if [[ -n "$start_line" ]]; then
            # Simple approach: remove marker line and up to 5 following lines
            # This handles most cases (export statements, aliases, etc.)
            local line_count=1
            local current=$((start_line + 1))
            while [[ $line_count -lt 10 ]]; do
                local line_content=$(sed -n "${current}p" "$bashrc")
                # Stop if we hit an empty line or a new comment block
                if [[ -z "$line_content" ]] || [[ "$line_content" =~ ^[[:space:]]*$ ]]; then
                    break
                fi
                if [[ "$line_content" =~ ^[[:space:]]*#.*Extension ]]; then
                    break
                fi
                ((line_count++))
                ((current++))
            done

            # Use a more precise sed pattern based on the marker
            sed -i "/$marker/,+${line_count}d" "$bashrc" 2>/dev/null || true
            print_success "Removed entries from .bashrc"
        fi
    fi
}

# Setup git aliases for an extension
# Usage: setup_git_aliases "alias1:command1" "alias2:command2" ...
# Example: setup_git_aliases "py-test:!pytest" "py-lint:!ruff check"
setup_git_aliases() {
    local alias_defs=("$@")

    if ! command_exists git; then
        return 0
    fi

    for alias_def in "${alias_defs[@]}"; do
        local alias_name="${alias_def%%:*}"
        local alias_cmd="${alias_def#*:}"
        git config --global "alias.${alias_name}" "$alias_cmd" 2>/dev/null || true
        print_debug "Configured git alias: $alias_name"
    done
}

# Remove git aliases for an extension
# Usage: cleanup_git_aliases "alias1" "alias2" ...
cleanup_git_aliases() {
    local aliases=("$@")

    if ! command_exists git; then
        return 0
    fi

    for alias in "${aliases[@]}"; do
        if git config --global --get-all "alias.${alias}" >/dev/null 2>&1; then
            git config --global --unset-all "alias.${alias}" 2>/dev/null || true
            print_debug "Removed git alias: $alias"
        fi
    done
}

# Standardized confirmation prompt
# Usage: if prompt_confirmation "Question text?"; then ... fi
# Returns: 0 if user answered yes, 1 if no
prompt_confirmation() {
    local prompt="${1:-Continue?}"
    read -p "$prompt (y/N): " -r
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Display list of dependent extensions
# Usage: show_dependent_extensions_warning "cmd1" "cmd2" ...
show_dependent_extensions_warning() {
    local dependent_exts=()
    mapfile -t dependent_exts < <(check_dependent_extensions "$@")

    if [[ ${#dependent_exts[@]} -gt 0 ]]; then
        print_warning "The following active extensions depend on this extension and may stop working:"
        for ext in "${dependent_exts[@]}"; do
            echo "  - $ext"
        done
        echo ""
        return 0
    fi
    return 1
}

# ============================================================================
# EXPORTS
# ============================================================================

# Export all functions for use by extensions
export -f extension_init
export -f extension_main

# Environment helpers
export -f is_ci_mode
export -f activate_mise_environment

# Prerequisite checks
export -f check_mise_prerequisite
export -f check_disk_space

# Status helpers
export -f print_extension_header

# Validation helpers
export -f validate_commands

# Mise helpers
export -f install_mise_config
export -f remove_mise_config

# Dependency checking
export -f check_dependent_extensions
export -f show_dependent_extensions_warning

# Cleanup helpers
export -f cleanup_bashrc
export -f setup_git_aliases
export -f cleanup_git_aliases
export -f prompt_confirmation
