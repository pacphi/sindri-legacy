# Sindri Quick Start

Get your AI-powered development forge running in 5 minutes.

## Prerequisites

1. **[Fly.io CLI](https://fly.io/docs/flyctl/install/)** installed
2. **[Fly.io account](https://fly.io/signup)** (free tier available)
3. **SSH key pair** ([create one](TROUBLESHOOTING.md#creating-and-managing-ssh-keys))
4. **Claude Max** subscription OR **[API key](https://console.anthropic.com/settings/keys)**

## Deploy VM

```bash
# Clone and setup
git clone https://github.com/pacphi/sindri.git
cd sindri

# Make sure shell scripts are executable
chmod +x scripts/*.sh

# Deploy (takes ~3 minutes)
./scripts/vm-setup.sh --app-name my-sindri-dev --region sjc
```

The script automatically creates VM, storage, and SSH access.

## Connect

```bash
ssh developer@my-sindri-dev.fly.dev -p 10022
```

For IDE setup, see [IDE Setup Guide](IDE_SETUP.md) first, then [VSCode](VSCODE.md) or [IntelliJ](INTELLIJ.md).

## First-Time Setup

After connecting, configure your development environment:

```bash
# Set up extensions interactively (recommended for first-time)
extension-manager --interactive

# Or install specific extensions
extension-manager install nodejs
extension-manager install python

# Optional: API key authentication for Claude Code (only if using API key, not Pro/Max)
extension-manager install claude-auth-with-api-key

# Authenticate Claude Code (if using Pro/Max subscription, just run this)
claude
```

Extensions include language runtimes (Node.js, Python, Go, Rust), frameworks, and development tools.

## Create Your First Project

Sindri provides intelligent project scaffolding with automatic extension activation:

```bash
# Create a new project (auto-detects type from name)
new-project my-rails-app              # Detects Rails
new-project my-api-server             # Prompts for API type
new-project my-app --type python      # Explicit type

# Or clone an existing repository
clone-project https://github.com/user/repo
clone-project https://github.com/user/repo --fork --feature my-feature
```

**What happens automatically:**

- ✅ Project type detection or selection
- ✅ Extension activation via `extension-manager`
- ✅ Git repository initialization with hooks
- ✅ Template files and structure creation
- ✅ CLAUDE.md context file generation
- ✅ Claude Flow and agent-flow initialization
- ✅ Dependency installation

### Project Types

Available templates (use `new-project --list-types` for full list):

- **Languages**: `node`, `python`, `go`, `rust`, `ruby`
- **Frameworks**: `rails`, `django`, `spring`, `dotnet`
- **Infrastructure**: `terraform`, `docker`

Each template automatically activates the required extensions using `extension-manager`.

### Example Workflows

**Node.js API:**

```bash
new-project my-api --type node
cd /workspace/projects/active/my-api
# Dependencies already installed automatically
npm run dev
```

**Python Application:**

```bash
new-project ml-service --type python
cd /workspace/projects/active/ml-service
source venv/bin/activate
# Dependencies already installed automatically
python main.py
```

**Clone and Enhance:**

```bash
# Clone with automatic enhancements
clone-project https://github.com/company/app

# Fork and create feature branch
clone-project https://github.com/upstream/project \
  --fork --feature add-auth --git-name "Your Name"
```

## Extension Management

Manage development tools and runtimes:

```bash
# List available extensions
extension-manager list

# Interactive setup (recommended for first-time)
extension-manager --interactive

# Install specific extension
extension-manager install golang
extension-manager install docker

# Check status
extension-manager status nodejs
extension-manager validate-all
```

**Note:** Extensions are automatically activated when creating projects with `new-project`.

## Essential Commands

```bash
# VM lifecycle management (from host machine)
./scripts/vm-suspend.sh              # Save costs when not using
./scripts/vm-resume.sh               # Resume work
./scripts/vm-teardown.sh             # Remove VM completely
./scripts/cost-monitor.sh            # Check usage

# Project creation (on VM)
new-project <name> [--type <type>]   # Create new project
clone-project <url> [options]        # Clone repository

# Extension management (on VM)
extension-manager list               # List extensions
extension-manager install <name>     # Install extension

# Troubleshooting (from host machine)
flyctl status -a my-sindri-dev       # Check VM status
flyctl logs -a my-sindri-dev         # View logs
```

## Architecture Overview

Sindri's project system uses:

- **Template-based scaffolding** (`project-templates.yaml`)
- **Shared libraries** (`project-core.sh`, `project-templates.sh`)
- **Extension management** (`extension-manager` for tool activation)
- **YAML parsing** (`yq` for reliable template processing)
- **Schema validation** (optional, for template integrity)

For implementation details, see the archived design docs in `.archive/`.

## Next Steps

- [Command Reference](REFERENCE.md) - All available commands
- [Extension System](../docker/lib/extensions.d/README.md) - Extension development
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
- [Cost Management](COST_MANAGEMENT.md) - Optimization strategies

**Ready?** Run `./scripts/vm-setup.sh` and start coding with Claude! 🚀
