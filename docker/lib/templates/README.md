# Extension Templates

This directory contains template files that are copied by extensions during installation.

## Purpose

Templates are kept separate from core library files to prevent false-positive "already installed"
status when extensions check for the existence of files they create.

## Architecture

**Problem:** If template files exist in `/docker/lib/`, they get copied to `/workspace/scripts/lib/`
by `entrypoint.sh`. When extensions check if they're installed by looking for files they create,
they find the template copies and incorrectly report "already installed", skipping configuration.

**Solution:** Templates are stored in `/docker/lib/templates/` subdirectory:
- `entrypoint.sh` copies all of `/docker/lib/` including `templates/` subdirectory
- Template files end up in `/workspace/scripts/lib/templates/` (not the target location)
- Extensions copy from `/docker/lib/templates/` to their target locations
- Status checks look at target locations (not templates/), correctly detecting installation state

## Template Files

| File | Used By | Target Location |
|------|---------|-----------------|
| `context-loader.sh` | context-loader | `/workspace/scripts/lib/context-loader.sh` |
| `cf-with-context.sh` | context-loader | `/workspace/scripts/cf-with-context.sh` |
| `agent-discovery.sh` | agent-manager | `/workspace/scripts/lib/agent-discovery.sh` |

## Adding New Templates

When creating a new extension that uses template files:

1. **Store template in this directory:** `/docker/lib/templates/your-template.sh`
2. **Reference in extension:** `local template="/docker/lib/templates/your-template.sh"`
3. **Copy to target:** `cp "$template" "/workspace/path/to/target"`
4. **Check target in status():** Look for `/workspace/path/to/target` not the template

## Not Templates

Files in `/docker/lib/` that are NOT templates (copied by entrypoint for general use):
- Core extension system: `extension-manager.sh`, `extensions-common.sh`
- Developer utilities: `new-project.sh`, `clone-project.sh`, `git.sh`, etc.
- Utility libraries: `tmux-*.sh`, `backup.sh`, `system-status.sh`, etc.

These files are meant to exist in `/workspace/scripts/lib/` and don't conflict with extension
installation detection.
