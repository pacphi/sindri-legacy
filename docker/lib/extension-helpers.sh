#!/bin/bash
# Extension helper functions for secure operations
# Part of Sindri security hardening initiative

# Secure download with checksum verification
# Usage: secure_download URL EXPECTED_SHA256 OUTPUT_FILE
secure_download() {
    local url="$1"
    local expected_sha256="$2"
    local output_file="$3"
    local temp_file

    temp_file=$(mktemp) || {
        echo "ERROR: Failed to create temporary file" >&2
        return 1
    }

    # Ensure cleanup
    trap 'rm -f "$temp_file"' RETURN

    # Download with timeout and TLS verification
    if ! curl --proto '=https' --tlsv1.2 -sSfL \
         --max-time 120 \
         --connect-timeout 30 \
         -o "$temp_file" \
         "$url"; then
        echo "ERROR: Download failed from $url" >&2
        return 1
    fi

    # Verify checksum
    local actual_sha256
    actual_sha256=$(sha256sum "$temp_file" | cut -d' ' -f1)

    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        echo "ERROR: Checksum mismatch!" >&2
        echo "  Expected: $expected_sha256" >&2
        echo "  Actual:   $actual_sha256" >&2
        return 1
    fi

    # Move to final location
    mv "$temp_file" "$output_file"
    return 0
}

# Secure script execution (download, verify, execute, cleanup)
# Usage: secure_execute URL EXPECTED_SHA256 [ARGS...]
secure_execute() {
    local url="$1"
    local expected_sha256="$2"
    shift 2
    local args=("$@")
    local temp_script

    temp_script=$(mktemp) || {
        echo "ERROR: Failed to create temporary file" >&2
        return 1
    }

    # Ensure cleanup
    trap 'rm -f "$temp_script"' RETURN

    if ! secure_download "$url" "$expected_sha256" "$temp_script"; then
        return 1
    fi

    chmod +x "$temp_script"
    bash "$temp_script" "${args[@]}"
}

# Download and verify GPG key
# Usage: secure_gpg_key URL EXPECTED_SHA256 OUTPUT_PATH
secure_gpg_key() {
    local url="$1"
    local expected_sha256="$2"
    local output_path="$3"

    if ! secure_download "$url" "$expected_sha256" "$output_path"; then
        return 1
    fi

    # Verify it's a valid GPG key
    if ! gpg --show-keys "$output_path" >/dev/null 2>&1; then
        echo "ERROR: Invalid GPG key format" >&2
        return 1
    fi

    return 0
}

# Secure temporary file creation with automatic cleanup
# Returns temp file path via stdout
create_secure_temp_file() {
    local temp_file
    temp_file=$(mktemp) || {
        echo "ERROR: Failed to create temporary file" >&2
        return 1
    }

    # Set restrictive permissions immediately
    chmod 600 "$temp_file" || {
        rm -f "$temp_file"
        echo "ERROR: Failed to set temp file permissions" >&2
        return 1
    }

    echo "$temp_file"
    return 0
}

# Secure temporary directory creation with automatic cleanup
# Returns temp directory path via stdout
create_secure_temp_dir() {
    local temp_dir
    temp_dir=$(mktemp -d) || {
        echo "ERROR: Failed to create temporary directory" >&2
        return 1
    }

    # Set restrictive permissions immediately
    chmod 700 "$temp_dir" || {
        rm -rf "$temp_dir"
        echo "ERROR: Failed to set temp directory permissions" >&2
        return 1
    }

    echo "$temp_dir"
    return 0
}

# Setup cleanup trap for temporary files/directories
# Usage: setup_cleanup_trap temp_file1 temp_file2 temp_dir1 ...
setup_cleanup_trap() {
    local items=("$@")

    # shellcheck disable=SC2329  # Function invoked via trap
    cleanup() {
        local exit_code=$?
        for item in "${items[@]}"; do
            if [[ -d "$item" ]]; then
                rm -rf "$item" 2>/dev/null
            elif [[ -f "$item" ]]; then
                rm -f "$item" 2>/dev/null
            fi
        done
        exit $exit_code
    }

    trap cleanup EXIT INT TERM
}

# Get checksum from manifest
# Usage: get_checksum URL
get_checksum() {
    local url="$1"
    local checksums_file="/docker/lib/extensions.d/checksums.txt"

    if [[ ! -f "$checksums_file" ]]; then
        echo "ERROR: Checksums file not found: $checksums_file" >&2
        return 1
    fi

    grep -F "$url" "$checksums_file" 2>/dev/null | head -n1 | cut -d' ' -f1
}
