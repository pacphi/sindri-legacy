# Extension API v2.0 - Migration Guide

This guide helps extension developers migrate from Extension API v1.0 to v2.0.

## Why Upgrade?

Extension API v2.0 adds standardized upgrade support:

- Consistent upgrade experience across all extensions
- Automated upgrade via `extension-manager upgrade-all`
- Dry-run capability for testing
- Upgrade history tracking
- Rollback support

## Migration Checklist

### Step 1: Add Metadata Fields

Add `EXT_INSTALL_METHOD` and `EXT_UPGRADE_STRATEGY` after `EXT_CATEGORY`:

```bash
EXT_CATEGORY="language"
EXT_INSTALL_METHOD="mise"          # Choose: mise, apt, binary, git, native, mixed, manual
EXT_UPGRADE_STRATEGY="automatic"   # Choose: automatic, manual, pinned, security-only
```

### Step 2: Implement upgrade() Function

Add `upgrade()` function after `remove()`:

```bash
# ============================================================================
# UPGRADE - Extension API v2.0
# ============================================================================

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    # Use appropriate helper based on installation method
    case "${EXT_INSTALL_METHOD}" in
        mise)
            upgrade_mise_tools "${EXT_NAME}"
            ;;
        apt)
            upgrade_apt_packages "package1" "package2"
            ;;
        binary)
            upgrade_github_binary "repo/name" "binary" "/path"
            ;;
        git)
            upgrade_git_repo "/path/to/repo" "rebuild-cmd"
            ;;
        native)
            check_native_update "tool-name" "--version"
            return $?
            ;;
        mixed)
            # Custom logic combining multiple methods
            ;;
    esac
}
```

### Step 3: Bump Version

Update to major version 2.0.0:

```bash
EXT_VERSION="2.0.0"  # Major bump for API v2.0
```

### Step 4: Test

```bash
# Install extension
extension-manager install myextension

# Test dry-run upgrade
extension-manager upgrade myextension --dry-run

# Test actual upgrade
extension-manager upgrade myextension

# Validate
extension-manager validate myextension
```

## Installation Method Examples

### mise-Managed Extensions

```bash
EXT_INSTALL_METHOD="mise"
EXT_UPGRADE_STRATEGY="automatic"

upgrade() {
    upgrade_mise_tools "${EXT_NAME}"
}
```

### APT Package Extensions

```bash
EXT_INSTALL_METHOD="apt"
EXT_UPGRADE_STRATEGY="automatic"

upgrade() {
    upgrade_apt_packages "pkg1" "pkg2" "pkg3"
}
```

### Mixed Method Extensions

```bash
EXT_INSTALL_METHOD="mixed"
EXT_UPGRADE_STRATEGY="automatic"

upgrade() {
    local upgrade_failed=0

    # APT packages
    if ! upgrade_apt_packages "pkg1" "pkg2"; then
        upgrade_failed=1
    fi

    # Binary downloads
    if ! upgrade_github_binary "repo/name" "binary" "/path"; then
        upgrade_failed=1
    fi

    [[ $upgrade_failed -eq 0 ]]
}
```

## Available Helper Functions

All helpers are in `extensions-common.sh`:

```bash
# Upgrade helpers
upgrade_mise_tools "extension-name"
upgrade_apt_packages "pkg1" "pkg2" ...
upgrade_github_binary "repo/name" "binary" "/path" ["--version"]
upgrade_git_repo "/path/to/repo" ["rebuild-cmd"]
check_native_update "tool-name" ["--version"]

# Utility helpers
is_dry_run              # Check if DRY_RUN=true
dry_run_prefix          # Get "[DRY-RUN] " prefix
supports_upgrade        # Check if upgrade() exists
version_gt "v1" "v2"    # Compare versions
```

## Testing Your Extension

```bash
# Unit test upgrade() function
./your-extension.extension upgrade

# Test via extension-manager
extension-manager upgrade your-extension

# Test dry-run mode
DRY_RUN=true extension-manager upgrade your-extension

# Validate after upgrade
extension-manager validate your-extension
```

## Common Patterns

See [Extension API v2.0 Specification](EXTENSION_API_V2.md) for detailed patterns and examples.

## Need Help?

- Read the specification: `docs/EXTENSION_API_V2.md`
- Review example extensions: `nodejs.extension`, `docker.extension`
- Check upgrade helpers: `docker/lib/extensions-common.sh`
