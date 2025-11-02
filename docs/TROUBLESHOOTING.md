# 🛠️ Troubleshooting Guide

This comprehensive guide helps resolve common issues with your Sindri development environment on Fly.io.

## Table of Contents

1. [SSH Connection Issues](#ssh-connection-issues)
2. [Creating and Managing SSH Keys](#creating-and-managing-ssh-keys)
3. [VM Management Issues](#vm-management-issues)
4. [Configuration Problems](#configuration-problems)
5. [SSH Service Architecture](#ssh-service-architecture)
6. [IDE Connection Issues](#ide-connection-issues)
7. [Performance Issues](#performance-issues)
8. [Cost and Billing Issues](#cost-and-billing-issues)
9. [Claude Tools Issues](#claude-tools-issues)
10. [mise Troubleshooting](#mise-troubleshooting)

## SSH Connection Issues

### Understanding SSH Connection Methods

Sindri provides **two ways** to connect to your VM. Understanding when to use each is important for the best experience.

#### Method 1: Regular SSH (Recommended for Daily Use)

```bash
ssh developer@<app-name>.fly.dev -p 10022
```

**When to use:**

- ✅ Normal development work
- ✅ Running extension-manager commands
- ✅ IDE remote development (VSCode, IntelliJ)
- ✅ Daily workflow operations

**Benefits:**

- Automatically connects as `developer` user
- Full shell environment with .bashrc loaded
- Best performance and user experience
- Works with IDE remote development
- No additional flags needed

**How it works:**

- Uses custom SSH daemon on port 10022
- Configured via `ssh-environment` protected extension
- Persistent SSH keys in `/workspace/developer/.ssh/`

#### Method 2: flyctl ssh console (Troubleshooting/Emergency)

```bash
# Default (connects as root)
flyctl ssh console -a <app-name>

# Connect as developer user (for extension work)
flyctl ssh console -a <app-name> --user developer
```

**When to use:**

- ⚠️ Port 10022 SSH is broken
- ⚠️ Emergency access needed
- ⚠️ Debugging system-level issues
- ⚠️ SSH daemon troubleshooting

**Important Notes:**

- **Defaults to root user** - good for system troubleshooting
- Use `--user developer` flag when running extension commands
- Uses Fly.io's built-in hallpass service (always available)
- Fallback when custom SSH daemon fails

**User Context Matters:**

```bash
# ❌ BAD: Extensions install to /root/.local/ (won't be in developer's PATH)
flyctl ssh console -a my-app -C "extension-manager install nodejs"

# ✅ GOOD: Extensions install to /workspace/developer/.local/
flyctl ssh console -a my-app --user developer -C "extension-manager install nodejs"

# ✅ BEST: Use regular SSH instead
ssh developer@my-app.fly.dev -p 10022
# Then run: extension-manager install nodejs
```

#### Quick Decision Guide

| Scenario                   | Use This Method                                          |
| -------------------------- | -------------------------------------------------------- |
| Daily development          | `ssh developer@<app>.fly.dev -p 10022`                   |
| Running extension-manager  | `ssh developer@<app>.fly.dev -p 10022`                   |
| IDE remote development     | `ssh developer@<app>.fly.dev -p 10022`                   |
| Port 10022 not working     | `flyctl ssh console -a <app> --user developer`           |
| System debugging (as root) | `flyctl ssh console -a <app>`                            |
| Check sshd status          | `flyctl ssh console -a <app> -C "systemctl status sshd"` |

**Key Takeaway:** For regular development, always use standard SSH (port 10022). Only use `flyctl ssh console` as a fallback, and remember to add `--user developer` if running extension or development commands.

---

### Host Key Verification Failed

**Problem:** After tearing down and recreating a VM with the same name, you get:

```bash
kex_exchange_identification: read: Connection reset by peer
Connection reset by 2a09:8280:1::8c:fcda:0 port 10022
```

**Solution:** Remove the old host key from your known_hosts file:

```bash
# For standard hostnames
ssh-keygen -R "[my-sindri-dev.fly.dev]:10022"

# If you have IPv6 addresses cached
ssh-keygen -R "[2a09:8280:1::8c:fcda:0]:10022"

# Then retry your connection
ssh developer@my-sindri-dev.fly.dev -p 10022
```

**Why this happens:** SSH stores host keys to prevent man-in-the-middle attacks. When you recreate a VM,
it gets a new host key, causing a mismatch with the stored key.

### Connection Refused

**Problem:** SSH connection is immediately refused.

**Solutions:**

1. Check if the VM is running:

   ```bash
   flyctl status -a my-sindri-dev
   flyctl machine list -a my-sindri-dev
   ```

2. If the VM is suspended, resume it:

   ```bash
   ./scripts/vm-resume.sh --app-name my-sindri-dev
   # Wait 30-60 seconds for the VM to fully start
   ```

3. Check VM logs for errors:

   ```bash
   flyctl logs -a my-sindri-dev
   ```

### Connection Timeout

**Problem:** SSH connection hangs and eventually times out.

**Solutions:**

1. Test with verbose output to see where it fails:

   ```bash
   ssh -vvv developer@my-sindri-dev.fly.dev -p 10022
   ```

2. Check if the app is accessible:

   ```bash
   flyctl ping -a my-sindri-dev
   ```

3. Verify your firewall isn't blocking port 10022:

   ```bash
   # Test connectivity
   nc -zv my-sindri-dev.fly.dev 10022
   ```

### Permission Denied (publickey)

**Problem:** SSH rejects your authentication.

**Solutions:**

1. Verify you're using the correct private key:

   ```bash
   ssh -i ~/.ssh/id_rsa developer@my-sindri-dev.fly.dev -p 10022
   ```

2. Check key permissions (must be 600 for private keys):

   ```bash
   ls -la ~/.ssh/id_rsa
   chmod 600 ~/.ssh/id_rsa
   ```

3. Ensure your public key was deployed:

   ```bash
   flyctl ssh console -a my-sindri-dev
   cat /workspace/developer/.ssh/authorized_keys
   ```

## Creating and Managing SSH Keys

If you don't have SSH keys yet, follow these steps:

### Creating New SSH Keys

#### Option 1: Ed25519 (Recommended - more secure and faster)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "your-email@example.com"
```

#### Option 2: RSA (broader compatibility)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -C "your-email@example.com"
```

### Setting Correct Permissions

SSH requires specific permissions for security:

```bash
# For RSA keys
chmod 600 ~/.ssh/id_rsa        # Private key - owner read/write only
chmod 644 ~/.ssh/id_rsa.pub    # Public key - readable by others

# For Ed25519 keys
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# SSH directory itself
chmod 700 ~/.ssh
```

### Common SSH Key Mistakes

1. **Using the wrong key file in SSH config**
   - ❌ Wrong: `IdentityFile ~/.ssh/id_rsa.pub` (public key)
   - ✅ Correct: `IdentityFile ~/.ssh/id_rsa` (private key)

2. **Incorrect permissions**
   - SSH will refuse to use keys with incorrect permissions
   - Private keys must be 600 (read/write for owner only)

3. **Multiple keys confusion**
   - Use `ssh -i` to specify which key to use
   - Or configure in `~/.ssh/config` for automatic selection

### Adding Keys to SSH Agent

For convenience, add your key to the SSH agent:

```bash
# Start the agent
eval "$(ssh-agent -s)"

# Add your key
ssh-add ~/.ssh/id_rsa
# or
ssh-add ~/.ssh/id_ed25519

# List loaded keys
ssh-add -l
```

## VM Management Issues

### VM Won't Start

**Problem:** The VM fails to start or crashes immediately.

**Solutions:**

1. Check machine status and logs:

   ```bash
   flyctl status -a my-sindri-dev
   flyctl machine list -a my-sindri-dev
   flyctl logs -a my-sindri-dev
   ```

2. Restart the machine:

   ```bash
   flyctl machine restart <machine-id> -a my-sindri-dev
   ```

3. Check resource allocation:

   ```bash
   flyctl scale show -a my-sindri-dev
   ```

### VM Suspended Unexpectedly

**Problem:** VM suspends while you're working.

**Solutions:**

1. Adjust auto-stop settings in `fly.toml`:

   ```toml
   [services.concurrency]
   auto_stop_machines = "suspend"
   auto_start_machines = true
   min_machines_running = 0
   ```

2. Keep VM running with activity:

   ```bash
   # Run a keep-alive command
   while true; do date; sleep 300; done
   ```

### Volume Not Mounting

**Problem:** `/workspace` directory is empty or missing.

**Solutions:**

1. Check volume attachment:

   ```bash
   flyctl volumes list -a my-sindri-dev
   ```

2. Verify mount in machine config:

   ```bash
   flyctl config show -a my-sindri-dev
   ```

3. Restart with volume check:

   ```bash
   flyctl machine restart <machine-id> -a my-sindri-dev --force
   ```

## Configuration Problems

### Scripts Not Found

**Problem:** Configuration scripts are missing in `/workspace/scripts/`.

**Solutions:**

1. The scripts are created on first VM deployment. If missing:

   ```bash
   # Redeploy the application
   flyctl deploy -a my-sindri-dev
   ```

2. Check if volume is mounted correctly:

   ```bash
   df -h /workspace
   ls -la /workspace/
   ```

### Node.js/npm Not Available

**Problem:** `node` or `npm` commands not found.

**Solution:** Run the configuration script:

```bash
/workspace/scripts/vm-configure.sh
source ~/.bashrc
```

### Git Configuration Missing

**Problem:** Git commits fail with "Please tell me who you are" error.

**Solution:** The configuration script sets this up, but you can manually configure:

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

## SSH Service Architecture

### Understanding Dual SSH Access

Your Claude environment provides two SSH access methods:

#### 1. **Custom SSH Daemon** (Primary for Development)

- **External Port**: 10022 (what you connect to)
- **Internal Port**: 2222 (where SSH daemon runs)
- **Usage**: `ssh developer@<app-name>.fly.dev -p 10022`
- **Purpose**: IDE connections, file transfers, persistent sessions

#### 2. **Fly.io Hallpass Service** (Built-in)

- **Internal Port**: 22 (Fly.io's built-in service)
- **Usage**: `flyctl ssh console -a <app-name>`
- **Purpose**: Quick access, debugging, CI/CD operations

### Common SSH Architecture Issues

#### Port Conflicts in CI/CD

**Problem:** Integration tests fail with health check loops or port binding errors.

**Cause:** Custom SSH daemon trying to bind to port 22 conflicts with Fly.io's hallpass service.

**Solution:** The system automatically resolves this:

- **Production**: SSH daemon runs on port 2222, no conflicts
- **CI Mode**: SSH daemon disabled entirely, only hallpass available

#### When to Use Which SSH Method

**Use Custom SSH (`ssh -p 10022`)** for:

- IDE remote development (VSCode, IntelliJ)
- File transfers (rsync, scp)
- Long-running sessions
- Port forwarding

**Use Flyctl SSH (`flyctl ssh console`)** for:

- Quick debugging and inspection
- CI/CD pipeline access
- When custom SSH is unavailable
- Emergency access

#### Troubleshooting SSH Service Issues

**Check which SSH services are running:**

```bash
# Via flyctl
flyctl ssh console -a <app-name> --command "ps aux | grep ssh"

# Expected output:
# root   123  sshd: hallpass (Fly.io service on port 22)
# root   456  sshd: custom daemon (your service on port 2222)
```

**Test both access methods:**

```bash
# Test custom SSH
ssh developer@<app-name>.fly.dev -p 10022 'echo "Custom SSH working"'

# Test flyctl SSH
flyctl ssh console -a <app-name> --command 'echo "Hallpass SSH working"'
```

**Common fixes:**

1. **Custom SSH not responding**: Check VM status and restart if needed
2. **Flyctl SSH not working**: Check Fly.io authentication and app status
3. **Port 10022 blocked**: Check local firewall or try flyctl SSH as alternative

## IDE Connection Issues

### VSCode Remote-SSH Issues

See [IDE Setup Guide](IDE_SETUP.md#common-troubleshooting) for general issues and
[VSCode Setup Guide](VSCODE.md#vs-code-troubleshooting) for VS Code-specific troubleshooting.

Common quick fixes:

1. Clear VSCode's remote server cache:

   ```bash
   rm -rf ~/.vscode-server
   ```

2. Restart VSCode and reconnect

### IntelliJ Gateway Issues

See [IDE Setup Guide](IDE_SETUP.md#common-troubleshooting) for general issues and
[IntelliJ Setup Guide](INTELLIJ.md#intellij-troubleshooting) for IntelliJ-specific troubleshooting.

Common quick fixes:

1. Clear Gateway cache
2. Verify SSH configuration in Gateway settings
3. Try connecting via terminal first to verify SSH works

## Performance Issues

### Slow SSH Connection

**Solutions:**

1. Add connection multiplexing to `~/.ssh/config`:

   ```bash
   Host my-sindri-dev
       ControlMaster auto
       ControlPath ~/.ssh/control-%r@%h:%p
       ControlPersist 10m
   ```

2. Use a region closer to you:

   ```bash
   flyctl regions list
   ./scripts/vm-setup.sh --app-name my-claude --region <closer-region>
   ```

### VM Running Slowly

**Solutions:**

1. Check current resources:

   ```bash
   flyctl scale show -a my-sindri-dev
   ```

2. Scale up if needed:

   ```bash
   flyctl scale vm shared-cpu-2x -a my-sindri-dev
   flyctl scale memory 2048 -a my-sindri-dev
   ```

3. Use performance CPU for intensive workloads:

   ```bash
   flyctl scale vm performance-2x -a my-sindri-dev
   ```

## Cost and Billing Issues

### Unexpected Charges

**Problem:** Higher than expected Fly.io charges.

**Solutions:**

1. Monitor usage regularly:

   ```bash
   ./scripts/cost-monitor.sh
   ```

2. Ensure auto-suspend is working:

   ```bash
   flyctl status -a my-sindri-dev
   # Should show "stopped" when not in use
   ```

3. Suspend VMs when not needed:

   ```bash
   ./scripts/vm-suspend.sh --app-name my-sindri-dev
   ```

4. Review Fly.io dashboard:
   - Check at [Fly.io Dashboard](https://fly.io/dashboard)
   - Look for running machines you forgot about

### Reducing Costs

1. **Use shared CPU instead of performance**:

   ```bash
   flyctl scale vm shared-cpu-1x -a my-sindri-dev
   ```

2. **Reduce memory allocation**:

   ```bash
   flyctl scale memory 512 -a my-sindri-dev
   ```

3. **Delete unused volumes**:

   ```bash
   flyctl volumes list -a my-sindri-dev
   flyctl volumes destroy <volume-id> -a my-sindri-dev
   ```

## Claude Tools Issues

### Claude Authentication Failed

**Problem:** Can't authenticate Claude Code.

**Solutions:**

1. Check if you have a valid subscription or API key

2. Re-run authentication:

   ```bash
   claude logout
   claude
   ```

3. For API key authentication:

   ```bash
   export ANTHROPIC_API_KEY="sk-ant-..."
   claude
   ```

### Claude Flow Init Fails

**Problem:** `npx claude-flow@alpha init` fails.

**Solutions:**

1. Ensure you're in a project directory:

   ```bash
   cd /workspace/projects/active/your-project
   ```

2. Clear npm cache and retry:

   ```bash
   npm cache clean --force
   npx claude-flow@alpha init --force
   ```

3. Check Node.js version:

   ```bash
   node --version  # Should be 18.x or later
   ```

## mise Troubleshooting

### Tool Version Conflicts

**Problem:** Multiple tools trying to use different versions of the same dependency.

**Symptoms:**

```bash
mise: Command failed with exit code 1
mise: Tool X requires version Y but version Z is installed
```

**Solutions:**

1. Check which tools are managing the same dependency:

   ```bash
   mise ls
   mise current
   ```

2. Review your `.mise.toml` for conflicting version specifications:

   ```bash
   cat .mise.toml
   ```

3. Resolve conflicts by:
   - Standardizing on a single version across all tools
   - Using version ranges instead of exact pins
   - Removing duplicate tool definitions

4. Clear mise cache and reinstall:

   ```bash
   mise cache clear
   mise install --force
   ```

### mise Registry Unavailable

**Problem:** Cannot download tools from mise registry.

**Symptoms:**

```bash
mise: Failed to fetch registry
mise: Connection timeout to registry.mise.jdx.dev
```

**Solutions:**

1. Check network connectivity:

   ```bash
   curl -I https://registry.mise.jdx.dev
   ```

2. Verify DNS resolution:

   ```bash
   nslookup registry.mise.jdx.dev
   ```

3. Use offline mode with local cache:

   ```bash
   mise install --offline
   ```

4. Temporarily use GitHub backend if registry is down:

   ```bash
   export MISE_USE_GITHUB_BACKEND=1
   mise install
   ```

5. Check Fly.io network restrictions:

   ```bash
   flyctl ssh console -a <app-name>
   curl -v https://registry.mise.jdx.dev
   ```

### Tool Not Found After Installation

**Problem:** Tool installed via mise but command not available in PATH.

**Symptoms:**

```bash
mise install node@20
# Installation succeeds
node --version
# bash: node: command not found
```

**Solutions:**

1. Verify mise is properly initialized in shell:

   ```bash
   mise doctor
   # Look for shell integration status
   ```

2. Check if mise shims directory is in PATH:

   ```bash
   echo $PATH | grep mise
   ```

3. Activate mise in current shell:

   ```bash
   eval "$(mise activate bash)"
   # or for zsh
   eval "$(mise activate zsh)"
   ```

4. Verify tool is actually installed:

   ```bash
   mise ls
   mise which node
   ```

5. Reload shell configuration:

   ```bash
   source ~/.bashrc
   # or
   exec bash -l
   ```

6. Check for conflicting tool managers:

   ```bash
   which -a node  # Shows all instances in PATH
   ```

### mise doctor Output Interpretation

**Problem:** Understanding `mise doctor` diagnostics.

**Usage:**

```bash
mise doctor
```

**Key Indicators:**

1. **Shell Integration**:

   ```
   ✓ shell: bash
   ✓ mise hook: installed
   ```

   - ✓ means mise is properly integrated
   - ✗ means shell hook is missing - run `mise activate`

2. **Configuration Files**:

   ```
   ✓ config: /workspace/projects/active/myapp/.mise.toml
   ✓ config: ~/.config/mise/config.toml
   ```

   - Shows which config files are being loaded
   - Order matters: project-level overrides global

3. **Tool Installation**:

   ```
   ✓ node@20.11.0: installed at /home/developer/.local/share/mise/installs/node/20.11.0
   ✗ python@3.12: not installed
   ```

   - ✓ means tool is installed and working
   - ✗ means tool needs installation

4. **PATH Configuration**:
   ```
   ✓ mise shims in PATH
   ✗ conflicting version managers detected
   ```

   - Check for conflicts with nvm, rbenv, pyenv, etc.

**Common Issues and Fixes**:

- **Shell hook not installed**: Add to `~/.bashrc`:

  ```bash
  eval "$(mise activate bash)"
  ```

- **Config file not found**: Create project config:

  ```bash
  mise use node@20
  ```

- **Tool not in PATH**: Verify shims directory:
  ```bash
  ls -la $(mise config dir)/shims
  ```

### TOML Syntax Errors

**Problem:** Malformed `.mise.toml` configuration files.

**Symptoms:**

```bash
mise: TOML parse error at line 5
mise: Invalid TOML syntax
```

**Common Mistakes:**

1. **Missing quotes around strings**:

   ```toml
   # Wrong
   [tools]
   node = 20.11.0

   # Correct
   [tools]
   node = "20.11.0"
   ```

2. **Incorrect array syntax**:

   ```toml
   # Wrong
   [env]
   PATH = "$HOME/bin:$PATH"

   # Correct
   [env]
   _.path = ["$HOME/bin"]
   ```

3. **Invalid environment variable format**:

   ```toml
   # Wrong
   [env]
   MY_VAR = value with spaces

   # Correct
   [env]
   MY_VAR = "value with spaces"
   ```

4. **Duplicate keys**:

   ```toml
   # Wrong - duplicate [tools] section
   [tools]
   node = "20"
   [tools]
   python = "3.12"

   # Correct
   [tools]
   node = "20"
   python = "3.12"
   ```

**Validation:**

1. Use mise to validate syntax:

   ```bash
   mise config validate
   ```

2. Check for common issues:

   ```bash
   mise ls --json 2>&1 | grep -i error
   ```

3. Use TOML linter:

   ```bash
   # Install taplo (TOML formatter/linter)
   cargo install taplo-cli
   taplo check .mise.toml
   ```

### Permission Issues with ~/.config/mise

**Problem:** Cannot write to mise configuration directory.

**Symptoms:**

```bash
mise: Permission denied: /home/developer/.config/mise/config.toml
mise: Failed to create directory /home/developer/.local/share/mise
```

**Solutions:**

1. Check directory ownership:

   ```bash
   ls -la ~/.config/mise
   ls -la ~/.local/share/mise
   ```

2. Fix ownership if incorrect:

   ```bash
   sudo chown -R $(whoami):$(whoami) ~/.config/mise
   sudo chown -R $(whoami):$(whoami) ~/.local/share/mise
   ```

3. Fix directory permissions:

   ```bash
   chmod 755 ~/.config/mise
   chmod 755 ~/.local/share/mise
   chmod 644 ~/.config/mise/config.toml
   ```

4. If directories don't exist, create them:

   ```bash
   mkdir -p ~/.config/mise
   mkdir -p ~/.local/share/mise/{installs,plugins,shims}
   ```

5. For VM environment, verify workspace volume is mounted:

   ```bash
   df -h /workspace
   mount | grep workspace
   ```

6. Reset mise directory structure:

   ```bash
   # Backup existing config
   cp ~/.config/mise/config.toml ~/mise-config-backup.toml

   # Remove and recreate
   rm -rf ~/.config/mise ~/.local/share/mise
   mise doctor  # Will recreate directories

   # Restore config
   cp ~/mise-config-backup.toml ~/.config/mise/config.toml
   ```

**Prevention:**

- Always run mise as the developer user, not root
- Ensure `/workspace` is properly mounted before using mise
- Add mise directories to backup scripts to preserve configuration

## Getting More Help

If your issue isn't covered here:

1. **Check logs for detailed error messages**:

   ```bash
   flyctl logs -a my-sindri-dev --since 1h
   ```

2. **Enable debug mode for scripts**:

   ```bash
   DEBUG=true ./scripts/vm-setup.sh --app-name my-sindri-dev
   ```

3. **Enable mise debug output**:

   ```bash
   MISE_DEBUG=1 mise install
   MISE_VERBOSE=1 mise doctor
   ```

4. **Community resources**:
   - [Fly.io Community Forum](https://community.fly.io)
   - [Claude Documentation](https://docs.anthropic.com)
   - [mise Documentation](https://mise.jdx.dev)
   - [GitHub Issues](https://github.com/pacphi/sindri/issues)

5. **Contact support**:
   - [Fly.io Support](https://fly.io/docs/about/support/)
   - [Anthropic Support](https://support.anthropic.com)
   - [mise GitHub Issues](https://github.com/jdx/mise/issues)

Remember to include:

- Exact error messages
- Commands you ran
- Output from `flyctl status` and `flyctl logs`
- Output from `mise doctor` if mise-related
- Your `fly.toml` and `.mise.toml` configurations (remove any secrets)
