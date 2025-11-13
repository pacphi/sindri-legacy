# IDE Remote Development Setup Guide

## Common setup guide for connecting any IDE to your Sindri development environment on Fly.io

> **⚡ Need to set up your Fly.io environment first?** Use our automated setup script:
> `./scripts/vm-setup.sh --app-name my-sindri-dev`. See the [Quick Start Guide](QUICKSTART.md) for details.

This guide covers the common setup steps for connecting any IDE to your Fly.io-hosted Sindri development
environment. For IDE-specific instructions, see:

- **[VS Code Setup](VSCODE.md)** - Visual Studio Code with Remote-SSH
- **[IntelliJ Setup](INTELLIJ.md)** - JetBrains IDEs with Gateway

## Prerequisites

Before setting up any IDE connection, ensure you have:

- ✅ Your Fly.io Sindri development environment deployed
- ✅ SSH key pair created and configured with Fly.io
- ✅ VM is running (check with `flyctl status -a your-app-name`)

### Environment Setup

If you haven't set up your Fly.io environment yet:

```bash
# Clone the repository
git clone https://github.com/pacphi/sindri.git
cd sindri

# Run automated setup
./scripts/vm-setup.sh --app-name my-sindri-dev --region sjc
```

The script will handle all the Fly.io configuration and provide connection details.

## SSH Configuration

### Step 1: Create SSH Configuration

Create or edit your SSH config file at `~/.ssh/config`:

```bash
# Replace 'my-sindri-dev' with your actual app name
Host sindri-dev
    HostName my-sindri-dev.fly.dev
    Port 10022
    User developer
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
    ServerAliveCountMax 3
    StrictHostKeyChecking accept-new
    LogLevel ERROR
    Compression yes

# Optional: Add a shorter alias
Host dev
    HostName my-sindri-dev.fly.dev
    Port 10022
    User developer
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### Step 2: Test SSH Connection

Before connecting any IDE, test the SSH connection:

```bash
ssh sindri-dev
```

You should connect successfully and see the welcome message from your VM.

## First-Time VM Configuration

**Important**: On your first connection to the VM, run the configuration script:

### Via Terminal (SSH or IDE)

1. Connect to your VM (SSH directly or through IDE terminal)
2. Run the configuration script:

   ```bash
   /workspace/scripts/vm-configure.sh
   ```

3. Follow the prompts to:
   - Install Node.js, Claude Code, and Claude Flow
   - Configure Git settings (name and email)
   - Set up workspace directory structure
   - Optionally install additional development tools
   - Optionally create project templates

4. Wait for completion - this only needs to be done once per VM

### Post-Configuration Workspace Structure

After configuration, your workspace will be organized as:

```text
/workspace/
├── projects/
│   ├── active/              # Current projects
│   └── archive/             # Completed projects
├── scripts/                 # Utility scripts
├── templates/               # Project templates
└── .config/                 # Configuration files
```

## Common Troubleshooting

For comprehensive troubleshooting including SSH issues, VM management, and performance optimization, see our
dedicated [Troubleshooting Guide](TROUBLESHOOTING.md).

### SSH Connection Issues

**Quick Debug Commands:**

```bash
# Test connection with verbose output
ssh -vvv developer@your-app-name.fly.dev -p 10022

# If host key verification fails after VM recreation:
ssh-keygen -R "[your-app-name.fly.dev]:10022"
```

**Common Solutions:**

1. Check if VM is running: `flyctl status -a your-app-name`
2. Start VM if stopped: `flyctl machine start <machine-id> -a your-app-name`
3. Verify SSH key permissions: `chmod 600 ~/.ssh/id_rsa`

### VM Management Issues

**VM Not Responding:**

```bash
# Check VM status
flyctl status -a your-app-name

# Restart VM if needed
flyctl machine restart <machine-id> -a your-app-name

# Check VM logs
flyctl logs -a your-app-name
```

## Development Workflow

### Project Organization

Work in the persistent `/workspace` directory:

```bash
# Navigate to active projects
cd /workspace/projects/active

# Create new project
mkdir my-project
cd my-project

# Initialize based on project type
npm init -y                    # Node.js
python3 -m venv venv          # Python
mvn archetype:generate        # Java/Maven
```

### Claude Code Integration

1. **Run Claude Code from Terminal**:

   ```bash
   cd /workspace/projects/active/your-project
   claude
   ```

2. **Create Project-Specific CLAUDE.md**:

   ```bash
   # Create a basic CLAUDE.md for your project
   cat > CLAUDE.md << 'EOF'
   # [PROJECT_NAME]

   ## Project Overview
   [Brief description]

   ## Development Commands
   [Add common commands]

   ## Architecture Notes
   [Add architectural decisions]
   EOF
   # Edit the file to add project-specific context
   ```

3. **Use Claude Flow for Multi-Agent Development**:

   ```bash
   npx claude-flow@alpha init --force
   npx claude-flow@alpha swarm "your development task"
   ```

### Git Configuration

Configure Git on the remote VM:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

**Optional SSH Agent Forwarding:**

Add to your SSH config for seamless Git operations:

```bash
Host sindri-dev
    ForwardAgent yes
    # ... other settings
```

## Terminal Utilities

The environment provides helpful utilities you can use in any IDE terminal:

### Common Library Functions

Source the common library for colored output and utilities:

```bash
# Source the common library for colored output
source /workspace/.system/lib/common.sh

# Use print functions in your terminal
print_success "Build completed!"
print_error "Tests failed"
print_warning "Low disk space"
print_status "Running deployment..."
```

### Available Utilities

**Common Functions:**

```bash
# Check if a command exists
if command_exists docker; then
    echo "Docker is available"
fi

# Create directories with proper ownership
create_directory "/workspace/my-project"

# Run commands with retry logic
retry_with_backoff 3 2 "npm install"
```

**Workspace Functions:**

```bash
# Source workspace utilities
source /workspace/.system/lib/workspace.sh

# Create a new project
setup_workspace_structure
create_project_templates
```

**Git Utilities:**

```bash
# Source Git utilities
source /workspace/.system/lib/git.sh

# Setup Git aliases and hooks
setup_git_aliases
setup_git_hooks
```

**Quick Commands:**

```bash
# System status
/workspace/scripts/system-status.sh

# Backup workspace
/workspace/scripts/backup.sh

# Create new project (language-specific)
/workspace/scripts/new-project.sh my-app node
```

## Performance Optimization

### Connection Optimization

**SSH Performance Settings:**

```bash
# Add to ~/.ssh/config for better performance
Host sindri-dev
    TCPKeepAlive yes
    ServerAliveInterval 30
    ServerAliveCountMax 6
    Compression yes
    ControlMaster auto
    ControlPath ~/.ssh/master-%r@%h:%p
    ControlPersist 600
```

### Resource Monitoring

Monitor VM resources and performance:

```bash
# Check system resources
htop
df -h /workspace
free -h

# Check network latency
ping your-app-name.fly.dev
```

### File System Optimization

**Exclude Large Directories:**

Configure your IDE to exclude these directories from indexing/watching:

- `node_modules/`
- `.git/objects/`
- `dist/` or `build/`
- `__pycache__/`
- `.venv/` or `venv/`
- `target/` (Java)

## Security Best Practices

1. **SSH Key Management**:
   - Use strong passphrases for SSH keys
   - Rotate keys regularly
   - Never share private keys

2. **Environment Variables for Secrets**:

   ```bash
   # Set secrets in Fly.io (not in code)
   flyctl secrets set API_KEY=your_secret -a your-app-name
   ```

3. **Regular Security Updates**:

   ```bash
   # Update system packages periodically
   sudo apt update && sudo apt upgrade
   ```

## Session Management

### Using tmux for Persistent Sessions

```bash
# Create named session
tmux new-session -s dev

# Detach: Ctrl+B, then D
# Reattach: tmux attach -t dev

# List sessions
tmux list-sessions
```

### Work Persistence

- All work in `/workspace` survives VM restarts
- Use Git commits frequently
- Run backup script periodically: `/workspace/scripts/backup.sh`

## Next Steps

After completing this common setup:

1. **Choose your IDE**:
   - **[VS Code Setup](VSCODE.md)** - For VS Code with Remote-SSH
   - **[IntelliJ Setup](INTELLIJ.md)** - For JetBrains IDEs with Gateway

2. **Explore Advanced Features**:
   - **[Customization Guide](CUSTOMIZATION.md)** - Advanced configuration options
   - **[Cost Management](COST_MANAGEMENT.md)** - Optimize your Fly.io costs

3. **Get Help**:
   - **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Solutions to common issues
   - **[Command Reference](REFERENCE.md)** - Complete command documentation
