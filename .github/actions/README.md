# Composite Actions for Fly.io Testing

This directory contains reusable composite actions for Fly.io test environment management.

## Available Actions

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

## Complete Example

```yaml
name: Test Extension

on:
  push:
    branches: [main]

env:
  TEST_APP_PREFIX: "ext-test"
  REGION: "sjc"

jobs:
  test-nodejs:
    runs-on: ubuntu-latest
    steps:
      - name: Setup Fly.io test environment
        id: setup
        uses: ./.github/actions/setup-fly-test-env
        with:
          app-prefix: ${{ env.TEST_APP_PREFIX }}
          extension-name: nodejs

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

      - name: Run tests
        env:
          FLY_API_TOKEN: ${{ secrets.FLYIO_AUTH_TOKEN }}
        run: |
          # Your test commands here
          flyctl ssh console --app ${{ steps.setup.outputs.app-name }} \
            --user developer \
            --command "node --version"

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
