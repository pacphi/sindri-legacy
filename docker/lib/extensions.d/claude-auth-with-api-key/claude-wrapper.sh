#!/bin/bash
# Claude Code CLI Wrapper with Automatic API Key Authentication
#
# This wrapper automatically loads the ANTHROPIC_API_KEY from encrypted secrets
# when running Claude Code, providing transparent authentication without requiring
# users to manually load secrets or run authentication commands.
#
# Location: /workspace/bin/claude (this wrapper)
# Real CLI:  /usr/local/bin/claude (actual Claude Code executable)

# Path to secrets library
SECRETS_LIB="$HOME/.secrets/lib.sh"

# Only load API key if secrets library exists and has the key
if [ -f "$SECRETS_LIB" ]; then
    # Source secrets library functions
    source "$SECRETS_LIB" 2>/dev/null

    # Check if API key is available and export it
    if declare -f has_secret >/dev/null 2>&1 && has_secret "anthropic_api_key" 2>/dev/null; then
        export ANTHROPIC_API_KEY=$(get_secret "anthropic_api_key" 2>/dev/null)
    fi
fi

# Execute the real Claude CLI with all arguments passed through
# Using exec replaces this shell process with claude, making it transparent
exec /usr/local/bin/claude "$@"
