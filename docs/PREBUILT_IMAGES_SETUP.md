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
```
sindri-registry  personal  (no deployment)
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

### Automatic Build Triggers

The system automatically builds Docker images when:

1. **Dockerfile Changes**: Any modification to `Dockerfile` or `docker/*`
2. **Pull Requests**: Builds PR-specific images (e.g., `pr-123-a1b2c3d`)
3. **Main Branch Pushes**: Builds and tags as `latest`

### Image Reuse Logic

Workflows intelligently reuse images:

```yaml
# Integration workflow checks for changes
- If Dockerfile/docker/* changed → Build new image
- If no changes → Reuse latest image
```

This happens automatically - no manual intervention needed.

### Image Naming Convention

Images are tagged based on context:

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
1. See [Image Optimization Guide](./IMAGE_OPTIMIZATION.md)
2. Use multi-stage builds
3. Minimize installed packages
4. Use `.dockerignore`

## Manual Operations

### Build Image Manually

```bash
# Trigger via GitHub CLI
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

See the [Cleanup Workflow](./.github/workflows/cleanup-images.yml) for automated cleanup, or manually:

```bash
# Delete specific tag (requires Fly CLI with registry access)
flyctl registry delete sindri-registry:<tag>
```

## Performance Metrics

Expected improvements after enabling pre-built images:

| Workflow | Before | After | Improvement |
|----------|--------|-------|-------------|
| Integration Tests | ~15min | ~4min | **73%** faster |
| Extension Tests | ~45min | ~12min | **73%** faster |
| Per-Extension (each) | ~6min | ~1.5min | **75%** faster |

**CI Minutes Savings**: ~70-80% reduction in total CI minutes

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

- Read [Docker Images Guide](./DOCKER_IMAGES.md) for detailed architecture
- See [Migration Guide](./MIGRATION_PREBUILT_IMAGES.md) for updating custom workflows
- Check [Cleanup Strategy](./IMAGE_CLEANUP.md) for managing old images

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) above
2. Review workflow logs in GitHub Actions
3. File an issue at: `https://github.com/your-org/sindri/issues`
