# Extension System Guide

This guide covers the Sindri extension system, available extensions, and how to manage them.

## Overview

Sindri uses a manifest-based extension system to manage development tools and environments. Extensions provide:

- Language runtimes (Node.js, Python, Rust, Go, Ruby, etc.)
- Development tools (Docker, kubectl, Terraform, etc.)
- AI coding assistants (Claude Code, Codex, etc.)
- Infrastructure utilities (monitoring, cloud CLIs, etc.)

## Quick Reference

```bash
# Interactive setup (recommended for first-time)
extension-manager --interactive

# List all available extensions
extension-manager list

# Install specific extension
extension-manager install <name>

# Install all active extensions
extension-manager install-all

# Check status
extension-manager status <name>

# Validate installation
extension-manager validate <name>

# Upgrade (Extension API v2.0)
extension-manager upgrade <name>
extension-manager upgrade-all
```

## Protected Extensions

These core extensions are automatically installed and cannot be removed:

- **workspace-structure** - Base directory structure (must be first)
- **mise-config** - Unified tool version manager
- **ssh-environment** - SSH configuration for CI/CD

## Available Extensions

### Foundational Languages

#### nodejs (mise-powered)

- Node.js LTS via mise
- npm package manager
- Multiple version support
- No sudo required for global packages

```bash
extension-manager install nodejs
node --version
npm --version
```

#### python (mise-powered)

- Python 3.13 via mise
- pip, venv, uv, pipx
- Virtual environment support

```bash
extension-manager install python
python --version
pip --version
```

### Additional Languages

#### rust (mise-powered)

- Rust stable toolchain
- cargo, clippy, rustfmt
- Development tools

```bash
extension-manager install rust
rustc --version
cargo --version
```

#### golang (mise-powered)

- Go 1.24
- gopls, delve, golangci-lint

```bash
extension-manager install golang
go version
```

#### ruby (mise-powered)

- Ruby 3.4.7 via mise
- Rails, Bundler
- Development gems (rubocop, rspec, pry)

```bash
extension-manager install ruby
ruby --version
bundle --version
```

#### php

- PHP 8.4
- Composer, Symfony CLI

```bash
extension-manager install php
php --version
composer --version
```

#### jvm

- SDKMAN with Java, Kotlin, Scala
- Maven, Gradle

```bash
extension-manager install jvm
java --version
```

#### dotnet

- .NET SDK 9.0/8.0
- ASP.NET Core

```bash
extension-manager install dotnet
dotnet --version
```

### Claude AI Tools

#### claude

- Claude Code CLI
- Developer configuration
- Auto-formatting hooks

```bash
extension-manager install claude
claude
```

#### claude-marketplace (requires claude)

- YAML-based marketplace configuration
- Automated plugin installation
- Curated marketplace collection

```bash
extension-manager install claude-marketplace
# Edit /workspace/marketplaces.yml to customize
```

#### openskills (requires nodejs, git)

- OpenSkills CLI for managing Claude Code skills
- Progressive skill disclosure
- Anthropic's marketplace integration

```bash
extension-manager install openskills
openskills install anthropics/anthropic-skills-marketplace
```

#### nodejs-devtools (requires nodejs, mise-powered)

- TypeScript, ESLint, Prettier
- nodemon, goalie AI research assistant
- Tools managed via mise npm plugin

```bash
extension-manager install nodejs-devtools
tsc --version
prettier --version
```

### Infrastructure & DevOps

#### docker

- Docker Engine with compose
- dive, ctop utilities

```bash
extension-manager install docker
docker --version
docker compose version
```

#### infra-tools

- Terraform, Ansible
- kubectl, Helm

```bash
extension-manager install infra-tools
terraform --version
kubectl version
```

#### cloud-tools

- AWS, Azure, GCP CLIs
- DigitalOcean, Oracle Cloud

```bash
extension-manager install cloud-tools
aws --version
az --version
```

#### github-cli

- GitHub CLI (gh)
- Workflow configuration

```bash
extension-manager install github-cli
gh --version
```

### Development Tools

#### ai-tools

- Codex, Gemini, Ollama
- Plandex, Hector
- GitHub Copilot CLI

```bash
extension-manager install ai-tools
# Requires API keys
```

#### monitoring

- System monitoring tools
- htop, iotop, etc.

```bash
extension-manager install monitoring
htop
```

#### tmux-workspace

- Tmux session management
- Pre-configured layouts

```bash
extension-manager install tmux-workspace
tmux
```

#### playwright

- Browser automation testing

```bash
extension-manager install playwright
playwright --version
```

#### agent-manager

- Claude Code agent management

```bash
extension-manager install agent-manager
agent-manager update
```

#### context-loader

- Context system for Claude Code

```bash
extension-manager install context-loader
cf-with-context <agent>
```

## mise Tool Manager

Several extensions use **mise** (https://mise.jdx.dev) for unified version management:

- nodejs, python, rust, golang, ruby (language runtimes)
- nodejs-devtools (npm global tools)

### Common mise Commands

```bash
# List installed tools
mise ls

# Switch tool version
mise use node@20
mise use python@3.11

# Update all tools
mise upgrade

# Per-project configuration (mise.toml)
cd /workspace/projects/active/my-project
cat > mise.toml << 'EOF'
[tools]
node = "20"
python = "3.11"
EOF
```

## Extension Activation Manifest

Extensions are executed in order defined in:

- Development: `docker/lib/extensions.d/active-extensions.conf.example`
- CI mode: `docker/lib/extensions.d/active-extensions.ci.conf`

To customize, edit the manifest before running `extension-manager install-all`.

## Extension API

Each extension implements:

- `prerequisites()` - Check system requirements
- `install()` - Install packages and tools
- `configure()` - Post-install configuration
- `validate()` - Run smoke tests
- `status()` - Check installation state
- `remove()` - Uninstall and cleanup
- `upgrade()` - Upgrade to newer version (API v2.0)

## Troubleshooting

### Extension Won't Install

```bash
# Check prerequisites
extension-manager status <name>

# View detailed logs
cat /var/log/extension-manager.log

# Try reinstalling
extension-manager uninstall <name>
extension-manager install <name>
```

### Command Not Found After Installation

```bash
# Reload shell environment
exec bash

# Check PATH
echo $PATH

# Verify installation
extension-manager validate <name>
```

### mise Version Conflicts

```bash
# Check current versions
mise ls

# Reset to global version
mise use --global node@lts

# Remove project override
rm /workspace/projects/active/my-project/mise.toml
```

## Best Practices

1. **Start with interactive mode**: Use `extension-manager --interactive` for first-time setup
2. **Install in dependency order**: mise-config before mise-powered extensions
3. **Use mise for version management**: Prefer mise over NVM, pyenv, rbenv, etc.
4. **Validate after installation**: Run `extension-manager validate <name>` to confirm
5. **Keep extensions updated**: Use `extension-manager upgrade-all` regularly
6. **Check compatibility**: Some extensions have prerequisites (see extension status)

## More Information

- Main documentation: `/workspace/README.md`
- Getting started: `/workspace/docs/getting-started.md`
- Extension source: `/workspace/scripts/extensions.d/`
- Project repository: https://github.com/pacphi/sindri

For extension-specific help:

```bash
extension-manager status <name>
```
