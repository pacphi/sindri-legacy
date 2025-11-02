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

# Activate extensions
# Copy example file, then edit (un/comment other extensions)
cp docker/lib/extensions.d/active-extensions.conf.example docker/lib/extensions.d/active-extensions.conf

# Deploy (takes ~3 minutes)
./scripts/vm-setup.sh --app-name my-sindri-dev --region sjc
```

The script automatically creates VM, storage, and SSH access.

## Connect

```bash
ssh developer@my-sindri-dev.fly.dev -p 10022
```

For IDE setup, see [IDE Setup Guide](IDE_SETUP.md) first, then [VSCode](VSCODE.md) or [IntelliJ](INTELLIJ.md).

## First-Time Configuration

Run once after connecting:

```bash
/workspace/scripts/vm-configure.sh
```

This installs Node.js and Claude Code.
Sindri's integrated tools (Claude Flow, Agentic Flow, and curated development tools) are available when you create or
clone projects.

## Start Using Claude

```bash
# Authenticate Claude Code
claude

# Create a project
cd /workspace/projects/active
mkdir my-project && cd my-project

# Initialize Claude Flow
npx claude-flow@alpha init --force
```

## Essential Commands

```bash
# Lifecycle management
./scripts/vm-suspend.sh     # Save costs when not using
./scripts/vm-resume.sh       # Resume work
./scripts/cost-monitor.sh    # Check usage

# If issues arise
flyctl status -a my-sindri-dev
flyctl logs -a my-sindri-dev
```

## Next Steps

- [Command Reference](REFERENCE.md) - All available commands
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
- [Cost Management](COST_MANAGEMENT.md) - Optimization strategies

**Ready?** Run `./scripts/vm-setup.sh` and start coding with Claude! 🚀
