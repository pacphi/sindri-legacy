# Extension Versioning Strategy

This document describes the versioning strategy for Sindri extensions, designed to support both development and release workflows.

## Overview

Sindri uses **dual versioning** to separate API compatibility from extension features:

- **Extension Version** (`EXT_VERSION`): Semantic version of the extension itself
- **API Version** (`EXT_API_VERSION`): API compatibility level

This separation allows extensions to evolve independently while maintaining API compatibility.

## Version Fields

### EXT_VERSION

Format: `MAJOR.MINOR.PATCH[-prerelease]`

**Semantic Versioning (SemVer) Rules:**

- **MAJOR**: Incremented for breaking changes (incompatible API changes)
- **MINOR**: Incremented for new features (backward-compatible)
- **PATCH**: Incremented for bug fixes (backward-compatible)
- **prerelease** (optional): Pre-release identifier (alpha, beta, rc, dev)

**Examples:**
```bash
EXT_VERSION="2.0.0"         # Stable release
EXT_VERSION="2.1.0"         # New features added
EXT_VERSION="2.1.1"         # Bug fix
EXT_VERSION="2.2.0-beta"    # Beta release
EXT_VERSION="2.2.0-alpha.1" # Alpha release with iteration
EXT_VERSION="3.0.0-rc.1"    # Release candidate for major version
```

### EXT_API_VERSION

Format: `MAJOR.MINOR`

Defines the Extension API compatibility level. Extensions with the same API MAJOR version are compatible.

**Current API Version:** `2.0`

**Rules:**
- Extension MAJOR version must match API MAJOR version
- Extensions can have different MINOR/PATCH versions while using the same API
- API version changes when extension function signatures or behaviors change

**Examples:**
```bash
# All compatible with Extension API v2.0
EXT_VERSION="2.0.0"  EXT_API_VERSION="2.0"  ✓ Valid
EXT_VERSION="2.1.0"  EXT_API_VERSION="2.0"  ✓ Valid (new features)
EXT_VERSION="2.5.3"  EXT_API_VERSION="2.0"  ✓ Valid
EXT_VERSION="3.0.0"  EXT_API_VERSION="2.0"  ✗ Invalid (major mismatch)
EXT_VERSION="2.0.0"  EXT_API_VERSION="3.0"  ✗ Invalid (API breaking change)
```

## Development Workflow

### Feature Development

When adding new features to an extension:

```bash
# Before (stable release)
EXT_VERSION="2.1.0"
EXT_API_VERSION="2.0"

# During development (pre-release)
EXT_VERSION="2.2.0-alpha"
EXT_API_VERSION="2.0"

# Beta testing
EXT_VERSION="2.2.0-beta"
EXT_API_VERSION="2.0"

# Release candidate
EXT_VERSION="2.2.0-rc.1"
EXT_API_VERSION="2.0"

# Final release
EXT_VERSION="2.2.0"
EXT_API_VERSION="2.0"
```

### Bug Fixes

```bash
# Current release
EXT_VERSION="2.1.0"
EXT_API_VERSION="2.0"

# Bug fix (increment PATCH)
EXT_VERSION="2.1.1"
EXT_API_VERSION="2.0"
```

### Breaking Changes (New API)

When making breaking changes that require a new Extension API:

```bash
# Current API v2.0
EXT_VERSION="2.5.0"
EXT_API_VERSION="2.0"

# New API v3.0 (breaking changes)
EXT_VERSION="3.0.0"
EXT_API_VERSION="3.0"
```

## Release Workflow

### Stable Releases

Production-ready versions with no pre-release identifier:

```bash
EXT_VERSION="2.1.0"
EXT_API_VERSION="2.0"
```

### Pre-Release Versions

For testing and validation before stable release:

- **alpha**: Early development, unstable
- **beta**: Feature-complete, testing phase
- **rc**: Release candidate, final validation

```bash
EXT_VERSION="2.2.0-alpha.1"   # First alpha
EXT_VERSION="2.2.0-alpha.2"   # Second alpha
EXT_VERSION="2.2.0-beta.1"    # First beta
EXT_VERSION="2.2.0-rc.1"      # Release candidate
EXT_VERSION="2.2.0"           # Stable release
```

## CI/CD Validation

GitHub Actions workflows automatically validate:

1. **Metadata Presence**: All required fields exist
   - `EXT_VERSION`
   - `EXT_API_VERSION`
   - `EXT_INSTALL_METHOD`
   - `EXT_UPGRADE_STRATEGY`

2. **Version Format**: Valid semantic version
   - Pattern: `MAJOR.MINOR.PATCH[-prerelease]`
   - Pre-release: Optional alphanumeric with dots/hyphens

3. **API Compatibility**: Extension and API versions align
   - Extension MAJOR version must match API MAJOR version
   - Ensures no version drift between extension and API

## Examples

### Real-World Scenarios

#### Scenario 1: PHP Version Upgrade (8.3 → 8.4)

This is a **minor version** change because it adds new features (PHP 8.4) but maintains API compatibility:

```bash
# Before
EXT_VERSION="2.0.0"
EXT_API_VERSION="2.0"
EXT_DESCRIPTION="PHP 8.3 with Composer, Symfony CLI"

# After
EXT_VERSION="2.1.0"
EXT_API_VERSION="2.0"
EXT_DESCRIPTION="PHP 8.4.14 with Composer, Symfony CLI"
```

#### Scenario 2: Security Patch

Bug fix with no new features:

```bash
# Before
EXT_VERSION="2.1.0"
EXT_API_VERSION="2.0"

# After (security fix)
EXT_VERSION="2.1.1"
EXT_API_VERSION="2.0"
```

#### Scenario 3: Extension API v3.0 Development

Breaking changes requiring new API:

```bash
# Development
EXT_VERSION="3.0.0-alpha"
EXT_API_VERSION="3.0"

# Testing
EXT_VERSION="3.0.0-beta"
EXT_API_VERSION="3.0"

# Release
EXT_VERSION="3.0.0"
EXT_API_VERSION="3.0"
```

## Benefits

This dual-versioning approach provides:

1. **Clear API Compatibility**: Extensions declare API version explicitly
2. **Independent Evolution**: Extensions can evolve at different rates
3. **Pre-Release Support**: Alpha/beta/rc versions supported in CI/CD
4. **Breaking Change Visibility**: API version changes signal incompatibility
5. **Semantic Versioning**: Standard versioning practices for extensions
6. **Automated Validation**: CI ensures version consistency

## Migration Guide

For existing extensions without `EXT_API_VERSION`:

```bash
# Add after EXT_VERSION line
EXT_API_VERSION="2.0"
```

All extensions must include `EXT_API_VERSION` for CI validation to pass.

## References

- [Semantic Versioning 2.0.0](https://semver.org/)
- [Extension API Documentation](EXTENSIONS.md)
- [CI/CD Workflows](.github/workflows/test-extensions-metadata.yml)
