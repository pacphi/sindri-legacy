#!/bin/bash
# setup-workspace.sh - Initialize /workspace directory structure
# This runs at container startup and must be idempotent
# Creates user workspace directories - system files stay in /docker

set -e

WORKSPACE_DIR="/workspace"

# ==============================================================================
# Helper Functions
# ==============================================================================

# ------------------------------------------------------------------------------
# create_dir_if_needed - Create directory if it doesn't exist
# ------------------------------------------------------------------------------
create_dir_if_needed() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "  ✓ Created: ${dir#"$WORKSPACE_DIR"/}"
    fi
}

# ==============================================================================
# Workspace Initialization Functions
# ==============================================================================

# ------------------------------------------------------------------------------
# create_directory_structure - Create all workspace directories
# ------------------------------------------------------------------------------
create_directory_structure() {
    echo "📁 Creating directory structure..."

    # Create workspace root if it doesn't exist
    if [ ! -d "$WORKSPACE_DIR" ]; then
        mkdir -p "$WORKSPACE_DIR"
        echo "  ✓ Created workspace root: $WORKSPACE_DIR"
    fi

    # Create user directories (developer-owned, writable)
    local user_dirs=(
        "developer"
        "scripts"
        "config"
        "config/templates"
        "projects"
        "projects/active"
        "agents"
        "context"
        "context/global"
        "context/templates"
        "bin"
        "backups"
        "docs"
    )

    for dir in "${user_dirs[@]}"; do
        create_dir_if_needed "$WORKSPACE_DIR/$dir"
    done

    # Create system directory (root-owned, read-only to users)
    local system_dirs=(
        ".system"
        ".system/bin"
        ".system/lib"
        ".system/manifest"
    )

    for dir in "${system_dirs[@]}"; do
        create_dir_if_needed "$WORKSPACE_DIR/$dir"
    done
}

# ------------------------------------------------------------------------------
# create_system_symlinks - Create symlinks to Docker image files
# ------------------------------------------------------------------------------
create_system_symlinks() {
    echo "🔗 Creating system symlinks..."

    # Symlink extension-manager for PATH access
    if [ ! -L "$WORKSPACE_DIR/.system/bin/extension-manager" ]; then
        ln -sf /docker/lib/extension-manager.sh "$WORKSPACE_DIR/.system/bin/extension-manager"
        echo "  ✓ Linked extension-manager"
    fi

    # Symlink common libraries
    if [ ! -L "$WORKSPACE_DIR/.system/lib/common.sh" ]; then
        ln -sf /docker/lib/common.sh "$WORKSPACE_DIR/.system/lib/common.sh"
        echo "  ✓ Linked common.sh"
    fi

    if [ ! -L "$WORKSPACE_DIR/.system/lib/extensions-common.sh" ]; then
        ln -sf /docker/lib/extensions-common.sh "$WORKSPACE_DIR/.system/lib/extensions-common.sh"
        echo "  ✓ Linked extensions-common.sh"
    fi

    # Symlink extensions directory
    if [ ! -L "$WORKSPACE_DIR/.system/lib/extensions.d" ]; then
        ln -sf /docker/lib/extensions.d "$WORKSPACE_DIR/.system/lib/extensions.d"
        echo "  ✓ Linked extensions.d"
    fi
}

# ------------------------------------------------------------------------------
# initialize_manifest - Initialize extension activation manifest
# ------------------------------------------------------------------------------
initialize_manifest() {
    if [ -f "$WORKSPACE_DIR/.system/manifest/active-extensions.conf" ]; then
        return
    fi

    echo "📋 Initializing extension manifest..."

    # Use CI manifest in CI mode, otherwise use example
    if [ "$CI_MODE" = "true" ]; then
        cp /docker/lib/extensions.d/active-extensions.ci.conf \
           "$WORKSPACE_DIR/.system/manifest/active-extensions.conf"
        echo "  ✓ Copied CI manifest"
    else
        cp /docker/lib/extensions.d/active-extensions.conf.example \
           "$WORKSPACE_DIR/.system/manifest/active-extensions.conf"
        echo "  ✓ Copied manifest example"
    fi

    chmod 644 "$WORKSPACE_DIR/.system/manifest/active-extensions.conf"
}

# ------------------------------------------------------------------------------
# set_permissions - Set proper ownership and permissions
# ------------------------------------------------------------------------------
set_permissions() {
    echo "🔒 Setting permissions..."

    # Set ownership on user workspace directories
    # Only set if developer user exists (may not during Docker build)
    if id "developer" >/dev/null 2>&1; then
        chown -R developer:developer \
            "$WORKSPACE_DIR/developer" \
            "$WORKSPACE_DIR/scripts" \
            "$WORKSPACE_DIR/config" \
            "$WORKSPACE_DIR/projects" \
            "$WORKSPACE_DIR/agents" \
            "$WORKSPACE_DIR/context" \
            "$WORKSPACE_DIR/docs" \
            "$WORKSPACE_DIR/backups" \
            "$WORKSPACE_DIR/bin" \
            "$WORKSPACE_DIR/.system/manifest" 2>/dev/null || true

        chmod 775 \
            "$WORKSPACE_DIR/scripts" \
            "$WORKSPACE_DIR/config" \
            "$WORKSPACE_DIR/projects" \
            "$WORKSPACE_DIR/agents" \
            "$WORKSPACE_DIR/context" \
            "$WORKSPACE_DIR/docs" \
            "$WORKSPACE_DIR/backups" \
            "$WORKSPACE_DIR/bin" \
            "$WORKSPACE_DIR/.system/manifest" 2>/dev/null || true

        echo "  ✓ User workspace permissions set"
    fi

    # System directory remains root-owned (except manifest which is developer-owned)
    chmod 755 "$WORKSPACE_DIR/.system" 2>/dev/null || true
    chmod 755 "$WORKSPACE_DIR/.system/bin" 2>/dev/null || true
    chmod 755 "$WORKSPACE_DIR/.system/lib" 2>/dev/null || true

    echo "  ✓ System directory permissions set"
}

# ------------------------------------------------------------------------------
# create_readme - Create workspace README documentation
# ------------------------------------------------------------------------------
create_readme() {
    if [ -f "$WORKSPACE_DIR/README.md" ]; then
        return
    fi

    echo "📝 Creating workspace README..."

    cat > "$WORKSPACE_DIR/README.md" << 'EOF'
# Sindri Workspace

This is your persistent development workspace.

## Directory Structure

### User Workspace (developer-owned, writable)
- `developer/` - Developer home directory (persistent)
- `scripts/` - User scripts and extension-generated helpers
- `config/` - Configuration files and templates
- `projects/` - Active development projects
  - `active/` - Currently active projects
- `agents/` - AI agent configurations
- `context/` - Context management for AI tools
  - `global/` - Global context files
  - `templates/` - Context templates
- `bin/` - User binaries and scripts (added to PATH)
- `backups/` - Backup files
- `docs/` - Workspace-wide documentation

### System (read-only, managed by Sindri)
- `.system/` - System runtime files (do not modify)
  - `bin/` - System binaries (symlinked to /docker)
  - `lib/` - System libraries (symlinked to /docker)
  - `manifest/` - Extension activation configuration

## Extension System

Extensions are defined in the Docker image (`/docker/lib/extensions.d/`) and referenced
via symlinks. Your active extensions are configured in:

`.system/manifest/active-extensions.conf`

Use `extension-manager` to install, configure, and manage extensions.

## Persistence

All user data in `/workspace` persists across VM restarts on a Fly.io volume.
System files in `.system/` are symlinked to the Docker image for efficiency.

## Getting Started

1. Connect via SSH: `ssh developer@<app-name>.fly.dev -p 10022`
2. Install extensions: `extension-manager install-all`
3. Create or clone projects in `/workspace/projects/active/`

For more information, see the main project documentation.
EOF

    echo "  ✓ README created"
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

# ------------------------------------------------------------------------------
# main - Orchestrate workspace initialization
# ------------------------------------------------------------------------------
main() {
    echo "🚀 Initializing workspace..."

    create_directory_structure
    create_system_symlinks
    initialize_manifest
    set_permissions
    create_readme

    echo "✅ Workspace initialization complete"
}

# ==============================================================================
# Execute main function
# ==============================================================================
main "$@"
