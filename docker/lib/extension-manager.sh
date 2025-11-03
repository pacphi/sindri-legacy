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
    EXTENSIONS_BASE="/workspace/scripts/lib/extensions.d"
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

# Source upgrade history tracking
if [[ -f "$SCRIPT_DIR/upgrade-history.sh" ]]; then
    source "$SCRIPT_DIR/upgrade-history.sh"
elif [[ -f "/workspace/scripts/lib/upgrade-history.sh" ]]; then
    source "/workspace/scripts/lib/upgrade-history.sh"
fi

# Activation manifest file location (colocated with extensions)
if [[ -f "$EXTENSIONS_BASE/active-extensions.conf" ]]; then
    MANIFEST_FILE="$EXTENSIONS_BASE/active-extensions.conf"
elif [[ -f "/workspace/scripts/lib/extensions.d/active-extensions.conf" ]]; then
    MANIFEST_FILE="/workspace/scripts/lib/extensions.d/active-extensions.conf"
else
    # Default location
    MANIFEST_FILE="$EXTENSIONS_BASE/active-extensions.conf"
fi

# Core extensions that cannot be removed/deactivated
# These provide foundational system functionality and are installed first
PROTECTED_EXTENSIONS=(
    "workspace-structure"   # Must be first - creates directory structure
    "mise-config"           # Must be second - enables mise for other extensions
    "ssh-environment"       # Must be third - SSH config for CI/CD
)

# Extensions that must run last (cleanup, finalization)
CLEANUP_EXTENSIONS=(
    "post-cleanup"
)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Check if extension is installed (has successful status)
# Returns: 0 if installed, 1 if not installed or no status function
is_extension_installed() {
    local ext_name="$1"

    # Get the activated file
    local activated_file
    activated_file=$(get_activated_file "$ext_name")

    if [[ -z "$activated_file" ]] || [[ ! -f "$activated_file" ]]; then
        return 1
    fi

    # Source the extension
    source "$activated_file"

    # Check if status function exists and succeeds
    if declare -F status >/dev/null 2>&1; then
        # Suppress output and just check exit code
        if status >/dev/null 2>&1; then
            return 0
        fi
    fi

    return 1
}

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

# Function to check if an extension is protected (core extensions that cannot be removed)
is_protected_extension() {
    local ext_name="$1"

    # Remove file extension and path if present
    ext_name=$(basename "$ext_name" .extension)
    ext_name=$(basename "$ext_name" .sh)

    # Check if extension is in the protected list
    for protected in "${PROTECTED_EXTENSIONS[@]}"; do
        if [[ "$ext_name" == "$protected" ]]; then
            return 0  # Protected
        fi
    done

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

# Ensure protected extensions are in manifest and at the top
ensure_protected_extensions() {
    print_debug "Ensuring protected extensions are in manifest..."

    # Create manifest if it doesn't exist
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        mkdir -p "$(dirname "$MANIFEST_FILE")"
        cat > "$MANIFEST_FILE" << 'EOF'
# Active Extensions Configuration
# Extensions are executed in the order listed below
EOF
    fi

    # Read current manifest
    local current_extensions=()
    mapfile -t current_extensions < <(read_manifest)

    # Build new manifest content with protected extensions first
    local temp_file=$(mktemp)

    # Write header
    cat > "$temp_file" << 'EOF'
# Active Extensions Configuration
# Extensions are executed in the order listed below
# Protected extensions (required for system functionality):
EOF

    # Add protected extensions first (if they exist as files)
    local added_protected=()
    for protected in "${PROTECTED_EXTENSIONS[@]}"; do
        local ext_file=$(find_extension_file "$protected")
        if [[ -n "$ext_file" ]]; then
            echo "$protected" >> "$temp_file"
            added_protected+=("$protected")
            print_debug "  Protected extension: $protected"
        else
            print_warning "Protected extension file not found: $protected"
        fi
    done

    # Add blank line after protected extensions if any were added
    if [[ ${#added_protected[@]} -gt 0 ]]; then
        echo "" >> "$temp_file"
        echo "# Additional extensions:" >> "$temp_file"
    fi

    # Add remaining extensions (excluding protected ones)
    for ext_name in "${current_extensions[@]}"; do
        local is_protected=false
        for protected in "${added_protected[@]}"; do
            if [[ "$ext_name" == "$protected" ]]; then
                is_protected=true
                break
            fi
        done

        if [[ "$is_protected" == "false" ]]; then
            echo "$ext_name" >> "$temp_file"
        fi
    done

    # Replace manifest with new version
    mv "$temp_file" "$MANIFEST_FILE"

    if [[ ${#added_protected[@]} -gt 0 ]]; then
        print_success "Protected extensions ensured in manifest (${added_protected[*]})"
    fi

    # Also ensure cleanup extensions are at the end
    ensure_cleanup_extensions_last

    return 0
}

# Ensure cleanup extensions are at the end of manifest
ensure_cleanup_extensions_last() {
    print_debug "Ensuring cleanup extensions run last..."

    if [[ ! -f "$MANIFEST_FILE" ]]; then
        return 0
    fi

    # Read current manifest preserving comments and structure
    local temp_file=$(mktemp)
    local found_cleanup=false
    local cleanup_lines=()

    # First pass: copy everything except cleanup extensions, track cleanup extensions
    while IFS= read -r line; do
        # Keep comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            echo "$line" >> "$temp_file"
            continue
        fi

        # Check if this is a cleanup extension
        local ext_name=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        local is_cleanup=false

        for cleanup in "${CLEANUP_EXTENSIONS[@]}"; do
            if [[ "$ext_name" == "$cleanup" ]]; then
                is_cleanup=true
                found_cleanup=true
                cleanup_lines+=("$ext_name")
                break
            fi
        done

        # Add non-cleanup extensions to temp file
        if [[ "$is_cleanup" == "false" ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$MANIFEST_FILE"

    # Add cleanup section if we found any cleanup extensions
    if [[ "$found_cleanup" == "true" ]]; then
        echo "" >> "$temp_file"
        echo "# Cleanup extensions (run last):" >> "$temp_file"
        for cleanup_ext in "${cleanup_lines[@]}"; do
            echo "$cleanup_ext" >> "$temp_file"
        done
        print_debug "  Cleanup extensions moved to end: ${cleanup_lines[*]}"
    fi

    # Replace manifest
    mv "$temp_file" "$MANIFEST_FILE"
    return 0
}

# ============================================================================
# EXTENSION DISCOVERY FUNCTIONS
# ============================================================================

# Find extension file by name
find_extension_file() {
    local ext_name="$1"

    # Directory structure: extensions.d/<name>/<name>.extension
    if [[ -f "$EXTENSIONS_BASE/${ext_name}/${ext_name}.extension" ]]; then
        echo "$EXTENSIONS_BASE/${ext_name}/${ext_name}.extension"
        return 0
    fi

    # Extension not found
    print_debug "Extension not found: $ext_name"
    print_debug "Expected location: $EXTENSIONS_BASE/${ext_name}/${ext_name}.extension"
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
    # Ensure protected extensions are in manifest first
    ensure_protected_extensions

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
                local protected_marker=""
                if is_protected_extension "$ext_name"; then
                    protected_marker=" ${YELLOW}[PROTECTED]${NC}"
                fi
                echo -e "  ${position}. ${GREEN}✓${NC} $ext_name ($filename)${protected_marker}"
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
    for extension_dir in "$EXTENSIONS_BASE"/*/; do
        [[ ! -d "$extension_dir" ]] && continue
        local name=$(basename "$extension_dir")

        # Check if extension file exists
        local extension_file="${extension_dir}${name}.extension"
        [[ ! -f "$extension_file" ]] && continue

        found_any=true

        # Skip if in manifest
        if is_in_manifest "$name"; then
            continue
        fi

        echo -e "  ${YELLOW}○${NC} $name (${name}.extension)"
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

    # Check if extension is protected
    if is_protected_extension "$extension_name"; then
        print_error "Cannot deactivate protected extension: $extension_name"
        print_status "Protected extensions are required for system functionality"
        return 1
    fi

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

    # Extension file exists and is ready to be sourced
    print_success "Extension '$ext_name' ready"
    return 0
}

# ============================================================================
# MIGRATION HELPERS (for transitioning to directory structure)
# ============================================================================

# Migrate extension from flat to directory structure (preserving file names)
migrate_extension_to_directory() {
    local ext_name="$1"

    # Check if already migrated
    if [[ -d "$EXTENSIONS_BASE/${ext_name}" ]]; then
        print_status "Extension '$ext_name' already in directory structure"
        return 0
    fi

    # Find all related files with the extension name prefix
    local ext_file="$EXTENSIONS_BASE/${ext_name}.extension"

    if [[ ! -f "$ext_file" ]]; then
        print_error "Extension file not found: $ext_file"
        return 1
    fi

    # Create directory
    mkdir -p "$EXTENSIONS_BASE/${ext_name}"

    # Find and move ALL files that start with the extension name
    # This handles: .extension, .aliases, .toml, -ci.toml, .*.template, etc.
    local moved_count=0
    for file in "$EXTENSIONS_BASE/${ext_name}".* "$EXTENSIONS_BASE/${ext_name}"-*; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            mv "$file" "$EXTENSIONS_BASE/${ext_name}/${filename}"
            ((moved_count++))
            print_debug "  Moved: $filename"
        fi
    done

    if [[ $moved_count -eq 0 ]]; then
        print_warning "No files found for extension '$ext_name'"
        return 1
    fi

    print_success "Migrated '$ext_name' to directory structure ($moved_count files)"
    return 0
}

# Migrate all extensions
migrate_all_extensions() {
    print_status "Migrating extensions to directory structure..."

    for ext_file in "$EXTENSIONS_BASE"/*.extension; do
        [[ ! -f "$ext_file" ]] && continue
        local ext_name=$(basename "$ext_file" .extension)
        migrate_extension_to_directory "$ext_name"
    done

    print_success "All extensions migrated"
}

# Function to install an extension (prerequisites + install + configure)
install_extension() {
    local ext_name="$1"

    print_status "Installing extension: $ext_name"
    echo ""

    # Check if already installed (idempotency check)
    if is_extension_installed "$ext_name"; then
        print_success "Extension '$ext_name' is already installed (skipping)"
        return 0
    fi

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

    # Check if extension is protected
    if is_protected_extension "$ext_name"; then
        print_error "Cannot uninstall protected extension: $ext_name"
        print_status "Protected extensions are required for system functionality"
        return 1
    fi

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

    # Ensure mise is activated for extensions that depend on it
    # This provides access to mise-managed tools (python, node, etc.)
    if command -v mise &>/dev/null; then
        eval "$(mise activate bash)" 2>/dev/null || true
        # Also add mise shims to PATH as fallback
        if [[ -d "$HOME/.local/share/mise/shims" ]]; then
            export PATH="$HOME/.local/share/mise/shims:$PATH"
        fi
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

    # Ensure mise is activated for extensions that depend on it
    if command -v mise &>/dev/null; then
        eval "$(mise activate bash)" 2>/dev/null || true
        if [[ -d "$HOME/.local/share/mise/shims" ]]; then
            export PATH="$HOME/.local/share/mise/shims:$PATH"
        fi
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

    # First, ensure protected extensions are in manifest and at the top
    ensure_protected_extensions

    local active_extensions=()
    mapfile -t active_extensions < <(read_manifest)

    if [[ ${#active_extensions[@]} -eq 0 ]]; then
        print_warning "No extensions in activation manifest"
        print_status "Edit the manifest: $MANIFEST_FILE"
        return 0
    fi

    # Separate protected and non-protected extensions
    local protected_exts=()
    local other_exts=()

    for ext_name in "${active_extensions[@]}"; do
        if is_protected_extension "$ext_name"; then
            protected_exts+=("$ext_name")
        else
            other_exts+=("$ext_name")
        fi
    done

    local installed_count=0
    local failed_count=0

    # Install protected extensions first
    if [[ ${#protected_exts[@]} -gt 0 ]]; then
        print_status "Installing protected extensions first..."
        echo ""
        for ext_name in "${protected_exts[@]}"; do
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            if install_extension "$ext_name"; then
                ((installed_count++))
            else
                ((failed_count++))
                print_error "Failed to install protected extension: $ext_name"
                print_error "System may not function correctly without this extension!"
            fi
            echo ""
        done
    fi

    # Install remaining extensions
    if [[ ${#other_exts[@]} -gt 0 ]]; then
        print_status "Installing additional extensions..."
        echo ""
        for ext_name in "${other_exts[@]}"; do
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            if install_extension "$ext_name"; then
                ((installed_count++))
            else
                ((failed_count++))
                print_error "Failed to install: $ext_name"
            fi
            echo ""
        done
    fi

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

# ============================================================================
# UPGRADE COMMANDS - Extension API v2.0
# ============================================================================

# Upgrade a single extension
# Usage: upgrade_extension "extension-name"
# Returns: 0 on success, 1 on failure, 2 if upgrade not supported
upgrade_extension() {
    local extension_name="$1"
    local extension_file
    extension_file=$(find_extension_file "$extension_name")

    if [[ -z "$extension_file" ]]; then
        print_error "Extension not found: ${extension_name}"
        return 1
    fi

    # Source extension
    source "$extension_file"

    # Check if extension is installed
    if ! is_extension_installed "$extension_name"; then
        print_error "Extension not installed: ${extension_name}"
        print_status "Install with: extension-manager install ${extension_name}"
        return 1
    fi

    # Check if extension implements upgrade()
    if ! supports_upgrade; then
        print_warning "Extension ${extension_name} does not support upgrades (Extension API v1.0)"
        print_status "This extension requires Extension API v2.0 for upgrade support"
        print_status "Contact the extension maintainer to add upgrade() function"
        return 2
    fi

    # Get current version before upgrade
    local old_version="${EXT_VERSION:-unknown}"

    # Show current status
    print_status "Current status:"
    status
    echo ""

    # Run upgrade
    print_status "Starting upgrade..."
    local start_time
    start_time=$(date +%s)

    if upgrade; then
        local end_time duration new_version
        end_time=$(date +%s)
        duration=$((end_time - start_time))

        # Source extension again to get new version
        source "$extension_file"
        new_version="${EXT_VERSION:-unknown}"

        # Record in history
        if declare -F record_upgrade >/dev/null 2>&1; then
            record_upgrade "$extension_name" "$old_version" "$new_version" "success" "$duration"
        fi

        print_success "Upgrade completed successfully in ${duration}s"

        # Validate after upgrade
        echo ""
        print_status "Validating installation..."
        if validate; then
            print_success "Validation passed"
            return 0
        else
            print_warning "Validation failed after upgrade"
            return 1
        fi
    else
        # Record failure
        if declare -F record_upgrade >/dev/null 2>&1; then
            record_upgrade "$extension_name" "$old_version" "$old_version" "failed" "0"
        fi
        print_error "Upgrade failed"
        return 1
    fi
}

# Upgrade all installed extensions
# Usage: upgrade_all_extensions [--dry-run]
# Returns: 0 on success, 1 if any failures
upgrade_all_extensions() {
    local dry_run="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run="true"
                export DRY_RUN="true"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                return 1
                ;;
        esac
    done

    if [[ "$dry_run" == "true" ]]; then
        print_status "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    print_status "Upgrading all installed extensions..."
    echo ""

    # Read manifest
    local manifest="${EXTENSIONS_DIR}/active-extensions.conf"
    if [[ ! -f "$manifest" ]]; then
        print_error "Manifest not found: ${manifest}"
        return 1
    fi

    local -a extensions=()
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue

        extensions+=("$line")
    done < "$manifest"

    if [[ ${#extensions[@]} -eq 0 ]]; then
        print_warning "No extensions found in manifest"
        return 0
    fi

    local total=${#extensions[@]}
    local upgraded=0
    local skipped=0
    local failed=0

    for extension in "${extensions[@]}"; do
        print_header "Upgrading: ${extension}"

        local result
        upgrade_extension "$extension"
        result=$?

        case $result in
            0)
                ((upgraded++))
                ;;
            2)
                # Extension doesn't support upgrades
                ((skipped++))
                ;;
            *)
                ((failed++))
                ;;
        esac

        echo ""
    done

    # Summary
    print_header "Upgrade Summary"
    print_status "Total extensions: ${total}"
    print_success "Upgraded: ${upgraded}"

    if [[ $skipped -gt 0 ]]; then
        print_warning "Skipped (no upgrade support): ${skipped}"
    fi

    if [[ $failed -gt 0 ]]; then
        print_error "Failed: ${failed}"
        return 1
    fi

    print_success "All upgrades completed successfully"

    # Cleanup dry-run mode
    if [[ "$dry_run" == "true" ]]; then
        unset DRY_RUN
    fi

    return 0
}

# Check for available updates
# Usage: check_updates
# Returns: 0 if updates found, 1 if all up-to-date
check_updates() {
    print_status "Checking for available updates..."
    echo ""

    # Read manifest
    local manifest="${EXTENSIONS_DIR}/active-extensions.conf"
    local -a extensions=()

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        extensions+=("$line")
    done < "$manifest"

    local has_updates=0

    for extension in "${extensions[@]}"; do
        local extension_file
        extension_file=$(find_extension_file "$extension")

        if [[ -z "$extension_file" ]]; then
            continue
        fi

        # Source extension
        source "$extension_file"

        # Check if upgrade() exists
        if ! supports_upgrade; then
            continue
        fi

        # Get installation method
        local method="${EXT_INSTALL_METHOD:-unknown}"

        case "$method" in
            mise)
                if command_exists mise; then
                    # Check for mise updates
                    local outdated
                    if outdated=$(mise outdated 2>/dev/null) && [[ -n "$outdated" ]]; then
                        print_status "${extension}: Updates available"
                        echo "$outdated" | sed 's/^/  /'
                        has_updates=1
                    fi
                fi
                ;;
            apt)
                print_status "${extension}: Check with 'apt list --upgradable'"
                ;;
            binary)
                print_status "${extension}: Checking GitHub releases..."
                # Would need to implement per-binary checks
                ;;
            *)
                print_status "${extension}: Manual check required (${method})"
                ;;
        esac
    done

    echo ""
    if [[ $has_updates -eq 0 ]]; then
        print_success "All extensions are up to date"
    else
        print_status "Run 'extension-manager upgrade-all' to upgrade"
    fi

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

# ============================================================================
# ADVANCED FEATURES - Extension API v2.0 Phase 7
# ============================================================================

# Show upgrade history
# Usage: upgrade_history [extension-name] [limit]
upgrade_history() {
    local extension="${1:-}"
    local limit="${2:-10}"

    if declare -F show_upgrade_history >/dev/null 2>&1; then
        show_upgrade_history "$extension" "$limit"
    else
        print_error "Upgrade history not available"
        print_status "Upgrade history tracking requires upgrade-history.sh"
        return 1
    fi
}

# Rollback extension to previous version
# Usage: rollback_extension "extension-name"
rollback_extension() {
    local extension_name="$1"

    print_warning "Rollback functionality is limited to reinstallation"
    print_status "This will uninstall and reinstall ${extension_name}"

    if ! confirm "Continue with rollback?" "n"; then
        print_status "Rollback cancelled"
        return 0
    fi

    # Uninstall
    print_status "Uninstalling ${extension_name}..."
    if ! uninstall_extension "$extension_name"; then
        print_error "Uninstall failed"
        return 1
    fi

    # Reinstall
    print_status "Reinstalling ${extension_name}..."
    if ! install_extension "$extension_name"; then
        print_error "Reinstall failed"
        return 1
    fi

    print_success "Rollback completed"
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

  upgrade <name>           Upgrade a specific extension (API v2.0)
  upgrade-all              Upgrade all installed extensions (API v2.0)
  upgrade-all --dry-run    Preview upgrades without making changes
  check-updates            Check for available updates
  upgrade-history [name] [limit]  Show upgrade history (default: last 10)
  rollback <name>          Rollback extension (uninstall and reinstall)

  doctor                   Run health check on extension system
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

  # Upgrade extensions (API v2.0)
  $(basename "$0") upgrade nodejs               # Upgrade single extension
  $(basename "$0") upgrade-all --dry-run        # Preview upgrades
  $(basename "$0") upgrade-all                  # Upgrade all extensions
  $(basename "$0") check-updates                # Check for available updates

  # View upgrade history
  $(basename "$0") upgrade-history              # Show last 10 upgrades
  $(basename "$0") upgrade-history nodejs       # Show history for nodejs
  $(basename "$0") upgrade-history nodejs 20    # Show last 20 nodejs upgrades

  # Rollback an extension
  $(basename "$0") rollback rust                # Rollback rust extension

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
        upgrade)
            if [[ -z "${1:-}" ]]; then
                print_error "Extension name required"
                echo "Usage: extension-manager upgrade <name>"
                exit 1
            fi
            upgrade_extension "$1"
            ;;
        upgrade-all)
            shift
            upgrade_all_extensions "$@"
            ;;
        check-updates)
            check_updates
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
        upgrade-history)
            upgrade_history "$1" "$2"
            ;;
        rollback)
            if [[ -z "$1" ]]; then
                print_error "Extension name required"
                echo "Usage: extension-manager rollback <extension-name>"
                exit 1
            fi
            rollback_extension "$1"
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
