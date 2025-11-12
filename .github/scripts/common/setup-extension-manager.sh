#!/bin/bash
# Common setup for extension-manager to handle Hallpass SSH context
# Source this file in test scripts to ensure extension-manager is available

# Set up extension-manager with fallback to absolute path
# This handles Hallpass SSH context where PATH may not be fully configured
setup_extension_manager() {
    if command -v extension-manager &> /dev/null; then
        # extension-manager is in PATH, use it directly
        EXTENSION_MANAGER="extension-manager"
    elif [ -f "/workspace/.system/bin/extension-manager" ]; then
        # Use absolute path fallback
        EXTENSION_MANAGER="/workspace/.system/bin/extension-manager"
        echo "ℹ️  Using extension-manager from absolute path"
    elif [ -f "/workspace/bin/extension-manager" ]; then
        # Try workspace bin directory
        EXTENSION_MANAGER="/workspace/bin/extension-manager"
        echo "ℹ️  Using extension-manager from /workspace/bin"
    else
        echo "❌ Extension manager not found in PATH or known locations:"
        echo "   - Checked PATH"
        echo "   - Checked /workspace/.system/bin/extension-manager"
        echo "   - Checked /workspace/bin/extension-manager"
        return 1
    fi

    # Export for use in scripts
    export EXTENSION_MANAGER
    return 0
}

# Automatically set up when sourced
if ! setup_extension_manager; then
    exit 1
fi