# Registry Resilience Improvements

This document describes comprehensive improvements to make Sindri's CI/CD pipeline and extension system more resilient
to sporadic registry failures (Docker registry, APT mirrors, npm registry, PyPI, etc.).

## Table of Contents

- [Overview](#overview)
- [Implemented Changes](#implemented-changes)
- [Extension Retry Functions](#extension-retry-functions)
- [Workflow Improvements](#workflow-improvements)
- [Usage Examples](#usage-examples)
- [Testing Strategy](#testing-strategy)

## Overview

### Problem Statement

Sporadic failures occur in CI/CD pipelines and extension installations due to:

1. **Docker Registry Issues**: Image pull failures, timeout issues
2. **APT Repository Timeouts**: Ubuntu/Debian package registry slowness
3. **NPM Registry Failures**: Temporary npm registry unavailability
4. **PyPI Connectivity**: Python package download failures
5. **Network Transients**: General network connectivity issues
6. **Fly.io API Timeouts**: Deployment API temporary issues

### Solution Approach

Implement comprehensive retry logic with exponential backoff at multiple layers:

1. **Extension Layer**: Retry helpers for package managers (APT, npm, pip, wget, curl)
2. **Workflow Layer**: Retry logic for deployments, SSH commands, and machine operations
3. **Idempotent Operations**: Ensure all retries are safe to execute multiple times

## Implemented Changes

### 1. Registry Retry Helper Library

**Location**: `docker/lib/registry-retry.sh`

**Features**:

- APT update/install retry with package repair
- NPM install retry with cache clearing
- PIP install retry with cache purging
- wget/curl download retry with exponential backoff
- Automatic cleanup of failed partial installations

**Functions**:

```bash
apt_update_retry <max_attempts>
apt_install_retry <max_attempts> <packages...>
npm_install_retry <max_attempts> <packages...>
pip_install_retry <max_attempts> <packages...>
wget_retry <max_attempts> <url> <output_args...>
curl_retry <max_attempts> <curl_args...>
```

### 2. Extensions Common Library Update

**Location**: `docker/lib/extensions-common.sh`

**Change**: Automatically sources `registry-retry.sh` in `extension_init()`, making retry functions available to all extensions.

### 3. Resilient Integration Workflow

**Location**: `.github/workflows/integration-resilient.yml`

**Features**:

- Comprehensive retry utilities for Flyctl operations
- SSH command retry with exponential backoff
- Machine readiness checks with timeout
- Extension installation retry logic
- Detailed logging for debugging failures

**Key Functions**:

```bash
retry_with_backoff <max_attempts> <initial_delay> <max_delay> <command...>
flyctl_deploy_retry <app_name>
ssh_command_retry <app_name> <command>
wait_for_machine_ready <app_name>
```

## Extension Retry Functions

### APT Operations

**Before** (no retry):

```bash
install() {
  sudo apt-get update -qq
  sudo apt-get install -y package1 package2
}
```

**After** (with retry):

```bash
install() {
  # Automatically available after extension_init
  apt_update_retry 3
  apt_install_retry 3 package1 package2
}
```

**Benefits**:

- 3 retry attempts with exponential backoff (5s, 10s, 15s)
- Automatic `dpkg --configure -a` on failure
- Automatic `apt-get -f install` to fix broken dependencies

### NPM Operations

**Before** (no retry):

```bash
install() {
  npm install -g typescript eslint prettier
}
```

**After** (with retry):

```bash
install() {
  npm_install_retry 3 -g typescript eslint prettier
}
```

**Benefits**:

- 3 retry attempts with exponential backoff
- Automatic `npm cache clean --force` between retries
- Preserves all npm flags and arguments

### PIP Operations

**Before** (no retry):

```bash
install() {
  pip3 install requests numpy pandas
}
```

**After** (with retry):

```bash
install() {
  pip_install_retry 3 requests numpy pandas
}
```

**Benefits**:

- 3 retry attempts with exponential backoff
- Automatic `pip3 cache purge` between retries
- Quiet mode supported (`--quiet` flag preserved)

### Download Operations

**wget with retry**:

```bash
install() {
  # Download with 3 retries, 30s timeout per attempt
  wget_retry 3 "https://example.com/file.tar.gz" -O /tmp/file.tar.gz
}
```

**curl with retry**:

```bash
install() {
  # HTTP request with 3 retries, preserves all curl flags
  curl_retry 3 --fail --silent --show-error https://api.example.com/data
}
```

**Benefits**:

- Configurable retry count
- 30-second timeout per attempt
- Exponential backoff between retries

## Workflow Improvements

### Deployment Retry

**Implementation**:

```yaml
- name: Deploy with retry
  run: |
    source /tmp/retry_utils.sh
    flyctl_deploy_retry "${{ steps.app-name.outputs.app_name }}"
```

**Features**:

- 4 retry attempts (increased from 3)
- 180-second timeout per deployment
- Automatic log inspection for registry issues
- Exponential backoff: 15s, 30s, 45s

### SSH Command Retry

**Implementation**:

```yaml
- name: Execute command with retry
  run: |
    source /tmp/retry_utils.sh
    ssh_command_retry "$APP_NAME" "your-command-here"
```

**Features**:

- 5 retry attempts
- 30-second timeout per attempt
- Exponential backoff: 3s, 6s, 9s, 12s, 15s

### Machine Readiness Check

**Implementation**:

```yaml
- name: Wait for machine ready
  run: |
    source /tmp/retry_utils.sh
    wait_for_machine_ready "$APP_NAME"
```

**Features**:

- 30 retry attempts (60 seconds total)
- Checks both machine status and SSH responsiveness
- 2-second polling interval
- Detailed status reporting

### Extension Installation Retry

**Implementation**:

```yaml
- name: Install extension with retry
  run: |
    source /tmp/retry_utils.sh
    retry_with_backoff 3 10 60 \
      flyctl ssh console -a "$APP_NAME" \
        -C "extension-manager install nodejs"
```

**Features**:

- 3 retry attempts
- 10-60 second backoff range
- Works with any extension

## Usage Examples

### Example 1: Update Python Extension

**File**: `docker/lib/extensions.d/python.sh.example`

**Before**:

```bash
install() {
  print_status "Installing Python development environment..."

  sudo apt-get update -qq
  sudo apt-get install -y python3-full python3-dev python3-pip

  # ... rest of installation
}
```

**After**:

```bash
install() {
  print_status "Installing Python development environment..."

  # Use retry functions (automatically available after extension_init)
  apt_update_retry 3
  apt_install_retry 3 python3-full python3-dev python3-pip

  # ... rest of installation
}
```

### Example 2: Update Node.js Extension

**File**: `docker/lib/extensions.d/nodejs.sh.example`

**Before**:

```bash
install() {
  # Install NVM
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

  # Install global packages
  npm install -g typescript eslint prettier
}
```

**After**:

```bash
install() {
  # Install NVM with retry
  curl_retry 3 -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

  # Install global packages with retry
  npm_install_retry 3 -g typescript eslint prettier
}
```

### Example 3: Update Rust Extension

**File**: `docker/lib/extensions.d/rust.sh.example`

**Before**:

```bash
install() {
  # Install Rust toolchain
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

  # Install components
  rustup component add clippy rustfmt
}
```

**After**:

```bash
install() {
  # Install Rust toolchain with retry
  curl_retry 3 --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

  # Components install (rustup has built-in retry, but we can wrap for consistency)
  retry_with_backoff 3 5 30 rustup component add clippy rustfmt
}
```

### Example 4: Resilient Workflow Job

**Complete job example**:

```yaml
test-extension:
  runs-on: ubuntu-latest
  timeout-minutes: 30

  steps:
    - uses: actions/checkout@v5

    - name: Setup retry utilities
      run: |
        # Copy retry_utils.sh setup from integration-resilient.yml
        cat > /tmp/retry_utils.sh << 'EOF'
        # ... retry functions ...
        EOF
        source /tmp/retry_utils.sh

    - name: Deploy and test
      env:
        FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
      run: |
        source /tmp/retry_utils.sh

        # Deploy with retry
        flyctl_deploy_retry "my-app"

        # Wait for readiness
        wait_for_machine_ready "my-app"

        # Test with retry
        ssh_command_retry "my-app" "extension-manager install python"
```

## Testing Strategy

### Integration Testing in CI

**Current approach**:

- `.github/workflows/integration-resilient.yml` serves as comprehensive integration test
- Tests all retry scenarios: deployment, SSH, extensions, machine operations
- Generates unique app names to avoid conflicts
- Automatic cleanup on completion

**Running manually**:

```bash
# Trigger workflow manually
gh workflow run integration-resilient.yml

# Monitor progress
gh run watch
```

### Extension Testing

**Test extensions individually**:

```bash
# Deploy test VM
flyctl deploy --app test-extension-retry

# Test extension installation with retry
flyctl ssh console -a test-extension-retry -C \
  "DEBUG=true extension-manager install python"

# Verify retry messages appear in output
# Expected output:
# ▶️  APT update attempt 1 of 3...
# ✅ APT update successful
# ▶️  APT install attempt 1 of 3...
# ✅ APT install successful
```

## Migration Guide

### Phase 1: Update Core Extensions (High Priority)

Extensions with frequent registry issues:

1. **python** - APT + pip operations
2. **nodejs** - curl + npm operations
3. **rust** - curl + cargo operations
4. **golang** - wget + go install operations
5. **docker** - APT + docker registry pulls

**Action**: Add retry wrappers to all `apt-get`, `npm install`, `pip3 install`, `wget`, `curl` commands.

### Phase 2: Update Workflows (High Priority)

1. **integration.yml** - Replace with `integration-resilient.yml`
2. **extension-tests.yml** - Add retry utilities to all extension test jobs

**Action**: Copy retry_utils.sh setup to all workflow jobs that interact with Fly.io or install packages.

### Phase 3: Update Remaining Extensions (Medium Priority)

Extensions with less frequent issues:

- php, ruby, jvm, dotnet (language runtimes)
- docker, infra-tools, cloud-tools (infrastructure)
- monitoring, playwright (utilities)

**Action**: Systematic review and update of all extension install/configure functions.

### Phase 4: Documentation Update (Low Priority)

1. Update CUSTOMIZATION.md with retry examples
2. Update template.sh.example to show retry patterns
3. Update REFERENCE.md with retry function documentation

## Monitoring and Metrics

### Success Metrics

Track the following to measure improvement:

1. **CI Success Rate**: Percentage of workflows passing on first attempt
2. **Retry Usage**: How often retries are needed
3. **Time to Recovery**: Average time from failure to successful retry
4. **Extension Install Success**: Percentage of extensions installing successfully

### Logging

**Current logging**:

- Retry attempts logged with attempt number: `▶️  Attempt 1 of 3...`
- Success logged: `✅ Command succeeded`
- Failures logged with exit codes: `❌ Command failed (exit: 1)`
- Registry issues detected: `🔍 Detected potential registry issue`

**Enhanced logging** (future):

- Aggregate retry statistics to workflow summary
- Track which registries cause most failures
- Alert on consistent failures (not resolved by retry)

## Troubleshooting

### Retries Not Working

**Symptom**: Commands still failing without retry attempts

**Check**:

1. Verify `extension_init` called at start of extension
2. Confirm `registry-retry.sh` exists and is executable
3. Check that function is being called correctly

**Debug**:

```bash
# Test retry function directly
source docker/lib/registry-retry.sh
DEBUG=true apt_update_retry 3
```

### Excessive Retry Delays

**Symptom**: Installation taking too long due to retries

**Solution**:

- Reduce max_delay parameter: `retry_with_backoff 3 5 30` instead of `3 5 60`
- Reduce max_attempts for fast-failing scenarios
- Add timeout wrappers: `timeout 60 retry_with_backoff ...`

### Retry Exhaustion

**Symptom**: All retries fail, indicating persistent issue

**Investigation**:

1. Check if registry is actually down (not transient)
2. Verify network connectivity from Fly.io region
3. Check if package name/version is correct
4. Review full error logs for authentication or permission issues

**Mitigation**:

- Use alternative registries (APT mirrors, npm mirrors)
- Implement fallback package sources
- Add pre-flight connectivity checks

## Future Enhancements

### 1. Adaptive Retry Strategy

Adjust retry behavior based on error type:

```bash
smart_retry() {
  local error_msg="$1"

  if [[ "$error_msg" =~ "timeout" ]]; then
    # Network timeout: more retries, longer delays
    retry_with_backoff 5 10 120 "$@"
  elif [[ "$error_msg" =~ "404" ]]; then
    # Not found: don't retry
    return 1
  else
    # Generic error: standard retry
    retry_with_backoff 3 5 60 "$@"
  fi
}
```

### 2. Circuit Breaker Pattern

Prevent hammering a known-bad registry:

```bash
circuit_breaker_retry() {
  local circuit_file="/tmp/circuit-breaker-$1"

  # Check if circuit is open (too many recent failures)
  if [[ -f "$circuit_file" ]]; then
    local last_failure=$(cat "$circuit_file")
    local now=$(date +%s)
    if [[ $((now - last_failure)) -lt 300 ]]; then
      echo "⚠️  Circuit breaker open, skipping retry"
      return 1
    fi
  fi

  # Attempt operation
  if retry_with_backoff "$@"; then
    rm -f "$circuit_file"
    return 0
  else
    date +%s > "$circuit_file"
    return 1
  fi
}
```

### 3. Alternative Registry Support

Fallback to mirrors when primary fails:

```bash
apt_install_with_fallback() {
  local packages="$@"

  # Try primary
  if apt_install_retry 2 $packages; then
    return 0
  fi

  # Try mirrors
  for mirror in "http://mirror1.example.com" "http://mirror2.example.com"; do
    echo "⚠️  Trying fallback mirror: $mirror"
    sudo sed -i "s|http://archive.ubuntu.com|$mirror|g" /etc/apt/sources.list
    apt_update_retry 2

    if apt_install_retry 2 $packages; then
      return 0
    fi
  done

  return 1
}
```

## References

- [GitHub Actions: Retry Pattern](https://github.com/marketplace/actions/retry-action)
- [Exponential Backoff and Jitter](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Fly.io: Machine Restart API](https://fly.io/docs/machines/api/)
