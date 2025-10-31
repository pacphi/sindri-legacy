#!/bin/bash
# Test extension installation idempotency
# Usage: test-idempotency.sh

set -e

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"

print_section "Testing Idempotency"
print_info "Running extension-manager install-all a second time..."

cd "$(get_extension_manager_path)" || exit 1

# Run install-all again and capture output
if bash extension-manager.sh install-all 2>&1 | tee /tmp/configure2.log; then
    # Check for error indicators in output
    if grep -qi "error\|failed" /tmp/configure2.log; then
        print_warning "Warnings or errors detected on second run:"
        grep -i "error\|failed" /tmp/configure2.log || true
        # Don't fail on warnings, just report them
        print_warning "Idempotency test completed with warnings"
    else
        print_success "Second run completed without errors"
        print_success "Idempotency test passed"
    fi
else
    print_error "Second run failed"
    echo "Last 50 lines of output:"
    tail -50 /tmp/configure2.log
    exit 1
fi
