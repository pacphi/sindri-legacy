#!/bin/bash
#
# Setup Secrets Infrastructure
#
# This script sets up transparent secrets management using SOPS + age encryption.
# It creates the necessary directory structure, generates encryption keys,
# creates the secrets library, and syncs Fly.io secrets to an encrypted file.
#
# Architecture:
# - age key stored in ~/.age/key.txt (600 permissions)
# - Secrets library at ~/.secrets/lib.sh (helper functions)
# - Encrypted secrets at ~/.secrets/secrets.enc.yaml (600 permissions)
# - User commands: edit-secrets, view-secrets, load-secrets, with-secrets
#
# This is called by entrypoint.sh on every container start.
#

set -eo pipefail

# Disable immediate exit for secrets setup - we want to continue even if secrets fail
# This prevents container crashes when SOPS/age operations fail
set +e

# ==============================================================================
# Configuration
# ==============================================================================

DEVELOPER_USER="${DEVELOPER_USER:-developer}"
DEVELOPER_HOME="${DEVELOPER_HOME_RUNTIME:-/workspace/developer}"
SECRETS_DIR="$DEVELOPER_HOME/.secrets"
AGE_DIR="$DEVELOPER_HOME/.age"
AGE_KEY_FILE="$AGE_DIR/key.txt"
SECRETS_FILE="$SECRETS_DIR/secrets.enc.yaml"
SECRETS_LIBRARY="$SECRETS_DIR/lib.sh"

# ==============================================================================
# Functions
# ==============================================================================

# ------------------------------------------------------------------------------
# setup_age_key - Generate age encryption key if not exists
# ------------------------------------------------------------------------------
setup_age_key() {
    echo "🔑 Setting up age encryption key..."

    if [ -f "$AGE_KEY_FILE" ]; then
        echo "  ✓ Age key already exists"
        return 0
    fi

    # Create age directory
    mkdir -p "$AGE_DIR"

    # Generate age key
    sudo -u "$DEVELOPER_USER" age-keygen -o "$AGE_KEY_FILE" 2>/dev/null

    # Secure permissions
    chmod 700 "$AGE_DIR"
    chmod 600 "$AGE_KEY_FILE"
    chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "$AGE_DIR"

    echo "  ✓ Generated new age encryption key"
}

# ------------------------------------------------------------------------------
# create_secrets_library - Create secrets library with helper functions
# ------------------------------------------------------------------------------
create_secrets_library() {
    echo "📚 Creating secrets library..."

    mkdir -p "$SECRETS_DIR"

    cat > "$SECRETS_LIBRARY" << 'LIBRARY_EOF'
#!/bin/bash
#
# Secrets Library - Helper functions for secrets management
#
# This library provides functions for loading, getting, setting, and managing
# encrypted secrets using SOPS + age encryption.
#
# Usage:
#   source ~/.secrets/lib.sh
#   has_secret "api_key"
#   value=$(get_secret "api_key")
#   set_secret "api_key" "secret_value"
#

# Configuration
SECRETS_DIR="${HOME}/.secrets"
AGE_KEY_FILE="${HOME}/.age/key.txt"
SECRETS_FILE="${SECRETS_DIR}/secrets.enc.yaml"

# ------------------------------------------------------------------------------
# has_secret - Check if a secret exists
# Usage: has_secret "secret_name"
# Returns: 0 if exists, 1 if not
# ------------------------------------------------------------------------------
has_secret() {
    local secret_name="$1"

    if [ ! -f "$SECRETS_FILE" ]; then
        return 1
    fi

    # Decrypt and check for secret
    if SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops --decrypt "$SECRETS_FILE" 2>/dev/null | \
       grep -q "^${secret_name}:"; then
        return 0
    else
        return 1
    fi
}

# ------------------------------------------------------------------------------
# get_secret - Get a secret value
# Usage: value=$(get_secret "secret_name")
# Returns: Secret value or empty string if not found
# ------------------------------------------------------------------------------
get_secret() {
    local secret_name="$1"

    if [ ! -f "$SECRETS_FILE" ]; then
        echo ""
        return 1
    fi

    # Decrypt and extract secret
    local value=$(SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops --decrypt "$SECRETS_FILE" 2>/dev/null | \
                  grep "^${secret_name}:" | cut -d':' -f2- | sed 's/^ *//')

    echo "$value"
}

# ------------------------------------------------------------------------------
# set_secret - Add or update a secret
# Usage: set_secret "secret_name" "secret_value"
# ------------------------------------------------------------------------------
set_secret() {
    local secret_name="$1"
    local secret_value="$2"

    # Create secrets file if not exists
    if [ ! -f "$SECRETS_FILE" ]; then
        echo "# Encrypted secrets managed by SOPS + age" > "${SECRETS_DIR}/secrets.yaml"
        SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" \
        SOPS_AGE_RECIPIENTS="$(grep '^# public key:' "$AGE_KEY_FILE" | cut -d':' -f2 | tr -d ' ')" \
        sops --encrypt --age "$(grep '^# public key:' "$AGE_KEY_FILE" | cut -d':' -f2 | tr -d ' ')" \
             "${SECRETS_DIR}/secrets.yaml" > "$SECRETS_FILE"
        rm "${SECRETS_DIR}/secrets.yaml"
    fi

    # Decrypt, update, re-encrypt
    local temp_file=$(mktemp)
    SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops --decrypt "$SECRETS_FILE" > "$temp_file" 2>/dev/null

    # Update or add secret
    if grep -q "^${secret_name}:" "$temp_file"; then
        sed -i "s|^${secret_name}:.*|${secret_name}: ${secret_value}|" "$temp_file"
    else
        echo "${secret_name}: ${secret_value}" >> "$temp_file"
    fi

    # Re-encrypt
    SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" \
    SOPS_AGE_RECIPIENTS="$(grep '^# public key:' "$AGE_KEY_FILE" | cut -d':' -f2 | tr -d ' ')" \
    sops --encrypt --age "$(grep '^# public key:' "$AGE_KEY_FILE" | cut -d':' -f2 | tr -d ' ')" \
         "$temp_file" > "$SECRETS_FILE"

    rm "$temp_file"
    chmod 600 "$SECRETS_FILE"
}

# ------------------------------------------------------------------------------
# load_secrets - Load all secrets into environment (current shell only)
# Usage: load_secrets
# ------------------------------------------------------------------------------
load_secrets() {
    if [ ! -f "$SECRETS_FILE" ]; then
        echo "No secrets file found"
        return 1
    fi

    # Decrypt and export each secret
    while IFS=': ' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue

        # Export secret
        export "${key}=${value}"
    done < <(SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops --decrypt "$SECRETS_FILE" 2>/dev/null)

    echo "✓ Secrets loaded into environment"
}

# ------------------------------------------------------------------------------
# with_secrets - Run command with secrets loaded
# Usage: with_secrets command args...
# ------------------------------------------------------------------------------
with_secrets() {
    if [ ! -f "$SECRETS_FILE" ]; then
        echo "No secrets file found"
        return 1
    fi

    # Decrypt secrets and run command with them in environment
    local temp_env=$(mktemp)

    SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops --decrypt "$SECRETS_FILE" 2>/dev/null | \
    while IFS=': ' read -r key value; do
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
        echo "export ${key}='${value}'"
    done > "$temp_env"

    # Source and run command
    (
        source "$temp_env"
        "$@"
    )

    rm "$temp_env"
}

# Export functions for use in scripts
export -f has_secret get_secret set_secret load_secrets with_secrets
LIBRARY_EOF

    chmod 644 "$SECRETS_LIBRARY"
    chown "$DEVELOPER_USER:$DEVELOPER_USER" "$SECRETS_LIBRARY"

    echo "  ✓ Secrets library created"
}

# ------------------------------------------------------------------------------
# sync_flyio_secrets - Sync Fly.io environment secrets to encrypted file
# ------------------------------------------------------------------------------
sync_flyio_secrets() {
    echo "🔐 Syncing Fly.io secrets to encrypted file..."

    # Source the secrets library
    source "$SECRETS_LIBRARY"

    local secrets_updated=false

    # AI/Development Tools
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        set_secret "anthropic_api_key" "$ANTHROPIC_API_KEY"
        secrets_updated=true
        echo "  ✓ Synced anthropic_api_key"
    fi

    if [ -n "${GITHUB_TOKEN:-}" ]; then
        set_secret "github_token" "$GITHUB_TOKEN"
        secrets_updated=true
        echo "  ✓ Synced github_token"
    fi

    if [ -n "${PERPLEXITY_API_KEY:-}" ]; then
        set_secret "perplexity_api_key" "$PERPLEXITY_API_KEY"
        secrets_updated=true
        echo "  ✓ Synced perplexity_api_key"
    fi

    if [ -n "${OPENROUTER_API_KEY:-}" ]; then
        set_secret "openrouter_api_key" "$OPENROUTER_API_KEY"
        secrets_updated=true
        echo "  ✓ Synced openrouter_api_key"
    fi

    if [ -n "${GOOGLE_GEMINI_API_KEY:-}" ]; then
        set_secret "google_gemini_api_key" "$GOOGLE_GEMINI_API_KEY"
        secrets_updated=true
        echo "  ✓ Synced google_gemini_api_key"
    fi

    if [ -n "${XAI_API_KEY:-}" ]; then
        set_secret "xai_api_key" "$XAI_API_KEY"
        secrets_updated=true
        echo "  ✓ Synced xai_api_key"
    fi

    # Cloud Provider Credentials
    if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
        set_secret "aws_access_key_id" "$AWS_ACCESS_KEY_ID"
        secrets_updated=true
        echo "  ✓ Synced aws_access_key_id"
    fi

    if [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        set_secret "aws_secret_access_key" "$AWS_SECRET_ACCESS_KEY"
        secrets_updated=true
        echo "  ✓ Synced aws_secret_access_key"
    fi

    if [ -n "${AWS_SESSION_TOKEN:-}" ]; then
        set_secret "aws_session_token" "$AWS_SESSION_TOKEN"
        secrets_updated=true
        echo "  ✓ Synced aws_session_token"
    fi

    if [ -n "${AZURE_CLIENT_ID:-}" ]; then
        set_secret "azure_client_id" "$AZURE_CLIENT_ID"
        secrets_updated=true
        echo "  ✓ Synced azure_client_id"
    fi

    if [ -n "${AZURE_CLIENT_SECRET:-}" ]; then
        set_secret "azure_client_secret" "$AZURE_CLIENT_SECRET"
        secrets_updated=true
        echo "  ✓ Synced azure_client_secret"
    fi

    if [ -n "${AZURE_TENANT_ID:-}" ]; then
        set_secret "azure_tenant_id" "$AZURE_TENANT_ID"
        secrets_updated=true
        echo "  ✓ Synced azure_tenant_id"
    fi

    if [ "$secrets_updated" = true ]; then
        echo "  ✓ Secrets encrypted and stored"

        # Clear all secrets from environment
        unset ANTHROPIC_API_KEY GITHUB_TOKEN PERPLEXITY_API_KEY OPENROUTER_API_KEY
        unset GOOGLE_GEMINI_API_KEY XAI_API_KEY
        unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
        unset AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_TENANT_ID

        echo "  ✓ Environment variables cleared (secrets secured)"
    else
        echo "  ℹ️  No Fly.io secrets found to sync"
    fi
}

# ------------------------------------------------------------------------------
# add_user_commands - Add user-facing commands to bashrc
# ------------------------------------------------------------------------------
add_user_commands() {
    echo "🛠️  Adding user commands..."

    # Check if commands already added (prevent duplicates)
    if grep -q "# Secrets Management Commands" "$DEVELOPER_HOME/.bashrc" 2>/dev/null; then
        echo "  ✓ User commands already configured"
        return 0
    fi

    cat >> "$DEVELOPER_HOME/.bashrc" << 'BASHRC_EOF'

# Secrets Management Commands
alias view-secrets='SOPS_AGE_KEY_FILE=~/.age/key.txt sops --decrypt ~/.secrets/secrets.enc.yaml 2>/dev/null || echo "No secrets file found"'
alias edit-secrets='SOPS_AGE_KEY_FILE=~/.age/key.txt sops ~/.secrets/secrets.enc.yaml'
alias load-secrets='source ~/.secrets/lib.sh && load_secrets'

# with-secrets command function
with-secrets() {
    source ~/.secrets/lib.sh
    with_secrets "$@"
}
BASHRC_EOF

    echo "  ✓ Added user commands to .bashrc"
    echo "    - view-secrets: View decrypted secrets"
    echo "    - edit-secrets: Edit secrets (auto-encrypts on save)"
    echo "    - load-secrets: Load secrets into current shell"
    echo "    - with-secrets: Run command with secrets loaded"
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    echo "🔒 Setting up secrets infrastructure..."

    # Setup with error handling - don't crash container on failures
    if ! setup_age_key; then
        echo "⚠️  Warning: Failed to setup age key, secrets management may not work"
    fi

    if ! create_secrets_library; then
        echo "⚠️  Warning: Failed to create secrets library"
    fi

    # Sync secrets (non-critical - VM should start even if this fails)
    if ! sync_flyio_secrets; then
        echo "⚠️  Warning: Failed to sync Fly.io secrets"
    fi

    if ! add_user_commands; then
        echo "⚠️  Warning: Failed to add user commands to .bashrc"
    fi

    # Ensure proper ownership (best effort)
    if [ -d "$SECRETS_DIR" ]; then
        chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "$SECRETS_DIR" 2>/dev/null || true
    fi
    if [ -d "$AGE_DIR" ]; then
        chown -R "$DEVELOPER_USER:$DEVELOPER_USER" "$AGE_DIR" 2>/dev/null || true
    fi

    echo "✅ Secrets infrastructure setup complete"
    return 0  # Always return success to prevent container crash
}

main "$@"
