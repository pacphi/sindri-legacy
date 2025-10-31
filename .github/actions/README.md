# Composite Actions for Fly.io Testing

This directory contains reusable composite actions for Fly.io test environment management.

## Available Actions

### Infrastructure Actions
- **setup-fly-test-env** - Complete test environment setup
- **deploy-fly-app** - Deploy Fly.io app with volumes and secrets
- **wait-fly-deployment** - Wait for machine to reach desired state
- **cleanup-fly-app** - Destroy test resources

### Test Actions
- **test-ssh-connectivity** - Test SSH connectivity with retries
- **test-vm-configuration** - Validate VM setup and tools
- **test-volume-mount** - Verify volume mount and permissions
- **test-volume-persistence** - Test data persistence across restarts
- **test-machine-lifecycle** - Test machine stop/start cycle

### Utility Actions
- **run-vm-script** - Copy and execute scripts on VM

---

## Action Details

### setup-fly-test-env

Sets up the complete test environment for Fly.io extension testing.

**What it does:**
1. Checks out the code
2. Installs Fly CLI
3. Generates a unique app name with timestamp
4. Creates SSH key pair for VM access
5. Prepares fly.toml with test configuration

**Usage:**
```yaml
- name: Setup Fly.io test environment
  id: setup
  uses: ./.github/actions/setup-fly-test-env
  with:
    app-prefix: "ext-test"
    extension-name: "nodejs"
    vm-memory: "8192"  # Optional, default: 8192
    vm-cpu-count: "4"  # Optional, default: 4
```

**Outputs:**
- `app-name`: Generated Fly.io app name
- `ssh-key-path`: Path to private key (test_key)
- `ssh-pubkey-path`: Path to public key (test_key.pub)

---

### deploy-fly-app

Deploys a Fly.io app with volume and secrets, including retry logic.

**What it does:**
1. Creates Fly.io app
2. Creates and attaches volume
3. Sets SSH and CI secrets
4. Deploys with automatic retries (default: 3 attempts)

**Usage:**
```yaml
- name: Deploy test environment
  uses: ./.github/actions/deploy-fly-app
  with:
    app-name: ${{ steps.setup.outputs.app-name }}
    region: "sjc"
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    deploy-timeout: "300"  # Optional, default: 300s
```

**Features:**
- Automatic retry with exponential backoff
- Configurable timeout and retry attempts
- Volume creation and attachment
- SSH key injection

---

### wait-fly-deployment

Waits for Fly.io machine to reach desired state.

**What it does:**
1. Polls machine status at regular intervals
2. Waits for specified status (started or running)
3. Adds extra wait for SSH daemon initialization
4. Shows logs on failure

**Usage:**
```yaml
- name: Wait for deployment
  uses: ./.github/actions/wait-fly-deployment
  with:
    app-name: ${{ steps.setup.outputs.app-name }}
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    timeout-seconds: "240"      # Optional, default: 240
    expected-status: "started"  # Optional, default: started
```

**Features:**
- Configurable timeout and poll interval
- Flexible status matching (started/running)
- Automatic log retrieval on failure
- SSH daemon initialization wait

---

### cleanup-fly-app

Destroys all test resources (machines, volumes, app).

**What it does:**
1. Stops all machines
2. Destroys all machines
3. Destroys all volumes
4. Destroys the app
5. Removes SSH keys (optional)

**Usage:**
```yaml
- name: Cleanup test resources
  if: always()  # Run even on failure
  uses: ./.github/actions/cleanup-fly-app
  with:
    app-name: ${{ steps.setup.outputs.app-name }}
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
```

**Features:**
- Safe cleanup (continues on errors)
- Handles missing resources gracefully
- Optional SSH key cleanup
- Always runs with `if: always()`

---

### test-ssh-connectivity

Tests SSH connectivity to Fly.io machine with automatic retries.

**What it does:**
1. Attempts SSH connection with configurable retries
2. Verifies SSH environment is ready
3. Shows comprehensive diagnostics on failure
4. Provides configurable timeouts and retry intervals

**Usage:**
```yaml
- name: Test SSH connectivity
  uses: ./.github/actions/test-ssh-connectivity
  with:
    app-name: ${{ steps.setup.outputs.app-name }}
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    max-attempts: "8"       # Optional, default: 8
    wait-between: "15"      # Optional, default: 15s
```

**Features:**
- Automatic retry with configurable attempts
- SSH timeout protection
- Environment verification (user, home, path, workspace)
- Comprehensive diagnostic output on failure

---

### test-vm-configuration

Validates VM configuration, tools, and extension system.

**What it does:**
1. Checks extension manager presence
2. Verifies extension directory structure
3. Tests required tools availability
4. Validates workspace directory

**Usage:**
```yaml
- name: Test VM configuration
  uses: ./.github/actions/test-vm-configuration
  with:
    app-name: ${{ steps.setup.outputs.app-name }}
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    required-tools: "curl,git,ssh"  # Optional, default: curl,git,ssh
```

**Features:**
- Configurable required tools list
- Extension system validation
- Clear success/failure reporting

---

### test-volume-mount

Verifies volume mount, permissions, and write capability.

**What it does:**
1. Checks volume mount with df
2. Verifies directory contents and permissions
3. Tests write permissions
4. Shows mount information

**Usage:**
```yaml
- name: Test volume mount
  uses: ./.github/actions/test-volume-mount
  with:
    app-name: ${{ steps.setup.outputs.app-name }}
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    mount-path: "/workspace"  # Optional, default: /workspace
```

**Features:**
- Comprehensive mount verification
- Permission validation
- Write capability testing
- Detailed diagnostics

---

### test-volume-persistence

Tests volume persistence across machine restarts.

**What it does:**
1. Creates test file with unique content
2. Forces filesystem sync
3. Restarts machine
4. Verifies file and content after restart
5. Provides retry logic for verification

**Usage:**
```yaml
- name: Test volume persistence
  uses: ./.github/actions/test-volume-persistence
  with:
    app-name: ${{ steps.setup.outputs.app-name }}
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    test-path: "/workspace"  # Optional, default: /workspace
```

**Features:**
- Comprehensive persistence testing
- Filesystem sync verification
- Content validation with retry logic
- Detailed debugging on failure

---

### test-machine-lifecycle

Tests machine stop/start lifecycle with proper state polling.

**What it does:**
1. Stops machine with verification
2. Waits for full stop state
3. Starts machine
4. Waits for full started state
5. Provides configurable timeouts and retry logic

**Usage:**
```yaml
- name: Test machine lifecycle
  uses: ./.github/actions/test-machine-lifecycle
  with:
    app-name: ${{ steps.setup.outputs.app-name }}
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    stop-timeout: "60"       # Optional, default: 60s
    start-timeout: "120"     # Optional, default: 120s
```

**Features:**
- Proper state polling (fixes race conditions)
- Configurable timeouts
- Comprehensive status verification
- Detailed phase reporting

---

### run-vm-script

Generic utility to copy and execute scripts on VM.

**What it does:**
1. Copies local script to VM via SFTP
2. Executes script via SSH
3. Captures and displays output
4. Provides success/failure status

**Usage:**
```yaml
- name: Run custom test script
  uses: ./.github/actions/run-vm-script
  with:
    app-name: ${{ steps.setup.outputs.app-name }}
    fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
    script-path: .github/scripts/my-test.sh
    vm-destination: "/tmp"   # Optional, default: /tmp
    script-args: "arg1 arg2" # Optional
```

**Features:**
- SFTP file transfer
- Script execution with arguments
- Clear status reporting
- Error handling

---

## Complete Example

### Full Integration Test Workflow

```yaml
name: Integration Test

on:
  push:
    branches: [main]

env:
  TEST_APP_PREFIX: "integration-test"
  REGION: "sjc"

jobs:
  integration:
    runs-on: ubuntu-latest
    steps:
      # Setup and deployment
      - uses: actions/checkout@v5

      - name: Setup Fly.io test environment
        id: setup
        uses: ./.github/actions/setup-fly-test-env
        with:
          app-prefix: ${{ env.TEST_APP_PREFIX }}
          extension-name: integration
          vm-memory: "1024"
          vm-cpu-count: "1"
          volume-size: "5"

      - name: Deploy test environment
        uses: ./.github/actions/deploy-fly-app
        with:
          app-name: ${{ steps.setup.outputs.app-name }}
          region: ${{ env.REGION }}
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}

      - name: Wait for deployment
        uses: ./.github/actions/wait-fly-deployment
        with:
          app-name: ${{ steps.setup.outputs.app-name }}
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}

      # Test suite using new composite actions
      - name: Test SSH connectivity
        uses: ./.github/actions/test-ssh-connectivity
        with:
          app-name: ${{ steps.setup.outputs.app-name }}
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}

      - name: Test VM configuration
        uses: ./.github/actions/test-vm-configuration
        with:
          app-name: ${{ steps.setup.outputs.app-name }}
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}

      - name: Test volume mount
        uses: ./.github/actions/test-volume-mount
        with:
          app-name: ${{ steps.setup.outputs.app-name }}
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}

      - name: Test volume persistence
        uses: ./.github/actions/test-volume-persistence
        with:
          app-name: ${{ steps.setup.outputs.app-name }}
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}

      - name: Test machine lifecycle
        uses: ./.github/actions/test-machine-lifecycle
        with:
          app-name: ${{ steps.setup.outputs.app-name }}
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}

      - name: Run custom test script
        uses: ./.github/actions/run-vm-script
        with:
          app-name: ${{ steps.setup.outputs.app-name }}
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
          script-path: .github/scripts/my-test.sh

      # Cleanup
      - name: Cleanup test resources
        if: always()
        uses: ./.github/actions/cleanup-fly-app
        with:
          app-name: ${{ steps.setup.outputs.app-name }}
          fly-api-token: ${{ secrets.FLYIO_AUTH_TOKEN }}
```

## Development

### Testing Actions Locally

Composite actions can't be easily tested locally, but you can:

1. **Test individual steps**: Extract bash scripts from actions and run them
2. **Use act**: Test workflows with [act](https://github.com/nektos/act)
3. **Create test workflow**: Small workflow in separate branch

### Adding New Actions

1. Create directory under `.github/actions/<action-name>/`
2. Add `action.yml` with:
   - Clear name and description
   - Documented inputs with defaults
   - Useful outputs
   - Shell/composite steps
3. Update this README
4. Add usage example in WORKFLOW_REFACTORING.md

### Best Practices

- **Idempotent**: Actions should be safe to run multiple times
- **Error handling**: Use `|| true` for non-critical steps
- **Clear outputs**: Provide useful outputs for downstream steps
- **Documentation**: Document all inputs, outputs, and behavior
- **Defaults**: Provide sensible defaults for optional inputs
- **Secrets**: Never log or expose secrets
- **Timeouts**: Use reasonable timeouts to prevent hanging

## Troubleshooting

### Action not found

**Error**: `Can't find action.yml at ./.github/actions/setup-fly-test-env`

**Solution**: Ensure you've checked out the code first:
```yaml
- uses: actions/checkout@v5  # Required before using local actions
```

### Invalid inputs

**Error**: `Unexpected input(s) 'foo'`

**Solution**: Check action.yml for valid input names. All inputs are case-sensitive.

### API token issues

**Error**: `401 Unauthorized`

**Solution**: Ensure `FLYIO_AUTH_TOKEN` secret is set in repository settings.

### Cleanup not running

**Issue**: Resources left behind after failed tests

**Solution**: Always use `if: always()` on cleanup step:
```yaml
- name: Cleanup
  if: always()  # Critical: run even on failure
  uses: ./.github/actions/cleanup-fly-app
  # ...
```

## See Also

- [WORKFLOW_REFACTORING.md](../WORKFLOW_REFACTORING.md) - Complete refactoring documentation
- [Test Scripts](../scripts/extension-tests/) - Reusable test scripts
- [Composite Actions Guide](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
