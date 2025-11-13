#!/bin/bash
# Project helper functions for input validation
# Part of Sindri security hardening initiative

# Validate project name
# Only allows alphanumeric characters, hyphens, and underscores
validate_project_name() {
    local name="$1"

    # Check for empty name
    if [[ -z "$name" ]]; then
        echo "ERROR: Project name cannot be empty" >&2
        return 1
    fi

    # Length check (max 64 characters)
    if [[ ${#name} -gt 64 ]]; then
        echo "ERROR: Project name too long (max 64 characters)" >&2
        return 1
    fi

    # Only allow safe characters: alphanumeric, dash, underscore
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "ERROR: Invalid project name: $name" >&2
        echo "  Project names must contain only letters, numbers, hyphens, and underscores" >&2
        return 1
    fi

    # Prevent directory traversal
    if [[ "$name" =~ \.\. ]]; then
        echo "ERROR: Project name cannot contain '..'" >&2
        return 1
    fi

    # Prevent starting with dash or dot
    if [[ "$name" =~ ^[-\.] ]]; then
        echo "ERROR: Project name cannot start with '-' or '.'" >&2
        return 1
    fi

    # Reserved names
    local reserved_names=("tmp" "temp" "test" "system" "root" "bin" "etc" "var" "usr")
    for reserved in "${reserved_names[@]}"; do
        if [[ "$name" == "$reserved" ]]; then
            echo "ERROR: '$name' is a reserved name" >&2
            return 1
        fi
    done

    return 0
}

# Validate repository URL
# Only allows HTTPS and SSH URLs
validate_repo_url() {
    local url="$1"

    # Check for empty URL
    if [[ -z "$url" ]]; then
        echo "ERROR: Repository URL cannot be empty" >&2
        return 1
    fi

    # Only allow HTTPS and SSH URLs
    if [[ ! "$url" =~ ^https://[a-zA-Z0-9.-]+/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+(\.git)?$ ]] && \
       [[ ! "$url" =~ ^git@[a-zA-Z0-9.-]+:[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+(\.git)?$ ]]; then
        echo "ERROR: Invalid repository URL format" >&2
        echo "  Expected: https://github.com/user/repo or git@github.com:user/repo" >&2
        return 1
    fi

    # Block suspicious patterns
    if [[ "$url" =~ [;\$\`\|&<>()] ]]; then
        echo "ERROR: Repository URL contains invalid characters" >&2
        return 1
    fi

    return 0
}

# Sanitize project path
# Ensures path is under base directory
sanitize_project_path() {
    local base_dir="$1"
    local project_name="$2"

    # Validate inputs
    if ! validate_project_name "$project_name"; then
        return 1
    fi

    # Construct path
    local project_path="$base_dir/$project_name"

    # Resolve to canonical path
    local canonical_path
    canonical_path=$(readlink -f "$project_path" 2>/dev/null || echo "$project_path")

    # Verify it's under base_dir
    if [[ ! "$canonical_path" =~ ^$base_dir/ ]]; then
        echo "ERROR: Project path escapes base directory" >&2
        return 1
    fi

    echo "$canonical_path"
    return 0
}
