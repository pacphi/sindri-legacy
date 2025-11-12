#!/bin/bash
set -e

# ==============================================================================
# Sindri Container Entrypoint
# ==============================================================================
# Initializes and starts the Sindri development environment container.
# Functions are called serially from main() to ensure proper startup sequence.
# ==============================================================================

# ==============================================================================
# Environment Configuration
# ==============================================================================
DEVELOPER_USER="developer"
WORKSPACE_DIR="/workspace"
DEVELOPER_HOME_BUILD="/home/$DEVELOPER_USER"
DEVELOPER_HOME_RUNTIME="$WORKSPACE_DIR/$DEVELOPER_USER"
SKEL_DIR="/etc/skel"
WORKSPACE_BIN_DIR="$WORKSPACE_DIR/bin"
SYSTEM_BIN_DIR="$WORKSPACE_DIR/.system/bin"

# ==============================================================================
# Functions
# ==============================================================================

# ------------------------------------------------------------------------------
# setup_workspace - Create workspace directory structure
# ------------------------------------------------------------------------------
setup_workspace() {
    /docker/scripts/setup-workspace.sh
}

# ------------------------------------------------------------------------------
# setup_developer_home - Initialize developer home directory on persistent volume
# ------------------------------------------------------------------------------
setup_developer_home() {
    echo "🏠 Setting up developer home directory..."

    if [ ! -d "$DEVELOPER_HOME_RUNTIME" ]; then
        echo "  Creating developer home on persistent volume..."
        mkdir -p "$DEVELOPER_HOME_RUNTIME"

        # Copy skeleton files from /etc/skel
        if [ -d "$SKEL_DIR" ]; then
            cp -r "$SKEL_DIR/." "$DEVELOPER_HOME_RUNTIME/"
        fi

        # Copy core tool configurations from Docker build home to persistent volume
        # Binaries are in /usr/local/bin (system-wide), but configs are user-specific
        echo "  🔧 Copying core tool configurations..."

        # Copy mise configuration
        if [ -d "$DEVELOPER_HOME_BUILD/.config/mise" ]; then
            mkdir -p "$DEVELOPER_HOME_RUNTIME/.config"
            cp -r "$DEVELOPER_HOME_BUILD/.config/mise" "$DEVELOPER_HOME_RUNTIME/.config/"
            echo "    ✓ Copied mise configuration"
        fi

        # Copy Claude configuration
        if [ -d "$DEVELOPER_HOME_BUILD/.claude" ]; then
            cp -r "$DEVELOPER_HOME_BUILD/.claude" "$DEVELOPER_HOME_RUNTIME/"
            echo "    ✓ Copied Claude configuration"
        fi

        chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME_RUNTIME"
        chmod 755 "$DEVELOPER_HOME_RUNTIME"
    fi

    # Update the user's home directory to point to persistent volume
    usermod -d "$DEVELOPER_HOME_RUNTIME" "$DEVELOPER_USER"

    echo "✅ Developer home directory configured"
}

# ------------------------------------------------------------------------------
# setup_ssh_keys - Configure SSH authorized keys from environment
# ------------------------------------------------------------------------------
setup_ssh_keys() {
    if [ -n "$AUTHORIZED_KEYS" ]; then
        echo "🔑 Configuring SSH keys..."

        mkdir -p "$DEVELOPER_HOME_RUNTIME/.ssh"
        echo "$AUTHORIZED_KEYS" > "$DEVELOPER_HOME_RUNTIME/.ssh/authorized_keys"
        chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME_RUNTIME/.ssh"
        chmod 700 "$DEVELOPER_HOME_RUNTIME/.ssh"
        chmod 600 "$DEVELOPER_HOME_RUNTIME/.ssh/authorized_keys"

        echo "✅ SSH keys configured"
    else
        echo "⚠️  No SSH keys found in AUTHORIZED_KEYS environment variable"
    fi
}

# ------------------------------------------------------------------------------
# setup_workspace_bin - Create symlinks in user bin directory
# ------------------------------------------------------------------------------
setup_workspace_bin() {
    echo "🔗 Setting up workspace bin directory..."

    # Symlink system binaries to user bin (for PATH convenience)
    if [ -f "$SYSTEM_BIN_DIR/extension-manager" ] && [ ! -L "$WORKSPACE_BIN_DIR/extension-manager" ]; then
        ln -sf "$SYSTEM_BIN_DIR/extension-manager" "$WORKSPACE_BIN_DIR/extension-manager"
        echo "  ✓ Linked extension-manager"
    fi

    # Symlink user-facing scripts from /docker/scripts
    local user_scripts=(
        "backup"
        "clone-project"
        "new-project"
        "restore"
        "system-status"
        "upgrade-history"
    )

    for script in "${user_scripts[@]}"; do
        local source_file="/docker/scripts/${script}.sh"
        local target_link="$WORKSPACE_BIN_DIR/$script"

        if [ -f "$source_file" ] && [ ! -L "$target_link" ]; then
            ln -sf "$source_file" "$target_link"
            echo "  ✓ Linked $script"
        fi
    done

    echo "✅ Workspace bin directory configured"
}

# ------------------------------------------------------------------------------
# setup_environment_variables - Configure environment variables for developer user
# ------------------------------------------------------------------------------
setup_environment_variables() {
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        echo "🔐 Configuring environment variables..."
        echo "export ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY'" >> "$DEVELOPER_HOME_RUNTIME/.bashrc"
        echo "✅ Environment variables configured"
    fi
}

# ------------------------------------------------------------------------------
# setup_github_auth - Configure GitHub authentication (token and gh CLI)
# ------------------------------------------------------------------------------
setup_github_auth() {
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "🔐 Configuring GitHub authentication..."

        echo "export GITHUB_TOKEN='$GITHUB_TOKEN'" >> "$DEVELOPER_HOME_RUNTIME/.bashrc"

        # Create GitHub CLI config for gh commands
        sudo -u "$DEVELOPER_USER" mkdir -p "$DEVELOPER_HOME_RUNTIME/.config/gh"
        cat > "$DEVELOPER_HOME_RUNTIME/.config/gh/hosts.yml" << EOF
github.com:
    oauth_token: $GITHUB_TOKEN
    user: $GITHUB_USER
    git_protocol: https
EOF
        chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME_RUNTIME/.config/gh"
        chmod 600 "$DEVELOPER_HOME_RUNTIME/.config/gh/hosts.yml"

        echo "✅ GitHub authentication configured"
    fi
}

# ------------------------------------------------------------------------------
# setup_git_config - Configure Git user credentials and credential helper
# ------------------------------------------------------------------------------
setup_git_config() {
    local configured=false

    if [ -n "$GIT_USER_NAME" ]; then
        sudo -u "$DEVELOPER_USER" git config --global user.name "$GIT_USER_NAME"
        echo "✅ Git user name configured: $GIT_USER_NAME"
        configured=true
    fi

    if [ -n "$GIT_USER_EMAIL" ]; then
        sudo -u "$DEVELOPER_USER" git config --global user.email "$GIT_USER_EMAIL"
        echo "✅ Git user email configured: $GIT_USER_EMAIL"
        configured=true
    fi

    # Setup Git credential helper for GitHub token
    if [ -n "$GITHUB_TOKEN" ]; then
        # Create credential helper script
        cat > "$DEVELOPER_HOME_RUNTIME/.git-credential-helper.sh" << 'EOF'
#!/bin/bash
# Git credential helper for GitHub token authentication

if [ "$1" = "get" ]; then
    while IFS= read -r line; do
        case "$line" in
            host=github.com)
                echo "protocol=https"
                echo "host=github.com"
                echo "username=token"
                echo "password=$GITHUB_TOKEN"
                break
                ;;
            host=*)
                # For non-GitHub hosts, exit without providing credentials
                exit 0
                ;;
        esac
    done
fi
EOF

        chmod +x "$DEVELOPER_HOME_RUNTIME/.git-credential-helper.sh"
        chown "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME_RUNTIME/.git-credential-helper.sh"

        # Configure Git to use the credential helper
        sudo -u "$DEVELOPER_USER" git config --global credential.helper "$DEVELOPER_HOME_RUNTIME/.git-credential-helper.sh"
        echo "✅ Git credential helper configured"
        configured=true
    fi

    if [ "$configured" = false ]; then
        echo "ℹ️  No Git configuration provided (skipping)"
    fi
}

# ------------------------------------------------------------------------------
# setup_motd - Configure Message of the Day banner
# ------------------------------------------------------------------------------
setup_motd() {
    if [ -f "/docker/scripts/setup-motd.sh" ]; then
        echo "📋 Setting up MOTD banner..."
        bash /docker/scripts/setup-motd.sh
    fi
}

# ------------------------------------------------------------------------------
# start_ssh_daemon - Start SSH daemon (if not in CI mode)
# ------------------------------------------------------------------------------
start_ssh_daemon() {
    if [ "$CI_MODE" = "true" ]; then
        echo "🔌 CI Mode: Skipping SSH daemon startup (using Fly.io hallpass)"
        echo "🎯 Sindri is ready (CI Mode)!"
        echo "📡 SSH access available via flyctl ssh console"
        echo "🏠 Workspace mounted at /workspace"
    else
        echo "🔌 Starting SSH daemon on port ${SSH_PORT:-2222}..."
        mkdir -p /var/run/sshd
        /usr/sbin/sshd -D &

        echo "🎯 Sindri is ready!"
        echo "📡 SSH server listening on port ${SSH_PORT:-2222}"
        echo "🏠 Workspace mounted at /workspace"
    fi
}

# ------------------------------------------------------------------------------
# wait_for_shutdown - Handle graceful shutdown and wait for services
# ------------------------------------------------------------------------------
wait_for_shutdown() {
    # Handle shutdown gracefully
    trap 'echo "📴 Shutting down..."; kill $(jobs -p) 2>/dev/null; exit 0' SIGTERM SIGINT

    # Wait for SSH daemon (only if running)
    if [ "$CI_MODE" != "true" ]; then
        wait $!
    else
        # In CI mode, just keep container running
        sleep infinity
    fi
}

# ------------------------------------------------------------------------------
# main - Entry point that orchestrates container startup
# ------------------------------------------------------------------------------
main() {
    echo "🚀 Starting Sindri..."

    setup_workspace
    setup_developer_home
    setup_ssh_keys
    setup_workspace_bin
    setup_environment_variables
    setup_github_auth
    setup_git_config
    setup_motd
    start_ssh_daemon
    wait_for_shutdown
}

# ==============================================================================
# Execute main function
# ==============================================================================
main "$@"
