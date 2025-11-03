# GitHub Workflows

Comprehensive guide to Sindri's GitHub Actions workflows for automated testing, validation, and deployment.

## Table of Contents

- [Overview](#overview)
- [Quick Reference](#quick-reference)
- [Core Testing Workflows](#core-testing-workflows)
  - [Extension System Tests](#extension-system-tests)
  - [Integration Tests](#integration-tests)
- [Validation Workflows](#validation-workflows)
  - [Project Validation](#project-validation)
  - [Lint Documentation](#lint-documentation)
- [Build & Release Workflows](#build--release-workflows)
  - [Build and Push Docker Image](#build-and-push-docker-image)
  - [Release Automation](#release-automation)
- [Utility Workflows](#utility-workflows)
  - [Self-Service Deploy](#self-service-deploy)
  - [Report Results](#report-results)
- [Reusable Components](#reusable-components)
  - [Composite Actions](#composite-actions)
  - [Test Scripts](#test-scripts)
- [CI/CD Best Practices](#cicd-best-practices)
  - [Pre-Built Images](#pre-built-images)
  - [Workflow Triggers](#workflow-triggers)
  - [Manual Workflow Dispatch](#manual-workflow-dispatch)
  - [Debugging Failed Workflows](#debugging-failed-workflows)
- [Workflow Status Badges](#workflow-status-badges)
- [Related Documentation](#related-documentation)

## Overview

Sindri uses GitHub Actions for continuous integration and deployment with a focus on:

- **Modular Testing**: Separate workflows for different test categories
- **Performance Optimization**: Pre-built Docker images reduce CI time by ~75%
- **Reusable Components**: Composite actions and test scripts for maintainability
- **Comprehensive Coverage**: Extension system, integration tests, and validation

## Quick Reference

| Workflow | Purpose | Trigger | Duration |
|----------|---------|---------|----------|
| [Extension Tests](#extension-system-tests) | Test extension system and individual extensions | Push, PR to main/develop | ~12 min |
| [Integration Tests](#integration-tests) | End-to-end VM deployment and workflow validation | Push, PR, manual | ~4 min |
| [Project Validation](#project-validation) | Validate project structure and configuration | Push, PR | ~2 min |
| [Build Docker Image](#build-and-push-docker-image) | Build and cache Docker images | Dockerfile changes, manual | ~5 min |
| [Release Automation](#release-automation) | Automated releases and changelogs | Version tags | ~3 min |
| [Lint Documentation](#lint-documentation) | Markdown linting | Markdown changes | ~1 min |
| [Self-Service Deploy](#self-service-deploy) | Manual VM deployment from GitHub | Manual only | ~10 min |

## Core Testing Workflows

### Extension System Tests

**File**: `.github/workflows/extension-tests.yml`

Tests the complete extension system including Extension API v1.0 and v2.0.

**Triggers**:

- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Changes to extension system files, workflows, or test scripts

**What It Tests**:

- **Extension API Compliance**: Validates all extensions implement required functions
- **Individual Extensions**: Tests each extension in parallel (40+ extensions)
- **Upgrade Functionality**: Tests Extension API v2.0 upgrade operations
- **Idempotency**: Ensures extensions can be safely reinstalled
- **Protected Extensions**: Validates core extensions cannot be removed
- **Manifest Operations**: Tests extension ordering and activation
- **Dependency Chains**: Validates extension dependency resolution
- **Extension Combinations**: Tests common extension combinations

**Called Workflows**:

- `api-compliance.yml` - Extension API validation
- `per-extension.yml` - Individual extension testing
- `test-extensions-upgrade-vm.yml` - Upgrade functionality
- `protected-extensions-tests.yml` - Protected extension validation
- `manifest-operations-tests.yml` - Manifest operations
- `dependency-chain-tests.yml` - Dependency validation
- `extension-combinations.yml` - Combination testing
- `test-extensions-metadata.yml` - Metadata validation

**Performance**:

- Without pre-built images: ~45 minutes
- With pre-built images: ~12 minutes (**73% faster**)

**View Results**: [Extension Tests Badge](https://github.com/pacphi/sindri/actions/workflows/extension-tests.yml)

### Integration Tests

**File**: `.github/workflows/integration.yml`

End-to-end testing of VM deployment, developer workflows, and mise-powered stack integration.

**Triggers**:

- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual workflow dispatch
- Changes to deployment configuration, extension system, or integration scripts

**What It Tests**:

- **VM Deployment**: Full deployment lifecycle
- **Developer Workflow**: New project creation, Claude Flow setup, dependency installation
- **mise Stack Integration**: Validates mise-powered extensions (Node.js, Python, Rust, Go)
- **SSH Access**: Connection and authentication
- **Volume Persistence**: Data survival across VM restarts
- **Extension Installation**: Interactive and automated installation

**Called Workflows**:

- `integration-test.yml` - Basic deployment test
- `developer-workflow.yml` - Developer workflow validation
- `mise-stack-integration.yml` - mise integration testing

**Performance**:

- Without pre-built images: ~15 minutes
- With pre-built images: ~4 minutes (**73% faster**)

**View Results**: [Integration Tests Badge](https://github.com/pacphi/sindri/actions/workflows/integration.yml)

## Validation Workflows

### Project Validation

**File**: `.github/workflows/validate.yml`

Validates project structure, configuration files, and setup scripts.

**Triggers**:

- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`

**What It Validates**:

- **Required Files**: Checks for essential project files (Dockerfile, fly.toml, scripts)
- **fly.toml Syntax**: Validates Fly.io configuration
- **Extension Manager**: Tests help output and basic functionality
- **Shell Scripts**: Validates bash scripts with shellcheck
- **YAML Files**: Syntax validation for workflow files

**Called Workflows**:

- `syntax-validation.yml` - Shell and YAML validation
- `manager-validation.yml` - Extension manager validation

**Performance**: ~2 minutes

### Lint Documentation

**File**: `.github/workflows/test-documentation.yml`

Validates markdown documentation for formatting and style consistency.

**Triggers**:

- Push to `main` with markdown changes
- Pull requests with markdown file changes
- Called by other workflows

**What It Validates**:

- Markdown formatting (via markdownlint)
- Documentation style consistency
- Link validity
- Code block formatting

**Performance**: ~1 minute

## Build & Release Workflows

### Build and Push Docker Image

**File**: `.github/workflows/build-image.yml`

Builds Docker images and pushes them to Fly.io registry for reuse in CI/CD.

**Triggers**:

- Push to `main` or `develop` with Dockerfile/docker/* changes
- Pull requests with Dockerfile/docker/* changes
- Manual workflow dispatch with custom tag options

**What It Does**:

- Builds Docker image with buildx
- Pushes to Fly.io registry (`registry.fly.io/sindri-registry`)
- Generates appropriate tags:
  - PR builds: `pr-<number>-<sha>`
  - Branch builds: `<branch>-<sha>`
  - Manual: custom tag + optional `latest`

**Performance Impact**:

This workflow enables **~75% reduction** in CI/CD execution time by:

- Building images once instead of per-test-job
- Reusing cached images across all test workflows
- Automatic rebuilding when Docker files change

**Manual Usage**:

```bash
# Trigger with custom tag
gh workflow run build-image.yml -f tag=v1.2.3 -f push_latest=true
```

**See Also**: [Pre-Built Images Setup](PREBUILT_IMAGES_SETUP.md)

### Release Automation

**File**: `.github/workflows/release.yml`

Automated release creation with changelog generation.

**Triggers**:

- Push of version tags (e.g., `v1.0.0`, `v1.0.0-alpha.1`)

**What It Does**:

1. **Validates Tag**: Checks semantic version format
2. **Verifies Changelog**: Ensures version documented in CHANGELOG.md
3. **Generates Release Notes**: Extracts from CHANGELOG.md
4. **Creates GitHub Release**: Publishes release with notes
5. **Notifies**: Marks as prerelease for alpha/beta/rc versions

**Tag Format**:

- Stable: `v1.0.0`, `v2.1.3`
- Prerelease: `v1.0.0-alpha.1`, `v1.0.0-beta.2`, `v1.0.0-rc.1`

**Manual Release**:

```bash
# Update CHANGELOG.md first
git tag v1.2.3
git push origin v1.2.3
```

**See Also**: [Release Process](RELEASE.md)

## Utility Workflows

### Self-Service Deploy

**File**: `.github/workflows/self-service-deploy.yml`

Allows manual VM deployment directly from GitHub Actions interface.

**Triggers**:

- Manual workflow dispatch only

**Configuration Options**:

- **App Name**: Your Sindri VM name (required)
- **Region**: Fly.io region (default: sjc)
  - Options: sjc, iad, lhr, ams, fra, syd, nrt, gru
- **VM Preset**: Resource allocation (default: medium)
  - `small`: 2GB RAM, 1 shared CPU
  - `medium`: 8GB RAM, 4 shared CPUs
  - `large`: 16GB RAM, 4 performance CPUs
  - `xlarge`: 32GB RAM, 8 performance CPUs
- **Volume Size**: Persistent storage in GB (default: 30)
- **Extension Profile**: Pre-configured extension set (default: minimal)
  - `minimal`: Core extensions only
  - `developer`: Node.js, Python, Docker
  - `full-stack`: All development tools
  - `custom`: Use repository configuration

**Usage**:

1. Navigate to Actions tab in GitHub
2. Select "Self-Service Deploy" workflow
3. Click "Run workflow"
4. Fill in configuration
5. Click "Run workflow" button

**Requirements**:

- `FLYIO_AUTH_TOKEN` secret configured in repository settings
- Fly.io account with available resources

**Performance**: ~10 minutes (full deployment)

### Report Results

**File**: `.github/workflows/report-results.yml`

Collects and reports test results from all workflows.

**Triggers**:

- Called by other workflows
- Manual workflow dispatch

**What It Does**:

- Aggregates test results
- Generates test report summaries
- Posts status to PR comments
- Uploads test artifacts

## Reusable Components

### Composite Actions

Located in `.github/actions/`, these provide reusable workflow steps:

- **setup-fly-test-env**: Complete test environment setup
- **deploy-fly-app**: Fly.io deployment with retry logic and pre-built image support
- **build-push-image**: Build and push Docker images
- **wait-fly-deployment**: Wait for deployment completion
- **cleanup-fly-app**: Resource cleanup

**Documentation**: [Composite Actions README](.github/actions/README.md)

### Test Scripts

Located in `.github/scripts/extension-tests/`, these provide reusable test utilities:

- **verify-commands.sh**: Verify command availability
- **test-key-functionality.sh**: Test primary tool functionality
- **test-api-compliance.sh**: Validate Extension API compliance
- **test-idempotency.sh**: Test idempotent installation
- **lib/test-helpers.sh**: Shared utility functions (20+)
- **lib/assertions.sh**: Test assertion library (10+)

**Documentation**: [Test Scripts README](.github/scripts/extension-tests/README.md)

## CI/CD Best Practices

### Pre-Built Images

For optimal performance, workflows use pre-built Docker images:

**Setup** (one-time):

```bash
flyctl apps create sindri-registry --org personal
```

**How It Works**:

1. `build-image.yml` detects Dockerfile changes
2. Builds image once and pushes to registry
3. Other workflows reuse the cached image
4. Automatic rebuilding when Docker files change

**Performance Gains**:

- Extension Tests: 45min → 12min (**73% faster**)
- Integration Tests: 15min → 4min (**73% faster**)
- Per-Extension Tests: 6min → 1.5min (**75% faster**)

**See**: [Pre-Built Images Setup](PREBUILT_IMAGES_SETUP.md)

### Workflow Triggers

Workflows are designed to run only when relevant:

```yaml
on:
  push:
    branches: [main, develop]
    paths:
      - "docker/**"           # Only run on Docker changes
      - ".github/workflows/**" # Or workflow changes
```

This prevents unnecessary CI runs and reduces costs.

### Manual Workflow Dispatch

Many workflows support manual triggering for debugging:

```bash
# Trigger integration tests manually
gh workflow run integration.yml

# Trigger with specific inputs
gh workflow run self-service-deploy.yml \
  -f app_name=test-vm \
  -f region=sjc \
  -f vm_preset=small
```

### Debugging Failed Workflows

**View Logs**:

```bash
# List recent workflow runs
gh run list --workflow=extension-tests.yml

# View specific run
gh run view <run-id>

# Download logs
gh run download <run-id>
```

**Common Issues**:

1. **Fly.io API Rate Limits**:
   - Retry logic built into deploy-fly-app action
   - Automatic backoff and retry

2. **Docker Build Timeouts**:
   - Use pre-built images
   - Check Dockerfile caching

3. **Extension Test Failures**:
   - Check `.github/scripts/extension-tests/` for test logic
   - Review extension implementation
   - Verify Extension API compliance

4. **SSH Connection Timeouts**:
   - Normal in CI mode (custom SSH disabled)
   - Use Fly.io hallpass service instead
   - Add retry logic for post-restart commands

## Workflow Status Badges

Add workflow status badges to your README:

```markdown
![Integration Tests](https://github.com/pacphi/sindri/actions/workflows/integration.yml/badge.svg)
![Extension Tests](https://github.com/pacphi/sindri/actions/workflows/extension-tests.yml/badge.svg)
```

## Related Documentation

- [Pre-Built Images Setup](PREBUILT_IMAGES_SETUP.md) - Docker image caching setup
- [Composite Actions](.github/actions/README.md) - Reusable workflow components
- [Test Scripts](.github/scripts/extension-tests/README.md) - Test utilities
- [Extension Testing](EXTENSION_TESTING.md) - Extension testing system
- [Release Process](RELEASE.md) - Release workflow guide
- [Contributing](CONTRIBUTING.md) - Contribution guidelines
