#!/bin/bash
# SECURITY: Enhanced error handling (H3 fix)
set -euo pipefail

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
CI_MODE="${CI_MODE:-false}"  # Default to production mode if not set

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
    else
        echo "  Developer home already exists on persistent volume"
    fi

    # CRITICAL: Always ensure proper ownership and permissions
    # This must run every time, not just on first creation
    # Without this, extensions fail with "Permission denied" on .bashrc writes
    echo "  🔒 Ensuring correct ownership and permissions..."

    # Ensure .bashrc exists (may be missing if directory was created externally)
    if [ ! -f "$DEVELOPER_HOME_RUNTIME/.bashrc" ] && [ -f "$SKEL_DIR/.bashrc" ]; then
        cp "$SKEL_DIR/.bashrc" "$DEVELOPER_HOME_RUNTIME/"
        echo "    ✓ Created missing .bashrc from skeleton"
    fi

    # Ensure .bash_profile exists
    if [ ! -f "$DEVELOPER_HOME_RUNTIME/.bash_profile" ] && [ -f "$SKEL_DIR/.bash_profile" ]; then
        cp "$SKEL_DIR/.bash_profile" "$DEVELOPER_HOME_RUNTIME/"
        echo "    ✓ Created missing .bash_profile from skeleton"
    fi

    # Ensure .claude directory exists (required for claude-marketplace extension)
    if [ ! -d "$DEVELOPER_HOME_RUNTIME/.claude" ] && [ -d "$DEVELOPER_HOME_BUILD/.claude" ]; then
        cp -r "$DEVELOPER_HOME_BUILD/.claude" "$DEVELOPER_HOME_RUNTIME/"
        echo "    ✓ Created missing .claude directory from Docker build"
    elif [ ! -d "$DEVELOPER_HOME_RUNTIME/.claude" ]; then
        # Fallback: create minimal .claude directory if build version doesn't exist
        mkdir -p "$DEVELOPER_HOME_RUNTIME/.claude"
        echo "    ✓ Created minimal .claude directory"
    fi

    # Create extensions directory for extension artifacts
    # This is where extensions install/configure (see WORKSPACE_DIR in common.sh)
    mkdir -p "$DEVELOPER_HOME_RUNTIME/extensions"
    echo "    ✓ Created extensions directory"

    # Always set ownership - critical for extension installation
    chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME_RUNTIME"
    chmod 755 "$DEVELOPER_HOME_RUNTIME"

    # Ensure .bashrc is writable by developer user
    if [ -f "$DEVELOPER_HOME_RUNTIME/.bashrc" ]; then
        chmod 644 "$DEVELOPER_HOME_RUNTIME/.bashrc"
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
# setup_secure_secrets - Configure secure secrets management
# SECURITY: Store secrets in protected file, not in bashrc (C4 fix)
# ------------------------------------------------------------------------------
setup_secure_secrets() {
    local secrets_dir="$DEVELOPER_HOME_RUNTIME/.secrets"
    local secrets_file="$secrets_dir/credentials"
    local secrets_loader="$secrets_dir/load-secrets.sh"
    local has_secrets=false

    # Create secrets directory
    mkdir -p "$secrets_dir"
    chmod 700 "$secrets_dir"

    # Create secrets file
    cat > "$secrets_file" << 'SECRETS_EOF'
# Sindri Secure Secrets
# This file is loaded on-demand, not automatically in bashrc
# Usage: source ~/.secrets/load-secrets.sh

SECRETS_EOF

    # Add secrets if they exist
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        echo "export ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY'" >> "$secrets_file"
        has_secrets=true
    fi

    if [ -n "$GITHUB_TOKEN" ]; then
        echo "export GITHUB_TOKEN='$GITHUB_TOKEN'" >> "$secrets_file"
        has_secrets=true
    fi

    if [ -n "$OPENROUTER_API_KEY" ]; then
        echo "export OPENROUTER_API_KEY='$OPENROUTER_API_KEY'" >> "$secrets_file"
        has_secrets=true
    fi

    if [ -n "$GOOGLE_GEMINI_API_KEY" ]; then
        echo "export GOOGLE_GEMINI_API_KEY='$GOOGLE_GEMINI_API_KEY'" >> "$secrets_file"
        has_secrets=true
    fi

    if [ -n "$PERPLEXITY_API_KEY" ]; then
        echo "export PERPLEXITY_API_KEY='$PERPLEXITY_API_KEY'" >> "$secrets_file"
        has_secrets=true
    fi

    # Set restrictive permissions
    chmod 600 "$secrets_file"
    chown "$DEVELOPER_USER:$DEVELOPER_USER" "$secrets_file"

    # Create loader script
    cat > "$secrets_loader" << 'LOADER_EOF'
#!/bin/bash
# Secure secrets loader
# Sources credentials file if it exists

SECRETS_FILE="$HOME/.secrets/credentials"

if [[ -f "$SECRETS_FILE" ]]; then
    source "$SECRETS_FILE"
else
    echo "Warning: Secrets file not found" >&2
fi
LOADER_EOF

    chmod 700 "$secrets_loader"
    chown "$DEVELOPER_USER:$DEVELOPER_USER" "$secrets_loader"

    # Create wrapper functions that load secrets on-demand
    cat >> "$DEVELOPER_HOME_RUNTIME/.bashrc" << 'BASHRC_EOF'

# Secure secret loading helpers (added by Sindri security hardening)
load_secrets() {
    if [[ -f "$HOME/.secrets/load-secrets.sh" ]]; then
        source "$HOME/.secrets/load-secrets.sh"
    fi
}

# Wrapper functions for tools that need API keys
claude() {
    load_secrets
    command claude "$@"
}

gh() {
    load_secrets
    command gh "$@"
}

goalie() {
    load_secrets
    command goalie "$@"
}

# Add more wrappers as needed for tools that require API keys
BASHRC_EOF

    chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "$secrets_dir"

    if [ "$has_secrets" = true ]; then
        echo "🔐 Secure secrets storage configured"
        echo "  ✓ Secrets stored in ~/.secrets/credentials (600)"
        echo "  ✓ Use 'load_secrets' function to access in scripts"
    else
        echo "ℹ️  No secrets provided (skipping)"
    fi

    # Remove old environment variables (don't pass to shell)
    unset ANTHROPIC_API_KEY
    unset GITHUB_TOKEN
    unset OPENROUTER_API_KEY
    unset GOOGLE_GEMINI_API_KEY
    unset PERPLEXITY_API_KEY
}

# ------------------------------------------------------------------------------
# setup_github_auth - Configure GitHub authentication (gh CLI)
# SECURITY: Token now stored in ~/.secrets/credentials, not bashrc (C4 fix)
# ------------------------------------------------------------------------------
setup_github_auth() {
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "🔐 Configuring GitHub CLI..."

        # Create GitHub CLI config for gh commands
        # gh CLI will get token from wrapper function that loads secrets
        sudo -u "$DEVELOPER_USER" mkdir -p "$DEVELOPER_HOME_RUNTIME/.config/gh"
        cat > "$DEVELOPER_HOME_RUNTIME/.config/gh/hosts.yml" << EOF
github.com:
    oauth_token: $GITHUB_TOKEN
    user: $GITHUB_USER
    git_protocol: https
EOF
        chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME_RUNTIME/.config/gh"
        chmod 600 "$DEVELOPER_HOME_RUNTIME/.config/gh/hosts.yml"

        echo "✅ GitHub CLI configured"
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
    # SECURITY: Credential helper reads from secure storage (C4/C7 fix)
    if [ -n "$GITHUB_TOKEN" ]; then
        # Create credential helper script that reads from secure storage
        cat > "$DEVELOPER_HOME_RUNTIME/.git-credential-helper.sh" << 'CREDHELPER_EOF'
#!/bin/bash
# Git credential helper - reads from secure storage
# SECURITY: Token not embedded in file

SECRETS_FILE="$HOME/.secrets/credentials"

if [ "$1" = "get" ]; then
    # Read request
    declare -A req
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        key="${line%%=*}"
        value="${line#*=}"
        req[$key]="$value"
    done

    # Only provide credentials for github.com
    if [[ "${req[host]}" == "github.com" ]]; then
        # Source secrets file to get GITHUB_TOKEN
        if [[ -f "$SECRETS_FILE" ]]; then
            source "$SECRETS_FILE"
            if [[ -n "$GITHUB_TOKEN" ]]; then
                echo "protocol=https"
                echo "host=github.com"
                echo "username=x-access-token"
                echo "password=$GITHUB_TOKEN"
            fi
        fi
    fi
fi
CREDHELPER_EOF

        chmod 700 "$DEVELOPER_HOME_RUNTIME/.git-credential-helper.sh"
        chown "$DEVELOPER_USER:$DEVELOPER_USER" "$DEVELOPER_HOME_RUNTIME/.git-credential-helper.sh"

        # Configure Git to use the credential helper
        sudo -u "$DEVELOPER_USER" git config --global credential.helper "$DEVELOPER_HOME_RUNTIME/.git-credential-helper.sh"
        echo "✅ Git credential helper configured (secure storage)"
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
    setup_secure_secrets
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
