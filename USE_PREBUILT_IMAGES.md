# Use Pre-Built Docker Images - Implementation Plan

## Executive Summary

This document outlines a comprehensive plan to implement pre-built Docker images in Sindri's CI/CD workflows using Fly.io's Docker registry. This optimization will reduce CI execution time by 40-60% by building the base Docker image once and reusing it across multiple deployments, rather than rebuilding from scratch for each test environment.

**Key Benefits:**

- **Time Savings**: 40-60% reduction in workflow execution time
- **Cost Reduction**: Lower Fly.io build resource usage
- **Reliability**: Pre-validated images reduce deployment failures
- **Consistency**: Identical base images across all test environments
- **Developer Experience**: Faster feedback loops on PRs

**Current State:**

- 30+ parallel extension tests, each rebuilding the Docker image (3-5 minutes each)
- Integration tests rebuild 3+ times per run
- API compliance tests rebuild 6 times per matrix
- Total waste: ~150+ redundant builds per full CI run

**Target State:**

- Build once per workflow run (~5 minutes)
- Deploy from pre-built image (~30-60 seconds per deployment)
- Total time: 10-15 minutes vs 25-40 minutes currently

## Table of Contents

- [Background](#background)
- [Architecture](#architecture)
- [Phase 1: Foundation](#phase-1-foundation)
- [Phase 2: Proof of Concept](#phase-2-proof-of-concept)
- [Phase 3: Single Workflow Migration](#phase-3-single-workflow-migration)
- [Phase 4: Core Workflows Migration](#phase-4-core-workflows-migration)
- [Phase 5: Full Rollout](#phase-5-full-rollout)
- [Phase 6: Optimization](#phase-6-optimization)
- [Testing Strategy](#testing-strategy)
- [Rollback Plan](#rollback-plan)
- [Monitoring and Metrics](#monitoring-and-metrics)
- [Risk Analysis](#risk-analysis)
- [Timeline and Effort](#timeline-and-effort)
- [Success Criteria](#success-criteria)

## Background

### Current Architecture

Sindri's CI/CD workflows currently use `flyctl deploy` to build and deploy test environments:

```yaml
# Current approach
- name: Deploy app
  run: flyctl deploy --app $app_name --strategy immediate
```

This command:

1. Reads the `Dockerfile`
2. Builds the image from scratch (Ubuntu 24.04 base)
3. Installs system packages
4. Copies scripts and configurations
5. Pushes to Fly.io's build service
6. Deploys to VM

**Time per deployment: 3-5 minutes**

### Fly.io Docker Registry

According to [Fly.io documentation](https://til.simonwillison.net/fly/fly-docker-registry), Fly.io provides a Docker registry at `registry.fly.io`:

```bash
# Build once
docker build -t registry.fly.io/app-name:tag .

# Authenticate
flyctl auth docker

# Push to registry
docker push registry.fly.io/app-name:tag

# Deploy without building
flyctl deploy --app app-name --image registry.fly.io/app-name:tag
```

**Time per deployment: 30-60 seconds**

### Workflows That Deploy VMs

| Workflow | Deployments | Current Time | Target Time | Savings |
|----------|-------------|--------------|-------------|---------|
| `per-extension.yml` | 30+ parallel | 25-30 min | 10-12 min | ~60% |
| `integration.yml` | 3 sequential | 15 min | 8 min | ~45% |
| `api-compliance.yml` | 6 parallel | 10 min | 5-6 min | ~45% |
| `extension-combinations.yml` | 7 parallel | 40 min | 15 min | ~65% |
| `protected-extensions-tests.yml` | 1 deployment | 5 min | 2 min | ~60% |
| `cleanup-extensions-tests.yml` | 1 deployment | 5 min | 2 min | ~60% |
| `manifest-operations-tests.yml` | 1 deployment | 5 min | 2 min | ~60% |
| `dependency-chain-tests.yml` | 1 deployment | 5 min | 2 min | ~60% |
| `test-extensions-metadata.yml` | 1 deployment | 5 min | 2 min | ~60% |
| `test-extensions-upgrade-vm.yml` | 1 deployment | 5 min | 2 min | ~60% |
| `developer-workflow.yml` | 1 deployment | 5 min | 2 min | ~60% |
| `mise-stack-integration.yml` | 1 deployment | 5 min | 2 min | ~60% |

**Total CI time reduction: 40-60% across all workflows**

## Architecture

### Image Tagging Strategy

```
registry.fly.io/sindri-registry:{tag}
```

**Tag formats:**

- **PR builds**: `pr-<number>-<sha>` (e.g., `pr-123-a1b2c3d`)
- **Branch builds**: `<branch>-<sha>` (e.g., `develop-a1b2c3d`, `main-a1b2c3d`)
- **Main branch**: `main-<sha>` + `latest` (dual-tagged)
- **Releases**: `v<version>` (e.g., `v1.0.0`)
- **Manual**: `manual-<timestamp>` (for workflow_dispatch)

### Cache Invalidation

Rebuild images when these paths change:

```yaml
paths:
  - 'Dockerfile'
  - 'docker/**'
```

Skip rebuild and reuse latest image when only these change:

```yaml
paths:
  - '.github/**'
  - 'scripts/**'
  - 'docs/**'
  - '**.md'
```

### Registry App Setup

Use a dedicated Fly.io app for the registry:

```bash
flyctl apps create sindri-registry --org personal
```

This app doesn't need to run; it only serves as a registry namespace.

### Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Actions                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────┐            │
│  │  build-image.yml (orchestrator)            │            │
│  │  - Triggers on Dockerfile changes          │            │
│  │  - Outputs: image-url, image-tag           │            │
│  └─────────────────┬──────────────────────────┘            │
│                    │                                         │
│                    ▼                                         │
│  ┌────────────────────────────────────────────┐            │
│  │  build-push-image (composite action)       │            │
│  │  - Builds Docker image                     │            │
│  │  - Authenticates with Fly registry         │            │
│  │  - Pushes to registry.fly.io               │            │
│  └─────────────────┬──────────────────────────┘            │
│                    │                                         │
│                    │ Outputs image URL                      │
│                    ▼                                         │
│  ┌────────────────────────────────────────────┐            │
│  │  extension-tests.yml (orchestrator)        │            │
│  │  - Needs: build-image                      │            │
│  │  - Passes image-url to child workflows     │            │
│  └─────────────────┬──────────────────────────┘            │
│                    │                                         │
│                    │ Passes pre_built_image                 │
│                    ▼                                         │
│  ┌────────────────────────────────────────────┐            │
│  │  per-extension.yml (workflow_call)         │            │
│  │  - Input: pre_built_image (optional)       │            │
│  │  - Passes to deploy-fly-app action         │            │
│  └─────────────────┬──────────────────────────┘            │
│                    │                                         │
│                    │ Uses pre-built image                   │
│                    ▼                                         │
│  ┌────────────────────────────────────────────┐            │
│  │  deploy-fly-app (composite action)         │            │
│  │  - Input: pre-built-image (optional)       │            │
│  │  - If provided: flyctl deploy --image      │            │
│  │  - Else: flyctl deploy (build from source) │            │
│  └────────────────────────────────────────────┘            │
│                                                              │
└──────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                    Fly.io Registry                            │
│                 registry.fly.io/sindri-registry               │
│                                                               │
│  Images:                                                      │
│  - main-a1b2c3d (latest)                                     │
│  - develop-x7y8z9                                            │
│  - pr-123-k4l5m6                                             │
│  - v1.0.0                                                    │
└───────────────────────────────────────────────────────────────┘
```

### Data Flow

```
1. Developer pushes code
   ↓
2. build-image.yml triggered (if Dockerfile/docker/* changed)
   ↓
3. Build image with tag (e.g., pr-123-a1b2c3d)
   ↓
4. Push to registry.fly.io/sindri-registry:pr-123-a1b2c3d
   ↓
5. Output image URL
   ↓
6. extension-tests.yml starts
   ↓
7. Pass image URL to per-extension.yml (and other child workflows)
   ↓
8. per-extension.yml passes image URL to deploy-fly-app
   ↓
9. deploy-fly-app uses: flyctl deploy --image <url>
   ↓
10. Fly.io pulls pre-built image from registry (fast!)
```

## Phase 1: Foundation

**Goal:** Set up infrastructure and create reusable components.

**Duration:** 2-3 days

### Tasks

#### 1.1: Create Fly Registry App

**File:** N/A (CLI command)

**Action:**

```bash
# Create dedicated registry app
flyctl apps create sindri-registry --org personal

# Verify creation
flyctl apps list | grep sindri-registry
```

**Success Criteria:**

- App `sindri-registry` exists in Fly.io dashboard
- App shows as "created" status

#### 1.2: Create Build-Push Composite Action

**File:** `.github/actions/build-push-image/action.yml`

**Content:**

```yaml
name: "Build and Push Docker Image"
description: "Builds Docker image and pushes to Fly.io registry"

inputs:
  fly-api-token:
    description: "Fly.io API token"
    required: true
  tag:
    description: "Image tag (e.g., pr-123-a1b2c3d)"
    required: true
  registry-app:
    description: "Fly registry app name"
    required: false
    default: "sindri-registry"
  dockerfile:
    description: "Path to Dockerfile"
    required: false
    default: "Dockerfile"
  build-context:
    description: "Docker build context directory"
    required: false
    default: "."

outputs:
  image-url:
    description: "Full image URL (registry.fly.io/app:tag)"
    value: ${{ steps.push.outputs.url }}
  image-tag:
    description: "Image tag used"
    value: ${{ inputs.tag }}

runs:
  using: "composite"
  steps:
    - name: Install Fly CLI
      uses: superfly/flyctl-actions/setup-flyctl@master

    - name: Authenticate with Fly Docker registry
      shell: bash
      env:
        FLY_API_TOKEN: ${{ inputs.fly-api-token }}
      run: |
        echo "Authenticating with Fly.io Docker registry..."
        flyctl auth docker

    - name: Build and push image
      id: push
      shell: bash
      run: |
        IMAGE_URL="registry.fly.io/${{ inputs.registry-app }}:${{ inputs.tag }}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Building Docker image"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Image: ${IMAGE_URL}"
        echo "Dockerfile: ${{ inputs.dockerfile }}"
        echo "Context: ${{ inputs.build-context }}"
        echo ""

        # Build image
        docker build \
          -f ${{ inputs.dockerfile }} \
          -t ${IMAGE_URL} \
          ${{ inputs.build-context }}

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Pushing to Fly.io registry"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Push to registry
        docker push ${IMAGE_URL}

        # Set outputs
        echo "url=${IMAGE_URL}" >> $GITHUB_OUTPUT
        echo ""
        echo "✅ Image pushed successfully: ${IMAGE_URL}"
```

**Testing:**

```bash
# Local test (requires Fly.io auth)
export FLY_API_TOKEN=<your-token>
flyctl auth docker
docker build -t registry.fly.io/sindri-registry:test .
docker push registry.fly.io/sindri-registry:test

# Verify
flyctl image show registry.fly.io/sindri-registry:test
```

**Success Criteria:**

- Composite action file exists and is syntactically valid
- Local test successfully pushes image to registry
- Image visible in Fly.io registry

#### 1.3: Create Build-Image Workflow

**File:** `.github/workflows/build-image.yml`

**Content:**

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [main, develop]
    paths:
      - 'Dockerfile'
      - 'docker/**'
  pull_request:
    branches: [main, develop]
    paths:
      - 'Dockerfile'
      - 'docker/**'
  workflow_dispatch:
    inputs:
      tag:
        description: 'Custom image tag (default: auto-generated)'
        required: false
        type: string
      push_latest:
        description: 'Tag as latest'
        required: false
        default: false
        type: boolean

jobs:
  build-push:
    name: Build & Push to Fly Registry
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      image-url: ${{ steps.build.outputs.image-url }}
      image-tag: ${{ steps.build.outputs.image-tag }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Generate image tag
        id: generate-tag
        run: |
          if [ -n "${{ github.event.inputs.tag }}" ]; then
            # Manual workflow dispatch with custom tag
            TAG="${{ github.event.inputs.tag }}"
          elif [ "${{ github.event_name }}" = "pull_request" ]; then
            # PR builds: pr-<number>-<sha>
            PR_NUMBER="${{ github.event.pull_request.number }}"
            SHA_SHORT=${GITHUB_SHA:0:7}
            TAG="pr-${PR_NUMBER}-${SHA_SHORT}"
          else
            # Push builds: <branch>-<sha>
            BRANCH=${GITHUB_REF#refs/heads/}
            BRANCH=${BRANCH//\//-}  # Replace / with -
            SHA_SHORT=${GITHUB_SHA:0:7}
            TAG="${BRANCH}-${SHA_SHORT}"
          fi

          echo "tag=${TAG}" >> $GITHUB_OUTPUT
          echo "Generated tag: ${TAG}"

      - name: Build and push image
        id: build
        uses: ./.github/actions/build-push-image
        with:
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
          tag: ${{ steps.generate-tag.outputs.tag }}
          registry-app: "sindri-registry"

      - name: Tag as latest (main branch or manual request)
        if: github.ref == 'refs/heads/main' || github.event.inputs.push_latest == 'true'
        env:
          FLY_API_TOKEN: ${{ secrets.FLYIO_AUTH_TOKEN }}
        run: |
          echo "Tagging as latest..."
          flyctl auth docker

          SOURCE_IMAGE="${{ steps.build.outputs.image-url }}"
          LATEST_IMAGE="registry.fly.io/sindri-registry:latest"

          docker pull ${SOURCE_IMAGE}
          docker tag ${SOURCE_IMAGE} ${LATEST_IMAGE}
          docker push ${LATEST_IMAGE}

          echo "✅ Latest tag pushed: ${LATEST_IMAGE}"

      - name: Output summary
        run: |
          echo "## 🐳 Docker Image Built" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Image URL:** \`${{ steps.build.outputs.image-url }}\`" >> $GITHUB_STEP_SUMMARY
          echo "**Tag:** \`${{ steps.build.outputs.image-tag }}\`" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY

          if [ "${{ github.ref }}" = "refs/heads/main" ] || [ "${{ github.event.inputs.push_latest }}" = "true" ]; then
            echo "**Latest:** Yes ✅" >> $GITHUB_STEP_SUMMARY
          else
            echo "**Latest:** No" >> $GITHUB_STEP_SUMMARY
          fi
```

**Testing:**

```bash
# Test workflow syntax
yq eval . .github/workflows/build-image.yml > /dev/null

# Trigger manually
gh workflow run build-image.yml --ref feature/use-prebuilt-images

# Monitor
gh run list --workflow=build-image.yml
gh run view <run-id> --log
```

**Success Criteria:**

- Workflow file is syntactically valid (passes YAML validation)
- Manual trigger successfully builds and pushes image
- Image appears in Fly.io registry with correct tag
- `latest` tag applied when pushing to main branch

#### 1.4: Create Documentation Stub

**File:** `.github/actions/build-push-image/README.md`

**Content:**

```markdown
# Build and Push Docker Image Action

Composite action for building Docker images and pushing to Fly.io registry.

## Usage

\`\`\`yaml
- name: Build and push image
  uses: ./.github/actions/build-push-image
  with:
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    tag: "pr-123-a1b2c3d"
    registry-app: "sindri-registry"
\`\`\`

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `fly-api-token` | Fly.io API token | Yes | N/A |
| `tag` | Image tag | Yes | N/A |
| `registry-app` | Registry app name | No | `sindri-registry` |
| `dockerfile` | Path to Dockerfile | No | `Dockerfile` |
| `build-context` | Build context directory | No | `.` |

## Outputs

| Output | Description |
|--------|-------------|
| `image-url` | Full image URL (e.g., `registry.fly.io/app:tag`) |
| `image-tag` | Image tag used |

## Examples

See `.github/workflows/build-image.yml` for a complete example.
```

**Success Criteria:**

- Documentation exists and describes all inputs/outputs
- Examples are clear and actionable

### Phase 1 Deliverables

- [ ] Fly registry app created (`sindri-registry`)
- [ ] Composite action created (`.github/actions/build-push-image/action.yml`)
- [ ] Build workflow created (`.github/workflows/build-image.yml`)
- [ ] Documentation created
- [ ] Manual test successful (image pushed to registry)
- [ ] Workflow syntax validation passes

### Phase 1 Testing Checklist

- [ ] Registry app accessible via `flyctl apps list`
- [ ] Local Docker push succeeds
- [ ] Workflow dispatch succeeds
- [ ] Image visible in Fly.io registry
- [ ] Image pullable from registry
- [ ] `latest` tag works correctly

## Phase 2: Proof of Concept

**Goal:** Test the pre-built image approach end-to-end with minimal changes.

**Duration:** 2-3 days

### Tasks

#### 2.1: Update deploy-fly-app Composite Action

**File:** `.github/actions/deploy-fly-app/action.yml`

**Changes:**

1. Add new input parameter:

```yaml
inputs:
  # ... existing inputs ...

  pre-built-image:
    description: "Pre-built image URL (e.g., registry.fly.io/app:tag). If provided, skips build."
    required: false
    default: ""
```

2. Modify deployment step:

```yaml
- name: Deploy app with retry logic
  id: deploy
  shell: bash
  env:
    FLY_API_TOKEN: ${{ inputs.fly-api-token }}
  run: |
    echo "Deploying app: ${{ inputs.app-name }}"
    max_attempts=${{ inputs.max-deploy-attempts }}
    attempt=1

    # Determine deployment command
    if [ -n "${{ inputs.pre-built-image }}" ]; then
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "Using pre-built image (fast deployment)"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "Image: ${{ inputs.pre-built-image }}"
      echo ""

      DEPLOY_CMD="flyctl deploy --app ${{ inputs.app-name }} \
        --image ${{ inputs.pre-built-image }} \
        --strategy immediate \
        --wait-timeout ${{ inputs.deploy-timeout }}s \
        --yes"
    else
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "Building from source (no pre-built image)"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""

      DEPLOY_CMD="flyctl deploy --app ${{ inputs.app-name }} \
        --strategy immediate \
        --wait-timeout ${{ inputs.deploy-timeout }}s \
        --yes"
    fi

    while [ $attempt -le $max_attempts ]; do
      echo "Deployment attempt $attempt of $max_attempts..."

      if eval $DEPLOY_CMD; then
        echo "✅ Deployment successful"
        echo "status=success" >> $GITHUB_OUTPUT
        exit 0
      else
        if [ $attempt -lt $max_attempts ]; then
          wait_time=$((30 * attempt))
          echo "⚠️  Deployment failed, retrying in ${wait_time}s..."
          sleep $wait_time
          attempt=$((attempt + 1))
        else
          echo "❌ Deployment failed after $max_attempts attempts"
          echo "status=failure" >> $GITHUB_OUTPUT
          exit 1
        fi
      fi
    done
```

**Success Criteria:**

- Action accepts `pre-built-image` as optional input
- When image provided, uses `flyctl deploy --image`
- When image not provided, falls back to build from source
- Deployment succeeds in both modes

#### 2.2: Create Standalone Test Workflow

**File:** `.github/workflows/test-prebuilt-image.yml`

**Content:**

```yaml
name: Test Pre-Built Image (POC)

on:
  workflow_dispatch:
    inputs:
      use_prebuilt:
        description: 'Use pre-built image (if false, builds from source for comparison)'
        required: false
        default: true
        type: boolean
      image_tag:
        description: 'Image tag to use (default: latest)'
        required: false
        default: 'latest'
        type: string

jobs:
  build-image:
    name: Build Docker Image
    runs-on: ubuntu-latest
    if: inputs.use_prebuilt == true
    outputs:
      image-url: ${{ steps.build.outputs.image-url }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Generate tag
        id: gen-tag
        run: |
          if [ "${{ inputs.image_tag }}" = "latest" ]; then
            TAG="test-$(date +%s)-${GITHUB_SHA:0:7}"
          else
            TAG="${{ inputs.image_tag }}"
          fi
          echo "tag=${TAG}" >> $GITHUB_OUTPUT
          echo "Using tag: ${TAG}"

      - name: Build and push image
        id: build
        uses: ./.github/actions/build-push-image
        with:
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
          tag: ${{ steps.gen-tag.outputs.tag }}

      - name: Output image info
        run: |
          echo "## 🐳 Image Built" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**URL:** \`${{ steps.build.outputs.image-url }}\`" >> $GITHUB_STEP_SUMMARY

  test-deployment:
    name: Test Deployment
    needs: build-image
    if: always() && (needs.build-image.result == 'success' || inputs.use_prebuilt == false)
    runs-on: ubuntu-latest
    timeout-minutes: 20

    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Setup test environment
        id: setup
        uses: ./.github/actions/setup-fly-test-env
        with:
          app-prefix: "poc-test"
          extension-name: "prebuilt"
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
          vm-memory: "2048"
          vm-cpu-kind: "shared"
          vm-cpu-count: "1"

      - name: Deploy test app
        id: deploy
        uses: ./.github/actions/deploy-fly-app
        with:
          app-name: ${{ steps.setup.outputs.app-name }}
          region: "sjc"
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
          pre-built-image: ${{ inputs.use_prebuilt == true && needs.build-image.outputs.image-url || '' }}

      - name: Wait for deployment
        uses: ./.github/actions/wait-fly-deployment
        with:
          app-name: ${{ steps.setup.outputs.app-name }}
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
          timeout-seconds: "180"

      - name: Test basic functionality
        env:
          FLY_API_TOKEN: ${{ secrets.FLYIO_AUTH_TOKEN }}
        run: |
          app_name="${{ steps.setup.outputs.app-name }}"

          echo "Testing basic VM functionality..."
          flyctl ssh console --app $app_name --user developer --command "/bin/bash -lc '
            echo \"VM is accessible via SSH\"
            echo \"User: \$(whoami)\"
            echo \"Home: \$HOME\"
            echo \"Workspace exists: \$([ -d /workspace ] && echo Yes || echo No)\"
            which git && echo \"✅ git installed\"
            which curl && echo \"✅ curl installed\"
            which ssh && echo \"✅ ssh installed\"
          '"

      - name: Output summary
        if: always()
        run: |
          echo "## Test Results" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Mode:** ${{ inputs.use_prebuilt == true && 'Pre-built image' || 'Build from source' }}" >> $GITHUB_STEP_SUMMARY
          echo "**Status:** ${{ steps.deploy.outputs.deployment-status }}" >> $GITHUB_STEP_SUMMARY

          if [ "${{ inputs.use_prebuilt }}" = "true" ]; then
            echo "**Image:** \`${{ needs.build-image.outputs.image-url }}\`" >> $GITHUB_STEP_SUMMARY
          fi

      - name: Cleanup
        if: always()
        uses: ./.github/actions/cleanup-fly-app
        with:
          app-name: ${{ steps.setup.outputs.app-name }}
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
```

**Testing:**

```bash
# Test with pre-built image
gh workflow run test-prebuilt-image.yml \
  --ref feature/use-prebuilt-images \
  -f use_prebuilt=true

# Test without pre-built image (baseline)
gh workflow run test-prebuilt-image.yml \
  --ref feature/use-prebuilt-images \
  -f use_prebuilt=false

# Compare timing
gh run list --workflow=test-prebuilt-image.yml --limit 2
```

**Success Criteria:**

- Both modes complete successfully
- Pre-built image deployment is significantly faster (2-3 min vs 5 min)
- VM functions identically in both modes
- All smoke tests pass

#### 2.3: Measure and Document Performance

**Action:** Run the test workflow multiple times and document results.

**Metrics to Capture:**

- Build time (with pre-built): ~5 minutes
- Deployment time (with pre-built): ~30-60 seconds
- Total time (with pre-built): ~6 minutes
- Build time (from source): N/A
- Deployment time (from source): ~3-5 minutes
- Total time (from source): ~3-5 minutes
- Time savings: ~2-4 minutes per deployment

**Documentation Update:** Add results to this document in a new section.

**Success Criteria:**

- At least 3 test runs completed successfully in each mode
- Performance improvement quantified and documented
- No functional regressions observed

### Phase 2 Deliverables

- [ ] `deploy-fly-app` action updated with image support
- [ ] POC test workflow created
- [ ] Successful test runs (both modes)
- [ ] Performance metrics documented
- [ ] No functional regressions

### Phase 2 Testing Checklist

- [ ] Pre-built mode deploys successfully
- [ ] Build-from-source mode still works (backward compatibility)
- [ ] Deployment time reduced by 40-60%
- [ ] VM functions identically in both modes
- [ ] Extensions install correctly
- [ ] SSH access works
- [ ] Volume mounts correctly

## Phase 3: Single Workflow Migration

**Goal:** Migrate one production workflow to use pre-built images.

**Duration:** 3-4 days

**Target Workflow:** `developer-workflow.yml` (low risk, single deployment)

### Tasks

#### 3.1: Update developer-workflow.yml

**File:** `.github/workflows/developer-workflow.yml`

**Changes:**

1. Add `pre_built_image` input:

```yaml
on:
  workflow_call:
    inputs:
      # ... existing inputs ...
      pre_built_image:
        description: "Pre-built Docker image URL (optional)"
        required: false
        default: ""
        type: string
```

2. Pass to deploy action:

```yaml
- name: Deploy test environment
  uses: ./.github/actions/deploy-fly-app
  with:
    app-name: ${{ steps.setup.outputs.app-name }}
    region: ${{ inputs.region }}
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    deploy-timeout: "300"
    pre-built-image: ${{ inputs.pre_built_image }}  # NEW
```

**Success Criteria:**

- Workflow accepts optional `pre_built_image` input
- Falls back to build-from-source when not provided
- Passes value through to deploy action

#### 3.2: Update integration.yml Orchestrator

**File:** `.github/workflows/integration.yml`

**Changes:**

1. Add build job:

```yaml
jobs:
  setup-config:
    # ... existing ...

  build-image:
    name: Build Docker Image
    runs-on: ubuntu-latest
    # Only build if Dockerfile or docker/* changed
    if: |
      contains(github.event.head_commit.modified, 'Dockerfile') ||
      contains(github.event.head_commit.modified, 'docker/')
    outputs:
      image-url: ${{ steps.build.outputs.image-url }}
      should-use-image: ${{ steps.check.outputs.should-use }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Check if build needed
        id: check
        run: |
          # Always use pre-built images in CI
          echo "should-use=true" >> $GITHUB_OUTPUT

      - name: Generate tag
        id: gen-tag
        run: |
          SHA_SHORT=${GITHUB_SHA:0:7}
          BRANCH=${GITHUB_REF#refs/heads/}
          BRANCH=${BRANCH//\//-}
          TAG="${BRANCH}-${SHA_SHORT}"
          echo "tag=${TAG}" >> $GITHUB_OUTPUT

      - name: Build and push
        id: build
        if: steps.check.outputs.should-use == 'true'
        uses: ./.github/actions/build-push-image
        with:
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
          tag: ${{ steps.gen-tag.outputs.tag }}

  integration-test:
    # ... existing ...

  developer-workflow:
    name: Developer Workflow
    needs: [setup-config, integration-test, build-image]
    if: always() && needs.integration-test.result == 'success'
    uses: ./.github/workflows/developer-workflow.yml
    with:
      test_app_prefix: ${{ needs.setup-config.outputs.test_app_prefix }}
      region: ${{ needs.setup-config.outputs.region }}
      skip_cleanup: ${{ fromJSON(needs.setup-config.outputs.skip_cleanup) }}
      pre_built_image: ${{ needs.build-image.outputs.should-use-image == 'true' && needs.build-image.outputs.image-url || '' }}  # NEW
    secrets:
      FLYIO_AUTH_TOKEN: ${{ secrets.FLYIO_AUTH_TOKEN }}
```

**Success Criteria:**

- Build job triggers when Dockerfile changes
- Build job can be skipped when not needed
- Image URL passed to developer-workflow
- Workflow works with and without pre-built image

#### 3.3: Add Conditional Image Reuse

**Goal:** Reuse existing images when Dockerfile hasn't changed.

**Changes to build-image job:**

```yaml
- name: Check if build needed
  id: check
  run: |
    # Get list of changed files
    if [ "${{ github.event_name }}" = "pull_request" ]; then
      CHANGED_FILES=$(gh pr view ${{ github.event.pull_request.number }} --json files --jq '.files[].path')
    else
      CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
    fi

    # Check if Dockerfile or docker/* changed
    if echo "$CHANGED_FILES" | grep -qE '^(Dockerfile|docker/)'; then
      echo "Docker files changed, rebuild needed"
      echo "should-build=true" >> $GITHUB_OUTPUT
      echo "should-use=true" >> $GITHUB_OUTPUT
    else
      echo "Docker files unchanged, reusing latest image"
      echo "should-build=false" >> $GITHUB_OUTPUT
      echo "should-use=true" >> $GITHUB_OUTPUT
    fi

- name: Get existing image if no rebuild needed
  id: get-existing
  if: steps.check.outputs.should-build == 'false'
  run: |
    # Use latest image
    IMAGE_URL="registry.fly.io/sindri-registry:latest"
    echo "url=${IMAGE_URL}" >> $GITHUB_OUTPUT
    echo "Using existing image: ${IMAGE_URL}"

- name: Build and push new image
  id: build
  if: steps.check.outputs.should-build == 'true'
  uses: ./.github/actions/build-push-image
  with:
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    tag: ${{ steps.gen-tag.outputs.tag }}

- name: Set final image URL
  id: final
  run: |
    if [ "${{ steps.check.outputs.should-build }}" = "true" ]; then
      IMAGE_URL="${{ steps.build.outputs.image-url }}"
    else
      IMAGE_URL="${{ steps.get-existing.outputs.url }}"
    fi
    echo "image-url=${IMAGE_URL}" >> $GITHUB_OUTPUT
```

**Success Criteria:**

- Skips build when Dockerfile unchanged
- Reuses latest image successfully
- Still works when rebuild needed

#### 3.4: Integration Testing

**Testing Plan:**

1. **Baseline test (no pre-built image):**

   ```bash
   # Trigger without changes to Dockerfile
   git commit --allow-empty -m "test: baseline workflow [test-workflow]"
   git push
   ```

   Expected: Builds from source (~5 min)

2. **Test with pre-built image:**

   ```bash
   # Merge changes, trigger workflow
   git push origin feature/use-prebuilt-images
   ```

   Expected: Builds image once (~5 min), deploys quickly (~1 min)

3. **Test image reuse:**

   ```bash
   # Make non-Docker changes
   echo "# Test" >> README.md
   git commit -am "docs: test image reuse [test-workflow]"
   git push
   ```

   Expected: Reuses existing image, deploys quickly (~1 min)

**Success Criteria:**

- All test scenarios pass
- Timing improvements validated
- No functional regressions
- Extension installations work correctly

### Phase 3 Deliverables

- [ ] `developer-workflow.yml` updated
- [ ] `integration.yml` updated with build job
- [ ] Conditional image reuse implemented
- [ ] Integration tests pass
- [ ] Performance improvements documented

### Phase 3 Testing Checklist

- [ ] Workflow runs successfully with pre-built image
- [ ] Workflow runs successfully without pre-built image (fallback)
- [ ] Image reuse works when Dockerfile unchanged
- [ ] Rebuild triggered when Dockerfile changes
- [ ] Developer workflow tests pass
- [ ] Extension installations work
- [ ] Volume persistence works
- [ ] Timing improved by 40-60%

## Phase 4: Core Workflows Migration

**Goal:** Migrate high-impact workflows with multiple deployments.

**Duration:** 5-7 days

### Tasks

#### 4.1: Update per-extension.yml

**File:** `.github/workflows/per-extension.yml`

**Changes:**

1. Add input parameter:

```yaml
on:
  workflow_call:
    inputs:
      # ... existing inputs ...
      pre_built_image:
        description: "Pre-built Docker image URL (optional)"
        required: false
        default: ""
        type: string
```

2. Pass to deploy action:

```yaml
- name: Deploy test environment
  uses: ./.github/actions/deploy-fly-app
  with:
    app-name: ${{ steps.setup.outputs.app-name }}
    region: ${{ inputs.region }}
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    pre-built-image: ${{ inputs.pre_built_image }}  # NEW
```

**Success Criteria:**

- Workflow accepts image URL input
- Passes to all 30+ parallel deployments
- Falls back to build-from-source when not provided

#### 4.2: Update extension-tests.yml Orchestrator

**File:** `.github/workflows/extension-tests.yml`

**Changes:**

1. Add build job (same pattern as integration.yml):

```yaml
jobs:
  setup-config:
    # ... existing ...

  build-image:
    name: Build Docker Image
    runs-on: ubuntu-latest
    outputs:
      image-url: ${{ steps.final.outputs.image-url }}
      should-use-image: ${{ steps.check.outputs.should-use }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Check if build needed
        id: check
        run: |
          # Get list of changed files
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            CHANGED_FILES=$(gh pr view ${{ github.event.pull_request.number }} --json files --jq '.files[].path')
          else
            CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
          fi

          # Check if Dockerfile or docker/* changed
          if echo "$CHANGED_FILES" | grep -qE '^(Dockerfile|docker/)'; then
            echo "Docker files changed, rebuild needed"
            echo "should-build=true" >> $GITHUB_OUTPUT
            echo "should-use=true" >> $GITHUB_OUTPUT
          else
            echo "Docker files unchanged, reusing latest image"
            echo "should-build=false" >> $GITHUB_OUTPUT
            echo "should-use=true" >> $GITHUB_OUTPUT
          fi

      - name: Generate tag
        id: gen-tag
        if: steps.check.outputs.should-build == 'true'
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            PR_NUMBER="${{ github.event.pull_request.number }}"
            TAG="pr-${PR_NUMBER}-${GITHUB_SHA:0:7}"
          else
            BRANCH=${GITHUB_REF#refs/heads/}
            BRANCH=${BRANCH//\//-}
            TAG="${BRANCH}-${GITHUB_SHA:0:7}"
          fi
          echo "tag=${TAG}" >> $GITHUB_OUTPUT

      - name: Build and push new image
        id: build
        if: steps.check.outputs.should-build == 'true'
        uses: ./.github/actions/build-push-image
        with:
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
          tag: ${{ steps.gen-tag.outputs.tag }}

      - name: Get existing image
        id: get-existing
        if: steps.check.outputs.should-build == 'false'
        run: |
          IMAGE_URL="registry.fly.io/sindri-registry:latest"
          echo "url=${IMAGE_URL}" >> $GITHUB_OUTPUT

      - name: Set final image URL
        id: final
        run: |
          if [ "${{ steps.check.outputs.should-build }}" = "true" ]; then
            IMAGE_URL="${{ steps.build.outputs.image-url }}"
          else
            IMAGE_URL="${{ steps.get-existing.outputs.url }}"
          fi
          echo "image-url=${IMAGE_URL}" >> $GITHUB_OUTPUT
          echo "Final image: ${IMAGE_URL}"

  # Update validation jobs to not need build-image (can run in parallel)
  extension-manager-validation:
    name: Extension Manager Validation
    uses: ./.github/workflows/manager-validation.yml

  extension-syntax-validation:
    name: Extension Syntax Validation
    uses: ./.github/workflows/syntax-validation.yml

  # All deployment jobs now need build-image
  per-extension-tests:
    name: Per-Extension Tests
    needs: [setup-config, build-image, extension-manager-validation, extension-syntax-validation]
    uses: ./.github/workflows/per-extension.yml
    with:
      extension_name: ${{ needs.setup-config.outputs.extension_name }}
      skip_cleanup: ${{ fromJSON(needs.setup-config.outputs.skip_cleanup) }}
      skip_idempotency: ${{ fromJSON(needs.setup-config.outputs.skip_idempotency) }}
      test_app_prefix: ${{ needs.setup-config.outputs.test_app_prefix }}
      region: ${{ needs.setup-config.outputs.region }}
      pre_built_image: ${{ needs.build-image.outputs.image-url }}  # NEW
    secrets:
      FLYIO_AUTH_TOKEN: ${{ secrets.FLYIO_AUTH_TOKEN }}

  extension-api-tests:
    name: Extension API Compliance
    needs: [setup-config, build-image, extension-manager-validation, extension-syntax-validation]
    uses: ./.github/workflows/api-compliance.yml
    with:
      test_app_prefix: ${{ needs.setup-config.outputs.test_app_prefix }}
      region: ${{ needs.setup-config.outputs.region }}
      skip_cleanup: ${{ fromJSON(needs.setup-config.outputs.skip_cleanup) }}
      pre_built_image: ${{ needs.build-image.outputs.image-url }}  # NEW
    secrets:
      FLYIO_AUTH_TOKEN: ${{ secrets.FLYIO_AUTH_TOKEN }}

  # ... repeat for all other deployment jobs ...
```

2. Update job dependency graph:

```yaml
# Before:
#   validation jobs → deployment jobs
#
# After:
#   build-image + validation jobs → deployment jobs
#   (build-image and validation jobs run in parallel)
```

**Success Criteria:**

- Build job runs in parallel with validation
- All deployment jobs receive image URL
- 30+ parallel deployments use same image
- Massive time savings realized

#### 4.3: Update Child Workflows

Update all workflows called by `extension-tests.yml`:

**Files to update:**

- `.github/workflows/api-compliance.yml`
- `.github/workflows/protected-extensions-tests.yml`
- `.github/workflows/cleanup-extensions-tests.yml`
- `.github/workflows/manifest-operations-tests.yml`
- `.github/workflows/dependency-chain-tests.yml`
- `.github/workflows/extension-combinations.yml`
- `.github/workflows/test-extensions-metadata.yml`
- `.github/workflows/test-extensions-upgrade-vm.yml`

**Changes for each:**

1. Add input parameter:

```yaml
on:
  workflow_call:
    inputs:
      # ... existing inputs ...
      pre_built_image:
        description: "Pre-built Docker image URL (optional)"
        required: false
        default: ""
        type: string
```

2. Pass to deploy actions:

```yaml
- name: Deploy test environment
  uses: ./.github/actions/deploy-fly-app
  with:
    # ... existing params ...
    pre-built-image: ${{ inputs.pre_built_image }}
```

**Success Criteria:**

- All workflows updated consistently
- All accept optional image URL
- All pass to deploy action
- No breaking changes to existing behavior

#### 4.4: Update Integration Workflows

**Files to update:**

- `.github/workflows/integration-test.yml`
- `.github/workflows/mise-stack-integration.yml`

**Changes:**

Same pattern as above:

1. Add `pre_built_image` input
2. Pass to deploy actions
3. Update orchestrator to provide image URL

**Success Criteria:**

- Integration workflows use pre-built images
- Timing improvements validated
- All tests still pass

#### 4.5: Comprehensive Testing

**Testing Strategy:**

1. **Trigger full extension test suite:**

   ```bash
   # Make Docker change to force rebuild
   echo "# Test change" >> Dockerfile
   git commit -am "test: trigger full extension tests"
   git push
   ```

   Expected:

   - Builds image once (~5 min)
   - 30+ deployments use pre-built image (~30-60 sec each)
   - Total time: ~15-20 min (vs ~30-40 min before)

2. **Trigger with image reuse:**

   ```bash
   # Make non-Docker change
   echo "# Test" >> README.md
   git commit -am "test: image reuse with extensions"
   git push
   ```

   Expected:

   - Reuses existing image (no build)
   - 30+ deployments (~30-60 sec each)
   - Total time: ~10-15 min

3. **Spot check individual extensions:**

   ```bash
   gh workflow run extension-tests.yml \
     --ref feature/use-prebuilt-images \
     -f extension_name=nodejs
   ```

   Expected: Single extension test completes in ~2 min

**Success Criteria:**

- Full test suite time reduced by 40-60%
- All extensions pass tests
- No functional regressions
- Image reuse works correctly
- Parallel deployments work correctly

### Phase 4 Deliverables

- [ ] `per-extension.yml` updated
- [ ] `extension-tests.yml` updated with build job
- [ ] All 9 child workflows updated
- [ ] Integration workflows updated
- [ ] Comprehensive testing completed
- [ ] Performance metrics documented

### Phase 4 Testing Checklist

- [ ] Full extension test suite passes
- [ ] All 30+ extensions install correctly
- [ ] API compliance tests pass
- [ ] Protected extensions tests pass
- [ ] Manifest operations tests pass
- [ ] Dependency chain tests pass
- [ ] Extension combinations tests pass
- [ ] Integration tests pass
- [ ] Timing reduced by 40-60%
- [ ] Image reuse works correctly
- [ ] Parallel deployments work

## Phase 5: Full Rollout

**Goal:** Complete migration of all workflows and finalize documentation.

**Duration:** 3-4 days

### Tasks

#### 5.1: Update Remaining Workflows

**Files to update (if any remain):**

Check for any workflows not yet migrated:

```bash
# Find workflows that use deploy-fly-app but don't have pre_built_image
grep -l "deploy-fly-app" .github/workflows/*.yml | while read -r file; do
  if ! grep -q "pre_built_image" "$file"; then
    echo "Needs update: $file"
  fi
done
```

**Action:** Update any remaining workflows following the established pattern.

**Success Criteria:**

- All workflows using `deploy-fly-app` have image support
- No workflows left behind

#### 5.2: Update Documentation

**Files to update:**

1. **CLAUDE.md** - Update CI/CD section:

```markdown
## CI/CD & GitHub Actions

Sindri uses GitHub Actions for automated testing and validation. The workflows use **pre-built Docker images** for fast, consistent deployments.

### Image Build Process

The base Docker image is built once and pushed to Fly.io's registry:

```bash
# Automatic on Dockerfile changes
registry.fly.io/sindri-registry:<branch>-<sha>

# Latest stable image
registry.fly.io/sindri-registry:latest
```

### Workflow Architecture

1. **Build Stage**: Build Docker image (if Dockerfile changed)
2. **Test Stage**: Deploy using pre-built image (30-60 sec per deployment)

This approach reduces CI time by 40-60% compared to building from source for each deployment.

### Available Workflows

... [existing workflow descriptions]

### Image Tagging Strategy

- PR builds: `pr-<number>-<sha>`
- Branch builds: `<branch>-<sha>`
- Main branch: `main-<sha>` + `latest`
```

2. **README.md** - Update Performance section (if exists):

```markdown
## Performance

- **Extension tests**: ~15-20 minutes (30+ extensions in parallel)
- **Integration tests**: ~8 minutes
- **Full CI suite**: ~25-35 minutes

Optimizations:

- Pre-built Docker images (40-60% time savings)
- Parallel test execution
- Conditional image rebuilds
```

3. **Create new doc:** `.github/DOCKER_IMAGES.md`

```markdown
# Docker Image Management

## Overview

Sindri uses pre-built Docker images stored in Fly.io's registry to speed up CI/CD workflows.

## Registry

**Location:** `registry.fly.io/sindri-registry`

**App:** `sindri-registry` (registry namespace, doesn't need to run)

## Image Tags

| Tag Pattern | Usage | Example |
|-------------|-------|---------|
| `pr-<n>-<sha>` | Pull request builds | `pr-123-a1b2c3d` |
| `<branch>-<sha>` | Branch builds | `develop-a1b2c3d` |
| `main-<sha>` | Main branch commits | `main-a1b2c3d` |
| `latest` | Latest main build | `latest` |
| `v<version>` | Release tags | `v1.0.0` |

## Building Images

### Automatic Builds

Images are automatically built when `Dockerfile` or `docker/**` changes:

- `.github/workflows/build-image.yml` triggers on push/PR
- Builds and pushes to registry
- Outputs image URL for downstream workflows

### Manual Builds

Trigger via workflow dispatch:

```bash
gh workflow run build-image.yml \
  --ref main \
  -f tag=custom-tag \
  -f push_latest=true
```

## Using Pre-Built Images

### In Workflows

```yaml
jobs:
  build-image:
    uses: ./.github/workflows/build-image.yml

  test:
    needs: build-image
    uses: ./.github/workflows/some-test.yml
    with:
      pre_built_image: ${{ needs.build-image.outputs.image-url }}
```

### Deployment Action

```yaml
- name: Deploy
  uses: ./.github/actions/deploy-fly-app
  with:
    app-name: my-app
    pre-built-image: registry.fly.io/sindri-registry:latest
```

## Image Lifecycle

1. **Build**: On Dockerfile changes, build and push to registry
2. **Reuse**: When Dockerfile unchanged, reuse `latest` tag
3. **Deploy**: All test deployments pull from registry (fast)
4. **Cleanup**: Manually delete old tags to save space

## Manual Operations

### List Images

```bash
# Via Docker CLI
flyctl auth docker
docker images | grep sindri-registry

# Via Fly CLI (not directly supported, use Docker)
```

### Pull Image

```bash
flyctl auth docker
docker pull registry.fly.io/sindri-registry:latest
```

### Delete Image

```bash
# Delete locally
docker rmi registry.fly.io/sindri-registry:old-tag

# Delete from registry (requires manual cleanup)
# Currently requires contacting Fly.io support or using Docker registry API
```

### Cleanup Old Images

Create a cleanup script or workflow to remove images older than 30 days:

```bash
#!/bin/bash
# TODO: Implement registry cleanup
# For now, manually delete via Docker:
# docker rmi registry.fly.io/sindri-registry:<old-tag>
```

## Troubleshooting

### Image Not Found

If workflow fails with "image not found":

1. Check if image exists: `docker pull registry.fly.io/sindri-registry:<tag>`
2. Verify tag in workflow outputs
3. Check build-image job logs
4. Manually trigger build-image workflow

### Authentication Failures

```bash
# Re-authenticate
flyctl auth docker

# Verify credentials
cat ~/.docker/config.json | grep registry.fly.io
```

### Deployment Failures

If deployment with pre-built image fails:

1. Check image exists in registry
2. Verify Fly.io authentication
3. Try deploying without pre-built image (build from source)
4. Check app logs: `flyctl logs -a <app-name>`

### Stale Images

If tests fail with outdated dependencies:

1. Trigger manual rebuild: `gh workflow run build-image.yml`
2. Wait for build to complete
3. Re-run failed workflow

## Performance Metrics

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Per-extension tests | 30 min | 12 min | 60% |
| Integration tests | 15 min | 8 min | 45% |
| Full CI suite | 40 min | 20 min | 50% |
| Single deployment | 5 min | 1 min | 80% |

## Best Practices

1. **Always use pre-built images in CI** - Significant time savings
2. **Rebuild on Dockerfile changes** - Ensures tests use latest base
3. **Reuse when possible** - Skip rebuild if Dockerfile unchanged
4. **Tag releases properly** - Use semantic version tags for releases
5. **Monitor registry size** - Periodically clean up old images
```

4. **Update composite action READMEs:**

Update `.github/actions/deploy-fly-app/README.md` to document the new parameter.

**Success Criteria:**

- All documentation updated and accurate
- Examples provided for common operations
- Troubleshooting guide available

#### 5.3: Create Migration Guide

**File:** `.github/MIGRATION_PREBUILT_IMAGES.md`

**Content:**

```markdown
# Migration to Pre-Built Docker Images

This document describes the changes made to support pre-built Docker images.

## Changes Overview

- Added Fly.io registry support
- Created build-push-image composite action
- Updated deploy-fly-app to accept pre-built images
- Updated all workflows to use pre-built images
- Reduced CI time by 40-60%

## Breaking Changes

**None.** All changes are backward-compatible:

- Workflows work with or without pre-built images
- Falls back to build-from-source if image not provided
- Existing workflows continue to function

## New Workflows

- `.github/workflows/build-image.yml` - Builds and pushes Docker images

## Updated Workflows

- `.github/workflows/extension-tests.yml` - Added build-image job
- `.github/workflows/integration.yml` - Added build-image job
- `.github/workflows/per-extension.yml` - Added pre_built_image input
- `.github/workflows/api-compliance.yml` - Added pre_built_image input
- [... list all updated workflows ...]

## New Composite Actions

- `.github/actions/build-push-image/` - Builds and pushes images to registry

## Updated Composite Actions

- `.github/actions/deploy-fly-app/` - Added `pre-built-image` input

## Configuration Changes

**Fly.io:**

- Created `sindri-registry` app for registry namespace

**GitHub Secrets:**

- No new secrets required (uses existing `FLYIO_AUTH_TOKEN`)

## Migration Steps (for contributors)

If you have custom workflows or forks:

1. Update `deploy-fly-app` calls to include `pre-built-image` parameter
2. Add build-image job to orchestrator workflows
3. Pass image URL to child workflows
4. Test thoroughly

## Rollback Procedure

If issues arise:

1. Remove `pre_built_image` parameter from workflow calls
2. Workflows automatically fall back to build-from-source
3. No other changes needed

## Performance Improvements

- Per-extension tests: 30 min → 12 min (60% faster)
- Integration tests: 15 min → 8 min (45% faster)
- Full CI suite: 40 min → 20 min (50% faster)
```

**Success Criteria:**

- Migration guide complete and accurate
- Rollback procedure documented
- Contributors can understand changes

#### 5.4: Update GitHub Actions Documentation

**File:** `.github/actions/README.md`

**Changes:**

Add new section:

```markdown
## Docker Image Management

### build-push-image

Builds Docker images and pushes to Fly.io registry.

**Location:** `.github/actions/build-push-image/`

**Usage:**

```yaml
- uses: ./.github/actions/build-push-image
  with:
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    tag: "pr-123-a1b2c3d"
```

**See:** [build-push-image/README.md](./build-push-image/README.md)

### deploy-fly-app (Updated)

Now supports pre-built images:

```yaml
- uses: ./.github/actions/deploy-fly-app
  with:
    app-name: my-app
    pre-built-image: registry.fly.io/sindri-registry:latest  # NEW
```

**See:** [deploy-fly-app/README.md](./deploy-fly-app/README.md)
```

**Success Criteria:**

- Actions documentation updated
- Links work correctly
- Examples are clear

#### 5.5: Final Testing

**Comprehensive Test Plan:**

1. **Full CI suite on PR:**

   ```bash
   # Create test PR
   gh pr create \
     --title "test: validate pre-built images" \
     --body "Full CI validation"
   ```

   Expected:

   - All workflows pass
   - Timing improvements visible
   - Image built once, used many times

2. **Merge to main:**

   ```bash
   gh pr merge --squash
   ```

   Expected:

   - `latest` tag updated
   - Future runs use new latest image

3. **Trigger individual workflows:**

   ```bash
   # Test each workflow type
   gh workflow run extension-tests.yml
   gh workflow run integration.yml
   gh workflow run build-image.yml
   ```

   Expected: All succeed

4. **Test fallback (no pre-built image):**

   ```bash
   # Manually trigger workflow without building image
   # (temporarily remove build-image dependency)
   ```

   Expected: Falls back to build-from-source

**Success Criteria:**

- All workflows pass on PR
- Merge to main succeeds
- `latest` tag works correctly
- Fallback behavior works
- No regressions

### Phase 5 Deliverables

- [ ] All remaining workflows updated
- [ ] Documentation updated (CLAUDE.md, README.md)
- [ ] New documentation created (DOCKER_IMAGES.md)
- [ ] Migration guide created
- [ ] Actions README updated
- [ ] Final testing completed
- [ ] PR merged to main

### Phase 5 Testing Checklist

- [ ] Full CI suite passes on PR
- [ ] Merge to main succeeds
- [ ] All workflows use pre-built images
- [ ] Documentation accurate and complete
- [ ] Examples work correctly
- [ ] Troubleshooting guide helpful
- [ ] No breaking changes
- [ ] Fallback works correctly

## Phase 6: Optimization

**Goal:** Optimize image management and add cleanup automation.

**Duration:** 2-3 days

### Tasks

#### 6.1: Implement Image Cleanup

**File:** `.github/workflows/cleanup-images.yml`

**Content:**

```yaml
name: Cleanup Old Docker Images

on:
  schedule:
    # Run weekly on Sunday at 2 AM UTC
    - cron: '0 2 * * 0'
  workflow_dispatch:
    inputs:
      dry_run:
        description: 'Dry run (show what would be deleted)'
        required: false
        default: true
        type: boolean
      keep_days:
        description: 'Keep images newer than N days'
        required: false
        default: 30
        type: number

jobs:
  cleanup:
    name: Cleanup Old Images
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Install Fly CLI
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Authenticate
        env:
          FLY_API_TOKEN: ${{ secrets.FLYIO_AUTH_TOKEN }}
        run: |
          flyctl auth docker

      - name: List and cleanup images
        env:
          DRY_RUN: ${{ github.event.inputs.dry_run || 'true' }}
          KEEP_DAYS: ${{ github.event.inputs.keep_days || 30 }}
        run: |
          echo "Listing images in registry..."
          echo ""

          # Get all tags (this is a placeholder - actual implementation depends on Docker registry API)
          # For now, we'll document the manual process

          cat << 'EOF'
          ⚠️  Automatic cleanup not yet implemented.

          Docker Registry API v2 is required for programmatic cleanup.
          Fly.io's registry supports this, but requires additional setup.

          Manual cleanup process:

          1. List images:
             flyctl auth docker
             # Use Docker Registry API or contact Fly.io support

          2. Delete old images:
             docker rmi registry.fly.io/sindri-registry:<old-tag>

          3. Or use Docker Registry API:
             curl -X DELETE https://registry.fly.io/v2/sindri-registry/manifests/<digest>

          For now, periodically review and manually delete old images.
          EOF

          # TODO: Implement actual cleanup using Docker Registry HTTP API v2
          # https://docs.docker.com/registry/spec/api/

      - name: Output summary
        run: |
          echo "## Image Cleanup Report" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Status:** Not yet implemented" >> $GITHUB_STEP_SUMMARY
          echo "**Action:** Manual cleanup required" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "See workflow logs for manual cleanup instructions." >> $GITHUB_STEP_SUMMARY
```

**Note:** Full implementation requires Docker Registry API v2 integration, which is beyond the scope of this initial rollout. Document manual cleanup process for now.

**Success Criteria:**

- Workflow exists and runs successfully
- Provides instructions for manual cleanup
- Can be enhanced later with actual cleanup logic

#### 6.2: Add Image Metadata Tracking

**Goal:** Track image build metadata for better debugging.

**File:** `.github/actions/build-push-image/action.yml`

**Changes:**

Add labels to Docker images:

```yaml
- name: Build and push image
  id: push
  shell: bash
  run: |
    IMAGE_URL="registry.fly.io/${{ inputs.registry-app }}:${{ inputs.tag }}"

    # Build with labels
    docker build \
      -f ${{ inputs.dockerfile }} \
      -t ${IMAGE_URL} \
      --label "org.opencontainers.image.created=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
      --label "org.opencontainers.image.revision=${GITHUB_SHA}" \
      --label "org.opencontainers.image.source=${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}" \
      --label "org.opencontainers.image.ref.name=${GITHUB_REF#refs/heads/}" \
      --label "com.sindri.build.workflow=${GITHUB_WORKFLOW}" \
      --label "com.sindri.build.run=${GITHUB_RUN_ID}" \
      ${{ inputs.build-context }}

    docker push ${IMAGE_URL}
    echo "url=${IMAGE_URL}" >> $GITHUB_OUTPUT
```

**Success Criteria:**

- Images have metadata labels
- Labels visible via `docker inspect`
- Helpful for debugging

#### 6.3: Performance Monitoring

**File:** `.github/workflows/monitor-performance.yml`

**Content:**

```yaml
name: Monitor CI Performance

on:
  workflow_run:
    workflows:
      - "Extension System Tests"
      - "Integration Tests"
    types:
      - completed

jobs:
  analyze:
    name: Analyze Performance
    runs-on: ubuntu-latest
    if: github.event.workflow_run.conclusion == 'success'

    steps:
      - name: Get workflow timing
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          run_id="${{ github.event.workflow_run.id }}"

          # Get workflow run details
          run_data=$(gh api "/repos/${{ github.repository }}/actions/runs/${run_id}")

          workflow_name=$(echo "$run_data" | jq -r '.name')
          started_at=$(echo "$run_data" | jq -r '.created_at')
          completed_at=$(echo "$run_data" | jq -r '.updated_at')

          # Calculate duration (requires date parsing)
          echo "Workflow: $workflow_name"
          echo "Started: $started_at"
          echo "Completed: $completed_at"

          # Output to summary
          echo "## ⏱️ Performance Report" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Workflow:** $workflow_name" >> $GITHUB_STEP_SUMMARY
          echo "**Run ID:** $run_id" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Started:** $started_at" >> $GITHUB_STEP_SUMMARY
          echo "**Completed:** $completed_at" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "View run: ${{ github.event.workflow_run.html_url }}" >> $GITHUB_STEP_SUMMARY

      - name: Compare with baseline
        run: |
          # TODO: Store historical data and compare trends
          # For now, just document expected times

          cat << 'EOF' >> $GITHUB_STEP_SUMMARY

          ### Expected Times (with pre-built images)

          | Workflow | Target Time |
          |----------|-------------|
          | Extension System Tests | 15-20 min |
          | Integration Tests | 8-10 min |
          | Per-Extension (single) | 2-3 min |
          | Full CI Suite | 20-30 min |
          EOF
```

**Success Criteria:**

- Performance tracking workflow exists
- Provides visibility into workflow timing
- Can be enhanced with historical tracking later

#### 6.4: Add Image Size Optimization

**Goal:** Reduce image size for faster pulls.

**File:** `Dockerfile`

**Optimization ideas:**

```dockerfile
# Before: Uses default Ubuntu packages
FROM ubuntu:24.04

# After: Consider multi-stage builds or Alpine base
FROM ubuntu:24.04 AS base

# Clean up in same RUN to reduce layer size
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        <packages> && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ... rest of Dockerfile ...
```

**Testing:**

```bash
# Before optimization
docker images | grep sindri-registry

# After optimization
docker images | grep sindri-registry

# Compare sizes
```

**Success Criteria:**

- Image size reduced (target: 10-20% smaller)
- No functional regressions
- Build time not significantly increased

#### 6.5: Add Workflow Timing Dashboard

**Goal:** Create a simple dashboard showing workflow performance.

**File:** `.github/workflows/update-dashboard.yml`

**Content:**

```yaml
name: Update Performance Dashboard

on:
  workflow_run:
    workflows: ["Extension System Tests", "Integration Tests"]
    types: [completed]
  workflow_dispatch:

jobs:
  update:
    name: Update Dashboard
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Update dashboard
        run: |
          # Create/update a markdown file with recent workflow times
          cat > docs/PERFORMANCE_DASHBOARD.md << 'EOF'
          # CI Performance Dashboard

          Last updated: $(date)

          ## Recent Workflow Runs

          <!-- This could be enhanced with actual data -->

          | Date | Workflow | Duration | Status |
          |------|----------|----------|--------|
          | TBD | Extension Tests | TBD | ✅ |
          | TBD | Integration Tests | TBD | ✅ |

          ## Performance Targets

          | Workflow | Target | Current |
          |----------|--------|---------|
          | Extension Tests | 15-20 min | TBD |
          | Integration Tests | 8-10 min | TBD |
          | Full CI Suite | 20-30 min | TBD |
          EOF

      - name: Commit dashboard
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add docs/PERFORMANCE_DASHBOARD.md
          git commit -m "chore: update performance dashboard" || echo "No changes"
          git push || echo "No changes to push"
```

**Note:** This is a basic implementation. Can be enhanced with actual data collection and visualization.

**Success Criteria:**

- Dashboard file created
- Updated on workflow completions
- Provides visibility into performance trends

### Phase 6 Deliverables

- [ ] Image cleanup workflow created
- [ ] Image metadata tracking added
- [ ] Performance monitoring workflow added
- [ ] Image size optimizations explored
- [ ] Performance dashboard created

### Phase 6 Testing Checklist

- [ ] Cleanup workflow runs successfully
- [ ] Image metadata visible
- [ ] Performance monitoring works
- [ ] Image size reduced (if optimized)
- [ ] Dashboard updates correctly

## Testing Strategy

### Unit Testing

**Composite Actions:**

- Test `build-push-image` in isolation
- Test `deploy-fly-app` with and without pre-built image
- Verify input/output handling

**Commands:**

```bash
# Test composite action locally (requires Fly auth)
cd .github/actions/build-push-image
# ... test steps ...
```

### Integration Testing

**Workflows:**

- Test each workflow in isolation with workflow_dispatch
- Verify image build and push
- Verify deployment with pre-built image
- Verify fallback to build-from-source

**Commands:**

```bash
# Test build-image workflow
gh workflow run build-image.yml --ref feature/prebuilt-images

# Test per-extension with specific extension
gh workflow run extension-tests.yml \
  --ref feature/prebuilt-images \
  -f extension_name=nodejs
```

### End-to-End Testing

**Full CI Suite:**

- Create PR with Dockerfile change
- Verify image rebuilt
- Verify all workflows use new image
- Verify timing improvements

**Commands:**

```bash
# Create test PR
echo "# Test" >> Dockerfile
git checkout -b test/e2e-prebuilt
git commit -am "test: e2e validation"
git push -u origin test/e2e-prebuilt
gh pr create --fill

# Monitor
gh pr checks
```

### Performance Testing

**Metrics to collect:**

- Build time (image creation)
- Deployment time (with pre-built image)
- Deployment time (from source, for comparison)
- Total workflow time
- Parallel deployment efficiency

**Baseline:** Run workflows before and after changes, compare times.

### Regression Testing

**Areas to verify:**

- Extension installations still work
- Volume persistence works
- SSH access works
- Environment variables set correctly
- All extension tests pass
- Integration tests pass
- No new failures introduced

### Stress Testing

**Scenarios:**

- Trigger all workflows simultaneously
- Verify parallel deployments work
- Check for race conditions
- Monitor Fly.io API rate limits

## Rollback Plan

### Immediate Rollback (Emergency)

**If critical issues arise:**

1. **Revert composite action:**

   ```bash
   git revert <commit-hash>  # Revert deploy-fly-app changes
   git push
   ```

2. **Workflows automatically fall back** to build-from-source (pre-built-image is optional)

3. **No data loss** - registry images remain available

**Time to rollback:** < 5 minutes

**Impact:** Workflows return to previous (slower) behavior

### Partial Rollback

**If specific workflows have issues:**

1. **Remove `pre_built_image` parameter** from problematic workflow:

   ```yaml
   # Before
   uses: ./.github/workflows/per-extension.yml
   with:
     pre_built_image: ${{ needs.build-image.outputs.image-url }}

   # After (rollback)
   uses: ./.github/workflows/per-extension.yml
   with:
     # pre_built_image removed, builds from source
   ```

2. **Commit and push**

3. **Other workflows** continue using pre-built images

**Time to rollback:** < 10 minutes per workflow

### Full Rollback

**If fundamental issues require complete rollback:**

1. **Revert all changes:**

   ```bash
   git revert <commit-range>  # Revert all prebuilt-image commits
   git push
   ```

2. **Remove build-image workflows:**

   ```bash
   git rm .github/workflows/build-image.yml
   git rm -r .github/actions/build-push-image
   git commit -m "rollback: remove pre-built image support"
   git push
   ```

3. **Clean up registry:**

   ```bash
   # Delete registry app (optional)
   flyctl apps destroy sindri-registry
   ```

**Time to rollback:** < 30 minutes

**Impact:** Return to previous architecture, no data loss

### Rollback Testing

**Before going live:**

1. Test rollback procedure on test branch
2. Verify workflows work after rollback
3. Document rollback steps clearly
4. Assign rollback authority to team lead

## Monitoring and Metrics

### Key Performance Indicators (KPIs)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Image build time | < 5 min | GitHub Actions logs |
| Deployment time (with image) | < 1 min | GitHub Actions logs |
| Deployment time (from source) | 3-5 min | Baseline measurement |
| Total workflow time reduction | 40-60% | Before/after comparison |
| Image reuse rate | > 80% | Builds skipped / total runs |
| Workflow failure rate | < 2% | Failed runs / total runs |

### Dashboards

**GitHub Actions:**

- Workflow run times (via Actions tab)
- Success/failure rates
- Job-level timing breakdown

**Metrics to track:**

- Average workflow duration (before/after)
- Image build frequency
- Image reuse frequency
- Deployment failure rate
- Time savings per workflow run

### Alerts

**Manual monitoring for:**

- Workflow failures after migration
- Significant performance degradation
- Image pull failures
- Registry capacity issues

**Future automation:**

- GitHub Actions status checks
- Slack/email notifications on failures
- Automatic rollback on critical failures

### Reporting

**Weekly report:**

- Workflow performance summary
- Time savings achieved
- Issues encountered
- Optimization opportunities

**Monthly report:**

- Total time savings
- Cost savings (Fly.io build minutes)
- Trend analysis
- Recommendations

## Risk Analysis

### Technical Risks

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Image build failures | High | Low | Fallback to build-from-source; retry logic |
| Registry unavailable | High | Low | Fly.io SLA; fallback to build-from-source |
| Stale images cause test failures | Medium | Medium | Rebuild on Dockerfile changes; manual trigger |
| Image pull rate limiting | Medium | Low | Fly.io likely no limits; monitor usage |
| Disk space issues (registry) | Low | Low | Implement cleanup; monitor size |
| Authentication failures | Medium | Low | Retry logic; clear error messages |
| Parallel deployment conflicts | Low | Low | Each deployment uses unique app name |
| Wrong image version deployed | Medium | Low | Strict tagging; validation checks |

### Operational Risks

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Team unfamiliar with new approach | Low | High | Documentation; training; examples |
| Debugging becomes harder | Medium | Medium | Image metadata; clear logging |
| Rollback complexity | Low | Low | Simple rollback process; tested procedure |
| Increased maintenance burden | Low | Medium | Good documentation; automation where possible |

### Business Risks

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Migration takes longer than planned | Low | Medium | Phased rollout; clear milestones |
| Performance gains not realized | Medium | Low | POC phase validates approach |
| Regression introduces production issues | High | Low | Thorough testing; gradual rollout |
| Cost increase (registry storage) | Low | Low | Monitor usage; implement cleanup |

### Risk Response Plan

**For each high-severity risk:**

1. **Image build failures:**
   - Immediate: Fallback to build-from-source
   - Short-term: Investigate failure, fix issue
   - Long-term: Add retry logic, better error handling

2. **Registry unavailable:**
   - Immediate: Fallback to build-from-source
   - Short-term: Check Fly.io status, wait for recovery
   - Long-term: Consider multi-registry approach (low priority)

3. **Regression introduces production issues:**
   - Immediate: Rollback changes
   - Short-term: Investigate root cause, fix issue
   - Long-term: Improve testing, add safeguards

## Timeline and Effort

### High-Level Timeline

| Phase | Duration | Dependencies | Effort (person-days) |
|-------|----------|--------------|----------------------|
| Phase 1: Foundation | 2-3 days | None | 2-3 |
| Phase 2: Proof of Concept | 2-3 days | Phase 1 | 2-3 |
| Phase 3: Single Workflow | 3-4 days | Phase 2 | 3-4 |
| Phase 4: Core Workflows | 5-7 days | Phase 3 | 5-7 |
| Phase 5: Full Rollout | 3-4 days | Phase 4 | 3-4 |
| Phase 6: Optimization | 2-3 days | Phase 5 | 2-3 |
| **Total** | **17-24 days** | | **17-24** |

### Detailed Task Estimates

**Phase 1: Foundation (2-3 days)**

| Task | Effort | Risk |
|------|--------|------|
| Create registry app | 0.25 days | Low |
| Create build-push action | 1 day | Low |
| Create build-image workflow | 1 day | Low |
| Testing | 0.5 days | Low |
| Documentation | 0.5 days | Low |

**Phase 2: Proof of Concept (2-3 days)**

| Task | Effort | Risk |
|------|--------|------|
| Update deploy-fly-app | 1 day | Medium |
| Create POC test workflow | 1 day | Low |
| Testing and validation | 1 day | Medium |
| Performance measurement | 0.5 days | Low |

**Phase 3: Single Workflow (3-4 days)**

| Task | Effort | Risk |
|------|--------|------|
| Update developer-workflow | 0.5 days | Low |
| Update integration orchestrator | 1 day | Medium |
| Implement image reuse | 1 day | Medium |
| Integration testing | 1.5 days | High |

**Phase 4: Core Workflows (5-7 days)**

| Task | Effort | Risk |
|------|--------|------|
| Update per-extension.yml | 0.5 days | Low |
| Update extension-tests orchestrator | 1 day | Medium |
| Update 9 child workflows | 2 days | Medium |
| Update integration workflows | 0.5 days | Low |
| Comprehensive testing | 3 days | High |

**Phase 5: Full Rollout (3-4 days)**

| Task | Effort | Risk |
|------|--------|------|
| Update remaining workflows | 1 day | Low |
| Update all documentation | 2 days | Low |
| Create migration guide | 0.5 days | Low |
| Final testing | 1 day | Medium |

**Phase 6: Optimization (2-3 days)**

| Task | Effort | Risk |
|------|--------|------|
| Image cleanup workflow | 1 day | Low |
| Image metadata tracking | 0.5 days | Low |
| Performance monitoring | 1 day | Low |
| Image optimization | 1 day | Medium |

### Resource Requirements

**Personnel:**

- 1 DevOps engineer (primary)
- 1 Developer (code reviews, testing)
- Access to CI/CD expertise (as needed)

**Infrastructure:**

- Fly.io account with API access
- GitHub repository with Actions enabled
- Docker registry space (minimal cost)

**Tools:**

- GitHub CLI (`gh`)
- Fly CLI (`flyctl`)
- Docker CLI
- Text editor / IDE

### Critical Path

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
         (POC)    (validation) (rollout)  (docs)   (optimize)
```

**Critical dependencies:**

- Phase 2 validates approach (go/no-go decision)
- Phase 3 proves pattern in production workflow
- Phase 4 achieves majority of benefits
- Phases 5-6 can be deprioritized if time-constrained

### Contingency Planning

**If timeline slips:**

1. **Minimum viable migration:**
   - Complete Phases 1-4 (foundation, POC, single workflow, core workflows)
   - Defer Phase 5 documentation to later
   - Skip Phase 6 optimization initially

2. **Parallel work:**
   - Multiple developers can update different workflows (Phase 4)
   - Documentation can be written in parallel with implementation

3. **Timeline padding:**
   - Add 20% buffer for unexpected issues
   - Plan for 3-week timeline (vs 2.5-week estimate)

## Success Criteria

### Phase-Level Success Criteria

**Phase 1: Foundation**

- [ ] Fly registry app created
- [ ] Composite action works
- [ ] Build workflow successful
- [ ] Image pushable/pullable

**Phase 2: Proof of Concept**

- [ ] POC workflow runs in both modes
- [ ] Performance improvement validated
- [ ] No functional regressions
- [ ] Go/no-go decision made

**Phase 3: Single Workflow**

- [ ] Production workflow uses pre-built images
- [ ] Image reuse working
- [ ] Integration tests pass
- [ ] Timing improved

**Phase 4: Core Workflows**

- [ ] All extension tests use pre-built images
- [ ] 30+ parallel deployments working
- [ ] API compliance tests passing
- [ ] Major time savings realized

**Phase 5: Full Rollout**

- [ ] All workflows migrated
- [ ] Documentation complete
- [ ] Migration guide available
- [ ] Team trained

**Phase 6: Optimization**

- [ ] Cleanup process documented
- [ ] Performance monitoring in place
- [ ] Optimizations explored
- [ ] Future improvements identified

### Overall Success Criteria

**Functional:**

- [ ] All workflows run successfully with pre-built images
- [ ] All tests pass (extensions, integration, API compliance)
- [ ] No functional regressions introduced
- [ ] Fallback to build-from-source works

**Performance:**

- [ ] Per-extension tests: 40-60% faster (30 min → 12-18 min)
- [ ] Integration tests: 40-50% faster (15 min → 8-10 min)
- [ ] Full CI suite: 40-60% faster (40 min → 16-24 min)
- [ ] Single deployment: 70-80% faster (5 min → 1-1.5 min)

**Operational:**

- [ ] Documentation complete and accurate
- [ ] Team understands new approach
- [ ] Troubleshooting guide available
- [ ] Rollback procedure tested
- [ ] Monitoring in place

**Business:**

- [ ] CI execution time reduced by 40-60%
- [ ] Developer feedback loop faster
- [ ] Infrastructure costs reduced (fewer build minutes)
- [ ] No increase in maintenance burden

### Acceptance Criteria

**For final sign-off:**

1. **All phases complete:** Phases 1-5 must be fully implemented and tested
2. **All tests passing:** Full CI suite passes on main branch
3. **Performance validated:** Timing improvements meet or exceed targets
4. **Documentation approved:** All docs reviewed and approved
5. **Team trained:** Team members comfortable with new approach
6. **No critical issues:** No high-severity bugs or regressions
7. **Rollback tested:** Rollback procedure validated

### Post-Launch Validation

**Week 1 after launch:**

- [ ] Monitor all workflow runs for failures
- [ ] Collect performance metrics
- [ ] Gather team feedback
- [ ] Fix any issues identified

**Week 2-4 after launch:**

- [ ] Analyze performance trends
- [ ] Optimize based on learnings
- [ ] Update documentation as needed
- [ ] Plan Phase 6 optimizations

**Month 2-3 after launch:**

- [ ] Complete Phase 6 optimizations
- [ ] Implement cleanup automation
- [ ] Add advanced monitoring
- [ ] Share learnings with community

---

## Appendix

### Glossary

- **Pre-built image:** Docker image built once and stored in registry
- **Registry:** Fly.io's Docker registry at registry.fly.io
- **Composite action:** Reusable GitHub Actions workflow component
- **Orchestrator workflow:** Parent workflow that calls child workflows
- **Image tag:** Unique identifier for a Docker image version
- **Fallback:** Automatic switch to build-from-source when image unavailable

### References

- [Fly.io Docker Registry](https://til.simonwillison.net/fly/fly-docker-registry)
- [GitHub Actions: Composite Actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [Docker Registry HTTP API V2](https://docs.docker.com/registry/spec/api/)
- [Fly.io Documentation](https://fly.io/docs/)

### Related Documents

- `.github/DOCKER_IMAGES.md` - Docker image management guide
- `.github/MIGRATION_PREBUILT_IMAGES.md` - Migration guide
- `.github/actions/README.md` - Composite actions documentation
- `CLAUDE.md` - Project CI/CD documentation

### Change Log

| Date | Author | Changes |
|------|--------|---------|
| 2025-01-03 | AI Assistant | Initial comprehensive plan created |

### Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Project Lead | | | |
| DevOps Lead | | | |
| Tech Lead | | | |

---

**Document Status:** Draft

**Last Updated:** 2025-01-03

**Next Review:** After Phase 2 completion
