#!/bin/bash
# install-claude.sh - Install Claude Code CLI during Docker build

set -e

echo "🤖 Installing Claude Code CLI..."

# Claude will be installed for the developer user then moved to system location
DEVELOPER_USER="developer"
DEVELOPER_HOME="/home/developer"
SYSTEM_BIN_DIR="/usr/local/bin"

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
CLAUDE_USER_PATH="$DEVELOPER_HOME/.local/bin/claude"

# Verify user installation
if [ -L "$CLAUDE_USER_PATH" ] || [ -f "$CLAUDE_USER_PATH" ]; then
    echo "  ✓ Claude Code installed to user directory"
else
    echo "  ✗ Claude Code binary not found at: $CLAUDE_USER_PATH"
    echo "  ℹ️  Installer may have failed silently"
    exit 1
fi

# Move Claude to system-wide location
echo "  🔧 Moving Claude Code to system-wide location..."
# Copy the binary (following symlinks) to /usr/local/bin
cp -L "$CLAUDE_USER_PATH" "$SYSTEM_BIN_DIR/claude"
chmod +x "$SYSTEM_BIN_DIR/claude"

# Verify system installation
if command -v claude >/dev/null 2>&1; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "Installed successfully")
    echo "  ✓ Claude Code installed system-wide: $CLAUDE_VERSION"
    echo "  📍 Location: $SYSTEM_BIN_DIR/claude"
else
    echo "  ✗ Claude Code not available in system PATH"
    exit 1
fi

# Clean up user installation (no longer needed)
rm -rf "$DEVELOPER_HOME/.local/bin/claude"* 2>/dev/null || true

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
echo "  📍 Binary location: $SYSTEM_BIN_DIR/claude"
echo "  📝 Authenticate with: claude"
echo "  📝 Or set ANTHROPIC_API_KEY environment variable for auto-authentication"
