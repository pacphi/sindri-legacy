#!/bin/bash
# setup-workspace.sh - Initialize and sync /workspace directory structure
# This runs at container startup and must be idempotent
# Handles both fresh volumes (empty) and existing volumes (with content)

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

    # Create main directories
    local main_dirs=(
        "projects"
        "projects/active"
        "scripts"
        "scripts/lib"
        "scripts/lib/extensions.d"
        "config"
        "config/templates"
        "agents"
        "context"
        "context/global"
        "context/templates"
        "bin"
        "backups"
        "docs"
    )

    for dir in "${main_dirs[@]}"; do
        create_dir_if_needed "$WORKSPACE_DIR/$dir"
    done
}

# ------------------------------------------------------------------------------
# sync_extension_manager - Sync extension-manager.sh from Docker image
# ------------------------------------------------------------------------------
sync_extension_manager() {
    if [ ! -d "/docker/lib" ]; then
        return
    fi

    # Ensure extension-manager.sh exists and is current
    if [ ! -f "$WORKSPACE_DIR/scripts/lib/extension-manager.sh" ] || \
       [ "/docker/lib/extension-manager.sh" -nt "$WORKSPACE_DIR/scripts/lib/extension-manager.sh" ]; then
        cp /docker/lib/extension-manager.sh "$WORKSPACE_DIR/scripts/lib/"
        chmod +x "$WORKSPACE_DIR/scripts/lib/extension-manager.sh"
        echo "  ✓ Synced extension-manager.sh"
    fi
}

# ------------------------------------------------------------------------------
# sync_common_scripts - Sync common utility scripts from Docker image
# ------------------------------------------------------------------------------
sync_common_scripts() {
    if [ ! -d "/docker/lib" ]; then
        return
    fi

    # Sync common.sh
    if [ -f "/docker/lib/common.sh" ]; then
        if [ ! -f "$WORKSPACE_DIR/scripts/lib/common.sh" ] || \
           [ "/docker/lib/common.sh" -nt "$WORKSPACE_DIR/scripts/lib/common.sh" ]; then
            cp /docker/lib/common.sh "$WORKSPACE_DIR/scripts/lib/"
            chmod +x "$WORKSPACE_DIR/scripts/lib/common.sh"
            echo "  ✓ Synced common.sh"
        fi
    fi

    # Sync extensions-common.sh
    if [ -f "/docker/lib/extensions-common.sh" ]; then
        if [ ! -f "$WORKSPACE_DIR/scripts/lib/extensions-common.sh" ] || \
           [ "/docker/lib/extensions-common.sh" -nt "$WORKSPACE_DIR/scripts/lib/extensions-common.sh" ]; then
            cp /docker/lib/extensions-common.sh "$WORKSPACE_DIR/scripts/lib/"
            chmod +x "$WORKSPACE_DIR/scripts/lib/extensions-common.sh"
            echo "  ✓ Synced extensions-common.sh"
        fi
    fi

    # Sync registry-retry.sh if it exists
    if [ -f "/docker/lib/registry-retry.sh" ]; then
        if [ ! -f "$WORKSPACE_DIR/scripts/lib/registry-retry.sh" ] || \
           [ "/docker/lib/registry-retry.sh" -nt "$WORKSPACE_DIR/scripts/lib/registry-retry.sh" ]; then
            cp /docker/lib/registry-retry.sh "$WORKSPACE_DIR/scripts/lib/"
            chmod +x "$WORKSPACE_DIR/scripts/lib/registry-retry.sh"
            echo "  ✓ Synced registry-retry.sh"
        fi
    fi
}

# ------------------------------------------------------------------------------
# sync_extension_scripts - Sync top-level extension scripts
# ------------------------------------------------------------------------------
sync_extension_scripts() {
    if [ ! -d "/docker/lib" ]; then
        return
    fi

    # Sync top-level extension scripts
    if [ "$(ls -A /docker/lib/extensions.d/*.extension 2>/dev/null)" ]; then
        for ext in /docker/lib/extensions.d/*.extension; do
            local ext_name
            ext_name=$(basename "$ext")
            if [ ! -f "$WORKSPACE_DIR/scripts/lib/extensions.d/$ext_name" ] || \
               [ "$ext" -nt "$WORKSPACE_DIR/scripts/lib/extensions.d/$ext_name" ]; then
                cp "$ext" "$WORKSPACE_DIR/scripts/lib/extensions.d/"
                echo "  ✓ Synced $ext_name"
            fi
        done
    fi
}

# ------------------------------------------------------------------------------
# sync_extension_subdirectories - Sync nested extension directories
# ------------------------------------------------------------------------------
sync_extension_subdirectories() {
    if [ ! -d "/docker/lib" ]; then
        return
    fi

    # Sync nested extension directories (e.g., claude/, nodejs/, etc.)
    for ext_dir in /docker/lib/extensions.d/*/; do
        [ ! -d "$ext_dir" ] && continue
        local ext_dir_name
        ext_dir_name=$(basename "$ext_dir")

        # Create extension subdirectory if needed
        create_dir_if_needed "$WORKSPACE_DIR/scripts/lib/extensions.d/$ext_dir_name"

        # Sync extension files from subdirectory
        for ext_file in "$ext_dir"/*; do
            [ ! -f "$ext_file" ] && continue
            local ext_file_name
            ext_file_name=$(basename "$ext_file")
            local dest_file="$WORKSPACE_DIR/scripts/lib/extensions.d/$ext_dir_name/$ext_file_name"

            if [ ! -f "$dest_file" ] || [ "$ext_file" -nt "$dest_file" ]; then
                cp "$ext_file" "$dest_file"
                [ -x "$ext_file" ] && chmod +x "$dest_file"
                echo "  ✓ Synced $ext_dir_name/$ext_file_name"
            fi
        done
    done
}

# ------------------------------------------------------------------------------
# sync_manifest_templates - Sync manifest configuration templates
# ------------------------------------------------------------------------------
sync_manifest_templates() {
    if [ ! -d "/docker/lib" ]; then
        return
    fi

    # Sync CI manifest template
    if [ ! -f "$WORKSPACE_DIR/scripts/lib/extensions.d/active-extensions.ci.conf" ] && \
       [ -f "/docker/lib/extensions.d/active-extensions.ci.conf" ]; then
        cp /docker/lib/extensions.d/active-extensions.ci.conf "$WORKSPACE_DIR/scripts/lib/extensions.d/"
        echo "  ✓ Synced CI manifest template"
    fi

    # Sync manifest example
    if [ ! -f "$WORKSPACE_DIR/scripts/lib/extensions.d/active-extensions.conf.example" ] && \
       [ -f "/docker/lib/extensions.d/active-extensions.conf.example" ]; then
        cp /docker/lib/extensions.d/active-extensions.conf.example "$WORKSPACE_DIR/scripts/lib/extensions.d/"
        echo "  ✓ Synced manifest example"
    fi
}

# ------------------------------------------------------------------------------
# sync_extension_system - Sync all extension components from Docker image
# ------------------------------------------------------------------------------
sync_extension_system() {
    echo "🔧 Syncing extension system..."

    sync_extension_manager
    sync_common_scripts
    sync_extension_scripts
    sync_extension_subdirectories
    sync_manifest_templates
}

# ------------------------------------------------------------------------------
# create_symlinks - Create symlinks for workspace tools
# ------------------------------------------------------------------------------
create_symlinks() {
    echo "🔗 Creating symlinks..."

    # Create symlink for extension-manager
    if [ -f "$WORKSPACE_DIR/scripts/lib/extension-manager.sh" ] && \
       [ ! -L "$WORKSPACE_DIR/bin/extension-manager" ]; then
        ln -sf "$WORKSPACE_DIR/scripts/lib/extension-manager.sh" "$WORKSPACE_DIR/bin/extension-manager"
        echo "  ✓ Created extension-manager symlink"
    fi
}

# ------------------------------------------------------------------------------
# set_permissions - Set proper permissions on workspace directories
# ------------------------------------------------------------------------------
set_permissions() {
    echo "🔒 Setting permissions..."

    chmod 755 "$WORKSPACE_DIR" 2>/dev/null || true
    chmod 755 "$WORKSPACE_DIR/bin" 2>/dev/null || true
    chmod 755 "$WORKSPACE_DIR/scripts" 2>/dev/null || true
    chmod 755 "$WORKSPACE_DIR/scripts/lib" 2>/dev/null || true

    echo "  ✓ Permissions set"
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

- `projects/` - Active development projects
  - `active/` - Currently active projects
- `scripts/` - Management and utility scripts
  - `lib/` - Shared library scripts and extensions
- `config/` - Configuration files and templates
- `agents/` - AI agent configurations
- `context/` - Context management for AI tools
  - `global/` - Global context files
  - `templates/` - Context templates
- `bin/` - User binaries and scripts (added to PATH)
- `backups/` - Backup files
- `docs/` - Workspace-wide documentation

## Persistence

All data in `/workspace` persists across VM restarts and is stored on a Fly.io volume.

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
    sync_extension_system
    create_symlinks
    set_permissions
    create_readme

    echo "✅ Workspace initialization complete"
}

# ==============================================================================
# Execute main function
# ==============================================================================
main "$@"
