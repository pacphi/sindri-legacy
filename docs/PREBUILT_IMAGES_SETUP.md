# Pre-Built Docker Images - Setup Guide

This guide walks through setting up the pre-built Docker images feature for Sindri CI/CD workflows.

## Overview

Pre-built Docker images dramatically improve CI/CD performance by:

- **Reducing workflow time by ~75%**: Build once, deploy many times
- **Saving CI minutes**: Reuse images when Docker files haven't changed
- **Improving reliability**: Consistent images across all test jobs

## Prerequisites

Before using pre-built images, you need:

1. **Fly.io CLI** installed and authenticated
2. **Fly.io Auth Token** in GitHub secrets as `FLYIO_AUTH_TOKEN`
3. **Registry app** created (one-time setup - see below)

## First-Time Setup

### Step 1: Create Fly Registry App

The registry app provides a namespace for storing Docker images. This is a **one-time setup**.

```bash
# Create the registry app (does not need to run, just needs to exist)
flyctl apps create sindri-registry --org personal

# Verify it was created
flyctl apps list | grep sindri-registry
```

**Output:**

```text
sindri-registry                 personal        pending
```

That's it! The registry app doesn't need to be deployed or running - it's just a namespace.

### Step 2: Verify GitHub Secrets

Ensure your repository has the required secret:

```bash
# Check in GitHub repo settings under:
# Settings → Secrets and variables → Actions → Repository secrets
```

Required secret:

- `FLYIO_AUTH_TOKEN` - Your Fly.io API token

### Step 3: Test the Setup

Trigger the build workflow manually to verify everything works:

```bash
# Via GitHub UI: Actions → "Build and Push Docker Image" → "Run workflow"
# Or via GitHub CLI:
gh workflow run build-image.yml
```

Check the workflow run to confirm the image builds and pushes successfully.

## How It Works

### Layered Build Architecture

Sindri uses a **3-layer base image strategy** to optimize build times:

```text
Layer 1: SYSTEM BASE (base-stable)
├─ Ubuntu 24.04 + system packages
├─ Changes rarely (monthly)
└─ Build time: ~3-4 minutes

Layer 2: TOOLING BASE (tooling-stable)
├─ mise, Claude CLI, SOPS + age, SSH config
├─ Changes occasionally (weekly/biweekly)
└─ Build time: ~2-3 minutes

Layer 3: APPLICATION (pr-123 or latest)
├─ Extension definitions, helper scripts
├─ Changes frequently (daily)
└─ Build time: ~10-15 seconds
```

### Automatic Build Triggers

The system intelligently detects changes and rebuilds only necessary layers:

1. **Base Layer Changes** (Dockerfile.base, install-packages.sh):
   - Rebuild base → tooling → application
   - Total time: ~5-6 minutes

2. **Tooling Layer Changes** (Dockerfile.tooling, mise/Claude/SOPS scripts):
   - Reuse base, rebuild tooling → application
   - Total time: ~2-3 minutes

3. **Application Layer Changes** (Dockerfile, extensions, scripts):
   - Reuse base + tooling, rebuild application only
   - Total time: ~10-15 seconds (**95% faster**)

4. **Pull Requests**: Builds PR-specific application images
5. **Main Branch Pushes**: Builds and tags as `latest`

### Image Reuse Logic

Workflows intelligently reuse layers:

```yaml
# Integration workflow detects changes automatically
- If base/tooling files changed → Build affected layers
- If only application files changed → Rebuild app layer only (~15s)
- Base and tooling layers are cached and reused
```

This happens automatically - no manual intervention needed.

### Image Naming Convention

Images are tagged by layer and context:

**Base Layer:**

- Versioned: `registry.fly.io/sindri-registry:base-<sha>`
- Stable: `registry.fly.io/sindri-registry:base-stable`

**Tooling Layer:**

- Versioned: `registry.fly.io/sindri-registry:tooling-<sha>`
- Stable: `registry.fly.io/sindri-registry:tooling-stable`

**Application Layer:**

- **PR builds**: `registry.fly.io/sindri-registry:pr-<number>-<sha>`
- **Branch builds**: `registry.fly.io/sindri-registry:<branch>-<sha>`
- **Latest (main)**: `registry.fly.io/sindri-registry:latest`

## Troubleshooting

### Error: "registry app not found"

**Problem**: The `sindri-registry` app doesn't exist.

**Solution**:

```bash
flyctl apps create sindri-registry --org personal
```

### Error: "failed to push image"

**Problem**: Authentication or network issues.

**Solution**:

1. Verify `FLYIO_AUTH_TOKEN` is set correctly
2. Check token hasn't expired: `flyctl auth whoami`
3. Regenerate token if needed: `flyctl tokens create deploy`

### Workflow using old image

**Problem**: Changes to Dockerfile aren't reflected.

**Solution**:

1. Check if Dockerfile changes were committed
2. Workflow only detects committed changes
3. Manually trigger build: `gh workflow run build-image.yml`

### Image size too large

**Problem**: Docker images are slow to pull/push.

**Solution**:

1. See [Layered Images Guide](./LAYERED_IMAGES_GUIDE.md) for optimization strategies
2. Review layer separation (base/tooling/application)
3. Minimize files copied in each layer
4. Use `.dockerignore` to exclude unnecessary files

## Manual Operations

### Build Base Images Manually

When base system tools need updating (e.g., Ubuntu packages, mise version):

```bash
# Build both base and tooling layers
gh workflow run build-base-images.yml -f layer=both

# Build only base layer
gh workflow run build-base-images.yml -f layer=base

# Build only tooling layer
gh workflow run build-base-images.yml -f layer=tooling

# With custom version tag
gh workflow run build-base-images.yml -f layer=both -f version=v1.0.0
```

### Build Application Image Manually

```bash
# Trigger via GitHub CLI (uses existing base layers)
gh workflow run build-image.yml

# With custom tag
gh workflow run build-image.yml -f tag=custom-v1

# Tag as latest
gh workflow run build-image.yml -f push_latest=true
```

### List Available Images

```bash
# Via Fly.io CLI (requires registry access)
flyctl registry list sindri-registry
```

### Pull Image Locally

```bash
# Authenticate Docker with Fly registry
flyctl auth docker

# Pull image
docker pull registry.fly.io/sindri-registry:latest
```

### Delete Old Images

See the [Cleanup Workflow](../.github/workflows/cleanup-registry.yml) for automated cleanup, or manually:

```bash
# Delete specific tag (requires Fly CLI with registry access)
flyctl registry delete sindri-registry:<tag>
```

## Performance Metrics

Expected improvements with layered base images:

### Build Time by Change Type

| Change Type            | Before | After (Layered) | Improvement     |
| ---------------------- | ------ | --------------- | --------------- |
| Extension scripts only | 5-6min | 10-15 sec       | **95%** faster  |
| Tooling updates        | 5-6min | 2-3 min         | **50%** faster  |
| System packages        | 5-6min | 5-6 min         | Same (rare)     |

### Workflow Execution Time

| Workflow             | Before | After   | Improvement    |
| -------------------- | ------ | ------- | -------------- |
| Integration Tests    | ~15min | ~4min   | **73%** faster |
| Extension Tests      | ~45min | ~12min  | **73%** faster |
| Per-Extension (each) | ~6min  | ~1.5min | **75%** faster |

### CI Cost Savings

- **Weekly builds**: 30 builds/week × 5.5 min = 165 min/week
- **With layered images**: ~37 min/week (70% extension changes, 20% tooling, 10% system)
- **Savings**: ~128 min/week (**78% reduction**)
- **Monthly cost reduction**: ~$22/month

**Most common scenario (extension changes)**: 70% of changes rebuild in ~15 seconds instead of 5-6 minutes

## Advanced Usage

### Custom Registry

To use a different registry:

1. Update registry app name in workflows:

   ```yaml
   registry-app: "your-registry-name"
   ```

2. Update `build-push-image` action calls:

   ```yaml
   uses: ./.github/actions/build-push-image
   with:
     registry-app: "your-registry-name"
   ```

### Skip Pre-built Images

To force building from source (for debugging):

```yaml
# In workflow dispatch, leave pre_built_image empty
# Or set environment variable
pre_built_image: ""
```

## Security Considerations

- **Private Registry**: Images are stored in your Fly.io org registry (private)
- **Token Security**: GitHub secrets are encrypted and only accessible to workflows
- **Image Scanning**: Consider adding vulnerability scanning to build workflow
- **Access Control**: Only authorized team members can access Fly registry

## Next Steps

- Read [Layered Images Guide](./LAYERED_IMAGES_GUIDE.md) for detailed architecture and best practices
- Review [GitHub Workflows Guide](./GITHUB_WORKFLOWS.md) for CI/CD integration details
- Check [Cleanup Registry Workflow](../.github/workflows/cleanup-registry.yml) for managing old images

## Support

For issues or questions:

1. Check [Troubleshooting](#troubleshooting) above
2. Review workflow logs in GitHub Actions
3. File an issue at: `https://github.com/your-org/sindri/issues`
