# Layered Docker Images - Architecture Guide

This guide explains Sindri's multi-layer base image architecture, design decisions, and best practices
for maintaining the build system.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Layer Definitions](#layer-definitions)
- [Build Flow](#build-flow)
- [Change Detection](#change-detection)
- [Performance Benefits](#performance-benefits)
- [Maintenance Guide](#maintenance-guide)
- [Troubleshooting](#troubleshooting)

## Overview

Sindri uses a **3-layer base image architecture** inspired by Fly.io's best practices for faster deployments.
This approach dramatically reduces build times by separating rarely-changing base layers from frequently-changing
application code.

### Design Goals

1. **Optimize for Common Changes**: 70% of changes are extension scripts - rebuild in ~15 seconds
2. **Minimize Waste**: Don't rebuild 550MB of base layers when only 1MB changed
3. **Maintain Simplicity**: Clear separation of concerns, easy to understand
4. **Cost Efficiency**: Reduce CI/CD costs by 78% (~$22/month savings)

### Key Principles

- **Immutability**: Lower layers never change when upper layers change
- **Caching**: Leverage Docker layer caching and registry pulls
- **Intelligence**: Automatically detect which layers need rebuilding
- **Backwards Compatibility**: Maintains same deployment model

## Architecture

```text
┌─────────────────────────────────────────────────────────────────────┐
│                          APPLICATION LAYER                          │
│                    (Dockerfile → pr-123 or latest)                  │
│                                                                     │
│  Contains: Extension definitions, helper scripts, configuration     │
│  Changes: Daily (70% of all changes)                                │
│  Build Time: ~10-15 seconds                                         │
│  Size: ~1MB (751MB total with base layers)                          │
│                                                                     │
│  Files:                                                             │
│  - docker/lib/extensions.d/*.extension                              │
│  - docker/lib/*.sh (helper scripts)                                 │
│  - docker/scripts/*.sh (application scripts)                        │
│  - docker/config/* (runtime configuration)                          │
└─────────────────────────────────────────────────────────────────────┘
                                 ↓ FROM
┌─────────────────────────────────────────────────────────────────────┐
│                          TOOLING LAYER                              │
│              (Dockerfile.tooling → tooling-stable)                  │
│                                                                     │
│  Contains: Development tools and environment setup                  │
│  Changes: Weekly/biweekly (20% of all changes)                      │
│  Build Time: ~2-3 minutes                                           │
│  Size: ~200MB (750MB total with base layer)                         │
│                                                                     │
│  Tools:                                                             │
│  - mise (tool version manager)                                      │
│  - Claude Code CLI                                                  │
│  - SOPS + age (secrets management)                                  │
│  - SSH environment configuration                                    │
│  - Developer user setup                                             │
└─────────────────────────────────────────────────────────────────────┘
                                 ↓ FROM
┌─────────────────────────────────────────────────────────────────────┐
│                          SYSTEM BASE LAYER                          │
│                  (Dockerfile.base → base-stable)                    │
│                                                                     │
│  Contains: Operating system and system packages                     │
│  Changes: Monthly or less (10% of all changes)                      │
│  Build Time: ~3-4 minutes                                           │
│  Size: ~550MB                                                       │
│                                                                     │
│  Packages:                                                          │
│  - Ubuntu 24.04                                                     │
│  - Build tools (build-essential, pkg-config)                        │
│  - System utilities (curl, git, jq, vim)                            │
│  - Database clients (postgresql-client, redis-tools)                │
│  - Development libraries (libssl-dev, zlib1g-dev)                   │
└─────────────────────────────────────────────────────────────────────┘
```

## Layer Definitions

### Layer 1: System Base (`Dockerfile.base`)

**Purpose**: Provide stable operating system foundation

**Contents**:

- Ubuntu 24.04 base image
- System package manager updates
- Core development tools and libraries
- Database and Redis clients
- Network utilities

**Build Triggers**:

- Ubuntu base image updates
- System package additions/removals
- Security patches

**Files**:

```text
Dockerfile.base
docker/lib/registry-retry.sh
docker/scripts/install-packages.sh
```

**Image Tags**:

- Versioned: `registry.fly.io/sindri-registry:base-<sha>`
- Stable: `registry.fly.io/sindri-registry:base-stable`

**Update Frequency**: Monthly or when security patches required

### Layer 2: Tooling Base (`Dockerfile.tooling`)

**Purpose**: Install development tools and environment

**Contents**:

- mise (unified tool version manager)
- Claude Code CLI
- SOPS + age (secrets management)
- SSH daemon configuration
- Developer user setup
- Workspace structure

**Build Triggers**:

- Tool version updates (mise, Claude, SOPS)
- SSH configuration changes
- User setup modifications

**Files**:

```text
Dockerfile.tooling
docker/config/sshd_config
docker/config/developer-sudoers
docker/scripts/setup-user.sh
docker/scripts/install-mise.sh
docker/scripts/setup-ssh-environment.sh
docker/scripts/install-claude.sh
docker/scripts/install-sops-age.sh
```

**Image Tags**:

- Versioned: `registry.fly.io/sindri-registry:tooling-<sha>`
- Stable: `registry.fly.io/sindri-registry:tooling-stable`

**Update Frequency**: Weekly/biweekly

### Layer 3: Application (`Dockerfile`)

**Purpose**: Package extension definitions and runtime scripts

**Contents**:

- Extension definitions (all 20+ extensions)
- Extension manager and helper scripts
- Runtime configuration files
- Bash environment setup
- MOTD and welcome messages

**Build Triggers**:

- Extension script changes
- Helper script updates
- Configuration file modifications
- Any `docker/` directory changes not in base/tooling

**Files**:

```text
Dockerfile
docker/lib/extensions.d/**/*.extension
docker/lib/*.sh
docker/scripts/*.sh
docker/config/*
```

**Image Tags**:

- PR builds: `registry.fly.io/sindri-registry:pr-<number>-<sha>`
- Branch builds: `registry.fly.io/sindri-registry:<branch>-<sha>`
- Latest: `registry.fly.io/sindri-registry:latest`

**Update Frequency**: Daily (most common changes)

## Build Flow

### Automatic Build Process

The build system uses intelligent change detection to minimize build time:

```text
1. Detect Changes (paths-filter)
   ├─ Check Dockerfile.base and system scripts
   ├─ Check Dockerfile.tooling and tool scripts
   └─ Check Dockerfile and application files

2. Decide Build Strategy
   ├─ If base changed: Rebuild base → tooling → application
   ├─ If tooling changed: Rebuild tooling → application
   └─ If application changed: Rebuild application only

3. Build Layers (conditional)
   ├─ Base Layer (if needed, ~3-4 min)
   ├─ Tooling Layer (if needed, ~2-3 min)
   └─ Application Layer (always, ~10-15 sec)

4. Tag and Push
   ├─ Tag base as base-stable
   ├─ Tag tooling as tooling-stable
   └─ Tag application with pr/branch/latest
```

### Build Scenarios

#### Scenario 1: Extension Script Change (70% of changes)

```bash
# Example: Update nodejs.extension script
touch docker/lib/extensions.d/nodejs/nodejs.extension

# Build flow:
# 1. Detect: application layer changed
# 2. Decide: Rebuild application only
# 3. Build: Pull tooling-stable → Build app (15 sec)
# 4. Result: 95% faster than full rebuild
```

#### Scenario 2: Tool Version Update (20% of changes)

```bash
# Example: Update mise version in install-mise.sh
vim docker/scripts/install-mise.sh

# Build flow:
# 1. Detect: tooling layer changed
# 2. Decide: Rebuild tooling + application
# 3. Build: Pull base-stable → Build tooling (2-3 min) → Build app (15 sec)
# 4. Result: 50% faster than full rebuild
```

#### Scenario 3: System Package Addition (10% of changes)

```bash
# Example: Add new system package
vim docker/scripts/install-packages.sh

# Build flow:
# 1. Detect: base layer changed
# 2. Decide: Rebuild all layers
# 3. Build: Base (3-4 min) → Tooling (2-3 min) → App (15 sec)
# 4. Result: Same as before, but rare
```

## Change Detection

### Path-Based Filters

The system uses `dorny/paths-filter@v3` to detect file changes:

```yaml
filters:
  base:
    - 'Dockerfile.base'
    - 'docker/lib/registry-retry.sh'
    - 'docker/scripts/install-packages.sh'

  tooling:
    - 'Dockerfile.tooling'
    - 'docker/config/sshd_config'
    - 'docker/config/developer-sudoers'
    - 'docker/scripts/setup-user.sh'
    - 'docker/scripts/install-mise.sh'
    - 'docker/scripts/setup-ssh-environment.sh'
    - 'docker/scripts/install-claude.sh'
    - 'docker/scripts/install-sops-age.sh'

  application:
    - 'Dockerfile'
    - 'docker/lib/**'
    - 'docker/scripts/**'
    - 'docker/config/**'
```

### Decision Logic

```bash
# Base layer changed → Rebuild base + tooling + application
if [ "$base_changed" == "true" ]; then
  build_base=true
  build_tooling=true  # Tooling depends on base

# Tooling layer changed → Rebuild tooling + application
elif [ "$tooling_changed" == "true" ]; then
  build_base=false
  build_tooling=true

# Application layer changed → Rebuild application only
else
  build_base=false
  build_tooling=false
fi
```

## Performance Benefits

### Build Time Comparison

| Change Type     | Monolithic | Layered | Improvement |
| --------------- | ---------- | ------- | ----------- |
| Extension (70%) | 5-6 min    | 15 sec  | **95%**     |
| Tooling (20%)   | 5-6 min    | 2-3 min | **50%**     |
| System (10%)    | 5-6 min    | 5-6 min | 0%          |

**Weighted Average**: 70% × 95% + 20% × 50% + 10% × 0% = **76.5% faster**

### CI Cost Savings

**Before (Monolithic)**:

```text
30 builds/week × 5.5 min = 165 min/week
Monthly: ~660 min (~$28 in CI costs)
```

**After (Layered)**:

```text
Extension changes: 21 builds × 15 sec = 5.25 min
Tooling changes: 6 builds × 2.5 min = 15 min
System changes: 3 builds × 5.5 min = 16.5 min
Total: 36.75 min/week
Monthly: ~147 min (~$6 in CI costs)
```

**Savings**: 128 min/week, ~$22/month (78% reduction)

### Developer Experience

**Faster PR Feedback**:

- Before: 6-7 min from commit to test results
- After: <2 min for extension changes
- Result: Less context switching, faster iteration

**Reduced Queue Time**:

- Shorter builds = less queue contention
- More parallel test capacity
- Predictable build times

## Maintenance Guide

### When to Update Each Layer

#### Base Layer Updates

**Triggers**:

- Ubuntu security patches
- New system package requirements
- Database client version updates
- Major tool dependency changes

**Procedure**:

```bash
# 1. Update install-packages.sh
vim docker/scripts/install-packages.sh

# 2. Build locally to test
docker build -f Dockerfile.base -t test-base .

# 3. Commit and push (automatic build)
git add docker/scripts/install-packages.sh Dockerfile.base
git commit -m "feat(base): add new system package"
git push

# 4. Verify build in GitHub Actions
gh run watch
```

**Frequency**: Monthly or as needed

#### Tooling Layer Updates

**Triggers**:

- mise version updates
- Claude CLI updates
- SOPS/age version updates
- SSH configuration changes

**Procedure**:

```bash
# 1. Update installation script
vim docker/scripts/install-mise.sh

# 2. Test locally
docker build -f Dockerfile.tooling \
  --build-arg BASE_IMAGE=registry.fly.io/sindri-registry:base-stable \
  -t test-tooling .

# 3. Commit and push
git commit -am "chore(tooling): update mise to latest"
git push
```

**Frequency**: Weekly/biweekly

#### Application Layer Updates

**Triggers**:

- Extension script changes
- Helper script updates
- Configuration file modifications
- New extension additions

**Procedure**:

```bash
# 1. Update extension
vim docker/lib/extensions.d/nodejs/nodejs.extension

# 2. Test locally
docker build \
  --build-arg TOOLING_IMAGE=registry.fly.io/sindri-registry:tooling-stable \
  -t test-app .

# 3. Commit and push (fast build ~15 sec)
git commit -am "feat(nodejs): update Node.js to LTS 22"
git push
```

**Frequency**: Daily

### Manual Base Image Builds

Sometimes you need to rebuild base layers manually:

```bash
# Build both base and tooling
gh workflow run build-base-images.yml \
  -f layer=both \
  -f version=v1.0.0

# Build only base layer
gh workflow run build-base-images.yml \
  -f layer=base \
  -f version=v1.1.0

# Build only tooling layer
gh workflow run build-base-images.yml \
  -f layer=tooling \
  -f version=v1.2.0
```

### Version Management

**Versioning Strategy**:

- Base: `base-<timestamp>` (auto) or `base-v1.0.0` (manual)
- Tooling: `tooling-<timestamp>` (auto) or `tooling-v1.0.0` (manual)
- Application: `pr-123-abc123` (PR) or `main-abc123` (branch)

**Stable Tags**:

- `base-stable` → Always points to latest base
- `tooling-stable` → Always points to latest tooling
- `latest` → Always points to latest application (main branch)

### Registry Cleanup

**Retention Policy**:

- Base versions: Keep indefinitely (rarely updated)
- Tooling versions: Keep last 3
- PR images: Delete after 7 days or when merged
- Branch images: Keep last 10

**Manual Cleanup**:

```bash
# List all images
flyctl registry list sindri-registry

# Delete old PR image
flyctl registry delete sindri-registry:pr-123-old

# Delete old tooling version
flyctl registry delete sindri-registry:tooling-20240101-120000
```

## Troubleshooting

### Base Image Not Found

**Problem**: `Error: base-stable not found`

**Solution**:

```bash
# Build initial base images
gh workflow run build-base-images.yml -f layer=both

# Or push to main branch (automatic build)
git push origin main
```

### Tooling Build Fails

**Problem**: Tooling layer fails to build

**Common Causes**:

1. Base image not available
2. Installation script errors
3. Network/download failures

**Debug**:

```bash
# Check base image exists
docker pull registry.fly.io/sindri-registry:base-stable

# Build locally to debug
docker build -f Dockerfile.tooling \
  --build-arg BASE_IMAGE=registry.fly.io/sindri-registry:base-stable \
  -t test-tooling . --progress=plain
```

### Application Build Uses Wrong Base

**Problem**: Application builds with old tooling version

**Solution**:

```bash
# Verify tooling-stable tag
docker pull registry.fly.io/sindri-registry:tooling-stable
docker inspect registry.fly.io/sindri-registry:tooling-stable

# Force rebuild tooling
gh workflow run build-base-images.yml -f layer=tooling
```

### Slow Build Despite Layering

**Problem**: Builds still taking 5-6 minutes

**Check**:

1. Is change detection working?

   ```bash
   # View workflow logs for "Decide what to build" step
   gh run view --log
   ```

2. Are base images being pulled?

   ```bash
   # Look for "Pulling base image" in logs
   gh run view --log | grep "Pulling"
   ```

3. Is Docker caching working?

   ```bash
   # Check if layers are reused
   gh run view --log | grep "CACHED"
   ```

### Change Detection Not Working

**Problem**: Application layer change triggers full rebuild

**Debug**:

```bash
# Check paths-filter output
gh run view --log | grep "paths-filter"

# Verify file paths match filter patterns
cat .github/workflows/build-image.yml | grep -A 10 "filters:"
```

**Fix**:

- Ensure `fetch-depth: 2` in checkout action
- Verify filter patterns are correct
- Check that paths-filter action is up to date

## Best Practices

### 1. Keep Base Layer Stable

- Avoid frequent base layer changes
- Batch system package updates
- Test thoroughly before pushing

### 2. Version Tool Updates Carefully

- Test tool updates in tooling layer first
- Document version changes in commits
- Maintain backwards compatibility

### 3. Optimize Application Layer

- Keep extension scripts small and focused
- Use helper functions for common code
- Minimize file copies in Dockerfile

### 4. Monitor Build Times

- Track build times in CI/CD metrics
- Identify slow builds and optimize
- Alert on unexpected build time increases

### 5. Document Changes

- Use semantic commit messages
- Document breaking changes
- Update CHANGELOG for layer updates

## References

- [Fly.io: Using Base Images for Faster Deployments](https://fly.io/docs/blueprints/using-base-images-for-faster-deployments/)
- [Fly.io: Using the Fly Docker Registry](https://fly.io/docs/blueprints/using-the-fly-docker-registry/)
- [Docker: Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Docker: Layer Caching](https://docs.docker.com/build/cache/)

## Support

For issues or questions:

1. Check [Troubleshooting](#troubleshooting) above
2. Review [PREBUILT_IMAGES_SETUP.md](./PREBUILT_IMAGES_SETUP.md)
3. Check workflow logs in GitHub Actions
4. File an issue at: `https://github.com/your-org/sindri/issues`
