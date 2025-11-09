#!/bin/bash
# install-mise.sh - Install and configure mise during Docker build

set -e

echo "🔧 Installing mise (unified tool version manager)..."

# mise will be installed system-wide to /usr/local/bin
DEVELOPER_USER="developer"
DEVELOPER_HOME="/home/developer"
MISE_INSTALL_PATH="/usr/local/bin"

# Create temporary home directory for Docker build
# (runtime home will be on persistent volume at /workspace/developer)
mkdir -p "$DEVELOPER_HOME"
chown "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME"

# Install mise system-wide using official installer
echo "  📥 Downloading and installing mise to $MISE_INSTALL_PATH..."
if curl -fsSL https://mise.run | MISE_INSTALL_PATH="$MISE_INSTALL_PATH" sh; then
    echo "  ✓ mise installed successfully"
else
    echo "  ✗ Failed to install mise"
    exit 1
fi

# Verify installation
if command -v mise >/dev/null 2>&1; then
    MISE_VERSION=$(mise --version 2>/dev/null | head -n1)
    echo "  ✓ mise version: $MISE_VERSION"
    echo "  📍 Location: $(which mise)"
else
    echo "  ✗ mise installation verification failed"
    exit 1
fi

# Configure mise in shell rc files
echo "  ⚙️  Configuring mise activation..."

# Add mise activation to .bashrc
BASHRC="$DEVELOPER_HOME/.bashrc"
if [ -f "$BASHRC" ]; then
    if ! grep -q 'mise activate bash' "$BASHRC"; then
        cat >> "$BASHRC" << 'EOF'

# mise - unified tool version manager
# Activates mise for this shell session
# mise manages Node.js, Python, Rust, Go, Ruby, and other development tools
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi
EOF
        echo "  ✓ mise activation added to .bashrc"
    else
        echo "  ✓ mise already configured in .bashrc"
    fi
fi

# Add mise activation to profile.d for SSH non-interactive sessions
# This is critical for CI/CD and remote command execution
PROFILE_D_MISE="/etc/profile.d/01-mise-activation.sh"
cat > "$PROFILE_D_MISE" << 'EOF'
#!/bin/bash
# mise activation for non-interactive SSH sessions
# This ensures mise-managed tools are available in CI/CD pipelines

# Activate mise if available (binary is in /usr/local/bin)
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi
EOF
chmod +x "$PROFILE_D_MISE"
echo "  ✓ mise activation added to profile.d for SSH sessions"

# Create mise config directory for developer user
MISE_CONFIG_DIR="$DEVELOPER_HOME/.config/mise"
su - "$DEVELOPER_USER" -c "mkdir -p $MISE_CONFIG_DIR/conf.d"
echo "  ✓ Created mise config directory"

# Create global mise config
GLOBAL_CONFIG="$MISE_CONFIG_DIR/config.toml"
su - "$DEVELOPER_USER" -c "cat > $GLOBAL_CONFIG" << 'EOF'
# Global mise configuration
# https://mise.jdx.dev/configuration.html

[settings]
# Automatically install tools when entering a directory with mise.toml
auto_install = true

# Use all CPU cores for compilation
jobs = 4

# Enable experimental features
experimental = true

[tools]
# Global tool versions (can be overridden per-project)
# Uncomment and modify as needed:
# node = "lts"
# python = "3.13"
# go = "1.24"
# rust = "stable"

[env]
# Global environment variables
# Example: NODE_ENV = "development"
EOF
chown "$DEVELOPER_USER:$DEVELOPER_USER" "$GLOBAL_CONFIG"
echo "  ✓ Created global mise config"

# Ensure proper ownership
chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "$MISE_CONFIG_DIR"

# Clean up to reduce image size
rm -rf /tmp/* 2>/dev/null || true

echo "✅ mise installed and configured successfully"
echo "  📍 Binary location: $MISE_INSTALL_PATH/mise"
echo "  📝 Tools can be installed with: mise use <tool>@<version>"
echo "  📝 Example: mise use node@20 python@3.13"
