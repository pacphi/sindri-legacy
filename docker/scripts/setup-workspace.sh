#!/bin/bash
# setup-workspace.sh - Create /workspace directory structure

set -e

echo "📁 Setting up workspace directory structure..."

WORKSPACE_DIR="/workspace"

# Helper function to create directory if it doesn't exist
create_dir_if_needed() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "  ✓ Created: ${dir#"$WORKSPACE_DIR"/}"
    fi
}

# Create workspace root if it doesn't exist
if [ ! -d "$WORKSPACE_DIR" ]; then
    mkdir -p "$WORKSPACE_DIR"
    echo "  ✓ Created workspace root: $WORKSPACE_DIR"
fi

# Create main directories
main_dirs=(
    "projects"
    "scripts"
    "config"
    "agents"
    "context"
    "bin"
    "backups"
    "docs"
)

for dir in "${main_dirs[@]}"; do
    create_dir_if_needed "$WORKSPACE_DIR/$dir"
done

# Create projects subdirectory
create_dir_if_needed "$WORKSPACE_DIR/projects/active"

# Create subdirectories for context management
context_dirs=(
    "context/global"
    "context/templates"
)

for dir in "${context_dirs[@]}"; do
    create_dir_if_needed "$WORKSPACE_DIR/$dir"
done

# Create scripts subdirectories
script_dirs=(
    "scripts/lib"
    "scripts/lib/extensions.d"
)

for dir in "${script_dirs[@]}"; do
    create_dir_if_needed "$WORKSPACE_DIR/$dir"
done

# Create config subdirectories
create_dir_if_needed "$WORKSPACE_DIR/config/templates"

# Set proper permissions on key directories
[ -d "$WORKSPACE_DIR/bin" ] && chmod 755 "$WORKSPACE_DIR/bin"
[ -d "$WORKSPACE_DIR/scripts" ] && chmod 755 "$WORKSPACE_DIR/scripts"
[ -d "$WORKSPACE_DIR/scripts/lib" ] && chmod 755 "$WORKSPACE_DIR/scripts/lib"

# Create a README in the workspace
if [ ! -f "$WORKSPACE_DIR/README.md" ]; then
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
    echo "  ✓ Created workspace README"
fi

echo "✅ Workspace directory structure created successfully"
