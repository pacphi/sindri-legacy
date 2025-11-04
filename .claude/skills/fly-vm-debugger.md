---
name: fly-vm-debugger
description: Diagnose and troubleshoot Fly.io VM issues including SSH connectivity, health checks, volume persistence, and deployment failures
---

# Fly.io VM Debugger Skill

This skill helps diagnose and resolve common Fly.io VM issues in the Sindri development environment.

## Diagnostic Capabilities

### 1. SSH Connection Issues

**Symptoms**:

- SSH connection refused
- Timeout connecting to VM
- Authentication failures
- Port conflicts

**Diagnostic Steps**:

```bash
# Check app status
flyctl status -a <app-name>

# Check machine status
flyctl machine list -a <app-name>

# Check specific machine
flyctl machine status <machine-id> -a <app-name>

# Test SSH with verbose output
ssh -vvv developer@<app-name>.fly.dev -p 10022

# Alternative: Use Fly.io hallpass
flyctl ssh console -a <app-name>
```

**Common Fixes**:

1. **Port Conflict** (CI_MODE issue):
   - Symptom: Custom SSH daemon conflicts with hallpass
   - Fix: Ensure CI_MODE=true for test deployments
   - Verification: Check if port 2222 is accessible

2. **Machine Not Running**:
   - Symptom: Machine in 'stopped' or 'suspended' state
   - Fix: `flyctl machine start <machine-id>`
   - Verification: Status shows 'started'

3. **Health Check Failures**:
   - Symptom: Machine starts but health checks fail
   - Fix: Increase timeout or disable health checks in CI
   - Command: `flyctl deploy --strategy immediate`

### 2. Health Check Issues

**Symptoms**:

- Deployment succeeds but VM marked unhealthy
- Continuous restart loops
- Timeout during deployment

**Diagnostic Steps**:

```bash
# View recent logs
flyctl logs -a <app-name>

# Check health check configuration
cat fly.toml | grep -A 10 "http_service"

# Monitor machine events
flyctl machine status <machine-id> --watch
```

**Common Fixes**:

1. **Slow Startup**:
   - Increase grace_period in fly.toml
   - Use --wait-timeout in deployment

2. **CI Mode Health Checks**:
   - Use `--strategy immediate` to skip health checks
   - Set appropriate timeout: `--wait-timeout 60s`

3. **SSH Daemon Conflicts**:
   - In CI mode, SSH daemon should be disabled
   - Verify CI_MODE environment variable is set

### 3. Volume Persistence Issues

**Symptoms**:

- Files disappear after restart
- 0-byte files after machine restart
- Volume not mounted correctly

**Diagnostic Steps**:

```bash
# List volumes
flyctl volumes list -a <app-name>

# Check volume status
flyctl volumes show <volume-id>

# Verify mount in VM
flyctl ssh console -C "df -h | grep workspace" -a <app-name>

# Check file permissions
flyctl ssh console -C "ls -la /workspace" -a <app-name>
```

**Common Fixes**:

1. **0-Byte File Issue**:
   - Symptom: Files exist but have 0 bytes
   - Cause: Filesystem not synced before restart
   - Fix: Add explicit sync in CI tests:

   ```bash
   flyctl ssh console -C "/bin/bash -c 'echo test > /workspace/test.txt && sync'" -a $APP
   ```

2. **Volume Not Mounted**:
   - Check fly.toml for correct mount configuration
   - Verify volume exists: `flyctl volumes list`
   - Check machine is in correct region

3. **Permission Issues**:
   - Files owned by wrong user
   - Fix: `chown -R developer:developer /workspace/path`

### 4. Deployment Failures

**Symptoms**:

- Deployment hangs
- Timeout errors
- Machine fails to start

**Diagnostic Steps**:

```bash
# Check recent deployments
flyctl releases -a <app-name>

# View deployment logs
flyctl logs -a <app-name> --verbose

# Check machine events
flyctl machine list -a <app-name>

# Inspect machine configuration
flyctl machine status <machine-id> -a <app-name>
```

**Common Fixes**:

1. **Network/Registry Issues**:
   - Retry deployment: `flyctl deploy --now`
   - Check Fly.io status: https://status.flyio.net

2. **Resource Constraints**:
   - Increase machine resources in fly.toml
   - Check for memory/CPU limits

3. **Configuration Errors**:
   - Validate fly.toml syntax
   - Check environment variables
   - Verify secrets are set

### 5. CI/CD Test Failures

**Symptoms**:

- Extension tests timeout
- SSH commands fail after restart
- Integration tests flaky

**Diagnostic Steps**:

```bash
# Check GitHub Actions logs
gh run view <run-id> --log

# Test SSH command execution
flyctl ssh console -C "/bin/bash -c 'echo test'" -a <app-name>

# Verify machine readiness
flyctl machine status <machine-id>
```

**Common Fixes**:

1. **SSH Command Execution**:
   - Always use explicit bash invocation:
   - Correct: `flyctl ssh console -C "/bin/bash -c 'command'" -a $APP`
   - Wrong: `flyctl ssh console -C "command" -a $APP`

2. **Machine Readiness**:
   - Add proper wait after restart:

   ```bash
   flyctl machine restart $MACHINE_ID
   timeout 120 bash -c 'until flyctl machine status $MACHINE_ID | grep -q "started"; do sleep 2; done'
   ```

3. **Extension Installation Timeouts**:
   - Increase timeout in test script
   - Use CI_MODE to skip unnecessary steps
   - Check network connectivity

## Quick Diagnostic Commands

**Complete Health Check**:

```bash
# Run all diagnostic checks
APP_NAME="your-app"

echo "=== App Status ==="
flyctl status -a $APP_NAME

echo "=== Machine List ==="
flyctl machine list -a $APP_NAME

echo "=== Recent Logs ==="
flyctl logs -a $APP_NAME --tail 50

echo "=== Volume Status ==="
flyctl volumes list -a $APP_NAME

echo "=== SSH Test ==="
flyctl ssh console -C "/bin/bash -c 'echo SSH OK && df -h /workspace'" -a $APP_NAME
```

**Machine Restart Recovery**:

```bash
# Safe machine restart with verification
MACHINE_ID="your-machine-id"
APP_NAME="your-app"

# Stop machine
flyctl machine stop $MACHINE_ID

# Start machine
flyctl machine start $MACHINE_ID --wait-timeout 120s

# Wait for ready state
timeout 120 bash -c "
  until flyctl machine status $MACHINE_ID | grep -q 'started'; do
    echo 'Waiting for machine to start...'
    sleep 2
  done
"

# Verify SSH access
flyctl ssh console -C "/bin/bash -c 'echo Machine ready'" -a $APP_NAME
```

## Common Error Patterns

### Error: "Error: failed to fetch an image or build from source"

**Cause**: Network issue or registry unavailable

**Fix**:

```bash
# Retry deployment
flyctl deploy --now --remote-only
```

### Error: "Error: failed to start machine: timeout"

**Cause**: Machine taking too long to start or health checks failing

**Fix**:

```bash
# Use immediate strategy (skip health checks)
flyctl deploy --strategy immediate --wait-timeout 300s
```

### Error: "SSH connection refused"

**Cause**: SSH daemon not running or port conflict

**Fix**:

```bash
# Use hallpass instead
flyctl ssh console -a <app-name>

# Or restart machine
flyctl machine restart <machine-id>
```

### Error: "Volume not found"

**Cause**: Volume deleted or in wrong region

**Fix**:

```bash
# List volumes to verify
flyctl volumes list -a <app-name>

# Create new volume if needed
flyctl volumes create <volume-name> --region <region> --size 10
```

## Recovery Procedures

### Complete VM Recovery

```bash
APP_NAME="your-app"

# 1. Check status
flyctl status -a $APP_NAME

# 2. Get machine ID
MACHINE_ID=$(flyctl machine list -a $APP_NAME -j | jq -r '.[0].id')

# 3. Restart machine
flyctl machine restart $MACHINE_ID

# 4. Wait for ready
sleep 10

# 5. Verify SSH
flyctl ssh console -C "/bin/bash -c 'echo Ready'" -a $APP_NAME

# 6. Check volume
flyctl ssh console -C "ls -la /workspace" -a $APP_NAME
```

### Emergency Teardown and Redeploy

```bash
APP_NAME="your-app"

# Complete teardown
./scripts/vm-teardown.sh

# Fresh deployment
./scripts/vm-setup.sh --app-name $APP_NAME
```

## Prevention Best Practices

1. **Always use CI_MODE** for test deployments
2. **Explicit bash invocation** for all SSH commands
3. **Add sync before file operations** in tests
4. **Use proper timeouts** for all network operations
5. **Wait for machine readiness** after restart
6. **Clean up resources** in always() blocks
7. **Check machine status** before operations
8. **Use retry logic** for transient failures

## Monitoring Commands

```bash
# Real-time monitoring
flyctl logs -a <app-name> --tail

# Watch machine status
watch -n 2 flyctl machine list -a <app-name>

# Monitor resources
flyctl ssh console -C "top -b -n 1 | head -20" -a <app-name>
```

This skill provides comprehensive diagnostics for Fly.io VM issues specific to the Sindri development environment.
