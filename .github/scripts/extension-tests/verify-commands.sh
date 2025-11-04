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
print_section "Environment Setup"
source_environment

print_section "Command Verification"
print_info "Commands to verify: $commands"
echo ""

# Convert comma-separated list to array
IFS=',' read -ra CMD_ARRAY <<< "$commands"
failed_commands=()

# Check each command
for cmd in "${CMD_ARRAY[@]}"; do
    # Trim whitespace
    cmd=$(echo "$cmd" | xargs)

    print_info "Checking command: $cmd"

    # Try multiple methods to find the command
    if command -v "$cmd" >/dev/null 2>&1; then
        cmd_path="$(command -v "$cmd")"
        print_success "$cmd available at: $cmd_path"

        # Show if it's a mise shim
        if [[ "$cmd_path" == *".mise/shims"* ]]; then
            print_info "  (mise shim - managed by mise)"
            # Show the actual mise tool version
            if command -v mise >/dev/null 2>&1; then
                mise_info=$(mise which "$cmd" 2>/dev/null || echo "unknown")
                print_info "  mise resolves to: $mise_info"
            fi
        fi

        # Try version check
        timeout 5 "$cmd" --version 2>/dev/null || \
        timeout 5 "$cmd" version 2>/dev/null || \
        echo "  (version check not supported)"
    else
        print_warning "$cmd not found via 'command -v'"

        # Try with full path expansion
        if type "$cmd" >/dev/null 2>&1; then
            type_result="$(type -p "$cmd" 2>/dev/null || echo "builtin")"
            print_success "$cmd found via type: $type_result"
        else
            print_warning "$cmd not found via 'type'"

            # Check common locations manually
            print_info "Searching common locations..."
            found=false
            for path in /usr/local/bin /usr/bin /bin ~/.local/bin ~/.cargo/bin ~/.mise/shims; do
                if [ -x "$path/$cmd" ]; then
                    print_success "$cmd found at: $path/$cmd"
                    print_warning "Command exists but not in PATH!"
                    print_info "Missing PATH entry: $path"
                    found=true
                    break
                fi
            done

            if [ "$found" = false ]; then
                print_error "$cmd not found in PATH or common locations"

                # Show mise status for mise-managed tools
                if command -v mise >/dev/null 2>&1; then
                    print_info "Checking mise for $cmd..."
                    mise which "$cmd" 2>&1 | sed 's/^/  /' || echo "  (not a mise tool)"
                fi

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
