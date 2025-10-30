#!/bin/bash
# extension-manager.sh - Manage extension scripts activation and deactivation
# Extension API v1.0 - Manifest-based activation with install/uninstall support
# This script provides comprehensive management of extension scripts in the extensions.d directory

# Determine script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if we're in the repository or on the VM
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    # In repository
    source "$SCRIPT_DIR/common.sh"
    EXTENSIONS_BASE="$SCRIPT_DIR/extensions.d"
elif [[ -f "/workspace/scripts/lib/common.sh" ]]; then
    # On VM
    source "/workspace/scripts/lib/common.sh"
    EXTENSIONS_BASE="/workspace/scripts/extensions.d"
else
    # Fallback - define minimal needed functions
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'

    print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
    print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
    print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
    print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
    print_debug() { [[ "${DEBUG:-}" == "true" ]] && echo -e "[DEBUG] $1"; }

    EXTENSIONS_BASE="./extensions.d"
fi

# Activation manifest file location (colocated with extensions)
if [[ -f "$EXTENSIONS_BASE/active-extensions.conf" ]]; then
    MANIFEST_FILE="$EXTENSIONS_BASE/active-extensions.conf"
elif [[ -f "/workspace/scripts/extensions.d/active-extensions.conf" ]]; then
    MANIFEST_FILE="/workspace/scripts/extensions.d/active-extensions.conf"
else
    # Default location
    MANIFEST_FILE="$EXTENSIONS_BASE/active-extensions.conf"
fi

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Function to extract extension name from filename
get_extension_name() {
    local filename="$1"
    local base=$(basename "$filename" .extension)
    # Remove leading numbers and dash (e.g., "10-rust" -> "rust")
    # This handles legacy naming and new naming without prefixes
    echo "$base" | sed 's/^[0-9]*-//'
}

# Function to check if an extension is activated
is_activated() {
    local example_file="$1"
    local activated_file="${example_file%.example}"
    [[ -f "$activated_file" ]]
}

# Function to check if an extension is protected (00 prefix for core initialization)
is_protected_extension() {
    local filename="$1"
    local base=$(basename "$filename" .extension)
    base=$(basename "$base" .sh)

    # Check if filename starts with 00 (core initialization script)
    if [[ "$base" =~ ^00- ]]; then
        return 0  # Protected
    fi
    return 1  # Not protected
}

# Function to check if a file has been modified from its example
file_has_been_modified() {
    local activated_file="$1"
    local example_file="${activated_file}.example"

    # If example doesn't exist, can't compare
    [[ ! -f "$example_file" ]] && return 0

    # Use checksum to compare files
    if command -v md5sum >/dev/null 2>&1; then
        local sum1=$(md5sum "$activated_file" 2>/dev/null | cut -d' ' -f1)
        local sum2=$(md5sum "$example_file" 2>/dev/null | cut -d' ' -f1)
    elif command -v md5 >/dev/null 2>&1; then
        local sum1=$(md5 -q "$activated_file" 2>/dev/null)
        local sum2=$(md5 -q "$example_file" 2>/dev/null)
    else
        # Fallback to byte comparison if no checksum tool
        if ! cmp -s "$activated_file" "$example_file"; then
            return 0  # Modified
        fi
        return 1  # Not modified
    fi

    [[ "$sum1" != "$sum2" ]]
}

# Function to create a backup of a file
create_backup() {
    local file="$1"
    local backup_file="${file}.backup"

    if cp "$file" "$backup_file"; then
        print_success "Backup created: $(basename "$backup_file")"
        return 0
    else
        print_error "Failed to create backup"
        return 1
    fi
}

# ============================================================================
# MANIFEST MANAGEMENT FUNCTIONS
# ============================================================================

# Read active extensions from manifest file
# Returns array of extension names in order
read_manifest() {
    local extensions=()

    if [[ ! -f "$MANIFEST_FILE" ]]; then
        print_debug "Manifest file not found: $MANIFEST_FILE"
        return 0
    fi

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Trim whitespace
        local ext_name=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -n "$ext_name" ]] && extensions+=("$ext_name")
    done < "$MANIFEST_FILE"

    printf '%s\n' "${extensions[@]}"
}

# Check if extension is in manifest
is_in_manifest() {
    local ext_name="$1"

    if [[ ! -f "$MANIFEST_FILE" ]]; then
        return 1
    fi

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        local manifest_name=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$manifest_name" == "$ext_name" ]]; then
            return 0
        fi
    done < "$MANIFEST_FILE"

    return 1
}

# Add extension to manifest
add_to_manifest() {
    local ext_name="$1"

    # Create manifest if it doesn't exist
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        mkdir -p "$(dirname "$MANIFEST_FILE")"
        cat > "$MANIFEST_FILE" << 'EOF'
# Active Extensions Configuration
# Extensions are executed in the order listed below
EOF
    fi

    # Check if already in manifest
    if is_in_manifest "$ext_name"; then
        print_warning "Extension '$ext_name' is already in manifest"
        return 1
    fi

    # Add to manifest
    echo "$ext_name" >> "$MANIFEST_FILE"
    print_success "Added '$ext_name' to activation manifest"
    return 0
}

# Remove extension from manifest
remove_from_manifest() {
    local ext_name="$1"

    if [[ ! -f "$MANIFEST_FILE" ]]; then
        print_error "Manifest file not found: $MANIFEST_FILE"
        return 1
    fi

    # Check if in manifest
    if ! is_in_manifest "$ext_name"; then
        print_warning "Extension '$ext_name' is not in manifest"
        return 1
    fi

    # Remove from manifest (create temp file to preserve comments)
    local temp_file=$(mktemp)
    while IFS= read -r line; do
        # Keep comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            echo "$line" >> "$temp_file"
            continue
        fi

        # Check if this line matches extension name
        local manifest_name=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$manifest_name" != "$ext_name" ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$MANIFEST_FILE"

    mv "$temp_file" "$MANIFEST_FILE"
    print_success "Removed '$ext_name' from activation manifest"
    return 0
}

# Get position of extension in manifest
get_manifest_position() {
    local ext_name="$1"
    local position=1

    if [[ ! -f "$MANIFEST_FILE" ]]; then
        return 1
    fi

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        local manifest_name=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$manifest_name" == "$ext_name" ]]; then
            echo "$position"
            return 0
        fi
        ((position++))
    done < "$MANIFEST_FILE"

    return 1
}

# ============================================================================
# EXTENSION DISCOVERY FUNCTIONS
# ============================================================================

# Find extension file by name
find_extension_file() {
    local ext_name="$1"

    # Try exact match first (new naming: rust.extension)
    if [[ -f "$EXTENSIONS_BASE/${ext_name}.extension" ]]; then
        echo "$EXTENSIONS_BASE/${ext_name}.extension"
        return 0
    fi

    # Try with numeric prefixes (legacy naming: 10-rust.extension)
    for example_file in "$EXTENSIONS_BASE"/*-"${ext_name}".extension; do
        if [[ -f "$example_file" ]]; then
            echo "$example_file"
            return 0
        fi
    done

    # Try pattern match
    for example_file in "$EXTENSIONS_BASE"/*.extension; do
        [[ ! -f "$example_file" ]] && continue
        local name=$(get_extension_name "$(basename "$example_file")")
        if [[ "$name" == "$ext_name" ]]; then
            echo "$example_file"
            return 0
        fi
    done

    return 1
}

# Get activated extension file (the .extension file itself, already active)
get_activated_file() {
    local ext_name="$1"
    local extension_file

    extension_file=$(find_extension_file "$ext_name")
    if [[ -z "$extension_file" ]]; then
        return 1
    fi

    # With the .extension naming, the file itself is the activated file
    echo "$extension_file"
    return 0
}

# ============================================================================
# EXTENSION EXECUTION FUNCTIONS
# ============================================================================

# Call a function from an extension if it exists
call_extension_function() {
    local ext_name="$1"
    local function_name="$2"
    shift 2
    local args=("$@")

    # Find and source the extension file
    local activated_file
    activated_file=$(get_activated_file "$ext_name")

    if [[ -z "$activated_file" ]] || [[ ! -f "$activated_file" ]]; then
        print_error "Extension '$ext_name' is not activated"
        return 1
    fi

    # Source the extension
    source "$activated_file"

    # Check if function exists
    if ! declare -F "$function_name" >/dev/null 2>&1; then
        print_error "Function '$function_name' not found in extension '$ext_name'"
        return 1
    fi

    # Call the function with provided arguments
    "$function_name" "${args[@]}"
}

# ============================================================================
# COMMAND FUNCTIONS (Manifest-based)
# ============================================================================

# Function to list all extensions with manifest status
list_extensions() {
    print_status "Available extensions in $EXTENSIONS_BASE:"
    print_status "Manifest: $MANIFEST_FILE"
    echo ""

    local found_any=false
    local active_extensions=()

    # Read active extensions from manifest
    if [[ -f "$MANIFEST_FILE" ]]; then
        mapfile -t active_extensions < <(read_manifest)
    fi

    # Show activated extensions first (in manifest order)
    if [[ ${#active_extensions[@]} -gt 0 ]]; then
        print_success "Active Extensions (in execution order):"
        local position=1
        for ext_name in "${active_extensions[@]}"; do
            local example_file
            example_file=$(find_extension_file "$ext_name")
            if [[ -n "$example_file" ]]; then
                local filename=$(basename "$example_file")
                echo -e "  ${position}. ${GREEN}✓${NC} $ext_name ($filename)"
                found_any=true
                ((position++))
            else
                echo -e "  ${position}. ${RED}✗${NC} $ext_name ${RED}[NOT FOUND]${NC}"
                ((position++))
            fi
        done
        echo ""
    fi

    # Show available but inactive extensions
    print_status "Available Extensions (not activated):"
    local inactive_found=false
    for extension_file in "$EXTENSIONS_BASE"/*.extension; do
        [[ ! -f "$extension_file" ]] && continue
        found_any=true

        local name=$(get_extension_name "$(basename "$extension_file")")
        local filename=$(basename "$extension_file")

        # Skip if in manifest
        if is_in_manifest "$name"; then
            continue
        fi

        echo -e "  ${YELLOW}○${NC} $name ($filename)"
        inactive_found=true
    done

    if [[ "$inactive_found" == "false" ]]; then
        echo "  (none)"
    fi

    if [[ "$found_any" == "false" ]]; then
        print_warning "No extension examples found in $EXTENSIONS_BASE"
        return 1
    fi

    echo ""
    print_status "Commands:"
    echo "  extension-manager install <name>      # Install extension (auto-activates if needed)"
    echo "  extension-manager install-all         # Install all extensions in manifest"
    echo "  extension-manager uninstall <name>    # Uninstall extension"
    echo "  extension-manager validate <name>     # Run validation tests"
    echo "  extension-manager status <name>       # Check installation status"
    echo "  extension-manager deactivate <name>   # Remove from manifest"
    echo "  extension-manager reorder <name> <pos> # Change execution order"
}


# Function to deactivate a single extension (remove from manifest, optionally delete file)
deactivate_extension() {
    local extension_name="$1"
    local delete_file="${2:-no}"  # yes|no

    # Remove from manifest
    if ! remove_from_manifest "$extension_name"; then
        return 1
    fi

    # Optionally delete the activated file
    if [[ "$delete_file" == "yes" ]]; then
        local activated_file
        activated_file=$(get_activated_file "$extension_name")

        if [[ -n "$activated_file" ]] && [[ -f "$activated_file" ]]; then
            if rm "$activated_file"; then
                print_success "Removed activated file: $(basename "$activated_file")"
            else
                print_warning "Failed to remove activated file"
            fi
        fi
    else
        print_status "Activated file preserved (use 'rm' to delete if needed)"
    fi

    print_success "Extension '$extension_name' deactivated"
    return 0
}

# Function to auto-activate an extension if needed (copy .example to .sh)
auto_activate_extension() {
    local ext_name="$1"

    # Check if already activated
    local activated_file
    activated_file=$(get_activated_file "$ext_name")

    if [[ -n "$activated_file" ]] && [[ -f "$activated_file" ]]; then
        # Already activated
        return 0
    fi

    # Find the .example file
    local example_file
    example_file=$(find_extension_file "$ext_name")

    if [[ -z "$example_file" ]]; then
        print_error "Extension '$ext_name' not found"
        echo "Available extensions:"
        for ef in "$EXTENSIONS_BASE"/*.extension; do
            [[ -f "$ef" ]] && echo "  - $(get_extension_name "$(basename "$ef")")"
        done
        return 1
    fi

    # With .extension naming, file is already activated, just ensure executable
    print_status "Ensuring extension '$ext_name' is executable..."
    chmod +x "$example_file"
    print_success "Extension '$ext_name' ready"
    return 0
}

# Function to install an extension (prerequisites + install + configure)
install_extension() {
    local ext_name="$1"

    print_status "Installing extension: $ext_name"
    echo ""

    # Auto-activate if needed
    if ! auto_activate_extension "$ext_name"; then
        return 1
    fi

    # Get the activated file
    local activated_file
    activated_file=$(get_activated_file "$ext_name")

    if [[ -z "$activated_file" ]] || [[ ! -f "$activated_file" ]]; then
        print_error "Extension '$ext_name' could not be activated"
        return 1
    fi

    # Source the extension
    source "$activated_file"

    # Run prerequisites check
    print_status "Checking prerequisites..."
    if declare -F prerequisites >/dev/null 2>&1; then
        if ! prerequisites; then
            print_error "Prerequisites not met for '$ext_name'"
            return 1
        fi
    else
        print_warning "No prerequisites() function found"
    fi

    # Run install
    print_status "Running installation..."
    if declare -F install >/dev/null 2>&1; then
        if ! install; then
            print_error "Installation failed for '$ext_name'"
            return 1
        fi
    else
        print_error "No install() function found in '$ext_name'"
        return 1
    fi

    # Run configure
    print_status "Running configuration..."
    if declare -F configure >/dev/null 2>&1; then
        if ! configure; then
            print_warning "Configuration had issues for '$ext_name'"
        fi
    else
        print_warning "No configure() function found"
    fi

    print_success "Extension '$ext_name' installed successfully"
    print_status "Run validation: extension-manager validate $ext_name"
    return 0
}

# Function to uninstall an extension (remove)
uninstall_extension() {
    local ext_name="$1"

    print_status "Uninstalling extension: $ext_name"
    echo ""

    # Check if extension exists and is activated
    local activated_file
    activated_file=$(get_activated_file "$ext_name")

    if [[ -z "$activated_file" ]] || [[ ! -f "$activated_file" ]]; then
        print_error "Extension '$ext_name' is not activated"
        return 1
    fi

    # Source the extension
    source "$activated_file"

    # Run remove
    if declare -F remove >/dev/null 2>&1; then
        if ! remove; then
            print_error "Uninstallation failed for '$ext_name'"
            return 1
        fi
    else
        print_error "No remove() function found in '$ext_name'"
        return 1
    fi

    print_success "Extension '$ext_name' uninstalled successfully"
    return 0
}

# Function to validate an extension
validate_extension() {
    local ext_name="$1"

    print_status "Validating extension: $ext_name"
    echo ""

    # Check if extension exists and is activated
    local activated_file
    activated_file=$(get_activated_file "$ext_name")

    if [[ -z "$activated_file" ]] || [[ ! -f "$activated_file" ]]; then
        print_error "Extension '$ext_name' is not activated"
        return 1
    fi

    # Source the extension
    source "$activated_file"

    # Run validate
    if declare -F validate >/dev/null 2>&1; then
        if validate; then
            print_success "Validation passed for '$ext_name'"
            return 0
        else
            print_error "Validation failed for '$ext_name'"
            return 1
        fi
    else
        print_warning "No validate() function found in '$ext_name'"
        return 1
    fi
}

# Function to check status of an extension
status_extension() {
    local ext_name="$1"

    print_status "Checking status: $ext_name"
    echo ""

    # Check if extension exists and is activated
    local activated_file
    activated_file=$(get_activated_file "$ext_name")

    if [[ -z "$activated_file" ]] || [[ ! -f "$activated_file" ]]; then
        print_warning "Extension '$ext_name' is not activated"
        return 1
    fi

    # Check if in manifest
    if is_in_manifest "$ext_name"; then
        local position
        position=$(get_manifest_position "$ext_name")
        print_success "Active in manifest (position: $position)"
    else
        print_warning "File exists but not in manifest"
    fi

    # Source the extension
    source "$activated_file"

    # Run status
    if declare -F status >/dev/null 2>&1; then
        if status; then
            return 0
        else
            return 1
        fi
    else
        print_warning "No status() function found in '$ext_name'"
        return 1
    fi
}

# Function to run interactive extension installation
interactive_install() {
    print_status "🔧 Interactive Extension Installation"
    echo "======================================"
    echo ""

    # Show current manifest status
    print_status "Current active extensions:"
    echo ""
    list_extensions
    echo ""

    # Ask if user wants to review/edit manifest
    if confirm "Review and edit active extensions?" "n"; then
        echo ""
        print_status "Edit the manifest file to activate/deactivate extensions:"
        print_status "File: $MANIFEST_FILE"
        echo ""
        print_status "Uncomment extensions you want to install, comment out those you don't."
        echo ""
        read -p "Press Enter when ready to continue..."
    fi

    # Re-read manifest in case it was edited
    local active_extensions=()
    mapfile -t active_extensions < <(read_manifest)

    if [[ ${#active_extensions[@]} -eq 0 ]]; then
        print_warning "No extensions are active in the manifest"
        if confirm "Would you like to activate some extensions now?" "y"; then
            list_extensions
            echo ""
            print_status "To activate extensions, uncomment them in: $MANIFEST_FILE"
            return 1
        fi
        return 0
    fi

    # Show what will be installed
    echo ""
    print_status "The following extensions will be installed:"
    for ext_name in "${active_extensions[@]}"; do
        echo "  • $ext_name"
    done
    echo ""

    # Confirm installation
    if ! confirm "Proceed with installation?" "y"; then
        print_status "Installation cancelled"
        return 0
    fi

    # Install all active extensions
    install_all_extensions
}

# Function to install all active extensions
install_all_extensions() {
    print_status "Installing all active extensions..."
    echo ""

    local active_extensions=()
    mapfile -t active_extensions < <(read_manifest)

    if [[ ${#active_extensions[@]} -eq 0 ]]; then
        print_warning "No extensions in activation manifest"
        print_status "Edit the manifest: $MANIFEST_FILE"
        return 0
    fi

    local installed_count=0
    local failed_count=0

    for ext_name in "${active_extensions[@]}"; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if install_extension "$ext_name"; then
            ((installed_count++))
        else
            ((failed_count++))
            print_error "Failed to install: $ext_name"
        fi
        echo ""
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_status "Installation Summary:"
    print_success "  Installed: $installed_count"
    [[ $failed_count -gt 0 ]] && print_error "  Failed: $failed_count"

    [[ $failed_count -eq 0 ]] && return 0 || return 1
}

# Function to validate all active extensions
validate_all_extensions() {
    print_status "Validating all active extensions..."
    echo ""

    local active_extensions=()
    mapfile -t active_extensions < <(read_manifest)

    if [[ ${#active_extensions[@]} -eq 0 ]]; then
        print_warning "No extensions in activation manifest"
        return 0
    fi

    local validated_count=0
    local failed_count=0

    for ext_name in "${active_extensions[@]}"; do
        if validate_extension "$ext_name"; then
            ((validated_count++))
        else
            ((failed_count++))
        fi
        echo ""
    done

    print_status "Validation Summary:"
    print_success "  Passed: $validated_count"
    [[ $failed_count -gt 0 ]] && print_error "  Failed: $failed_count"

    [[ $failed_count -eq 0 ]] && return 0 || return 1
}

# Function to reorder extension in manifest
reorder_extension() {
    local ext_name="$1"
    local new_position="$2"

    if [[ ! "$new_position" =~ ^[0-9]+$ ]]; then
        print_error "Position must be a number"
        return 1
    fi

    if ! is_in_manifest "$ext_name"; then
        print_error "Extension '$ext_name' is not in manifest"
        return 1
    fi

    # Read all extensions
    local extensions=()
    mapfile -t extensions < <(read_manifest)

    # Remove the extension from current position
    local filtered=()
    for ext in "${extensions[@]}"; do
        [[ "$ext" != "$ext_name" ]] && filtered+=("$ext")
    done

    # Insert at new position (1-indexed)
    local result=()
    local inserted=false
    for i in "${!filtered[@]}"; do
        if [[ $((i + 1)) -eq $new_position ]]; then
            result+=("$ext_name")
            inserted=true
        fi
        result+=("${filtered[$i]}")
    done

    # If position is after end, append
    if [[ "$inserted" == "false" ]]; then
        result+=("$ext_name")
    fi

    # Write back to manifest
    local temp_file=$(mktemp)

    # Preserve header comments
    if [[ -f "$MANIFEST_FILE" ]]; then
        grep '^#' "$MANIFEST_FILE" > "$temp_file" || true
    fi

    # Add extensions in new order
    for ext in "${result[@]}"; do
        echo "$ext" >> "$temp_file"
    done

    mv "$temp_file" "$MANIFEST_FILE"
    print_success "Moved '$ext_name' to position $new_position"
    return 0
}

# Function to show status of all active extensions
status_all_extensions() {
    local format="${1:-text}"

    # Read active extensions from manifest
    local active_extensions=()
    mapfile -t active_extensions < <(read_manifest)

    if [[ ${#active_extensions[@]} -eq 0 ]]; then
        if [[ "$format" == "json" ]]; then
            echo '{"error": "No extensions in activation manifest", "extensions": []}'
        else
            print_warning "No extensions in activation manifest"
            print_status "Edit the manifest: $MANIFEST_FILE"
        fi
        return 0
    fi

    if [[ "$format" == "json" ]]; then
        # JSON output for programmatic use
        echo '{'
        echo "  \"generated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"hostname\": \"$(hostname)\","
        echo "  \"manifest\": \"$MANIFEST_FILE\","
        echo '  "extensions": ['

        local first=true
        for ext_name in "${active_extensions[@]}"; do
            [[ "$first" == "false" ]] && echo ','
            first=false

            # Get extension file
            local activated_file
            activated_file=$(get_activated_file "$ext_name")

            echo -n "    {"
            echo -n "\"name\": \"$ext_name\", "

            if [[ -n "$activated_file" ]] && [[ -f "$activated_file" ]]; then
                echo -n "\"file\": \"$activated_file\", "
                echo -n "\"activated\": true, "

                # Check if in manifest
                if is_in_manifest "$ext_name"; then
                    local position
                    position=$(get_manifest_position "$ext_name")
                    echo -n "\"position\": $position, "
                    echo -n "\"in_manifest\": true"
                else
                    echo -n "\"in_manifest\": false"
                fi
            else
                echo -n "\"activated\": false, "
                echo -n "\"error\": \"Extension file not found\""
            fi

            echo -n "}"
        done

        echo ""
        echo '  ]'
        echo '}'
    else
        # Human-readable text output
        echo "=== Extension Status Report ==="
        echo "Generated: $(date)"
        echo "Hostname: $(hostname)"
        echo "Manifest: $MANIFEST_FILE"
        echo ""

        # Iterate through all active extensions
        for ext_name in "${active_extensions[@]}"; do
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            status_extension "$ext_name"
            echo ""
        done

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_success "Status report completed for ${#active_extensions[@]} extension(s)"
    fi

    return 0
}

# Function to perform health check on extension system
doctor_extensions() {
    print_status "Running extension system health check..."
    echo ""

    local issues_found=0

    # Check 1: Manifest file exists and is readable
    print_status "Checking manifest file..."
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        print_error "Manifest file not found: $MANIFEST_FILE"
        ((issues_found++))
    elif [[ ! -r "$MANIFEST_FILE" ]]; then
        print_error "Manifest file not readable: $MANIFEST_FILE"
        ((issues_found++))
    else
        print_success "Manifest file OK"
    fi
    echo ""

    # Check 2: Extensions directory exists and is accessible
    print_status "Checking extensions directory..."
    if [[ ! -d "$EXTENSIONS_BASE" ]]; then
        print_error "Extensions directory not found: $EXTENSIONS_BASE"
        ((issues_found++))
    elif [[ ! -r "$EXTENSIONS_BASE" ]]; then
        print_error "Extensions directory not readable: $EXTENSIONS_BASE"
        ((issues_found++))
    else
        print_success "Extensions directory OK"
    fi
    echo ""

    # Check 3: Disk space
    print_status "Checking disk space..."
    local workspace_avail
    if workspace_avail=$(df -h /workspace 2>/dev/null | awk 'NR==2 {print $4}'); then
        print_success "Available space in /workspace: $workspace_avail"
    else
        print_warning "Could not check disk space"
    fi
    echo ""

    # Check 4: Permissions
    print_status "Checking permissions..."
    if [[ -w "$EXTENSIONS_BASE" ]]; then
        print_success "Extensions directory is writable"
    else
        print_error "Extensions directory is not writable: $EXTENSIONS_BASE"
        ((issues_found++))
    fi
    echo ""

    # Check 5: Network connectivity (basic check)
    print_status "Checking network connectivity..."
    if ping -c 1 8.8.8.8 >/dev/null 2>&1 || ping -c 1 1.1.1.1 >/dev/null 2>&1; then
        print_success "Network connectivity OK"
    else
        print_warning "Network connectivity may be limited"
        print_status "Some extensions may fail to install packages"
    fi
    echo ""

    # Check 6: Run mise doctor if available
    print_status "Checking mise installation..."
    if command -v mise >/dev/null 2>&1; then
        print_success "mise is installed"
        echo ""
        print_status "Running 'mise doctor'..."
        echo ""
        mise doctor || print_warning "mise doctor reported issues"
    else
        print_status "mise not installed (optional)"
    fi
    echo ""

    # Check 7: Validate all active extensions
    print_status "Validating active extensions..."
    echo ""

    local active_extensions=()
    mapfile -t active_extensions < <(read_manifest)

    if [[ ${#active_extensions[@]} -eq 0 ]]; then
        print_warning "No extensions in activation manifest"
    else
        local validation_failed=0
        for ext_name in "${active_extensions[@]}"; do
            print_status "Validating: $ext_name"
            if validate_extension "$ext_name" 2>/dev/null; then
                print_success "  ✓ $ext_name validation passed"
            else
                print_error "  ✗ $ext_name validation failed"
                ((validation_failed++))
                ((issues_found++))
            fi
        done

        echo ""
        if [[ $validation_failed -eq 0 ]]; then
            print_success "All extensions validated successfully"
        else
            print_error "$validation_failed extension(s) failed validation"
        fi
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ $issues_found -eq 0 ]]; then
        print_success "Health check completed: No issues found"
        return 0
    else
        print_warning "Health check completed: $issues_found issue(s) found"
        return 1
    fi
}

# Function to upgrade all tools managed by mise
upgrade_all_tools() {
    print_status "Upgrading all mise-managed tools..."
    echo ""

    # Check if mise is available
    if ! command -v mise >/dev/null 2>&1; then
        print_warning "mise is not installed"
        print_status "This command requires mise for tool management"
        print_status "Install mise with: extension-manager install mise"
        return 1
    fi

    # Run mise upgrade
    print_status "Running 'mise upgrade'..."
    echo ""

    if mise upgrade; then
        print_success "mise upgrade completed successfully"
    else
        print_error "mise upgrade failed"
        return 1
    fi

    echo ""
    print_status "Checking for extension updates..."
    print_status "Extension files are managed via git repository updates"
    print_status "To update extensions, pull the latest changes from the repository"

    echo ""
    print_success "Upgrade process completed"
    return 0
}

# Function to compare status snapshots
status_diff_extensions() {
    local snapshot_file="${1:-}"
    local temp_current=$(mktemp)

    # Generate current status snapshot in JSON
    print_status "Generating current status snapshot..."
    status_all_extensions "json" > "$temp_current"

    if [[ -z "$snapshot_file" ]]; then
        # No previous snapshot provided, just save current one
        local snapshot_path="/tmp/extension-status-$(date +%Y%m%d-%H%M%S).json"
        cp "$temp_current" "$snapshot_path"
        print_success "Status snapshot saved to: $snapshot_path"
        print_status "Run 'extension-manager status-diff $snapshot_path' later to compare"
        rm -f "$temp_current"
        return 0
    fi

    if [[ ! -f "$snapshot_file" ]]; then
        print_error "Snapshot file not found: $snapshot_file"
        rm -f "$temp_current"
        return 1
    fi

    print_status "Comparing with snapshot: $snapshot_file"
    echo ""

    # Extract extension names from both snapshots
    local prev_extensions=$(grep -o '"name": "[^"]*"' "$snapshot_file" 2>/dev/null | cut -d'"' -f4 | sort)
    local curr_extensions=$(grep -o '"name": "[^"]*"' "$temp_current" 2>/dev/null | cut -d'"' -f4 | sort)

    # Find differences
    local added=()
    local removed=()
    local common=()

    # Find added extensions
    while IFS= read -r ext; do
        if ! echo "$prev_extensions" | grep -q "^${ext}$"; then
            added+=("$ext")
        else
            common+=("$ext")
        fi
    done <<< "$curr_extensions"

    # Find removed extensions
    while IFS= read -r ext; do
        if ! echo "$curr_extensions" | grep -q "^${ext}$"; then
            removed+=("$ext")
        fi
    done <<< "$prev_extensions"

    # Display results
    echo "=== Status Comparison Report ==="
    echo "Previous snapshot: $snapshot_file"
    echo "Current time: $(date)"
    echo ""

    if [[ ${#added[@]} -gt 0 ]]; then
        print_success "Added extensions (${#added[@]}):"
        for ext in "${added[@]}"; do
            echo "  + $ext"
        done
        echo ""
    fi

    if [[ ${#removed[@]} -gt 0 ]]; then
        print_warning "Removed extensions (${#removed[@]}):"
        for ext in "${removed[@]}"; do
            echo "  - $ext"
        done
        echo ""
    fi

    if [[ ${#common[@]} -gt 0 ]]; then
        print_status "Unchanged extensions (${#common[@]}):"
        for ext in "${common[@]}"; do
            echo "  = $ext"
        done
        echo ""
    fi

    if [[ ${#added[@]} -eq 0 ]] && [[ ${#removed[@]} -eq 0 ]]; then
        print_success "No changes detected"
    fi

    # Cleanup
    rm -f "$temp_current"

    return 0
}

# Function to show help
show_help() {
    cat << EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

Manage extension scripts with manifest-based activation and lifecycle management.
Extension API v1.0

Commands:
  list                     List all extensions with manifest status

  install <name>           Install extension (auto-activates if needed)
  install-all              Install all extensions listed in manifest
  --interactive            Interactive installation with prompts
  uninstall <name>         Uninstall extension (remove packages and config)

  validate <name>          Run extension validation tests
  validate-all             Validate all active extensions
  status <name>            Check extension installation status
  status-all [--json]      Show status of all active extensions

  doctor                   Run health check on extension system
  upgrade-all              Upgrade all mise-managed tools
  status-diff [snapshot]   Compare status with previous snapshot

  deactivate <name>        Remove extension from manifest
  reorder <name> <pos>     Change extension execution order in manifest
  help                     Show this help message

Options:
  --yes                    Skip confirmation prompts (for install/uninstall)
  --json                   Output in JSON format (for status-all)

Examples:
  # List all extensions and show activation status
  $(basename "$0") list

  # Interactive installation with prompts
  $(basename "$0") --interactive

  # Install an extension (auto-activates if needed)
  $(basename "$0") install rust

  # Install all extensions listed in manifest
  $(basename "$0") install-all

  # Check status and validate
  $(basename "$0") status rust
  $(basename "$0") validate rust
  $(basename "$0") validate-all

  # Show status of all active extensions
  $(basename "$0") status-all
  $(basename "$0") status-all --json | jq .

  # Run health check
  $(basename "$0") doctor

  # Upgrade all tools
  $(basename "$0") upgrade-all

  # Create and compare status snapshots
  $(basename "$0") status-diff                    # Create snapshot
  $(basename "$0") status-diff /tmp/snapshot.json # Compare with snapshot

  # Uninstall and deactivate
  $(basename "$0") uninstall rust
  $(basename "$0") deactivate rust

  # Change execution order (edit manifest or use reorder)
  $(basename "$0") reorder python 1       # Move python to first position

Manifest File:
  Location: $MANIFEST_FILE
  Extensions execute in the order listed in the manifest.

Extension Structure:
  Each extension must implement these functions:
    - prerequisites()  Check requirements before install
    - install()        Install packages and tools
    - configure()      Post-install configuration
    - validate()       Run smoke tests
    - status()         Check current installation state
    - remove()         Uninstall packages and cleanup

Note: Extensions are files in $EXTENSIONS_BASE
EOF
}

# Main script logic
main() {
    local command="${1:-list}"
    shift || true

    case "$command" in
        list)
            list_extensions
            ;;
        deactivate)
            if [[ -z "$1" ]]; then
                print_error "Extension name required"
                echo "Usage: extension-manager deactivate <extension-name>"
                exit 1
            fi
            deactivate_extension "$1"
            ;;
        install)
            if [[ -z "$1" ]]; then
                print_error "Extension name required"
                echo "Usage: extension-manager install <extension-name>"
                exit 1
            fi
            install_extension "$1"
            ;;
        uninstall)
            if [[ -z "$1" ]]; then
                print_error "Extension name required"
                echo "Usage: extension-manager uninstall <extension-name>"
                exit 1
            fi
            uninstall_extension "$1"
            ;;
        validate)
            if [[ -z "$1" ]]; then
                print_error "Extension name required"
                echo "Usage: extension-manager validate <extension-name>"
                exit 1
            fi
            validate_extension "$1"
            ;;
        status)
            if [[ -z "$1" ]]; then
                print_error "Extension name required"
                echo "Usage: extension-manager status <extension-name>"
                exit 1
            fi
            status_extension "$1"
            ;;
        status-all)
            # Check for --json flag
            local format="text"
            if [[ "$1" == "--json" ]]; then
                format="json"
            fi
            status_all_extensions "$format"
            ;;
        doctor)
            doctor_extensions
            ;;
        upgrade-all)
            upgrade_all_tools
            ;;
        status-diff)
            status_diff_extensions "$1"
            ;;
        install-all)
            install_all_extensions
            ;;
        --interactive|interactive)
            interactive_install
            ;;
        validate-all)
            validate_all_extensions
            ;;
        reorder)
            if [[ -z "$1" ]] || [[ -z "$2" ]]; then
                print_error "Extension name and position required"
                echo "Usage: extension-manager reorder <extension-name> <position>"
                exit 1
            fi
            reorder_extension "$1" "$2"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
