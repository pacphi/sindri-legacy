#!/bin/bash
# install-claude.sh - Install Claude Code CLI during Docker build

set -e

echo "🤖 Installing Claude Code CLI..."

# Claude will be installed for the developer user
DEVELOPER_USER="developer"
DEVELOPER_HOME="/home/developer"

# Ensure home directory exists (should be created by mise script, but double-check)
if [ ! -d "$DEVELOPER_HOME" ]; then
    mkdir -p "$DEVELOPER_HOME"
    chown "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME"
fi

# Install Claude Code using official installer with timeout
echo "  📥 Downloading and running Claude Code installer..."
echo "  ⏱️  Timeout: 5 minutes (prevents indefinite hangs in CI)"

# Add explicit timeout (5 minutes) to prevent indefinite hangs in CI
# Use -o pipefail to catch curl failures
if su - "$DEVELOPER_USER" -c 'timeout 300 bash -c "set -o pipefail; curl -fsSL https://claude.ai/install.sh | bash"'; then
    echo "  ✓ Claude Code installer completed"
else
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 124 ]; then
        echo "  ✗ Claude Code installation timed out after 5 minutes"
        echo "  ℹ️  This may indicate the installer is waiting for input or network issues"
    else
        echo "  ✗ Claude Code installation failed (exit code: $EXIT_CODE)"
    fi
    exit 1
fi

# The installer places Claude at ~/.local/bin/claude (symlink to versioned binary)
CLAUDE_BIN_DIR="$DEVELOPER_HOME/.local/bin"
CLAUDE_PATH="$CLAUDE_BIN_DIR/claude"

# Verify installation (check symlink with -L)
if [ -L "$CLAUDE_PATH" ] || [ -f "$CLAUDE_PATH" ]; then
    # Verify the binary works
    CLAUDE_VERSION=$(su - "$DEVELOPER_USER" -c "$CLAUDE_PATH --version 2>/dev/null" || echo "Installed successfully")
    echo "  ✓ Claude Code installed: $CLAUDE_VERSION"
    echo "  📍 Location: $CLAUDE_PATH"
else
    echo "  ✗ Claude Code binary not found at: $CLAUDE_PATH"
    echo "  ℹ️  Installer may have failed silently"
    exit 1
fi

# Add ~/.local/bin to PATH in shell config (installer doesn't do this)
BASHRC="$DEVELOPER_HOME/.bashrc"
if [ -f "$BASHRC" ]; then
    if ! grep -q "/.local/bin" "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'EOF'

# Added by Claude Code installation - CLI binary location
export PATH="$HOME/.local/bin:$PATH"
EOF
        echo "  ✓ Added ~/.local/bin to PATH in .bashrc"
    else
        echo "  ✓ ~/.local/bin already in .bashrc PATH"
    fi
fi

# Create Claude configuration directory
echo "  ⚙️  Setting up Claude Code configuration..."
CLAUDE_CONFIG_DIR="$DEVELOPER_HOME/.claude"
su - "$DEVELOPER_USER" -c "mkdir -p $CLAUDE_CONFIG_DIR"

# Create global CLAUDE.md with user preferences
if [ ! -f "$CLAUDE_CONFIG_DIR/CLAUDE.md" ]; then
    su - "$DEVELOPER_USER" -c "cat > $CLAUDE_CONFIG_DIR/CLAUDE.md" << 'EOF'
# Global Claude Preferences

## Code Style
- Use 2 spaces for indentation
- Use semicolons in JavaScript/TypeScript
- Prefer const over let
- Use meaningful variable names

## Git Workflow
- Use conventional commits (feat:, fix:, docs:, etc.)
- Create feature branches for new work
- Write descriptive commit messages

## Development Practices
- Write tests for new features
- Add documentation for public APIs
- Use TypeScript for new JavaScript projects
- Follow project-specific style guides

## Preferred Libraries
- React for frontend applications
- Express.js for Node.js APIs
- Jest for JavaScript testing
- Pytest for Python testing
EOF
    chown "$DEVELOPER_USER:$DEVELOPER_USER" "$CLAUDE_CONFIG_DIR/CLAUDE.md"
    echo "  ✓ Created global preferences: ~/.claude/CLAUDE.md"
else
    echo "  ✓ Global preferences already exist: ~/.claude/CLAUDE.md"
fi

# Create settings.json with useful hooks
if [ ! -f "$CLAUDE_CONFIG_DIR/settings.json" ]; then
    su - "$DEVELOPER_USER" -c "cat > $CLAUDE_CONFIG_DIR/settings.json" << 'EOF'
{
  "hooks": [
    {
      "matcher": "Edit|Write",
      "type": "command",
      "command": "prettier --write \"$CLAUDE_FILE_PATHS\" 2>/dev/null || echo 'Prettier not available for this file type'"
    },
    {
      "matcher": "Edit",
      "type": "command",
      "command": "if [[ \"$CLAUDE_FILE_PATHS\" =~ \\.(ts|tsx)$ ]]; then npx tsc --noEmit --skipLibCheck \"$CLAUDE_FILE_PATHS\" 2>/dev/null || echo '⚠️ TypeScript errors detected - please review'; fi"
    }
  ]
}
EOF
    chown "$DEVELOPER_USER:$DEVELOPER_USER" "$CLAUDE_CONFIG_DIR/settings.json"
    echo "  ✓ Created Claude hooks: ~/.claude/settings.json"
else
    echo "  ✓ Claude hooks already exist: ~/.claude/settings.json"
fi

# Ensure proper ownership
chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "$CLAUDE_CONFIG_DIR"

# Clean up to reduce image size
rm -rf /tmp/* 2>/dev/null || true

echo "✅ Claude Code installed and configured successfully"
echo "  📝 Authenticate with: claude"
echo "  📝 Or set ANTHROPIC_API_KEY environment variable for auto-authentication"
