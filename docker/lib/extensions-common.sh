#!/bin/bash
# extensions-common.sh - Shared utilities for extension scripts
# This library provides common functions used across all extension .example files

# Prevent multiple sourcing
if [[ "${EXTENSIONS_COMMON_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
EXTENSIONS_COMMON_SH_LOADED="true"

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
export -f check_dependent_extensions
export -f extension_main
export -f cleanup_bashrc
export -f cleanup_git_aliases
export -f prompt_confirmation
export -f show_dependent_extensions_warning
