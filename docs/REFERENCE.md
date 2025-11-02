# Command Reference

## VM Management Commands

### Initial Setup

**Deploy new VM:**

```bash
./scripts/vm-setup.sh --app-name <name> --region <region>

# Options:
--app-name <name>         # Fly.io application name (required)
--region <region>         # Deployment region (default: sjc)
--cpu-kind <shared|performance>  # CPU type (default: shared)
--cpu-count <number>      # Number of CPUs (default: 1)
--memory <mb>             # Memory in MB (default: 1024)
--volume-size <gb>        # Storage size in GB (default: 30)

# Examples:
./scripts/vm-setup.sh --app-name dev-vm --region lax
./scripts/vm-setup.sh --app-name prod-vm --cpu-kind performance --cpu-count 2 --memory 4096
```

**Configure environment (first time):**

```bash
# On the VM after SSH connection
/workspace/scripts/vm-configure.sh

# Options:
--extensions-only         # Run only extension scripts
--skip-extensions         # Skip extension installation
--verbose                 # Show detailed output
--help                    # Show usage information
```

### VM Lifecycle

**Suspend VM (save costs):**

```bash
./scripts/vm-suspend.sh [app-name]

# If no app-name provided, uses current directory name
# Suspends all machines in the application
```

**Resume VM:**

```bash
./scripts/vm-resume.sh [app-name]

# Starts all suspended machines
# VM will also auto-resume on SSH connection
```

**Restart VM:**

```bash
flyctl machine restart <machine-id> -a <app-name>

# Get machine ID:
flyctl machine list -a <app-name>
```

**Completely remove VM and resources:**

```bash
./scripts/vm-teardown.sh --app-name <name>

# Options:
--app-name <name>        # Application to remove (required)
--backup                # Create backup before removal
--force                 # Skip confirmation prompts

# Examples:
./scripts/vm-teardown.sh --app-name old-dev --backup
./scripts/vm-teardown.sh --app-name test-env --force
```

### VM Status and Monitoring

**Check VM status:**

```bash
flyctl status -a <app-name>
flyctl machine list -a <app-name>
flyctl logs -a <app-name>
flyctl metrics -a <app-name>
```

**Resource monitoring:**

```bash
./scripts/cost-monitor.sh

# Options:
--action <status|history|export|budget|alert>
--export-format <csv|json> # For export action
--export-file <filename>   # Output file for export
--monthly-limit <amount>   # For budget action
--threshold <percentage>   # Alert threshold
--daily-email <email>      # For alert notifications
--notify <slack|email>     # Notification method

# Examples:
./scripts/cost-monitor.sh --action status
./scripts/cost-monitor.sh --action export --export-format csv --export-file usage.csv
./scripts/cost-monitor.sh --action budget --monthly-limit 50
```

## Data Management Commands

### Backup Operations

**Create backup:**

```bash
./scripts/volume-backup.sh

# Options:
--action <full|incremental|sync|analyze>
--project <name>           # Backup specific project
--destination <path>       # Backup destination
--compress                 # Compress backup files
--exclude-cache            # Skip cache directories

# Examples:
./scripts/volume-backup.sh --action full --compress
./scripts/volume-backup.sh --project my-app --destination /external/backup
./scripts/volume-backup.sh --action incremental --exclude-cache
```

**Restore from backup:**

```bash
./scripts/volume-restore.sh --file <backup-file>

# Options:
--file <path>              # Backup file to restore (required)
--destination <path>       # Restore destination (default: /workspace)
--partial                  # Allow partial restoration
--verify                   # Verify backup integrity before restore

# Examples:
./scripts/volume-restore.sh --file backup_20250104_120000.tar.gz
./scripts/volume-restore.sh --file backup.tar.gz --destination /workspace/restore --verify
```

### Volume Management

**List volumes:**

```bash
flyctl volumes list -a <app-name>
```

**Create additional volume:**

```bash
flyctl volumes create <name> --region <region> --size <gb> -a <app-name>

# Options:
--region <region>          # Volume region
--size <gb>                # Volume size in GB
--encrypted                # Enable encryption (if supported)
--snapshot-id <id>         # Create from snapshot
```

**Extend volume:**

```bash
flyctl volumes extend <volume-id> --size <gb> -a <app-name>
```

## AI Model Management Commands

### agent-flow (Multi-Model AI)

Cost-optimized AI routing across 100+ models from multiple providers.

**Core commands:**

```bash
# Basic usage
af "task description"                  # Auto-select optimal model
af-help                                # Show all commands

# Agent-specific tasks
af-coder "Create REST API"             # Development tasks
af-reviewer "Review security"          # Code review
af-researcher "Research patterns"      # Research tasks

# Provider selection
af-claude "task"                       # Use Anthropic Claude
af-openrouter "task"                   # Use OpenRouter
af-gemini "task"                       # Use Google Gemini

# Optimization modes
af-cost "task"                         # Minimize cost
af-quality "task"                      # Maximize quality
af-speed "task"                        # Fastest response
af-llama "task"                        # Specific model (Llama 3.1)

# Utility functions
af-task <agent> "task"                 # Balanced optimization
af-provider <provider> "task"          # Provider wrapper
```

**Configuration:**

```bash
# Required for agent-flow
export ANTHROPIC_API_KEY=sk-ant-...   # Already configured

# Optional providers (cost optimization)
flyctl secrets set OPENROUTER_API_KEY=sk-or-... -a <app-name>
flyctl secrets set GOOGLE_GEMINI_API_KEY=... -a <app-name>
```

**Get API keys:**

- OpenRouter: <https://openrouter.ai/keys> (pay-per-use, no subscription)
- Gemini: <https://makersuite.google.com/app/apikey> (free tier available)

See [Cost Management](COST_MANAGEMENT.md#ai-model-cost-optimization-with-agent-flow) for optimization strategies.

## Development Commands

### SSH Connection

**Connect to VM:**

```bash
ssh developer@<app-name>.fly.dev -p 10022

# With specific key:
ssh -i ~/.ssh/specific_key developer@<app-name>.fly.dev -p 10022

# Connection troubleshooting:
ssh -vvv developer@<app-name>.fly.dev -p 10022
```

**SSH key management:**

```bash
# Add new SSH key
flyctl ssh issue --agent --email user@example.com -a <app-name>

# Console access (emergency)
flyctl ssh console -a <app-name>
```

### Project Management

**Create new project:**

```bash
# On the VM
/workspace/scripts/lib/new-project.sh <project-name> [options]

# Options:
--type <node|python|go|rust|web>  # Project type
--git-name "<name>"               # Git user name
--git-email "<email>"             # Git user email
--github-repo                     # Create GitHub repository
--claude-init                     # Initialize Claude Flow

# Examples:
/workspace/scripts/lib/new-project.sh my-api --type node --github-repo
/workspace/scripts/lib/new-project.sh data-analysis --type python --claude-init
```

**Clone and enhance existing project:**

```bash
clone-project <repository-url> [options]

# Options:
--fork                    # Fork repository before cloning
--branch <name>           # Clone specific branch
--feature <name>          # Create feature branch after clone
--git-name "<name>"       # Configure git user name
--git-email "<email>"     # Configure git user email
--no-enhance              # Skip Claude enhancements

# Examples:
clone-project https://github.com/user/repo --fork --feature my-changes
clone-project https://github.com/company/app --branch develop --git-name "John" --git-email "john@company.com"
```

### AI Development Tools

**Claude Code:**

```bash
# Start Claude Code session
claude

# Authenticate (first time)
claude auth

# Check version and status
claude --version
claude --help
```

**Claude Flow:**

```bash
# Initialize Claude Flow in project
cd /workspace/projects/active/my-project
npx claude-flow@alpha init --force

# Start swarm development
npx claude-flow@alpha swarm "implement user authentication"

# Swarm management
npx claude-flow@alpha swarm list          # List active swarms
npx claude-flow@alpha swarm status        # Check swarm status
npx claude-flow@alpha swarm stop          # Stop current swarm

# Agent management
npx claude-flow@alpha agent list          # List available agents
npx claude-flow@alpha agent run <name>    # Run specific agent
```

## Configuration Commands

### Environment Configuration

**System status:**

```bash
# On the VM
/workspace/scripts/lib/system-status.sh

# Check specific components
/workspace/scripts/lib/validate-setup.sh
```

**Git configuration:**

```bash
# Global git setup
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Project-specific git
cd /workspace/projects/active/project-name
git config user.name "Project Name"
git config user.email "project@company.com"
```

**Environment variables:**

```bash
# Set secrets via Fly.io
flyctl secrets set API_KEY=value -a <app-name>
flyctl secrets set DATABASE_URL="postgresql://..." -a <app-name>

# List current secrets
flyctl secrets list -a <app-name>

# Remove secret
flyctl secrets unset API_KEY -a <app-name>
```

### Extension Management

Sindri uses **Extension API v1.0** with manifest-based activation. Extensions are managed through the
`extension-manager` command and controlled via the `active-extensions.conf` manifest.

**List available extensions:**

```bash
extension-manager list
```

**Install an extension (auto-activates and installs):**

```bash
extension-manager install <name>

# Examples:
extension-manager install rust
extension-manager install python
extension-manager install docker

# Or use interactive mode for guided setup
extension-manager --interactive

# Or install all extensions from manifest
extension-manager install-all
```

**Check extension status:**

```bash
extension-manager status <name>
```

**Validate extension installation:**

```bash
extension-manager validate <name>

# Validate all active extensions
extension-manager validate-all
```

**Deactivate extension (removes from manifest):**

```bash
extension-manager deactivate <name>
```

**Uninstall extension:**

```bash
extension-manager uninstall <name>
```

**Reorder extension priority:**

```bash
extension-manager reorder <name> <position>
```

**Create custom extension:**

Custom extensions must implement the Extension API v1.0 with 6 required functions:

```bash
# Create new extension at docker/lib/extensions.d/custom.sh.example
cat > docker/lib/extensions.d/custom.sh.example << 'EOF'
#!/bin/bash
# custom.sh.example - Custom tools extension
# Implements Extension API v1.0

source /workspace/scripts/lib/common.sh

# Extension metadata
EXT_NAME="custom"
EXT_VERSION="1.0.0"
EXT_DESCRIPTION="Custom development tools"

# Required API functions
prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."
  # Check requirements
  print_success "All prerequisites met"
  return 0
}

install() {
  print_status "Installing ${EXT_NAME}..."
  # Installation commands
  print_success "Installation complete"
  return 0
}

configure() {
  print_status "Configuring ${EXT_NAME}..."
  # Configuration steps
  print_success "Configuration complete"
  return 0
}

validate() {
  print_status "Validating ${EXT_NAME}..."
  # Validation checks
  print_success "Validation passed"
  return 0
}

status() {
  print_status "Status for ${EXT_NAME}:"
  # Display installation status
  return 0
}

remove() {
  print_status "Removing ${EXT_NAME}..."
  # Cleanup steps
  print_success "Removal complete"
  return 0
}
EOF

# Install the custom extension (auto-activates)
extension-manager install custom
```

For detailed extension development, see the [Extension System README](../docker/lib/extensions.d/README.md).

## mise Commands

**mise** (https://mise.jdx.dev) is a modern polyglot tool version manager that provides unified management for language
runtimes and development tools. Sindri uses mise to standardize tool installation across extensions.

### Core Commands

**List installed tools:**

```bash
mise ls                          # List all installed tools and versions
mise ls node                     # List Node.js installations
mise ls --current               # Show currently active versions
mise ls --json                  # Output in JSON format

# Examples:
mise ls                         # Show all tools
mise ls python                  # Show Python versions
```

**Install tools:**

```bash
mise install                     # Install all tools from mise.toml
mise install node@22            # Install specific Node.js version
mise install python@3.13        # Install specific Python version
mise install npm:typescript     # Install npm package globally

# Examples:
mise install                    # Install from config
mise install rust@stable        # Install stable Rust
mise install cargo:ripgrep      # Install ripgrep via cargo
```

**Use/activate tools:**

```bash
mise use <tool>@<version>       # Add tool to mise.toml and install
mise use node@lts               # Use Node.js LTS version
mise use python@3.13            # Use Python 3.13
mise use npm:prettier           # Use npm package globally

# Options:
--global, -g                    # Install globally (~/.config/mise/config.toml)
--pin                          # Pin exact version
--path <path>                  # Specify mise.toml location

# Examples:
mise use node@lts              # Use Node LTS locally
mise use -g python@3.13        # Use Python 3.13 globally
mise use npm:typescript --pin  # Pin exact TypeScript version
```

**Upgrade tools:**

```bash
mise upgrade                    # Upgrade all tools to latest compatible versions
mise upgrade node              # Upgrade Node.js only
mise upgrade --interactive     # Interactive upgrade selection

# Examples:
mise upgrade                   # Upgrade everything
mise upgrade python rust       # Upgrade specific tools
```

**Remove tools:**

```bash
mise uninstall node@20         # Uninstall specific version
mise prune                     # Remove unused tool versions
mise prune --dry-run          # Preview what would be removed

# Examples:
mise uninstall python@3.12    # Remove Python 3.12
mise prune                    # Clean up unused versions
```

### Configuration Commands

**View/edit configuration:**

```bash
mise config                     # Show current configuration
mise config ls                 # List all config files
mise current                   # Show currently active tool versions
mise current node              # Show current Node.js version

# Examples:
mise config                    # View active config
mise current                   # Check active versions
mise current python rust       # Check specific tools
```

**Check available versions:**

```bash
mise ls-remote <tool>          # List all available versions
mise ls-remote node            # List available Node.js versions
mise ls-remote python          # List available Python versions
mise ls-remote --limit 20      # Limit results

# Examples:
mise ls-remote node           # See all Node versions
mise ls-remote rust           # See all Rust versions
```

**System diagnostics:**

```bash
mise doctor                    # Check mise installation and configuration
mise doctor --json            # Output diagnostics in JSON

# Checks:
# - mise installation
# - Shell integration
# - Tool installations
# - Configuration validity
```

### Tool Installation Patterns

**Language runtimes:**

```bash
mise use node@22               # Node.js 22.x
mise use node@lts              # Latest LTS
mise use python@3.13           # Python 3.13
mise use ruby@3.4              # Ruby 3.4
mise use go@1.24               # Go 1.24
mise use rust@stable           # Rust stable
```

**Package ecosystem tools:**

```bash
# npm packages
mise use npm:typescript        # TypeScript
mise use npm:prettier          # Prettier
mise use npm:eslint            # ESLint

# pipx packages (Python CLI tools)
mise use pipx:poetry           # Poetry
mise use pipx:black            # Black formatter
mise use pipx:ruff             # Ruff linter

# cargo packages (Rust tools)
mise use cargo:ripgrep         # ripgrep
mise use cargo:fd-find         # fd
mise use cargo:bat             # bat
```

**GitHub releases (ubi backend):**

```bash
mise use ubi:wagoodman/dive    # Docker image analyzer
mise use ubi:bcicen/ctop       # Container monitoring
mise use ubi:cli/cli           # GitHub CLI
```

**Infrastructure tools:**

```bash
mise use terraform@1.9         # Terraform
mise use kubectl@1.31          # kubectl
mise use helm@3.16             # Helm
```

### Configuration Files

**Project-level configuration:**

```bash
# /workspace/projects/active/my-project/.mise.toml
[tools]
node = "22"
python = "3.13"
"npm:typescript" = "latest"
"pipx:black" = "latest"

[env]
NODE_ENV = "development"
```

**Global configuration:**

```bash
# /workspace/developer/.config/mise/config.toml
[tools]
node = "lts"
python = "3.13"
rust = "stable"

[settings]
experimental = true
```

### Environment Variables

**mise-specific variables:**

```bash
# Enable experimental features
export MISE_EXPERIMENTAL=1

# Change data directory
export MISE_DATA_DIR=/custom/path

# Change cache directory
export MISE_CACHE_DIR=/custom/cache

# Disable telemetry
export MISE_TELEMETRY=0

# Verbose output
export MISE_DEBUG=1
export MISE_TRACE=1

# Shell integration
export MISE_SHELL=bash
```

### Integration with extension-manager

Extensions can use mise for tool installation:

```bash
# Check if mise is available
extension-manager status mise-config

# Install mise-managed tools
extension-manager install nodejs    # Uses mise for Node.js
extension-manager install python    # Uses mise for Python
extension-manager install rust      # Uses mise for Rust

# Validate mise-managed installations
extension-manager validate nodejs
extension-manager validate-all
```

### Common Workflows

**Setting up a new project:**

```bash
cd /workspace/projects/active/my-app
mise use node@lts python@3.13
mise use npm:typescript npm:prettier
mise install
```

**Switching tool versions:**

```bash
# Switch to different Node version
mise use node@20
node --version  # Now using Node 20

# Switch back to LTS
mise use node@lts
```

**Viewing bill of materials:**

```bash
# See all installed tools and versions
mise ls

# Export for documentation
mise ls --json > tools-bom.json
```

**Upgrading all tools:**

```bash
# Check what would be upgraded
mise outdated

# Upgrade everything
mise upgrade

# Upgrade selectively
mise upgrade --interactive
```

### Troubleshooting

**Tool not found after installation:**

```bash
# Ensure shell integration is active
mise activate bash >> ~/.bashrc
source ~/.bashrc

# Or manually add to PATH
eval "$(mise activate bash)"
```

**Version conflicts:**

```bash
# Check current versions
mise current

# Check configuration files
mise config ls

# Reset to global config
rm .mise.toml
mise current
```

**Cache issues:**

```bash
# Clear cache
rm -rf ~/.cache/mise

# Reinstall tools
mise install --force
```

**Registry unavailable:**

```bash
# Check network connectivity
mise doctor

# Use alternative registry (if supported)
export MISE_REGISTRY_URL=https://alternative-registry.example.com
```

For more information, see:

- mise documentation: https://mise.jdx.dev
- Available tools: https://mise.jdx.dev/registry.html
- Extension integration: [Extension System README](../docker/lib/extensions.d/README.md)

## Networking Commands

### Domain and SSL

**Add custom domain:**

```bash
flyctl certs create your-domain.com -a <app-name>

# Check certificate status
flyctl certs show your-domain.com -a <app-name>

# List all certificates
flyctl certs list -a <app-name>
```

**Remove domain:**

```bash
flyctl certs delete your-domain.com -a <app-name>
```

### Database Integration

**PostgreSQL:**

```bash
# Create PostgreSQL cluster
flyctl postgres create --name <db-name> --region <region>

# Attach to application
flyctl postgres attach <db-name> -a <app-name>

# Connect to database
flyctl postgres connect -a <db-name>

# Database proxy (for external access)
flyctl proxy 5432 -a <db-name>
```

**Redis:**

```bash
# Create Redis instance
flyctl redis create --name <cache-name> --region <region>

# Attach to application
flyctl redis attach <cache-name> -a <app-name>

# Connect to Redis
redis-cli -u $REDIS_URL
```

## Troubleshooting Commands

### Common Issues

**VM won't start:**

```bash
# Check application status
flyctl status -a <app-name>

# Check machine status
flyctl machine list -a <app-name>

# Restart machine
flyctl machine restart <machine-id> -a <app-name>

# View logs
flyctl logs -a <app-name>
```

**SSH connection issues:**

```bash
# Test connection with verbose output
ssh -vvv developer@<app-name>.fly.dev -p 10022

# Check SSH service on VM
flyctl ssh console -a <app-name> "systemctl status ssh"

# Restart SSH service
flyctl ssh console -a <app-name> "sudo systemctl restart ssh"
```

**Storage issues:**

```bash
# Check disk usage
flyctl ssh console -a <app-name> "df -h"

# Check volume status
flyctl volumes list -a <app-name>

# Clean up workspace
flyctl ssh console -a <app-name> "/workspace/scripts/lib/cleanup.sh"
```

### Log Analysis

**View logs:**

```bash
# Real-time logs
flyctl logs -a <app-name>

# Historical logs
flyctl logs -a <app-name> --since 1h

# Specific instance logs
flyctl logs -a <app-name> --instance <instance-id>
```

**System logs on VM:**

```bash
# SSH into VM first
ssh developer@<app-name>.fly.dev -p 10022

# System logs
sudo journalctl -u ssh
sudo journalctl -f
tail -f /var/log/syslog

# Authentication logs
sudo tail -f /var/log/auth.log
```

## File Paths and Locations

### Important Directories

**On VM (Runtime):**

```text
/workspace/                     # Persistent volume root
├── developer/                  # User home directory
├── projects/                   # Development projects
│   ├── active/                 # Current projects
│   └── archive/                # Archived projects
├── scripts/                    # Management scripts
│   ├── lib/                    # Shared libraries
│   │   ├── common.sh           # Common utility functions
│   │   ├── extension-manager.sh # Extension management
│   │   └── *.sh                # Other libraries
│   ├── extensions.d/           # Extension scripts
│   │   ├── active-extensions.conf # Activation manifest
│   │   └── *.sh.example        # Available extensions
│   └── vm-configure.sh         # Configuration script
├── config/                     # Configuration files
├── backups/                    # Local backups
└── .config/                    # Application configs
```

**Repository Structure:**

```text
sindri/
├── README.md                  # Main documentation
├── CLAUDE.md                  # Claude context
├── Dockerfile                 # Container definition
├── fly.toml                   # Fly.io configuration
├── docker/                    # Container files
│   ├── lib/                   # Shared libraries
│   │   ├── extension-manager.sh # Extension management
│   │   ├── extensions.d/      # Extension scripts
│   │   │   ├── active-extensions.conf.example
│   │   │   └── *.sh.example   # Available extensions
│   │   └── *.sh               # Other libraries
│   ├── scripts/               # VM setup scripts
│   │   ├── vm-configure.sh    # Main configuration
│   │   └── entrypoint.sh      # Container entrypoint
│   └── config/                # Configuration files
├── scripts/                   # Local management scripts
│   ├── vm-setup.sh            # Deploy VM
│   ├── vm-suspend.sh          # Suspend VM
│   └── vm-*.sh                # Other VM management
├── templates/                 # Configuration templates
└── docs/                      # Documentation
    ├── REFERENCE.md           # This file
    ├── EXTENSION_TESTING.md   # Extension testing
    ├── ARCHITECTURE.md        # System architecture
    └── AGENTS.md              # Agent system guide
```

### Configuration Files

**Key Configuration Files:**

- `/workspace/developer/.bashrc` - Shell configuration
- `/workspace/developer/.gitconfig` - Git configuration
- `/workspace/developer/.claude/settings.json` - Claude Code settings
- `/workspace/.swarm/` - Claude Flow configuration
- `/etc/ssh/sshd_config` - SSH daemon configuration (runs on port 2222)
- `fly.toml` - Fly.io deployment configuration

### Environment Variables

**Available Environment Variables:**

- `DATABASE_URL` - PostgreSQL connection string (if attached)
- `REDIS_URL` - Redis connection string (if attached)
- `ANTHROPIC_API_KEY` - Claude API key
- `GITHUB_TOKEN` - GitHub authentication token
- `PERPLEXITY_API_KEY` - Perplexity API key for Goalie research assistant
- `GIT_USER_NAME` - Git user name
- `GIT_USER_EMAIL` - Git user email

## Performance and Scaling

### Resource Scaling

**Scale CPU and Memory:**

```bash
flyctl scale memory 2048 -a <app-name>      # Scale memory to 2GB
flyctl scale count 2 -a <app-name>          # Scale to 2 instances

# Scale specific machine
flyctl machine update <machine-id> --vm-size shared-cpu-2x -a <app-name>
```

**Auto-scaling configuration:**

```bash
# Edit fly.toml for auto-scaling rules
[services.auto_stop_machines]
  enabled = true
  min_machines_running = 0

[services.auto_start_machines]
  enabled = true
```

This comprehensive command reference provides all the essential commands for managing your AI-assisted remote
development environment effectively.
