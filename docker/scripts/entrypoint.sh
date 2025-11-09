#!/bin/bash
set -e

# ==============================================================================
# Sindri Container Entrypoint
# ==============================================================================
# Initializes and starts the Sindri development environment container.
# Functions are called serially from main() to ensure proper startup sequence.
# ==============================================================================

# ------------------------------------------------------------------------------
# setup_workspace - Create workspace directory structure
# ------------------------------------------------------------------------------
setup_workspace() {
    echo "📁 Setting up workspace..."

    if [ ! -d "/workspace" ]; then
        mkdir -p /workspace
    fi

    chown developer:developer /workspace
    chmod 755 /workspace

    echo "✅ Workspace directory configured"
}

# ------------------------------------------------------------------------------
# setup_developer_home - Initialize developer home directory on persistent volume
# ------------------------------------------------------------------------------
setup_developer_home() {
    echo "🏠 Setting up developer home directory..."

    if [ ! -d "/workspace/developer" ]; then
        echo "  Creating developer home on persistent volume..."
        mkdir -p /workspace/developer

        # Copy skeleton files from /etc/skel
        if [ -d "/etc/skel" ]; then
            cp -r /etc/skel/. /workspace/developer/
        fi

        # Copy core tool configurations from Docker build home to persistent volume
        # Binaries are in /usr/local/bin (system-wide), but configs are user-specific
        echo "  🔧 Copying core tool configurations..."

        # Copy mise configuration
        if [ -d "/home/developer/.config/mise" ]; then
            mkdir -p /workspace/developer/.config
            cp -r /home/developer/.config/mise /workspace/developer/.config/
            echo "    ✓ Copied mise configuration"
        fi

        # Copy Claude configuration
        if [ -d "/home/developer/.claude" ]; then
            cp -r /home/developer/.claude /workspace/developer/
            echo "    ✓ Copied Claude configuration"
        fi

        chown -R developer:developer /workspace/developer
        chmod 755 /workspace/developer
    fi

    # Update the user's home directory to point to persistent volume
    usermod -d /workspace/developer developer

    echo "✅ Developer home directory configured"
}

# ------------------------------------------------------------------------------
# setup_ssh_keys - Configure SSH authorized keys from environment
# ------------------------------------------------------------------------------
setup_ssh_keys() {
    if [ -n "$AUTHORIZED_KEYS" ]; then
        echo "🔑 Configuring SSH keys..."

        mkdir -p /workspace/developer/.ssh
        echo "$AUTHORIZED_KEYS" > /workspace/developer/.ssh/authorized_keys
        chown -R developer:developer /workspace/developer/.ssh
        chmod 700 /workspace/developer/.ssh
        chmod 600 /workspace/developer/.ssh/authorized_keys

        echo "✅ SSH keys configured"
    else
        echo "⚠️  No SSH keys found in AUTHORIZED_KEYS environment variable"
    fi
}

# ------------------------------------------------------------------------------
# setup_scripts_lib - Copy library scripts to workspace
# ------------------------------------------------------------------------------
setup_scripts_lib() {
    if [ ! -d "/workspace/scripts/lib" ]; then
        echo "📚 Setting up scripts library..."

        cp -r /docker/lib /workspace/scripts/
        chown -R developer:developer /workspace/scripts/lib
        chmod +x /workspace/scripts/lib/*.sh

        echo "✅ Scripts library configured"
    fi
}

# ------------------------------------------------------------------------------
# setup_extension_manifest - Configure extension activation manifest
# ------------------------------------------------------------------------------
setup_extension_manifest() {
    echo "📋 Configuring extension manifest..."

    if [ "$CI_MODE" = "true" ]; then
        # CI mode: Use pre-configured CI manifest
        if [ -f "/docker/lib/extensions.d/active-extensions.ci.conf" ]; then
            cp /docker/lib/extensions.d/active-extensions.ci.conf \
               /workspace/scripts/lib/extensions.d/active-extensions.conf
            echo "✅ Using CI extension manifest"
        else
            echo "⚠️  CI manifest not found, creating empty manifest"
            mkdir -p /workspace/scripts/lib/extensions.d
            touch /workspace/scripts/lib/extensions.d/active-extensions.conf
        fi
    else
        # Production mode: Check if manifest exists, create from template if not
        if [ ! -f "/workspace/scripts/lib/extensions.d/active-extensions.conf" ]; then
            echo "  Creating default extension manifest..."
            # Use CI manifest as template (has good documentation)
            if [ -f "/docker/lib/extensions.d/active-extensions.ci.conf" ]; then
                cp /docker/lib/extensions.d/active-extensions.ci.conf \
                   /workspace/scripts/lib/extensions.d/active-extensions.conf
                echo "✅ Extension manifest created from template"
            else
                mkdir -p /workspace/scripts/lib/extensions.d
                touch /workspace/scripts/lib/extensions.d/active-extensions.conf
                echo "✅ Empty extension manifest created"
            fi
        else
            echo "✅ Existing extension manifest found"
        fi
    fi

    # Ensure correct permissions
    chown developer:developer /workspace/scripts/lib/extensions.d/active-extensions.conf
    chmod 644 /workspace/scripts/lib/extensions.d/active-extensions.conf
}

# ------------------------------------------------------------------------------
# setup_workspace_bin - Create workspace bin directory and symlinks
# ------------------------------------------------------------------------------
setup_workspace_bin() {
    echo "🔗 Setting up workspace bin directory..."

    if [ ! -d "/workspace/bin" ]; then
        mkdir -p /workspace/bin
        chown developer:developer /workspace/bin
    fi

    # Create symlink for extension-manager if script exists and symlink doesn't
    if [ -f "/workspace/scripts/lib/extension-manager.sh" ] && \
       [ ! -L "/workspace/bin/extension-manager" ]; then
        ln -sf /workspace/scripts/lib/extension-manager.sh /workspace/bin/extension-manager
        chown -h developer:developer /workspace/bin/extension-manager
    fi

    echo "✅ Workspace bin directory configured"
}

# ------------------------------------------------------------------------------
# setup_environment_variables - Configure environment variables for developer user
# ------------------------------------------------------------------------------
setup_environment_variables() {
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        echo "🔐 Configuring environment variables..."
        echo "export ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY'" >> /workspace/developer/.bashrc
        echo "✅ Environment variables configured"
    fi
}

# ------------------------------------------------------------------------------
# setup_github_auth - Configure GitHub authentication (token and gh CLI)
# ------------------------------------------------------------------------------
setup_github_auth() {
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "🔐 Configuring GitHub authentication..."

        echo "export GITHUB_TOKEN='$GITHUB_TOKEN'" >> /workspace/developer/.bashrc

        # Create GitHub CLI config for gh commands
        sudo -u developer mkdir -p /workspace/developer/.config/gh
        cat > /workspace/developer/.config/gh/hosts.yml << EOF
github.com:
    oauth_token: $GITHUB_TOKEN
    user: $GITHUB_USER
    git_protocol: https
EOF
        chown -R developer:developer /workspace/developer/.config/gh
        chmod 600 /workspace/developer/.config/gh/hosts.yml

        echo "✅ GitHub authentication configured"
    fi
}

# ------------------------------------------------------------------------------
# setup_git_config - Configure Git user credentials and credential helper
# ------------------------------------------------------------------------------
setup_git_config() {
    local configured=false

    if [ -n "$GIT_USER_NAME" ]; then
        sudo -u developer git config --global user.name "$GIT_USER_NAME"
        echo "✅ Git user name configured: $GIT_USER_NAME"
        configured=true
    fi

    if [ -n "$GIT_USER_EMAIL" ]; then
        sudo -u developer git config --global user.email "$GIT_USER_EMAIL"
        echo "✅ Git user email configured: $GIT_USER_EMAIL"
        configured=true
    fi

    # Setup Git credential helper for GitHub token
    if [ -n "$GITHUB_TOKEN" ]; then
        # Create credential helper script
        cat > /workspace/developer/.git-credential-helper.sh << 'EOF'
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

        chmod +x /workspace/developer/.git-credential-helper.sh
        chown developer:developer /workspace/developer/.git-credential-helper.sh

        # Configure Git to use the credential helper
        sudo -u developer git config --global credential.helper "/workspace/developer/.git-credential-helper.sh"
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
    setup_scripts_lib
    setup_extension_manifest
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