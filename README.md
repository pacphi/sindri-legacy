# Sindri

[![Version](https://img.shields.io/github/v/release/pacphi/sindri?include_prereleases)](https://github.com/pacphi/sindri/releases)
[![License](https://img.shields.io/github/license/pacphi/sindri)](LICENSE)
[![Integration Tests](https://github.com/pacphi/sindri/actions/workflows/integration.yml/badge.svg)](https://github.com/pacphi/sindri/actions/workflows/integration.yml)
[![Extension Tests](https://github.com/pacphi/sindri/actions/workflows/extension-tests.yml/badge.svg)](https://github.com/pacphi/sindri/actions/workflows/extension-tests.yml)
[![Changelog](https://img.shields.io/badge/changelog-latest-blue)](CHANGELOG.md)

A complete AI-powered cloud development forge running on Fly.io infrastructure with zero local installation, auto-suspend VMs, and persistent storage.

```text

   ███████╗██╗███╗   ██╗██████╗ ██████╗ ██╗
   ██╔════╝██║████╗  ██║██╔══██╗██╔══██╗██║
   ███████╗██║██╔██╗ ██║██║  ██║██████╔╝██║
   ╚════██║██║██║╚██╗██║██║  ██║██╔══██╗██║
   ███████║██║██║ ╚████║██████╔╝██║  ██║██║
   ╚══════╝╚═╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝

   🔨 Forging Software with AI • Running on Fly.io
   📦 https://github.com/pacphi/sindri
```

## About the Name

**Sindri** (Old Norse: "spark") was a legendary dwarf blacksmith in Norse mythology, renowned as one of the greatest craftsmen who ever lived. Together with his brother Brokkr, Sindri forged three of the most powerful artifacts in Norse mythology:

- **Mjölnir** - Thor's legendary hammer
- **Draupnir** - Odin's self-multiplying golden ring
- **Gullinbursti** - Freyr's radiant golden boar

Like its mythological namesake, Sindri forges powerful development environments from raw materials—transforming cloud infrastructure, AI tools, and developer workflows into a legendary platform for building software.

## ⚡ Quick Start

```bash
# Clone
git clone https://github.com/pacphi/sindri.git
cd sindri

# Prepare extension configuration
cp docker/lib/extensions.d/active-extensions.conf.example docker/lib/extensions.d/active-extensions.conf

# Deploy (flyctl will be auto-installed if needed)
./scripts/vm-setup.sh --app-name my-sindri-dev --region sjc

# Connect
ssh developer@my-sindri-dev.fly.dev -p 10022

# Configure extensions inside VM
extension-manager --interactive

# Start developing
claude
```

> **Prerequisites**: SSH keys + [Claude Max](https://www.anthropic.com/max) or [API key](https://console.anthropic.com/settings/keys)
>
> **Note**: The setup script will prompt to install [Fly.io CLI](https://fly.io/docs/flyctl/install/) if not found

## 📚 Documentation

- **[Quick Start Guide](docs/QUICKSTART.md)** - Fast setup using automated scripts
- **[Complete Setup](docs/SETUP.md)** - Manual setup walkthrough
- **[Architecture](docs/ARCHITECTURE.md)** - System architecture and file structure
- **[Cost Management](docs/COST_MANAGEMENT.md)** - Optimization strategies and monitoring
- **[Customization](docs/CUSTOMIZATION.md)** - Extensions, tools, and configuration
- **[Security](docs/SECURITY.md)** - Security features and best practices
- **[Agents](docs/AGENTS.md)** - Agent management, search, and development
- **[Turbo Flow](docs/TURBO_FLOW.md)** - Mimic enterprise AI development features from [turbo-flow-claude](https://github.com/marcuspat/turbo-flow-claude)
- **[Reference](docs/REFERENCE.md)** - Complete command and configuration reference
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

### IDE Setup

- **[IDE Setup Guide](docs/IDE_SETUP.md)** - Common setup for all IDEs
- **[VSCode](docs/VSCODE.md)** - VS Code-specific configuration
- **[IntelliJ](docs/INTELLIJ.md)** - JetBrains IDE-specific configuration

### Developer-focused

- **[Extension Testing](docs/EXTENSION_TESTING.md)** - Testing system for VM extensions
- **[Release Process](docs/RELEASE.md)** - Creating and publishing releases
- **[Contributing](docs/CONTRIBUTING.md)** - Contribution guidelines and roadmap

## 🌟 Key Features

- **Zero Local Setup** - All AI tools run on remote VMs
- **Cost Optimized** - Auto-suspend VMs (see [cost guide](docs/COST_MANAGEMENT.md) for details)
- **Multi-Model AI** - agent-flow integration for 85-99% cost savings with 100+ models
- **IDE Integration** - VSCode and IntelliJ remote development
- **Team Ready** - Shared or individual VMs with persistent volumes
- **Secure** - SSH access with Fly.io network isolation
- **Scalable** - Dynamic resource allocation

## 🚀 Getting Started

1. **Deploy VM**: Run automated setup script
2. **Connect IDE**: Use VSCode Remote-SSH or IntelliJ Gateway
3. **Configure**: One-time environment setup
4. **Develop**: Start coding with AI assistance

> See [Quick Start Guide](docs/QUICKSTART.md) for detailed walkthrough.

## 💰 Cost Management

VMs auto-suspend when idle for optimal cost efficiency.

Manual controls:

```bash
./scripts/vm-suspend.sh    # Suspend to save costs
./scripts/vm-resume.sh     # Resume when needed
./scripts/cost-monitor.sh  # Track usage
```

> See the [cost management guide](docs/COST_MANAGEMENT.md) for optimization strategies.

## 🔧 Essential Commands

```bash
# VM Management
flyctl status -a my-sindri-dev
./scripts/vm-teardown.sh --app-name my-sindri-dev

# Development
ssh developer@my-sindri-dev.fly.dev -p 10022
claude
```

> Full [command reference](docs/REFERENCE.md).

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Anthropic](https://www.anthropic.com/) for Claude Code and Claude AI
- [Reuven Cohen](https://www.linkedin.com/in/reuvencohen/) for [Claude Flow](https://github.com/ruvnet/claude-flow) and
  [Agentic Flow](https://github.com/ruvnet/agentic-flow)
- [Fly.io](https://fly.io/) for an excellent container hosting platform
