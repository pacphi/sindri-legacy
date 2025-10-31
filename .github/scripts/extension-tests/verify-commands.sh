#!/bin/bash
# Verify that extension commands are available
# Usage: verify-commands.sh <comma-separated-commands>

set -e

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"
source "$SCRIPT_DIR/lib/assertions.sh"

# Parse arguments
commands="$1"
if [ -z "$commands" ]; then
    print_error "Usage: $0 <comma-separated-commands>"
    exit 1
fi

# Source environment
source_environment

print_section "Command Verification"
print_info "Commands to verify: $commands"
print_info "Current PATH: $PATH"
echo ""

# Convert comma-separated list to array
IFS=',' read -ra CMD_ARRAY <<< "$commands"
failed_commands=()

# Check each command
for cmd in "${CMD_ARRAY[@]}"; do
    # Trim whitespace
    cmd=$(echo "$cmd" | xargs)

    echo "Checking command: $cmd"

    # Try multiple methods to find the command
    if command -v "$cmd" >/dev/null 2>&1; then
        print_success "$cmd available at: $(command -v "$cmd")"
        timeout 5 "$cmd" --version 2>/dev/null || \
        timeout 5 "$cmd" version 2>/dev/null || \
        echo "  (version check not supported)"
    else
        # Try with full path expansion
        if type "$cmd" >/dev/null 2>&1; then
            print_success "$cmd found via type: $(type -p "$cmd" || echo "builtin")"
        else
            # Check common locations
            found=false
            for path in /usr/local/bin /usr/bin /bin ~/.local/bin ~/.cargo/bin ~/.mise/shims; do
                if [ -x "$path/$cmd" ]; then
                    print_success "$cmd found at: $path/$cmd"
                    found=true
                    break
                fi
            done

            if [ "$found" = false ]; then
                print_error "$cmd not found in PATH or common locations"
                failed_commands+=("$cmd")
            fi
        fi
    fi
    echo ""
done

# Summary
if [ ${#failed_commands[@]} -eq 0 ]; then
    print_success "All commands verified successfully"
    exit 0
else
    print_error "Failed to verify commands: ${failed_commands[*]}"
    dump_environment
    exit 1
fi
