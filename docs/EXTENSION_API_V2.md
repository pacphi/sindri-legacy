# Extension API v2.0 Specification

**Status**: Implemented
**Version**: 2.0.0
**Date**: 2025-01-30
**Author**: Sindri Extension System

## Overview

Extension API v2.0 adds standardized upgrade support to the Sindri extension system. All extensions must implement the `upgrade()` function and declare installation metadata to enable automated tool upgrades via `extension-manager`.

## Changes from v1.0

### New Metadata Fields

```bash
EXT_INSTALL_METHOD="mise"        # Installation method (required)
EXT_UPGRADE_STRATEGY="automatic" # Upgrade behavior (required)
```

### New Function

```bash
upgrade() {
    # Upgrade installed tools and packages
    # Returns: 0 on success, 1 on failure, 2 for manual action required
}
```

### Updated Version

All extensions implementing v2.0 must update:
```bash
EXT_VERSION="2.0.0"  # Major bump for API change
```

## Metadata Fields

### EXT_INSTALL_METHOD

Declares how the extension installs tools. This determines which upgrade helpers to use.

**Valid values**:
- `mise` - Tools managed by mise (Node.js, Python, Rust, Go, etc.)
- `apt` - APT package manager (Docker, PHP, .NET, monitoring tools)
- `binary` - Direct binary downloads (GitHub releases, CDN, etc.)
- `git` - Git clone + manual build (rbenv, Ollama, etc.)
- `native` - Pre-installed in Docker image (GitHub CLI, system tools)
- `mixed` - Multiple methods (Docker: APT + binaries)
- `manual` - Custom installation requiring manual intervention

**Example**:
```bash
EXT_INSTALL_METHOD="mise"  # Node.js via mise
```

### EXT_UPGRADE_STRATEGY

Declares upgrade behavior and user expectations.

**Valid values**:
- `automatic` - Upgrade to latest automatically without confirmation
- `manual` - Require explicit user confirmation before upgrading
- `pinned` - Never upgrade (version locked for compatibility)
- `security-only` - Only apply security patches, skip feature updates

**Example**:
```bash
EXT_UPGRADE_STRATEGY="automatic"  # Auto-upgrade enabled
```

## The upgrade() Function

### Function Signature

```bash
upgrade() {
    # Implementation here
    return 0  # Success
    return 1  # Failure
    return 2  # Manual action required
}
```

### Placement

The `upgrade()` function must be placed:
1. **After** the `remove()` function
2. **Before** `extension_main "$@"`

### Return Codes

- `0` - Upgrade successful
- `1` - Upgrade failed (error occurred)
- `2` - Manual action required (native tools, Docker rebuild)

### Dry-Run Support

All upgrades must respect dry-run mode:

```bash
upgrade() {
    if is_dry_run; then
        print_status "Would upgrade: package-name"
        return 0
    fi

    # Actual upgrade logic
}
```

## Upgrade Patterns

### Pattern 1: mise-Managed Tools

For extensions using mise (Node.js, Python, Rust, Go):

```bash
EXT_INSTALL_METHOD="mise"
EXT_UPGRADE_STRATEGY="automatic"

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    if ! command_exists mise; then
        print_error "mise not installed"
        return 1
    fi

    activate_mise_environment

    # Show current version
    print_status "Current version:"
    mise current nodejs 2>/dev/null || true
    echo ""

    # Upgrade via mise
    if upgrade_mise_tools "${EXT_NAME}"; then
        print_success "Tools upgraded successfully"

        echo ""
        print_status "Updated version:"
        mise current nodejs

        return 0
    else
        print_error "Upgrade failed"
        return 1
    fi
}
```

### Pattern 2: APT Packages

For extensions using APT package manager:

```bash
EXT_INSTALL_METHOD="apt"
EXT_UPGRADE_STRATEGY="automatic"

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    # List packages to upgrade
    local packages=(
        "docker-ce"
        "docker-ce-cli"
        "containerd.io"
    )

    if upgrade_apt_packages "${packages[@]}"; then
        print_success "Packages upgraded successfully"
        return 0
    else
        print_error "APT upgrade failed"
        return 1
    fi
}
```

### Pattern 3: GitHub Binary Releases

For extensions downloading binaries from GitHub:

```bash
EXT_INSTALL_METHOD="binary"
EXT_UPGRADE_STRATEGY="automatic"

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    # Upgrade mise binary
    if upgrade_github_binary \
        "jdx/mise" \
        "mise" \
        "/usr/local/bin/mise" \
        "--version"; then
        print_success "Binary upgraded successfully"
        return 0
    else
        print_error "Binary upgrade failed"
        return 1
    fi
}
```

### Pattern 4: Git Repositories

For extensions built from git repositories:

```bash
EXT_INSTALL_METHOD="git"
EXT_UPGRADE_STRATEGY="automatic"

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    local repo_path="$HOME/.rbenv"
    local rebuild_cmd="cd $repo_path && src/configure && make -C src"

    if upgrade_git_repo "$repo_path" "$rebuild_cmd"; then
        print_success "Repository upgraded and rebuilt"
        return 0
    else
        print_error "Git upgrade failed"
        return 1
    fi
}
```

### Pattern 5: Native Tools (Pre-installed)

For tools pre-installed in Docker image:

```bash
EXT_INSTALL_METHOD="native"
EXT_UPGRADE_STRATEGY="manual"

upgrade() {
    print_status "Checking ${EXT_NAME}..."

    # Check version but can't upgrade (requires Docker rebuild)
    check_native_update "gh" "version"
    return $?  # Returns 2 (manual action required)
}
```

### Pattern 6: Mixed Installation

For extensions using multiple installation methods:

```bash
EXT_INSTALL_METHOD="mixed"
EXT_UPGRADE_STRATEGY="automatic"

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    local upgrade_failed=0

    # Upgrade APT packages
    print_status "Upgrading APT packages..."
    if ! upgrade_apt_packages "docker-ce" "docker-ce-cli" "containerd.io"; then
        print_error "APT upgrade failed"
        upgrade_failed=1
    fi

    # Upgrade binaries
    print_status "Upgrading binaries..."
    if ! upgrade_github_binary "docker/compose" "docker-compose" "/usr/local/bin/docker-compose"; then
        print_error "Binary upgrade failed"
        upgrade_failed=1
    fi

    if [[ $upgrade_failed -eq 0 ]]; then
        print_success "${EXT_NAME} upgraded successfully"
        return 0
    else
        print_error "${EXT_NAME} upgrade partially failed"
        return 1
    fi
}
```

## Helper Functions

All helper functions are available in `extensions-common.sh`:

### Utility Helpers

```bash
supports_upgrade()           # Check if upgrade() exists
is_dry_run()                 # Check if DRY_RUN=true
dry_run_prefix()             # Get "[DRY-RUN] " prefix for logging
```

### Mise Helpers

```bash
upgrade_mise_tools "extension-name"
# Upgrades all mise-managed tools for the extension
# Returns: 0 on success, 1 on failure
```

### APT Helpers

```bash
check_apt_updates "pkg1" "pkg2" ...
# Check which packages have updates available
# Returns: 0 if updates found, 1 if up-to-date

upgrade_apt_packages "pkg1" "pkg2" ...
# Upgrade specified APT packages
# Returns: 0 on success, 1 on failure
```

### Binary Helpers

```bash
version_gt "v2.0.0" "v1.9.0"
# Compare semantic versions
# Returns: 0 if first > second, 1 otherwise

upgrade_github_binary "repo/name" "binary" "/path" ["--version-flag"]
# Download and install latest GitHub release
# Returns: 0 on success, 1 on failure
```

### Git Helpers

```bash
upgrade_git_repo "/path/to/repo" ["rebuild-cmd"]
# Pull latest changes and optionally rebuild
# Returns: 0 on success, 1 on failure
```

### Native Helpers

```bash
check_native_update "tool-name" ["--version"]
# Check version and notify about Docker rebuild requirement
# Returns: 2 (manual action required)
```

## Extension Manager Commands

Extensions implementing v2.0 can be upgraded via:

```bash
# Single extension
extension-manager upgrade nodejs

# All extensions
extension-manager upgrade-all

# Dry-run (preview)
extension-manager upgrade-all --dry-run

# Check for updates
extension-manager check-updates

# View history
extension-manager upgrade-history
extension-manager upgrade-history nodejs 20

# Rollback (basic)
extension-manager rollback nodejs
```

## Testing Requirements

All extensions must be testable:

### Unit Testing

```bash
# Test upgrade() function directly
./extension-name.extension upgrade

# Test with dry-run
DRY_RUN=true ./extension-name.extension upgrade
```

### Integration Testing

```bash
# Via extension-manager
extension-manager upgrade extension-name

# Validate after upgrade
extension-manager validate extension-name
```

### Expected Behavior

1. **Prerequisites check**: Verify dependencies before upgrading
2. **Version display**: Show current version before upgrade
3. **Progress feedback**: Provide status updates during upgrade
4. **Error handling**: Return appropriate exit codes
5. **Version verification**: Show new version after upgrade
6. **Idempotent**: Running multiple times should be safe

## Migration Checklist

To migrate an extension from v1.0 to v2.0:

1. **Add metadata** (after EXT_CATEGORY):
   ```bash
   EXT_INSTALL_METHOD="mise"
   EXT_UPGRADE_STRATEGY="automatic"
   ```

2. **Update version**:
   ```bash
   EXT_VERSION="2.0.0"
   ```

3. **Implement upgrade()** (after remove()):
   ```bash
   upgrade() {
       # Use appropriate helper based on EXT_INSTALL_METHOD
   }
   ```

4. **Test**:
   ```bash
   extension-manager upgrade extension-name
   extension-manager validate extension-name
   ```

## Backward Compatibility

Extensions without `upgrade()` function:
- Will not break existing functionality
- Cannot be upgraded via `extension-manager upgrade`
- Will be skipped by `extension-manager upgrade-all`
- Should be migrated to v2.0 when possible

## Error Handling

### Common Errors

**Extension not installed**:
```bash
if ! command_exists tool-name; then
    print_error "${EXT_NAME} is not installed"
    return 1
fi
```

**Prerequisite missing**:
```bash
if ! check_mise_prerequisite; then
    return 1
fi
```

**Upgrade failed**:
```bash
if ! upgrade_mise_tools "${EXT_NAME}"; then
    print_error "Upgrade failed"
    return 1
fi
```

## Best Practices

1. **Check installation first**: Verify tools are installed before upgrading
2. **Show versions**: Display before/after versions for user clarity
3. **Use helpers**: Leverage provided helper functions
4. **Handle dry-run**: Always respect DRY_RUN environment variable
5. **Provide feedback**: Use print_status, print_success, print_error consistently
6. **Return proper codes**: 0 for success, 1 for failure, 2 for manual action
7. **Track failures**: For mixed methods, continue even if one component fails
8. **Test thoroughly**: Verify upgrade works in both normal and dry-run modes

## Examples

Complete working examples can be found in:
- `docker/lib/extensions.d/template.extension` - Reference implementation
- `docker/lib/extensions.d/nodejs.extension` - mise pattern
- `docker/lib/extensions.d/docker.extension` - mixed pattern
- `docker/lib/extensions.d/mise-config.extension` - binary pattern

## See Also

- [Extension API v2.0 Migration Guide](EXTENSION_API_V2_MIGRATION_GUIDE.md)
- [Extension API v2.0 Implementation Plan](EXTENSION_API_V2_IMPLEMENTATION_PLAN.md)
- [Extensions Documentation](EXTENSIONS.md)
- [extensions-common.sh](../docker/lib/extensions-common.sh) - Helper functions

## Version History

- **2.0.0** (2025-01-30) - Initial release with upgrade() support
- **1.0.0** (2025-01-15) - Original API (prerequisites, install, configure, validate, status, remove)
