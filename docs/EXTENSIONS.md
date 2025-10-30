# Extension System Documentation

## Overview

Sindri uses a manifest-based extension system to manage development tools and environments. Extensions provide language runtimes, development tools, infrastructure utilities, and AI coding assistants.

The extension system supports two approaches:
- **Traditional extensions**: Using language-specific version managers (NVM, rbenv, SDKMAN, etc.)
- **mise-powered extensions**: Using mise for unified tool management with declarative TOML configuration

## Extension API v1.0

All extensions implement six standard functions:

| Function | Purpose | Required |
|----------|---------|----------|
| `prerequisites()` | Check system requirements before installation | Yes |
| `install()` | Install packages and tools | Yes |
| `configure()` | Post-install configuration and setup | Yes |
| `validate()` | Run smoke tests to verify installation | Yes |
| `status()` | Check installation state and display metadata | Yes |
| `remove()` | Uninstall and cleanup | Yes |

## Extension Management Commands

### Basic Operations

```bash
# List all available extensions
extension-manager list

# Interactive setup with prompts (recommended for first-time setup)
extension-manager --interactive

# Install an extension (auto-activates if needed)
extension-manager install <name>

# Install all active extensions from manifest
extension-manager install-all

# Check extension status
extension-manager status <name>

# Check status of all installed extensions
extension-manager status-all

# Validate extension installation
extension-manager validate <name>

# Validate all installed extensions
extension-manager validate-all

# Uninstall extension
extension-manager uninstall <name>

# Reorder extension priority in manifest
extension-manager reorder <name> <position>
```

### Advanced Operations

```bash
# Upgrade all mise-managed tools
extension-manager upgrade-all

# Export status as JSON
extension-manager status-all --json

# Show version information
extension-manager --version

# Enable debug output
extension-manager install <name> --verbose
```

## Available Extensions

### Core Environment

| Extension | Description | Tool Manager | Version |
|-----------|-------------|--------------|---------|
| `workspace-structure` | Base directory structure | N/A | 1.0.0 |
| `nodejs` | Node.js LTS and npm | mise | 3.0.0 |
| `ssh-environment` | SSH wrappers for non-interactive sessions | N/A | 1.0.0 |

### Claude AI Tools

| Extension | Description | Tool Manager | Version | Dependencies |
|-----------|-------------|--------------|---------|--------------|
| `claude-config` | Claude Code CLI with developer configuration | npm | 1.0.0 | nodejs |
| `nodejs-devtools` | TypeScript, ESLint, Prettier, nodemon, goalie | mise (npm backend) | 2.0.0 | nodejs |

### Language Runtimes

| Extension | Description | Tool Manager | Version | mise-Powered |
|-----------|-------------|--------------|---------|--------------|
| `python` | Python 3.13 with pip, venv, uv, pipx tools | mise | 2.0.0 | ✅ |
| `rust` | Rust toolchain with cargo, clippy, rustfmt | mise | 2.0.0 | ✅ |
| `golang` | Go 1.24 with gopls, delve, golangci-lint | mise | 2.0.0 | ✅ |
| `ruby` | Ruby 3.4/3.3 with rbenv, Rails, Bundler | rbenv | 1.0.0 | ❌ |
| `php` | PHP 8.3 with Composer, Symfony CLI | apt (Ondrej PPA) | 1.0.0 | ❌ |
| `jvm` | SDKMAN with Java, Kotlin, Scala, Maven, Gradle | SDKMAN | 1.0.0 | ❌ |
| `dotnet` | .NET SDK 9.0/8.0 with ASP.NET Core | apt (Microsoft) | 1.0.0 | ❌ |

### Infrastructure & DevOps

| Extension | Description | Tool Manager | Version |
|-----------|-------------|--------------|---------|
| `docker` | Docker Engine with compose, dive, ctop | apt | 1.0.0 |
| `infra-tools` | Terraform, Ansible, kubectl, Helm, Carvel | Mixed | 1.0.0 |
| `cloud-tools` | AWS, Azure, GCP, Oracle, DigitalOcean CLIs | Official installers | 1.0.0 |
| `ai-tools` | AI coding assistants (Codex, Gemini, Ollama, etc.) | Mixed | 1.0.0 |

### Monitoring & Utilities

| Extension | Description | Tool Manager | Version |
|-----------|-------------|--------------|---------|
| `monitoring` | System monitoring tools (htop, glances, btop, etc.) | apt | 1.0.0 |
| `tmux-workspace` | Tmux session management | apt | 1.0.0 |
| `playwright` | Browser automation testing | npm | 1.0.0 |
| `agent-manager` | Claude Code agent management | Custom | 1.0.0 |
| `context-loader` | Context system for Claude | Custom | 1.0.0 |
| `github-cli` | GitHub CLI authentication and workflows | Pre-installed | 1.0.0 |

## mise-Powered Extensions

### What is mise?

[mise](https://mise.jdx.dev) is a modern polyglot tool version manager that provides:
- **Unified tool management**: Single command for all language runtimes and CLI tools
- **Declarative configuration**: TOML-based configuration files
- **Version management**: Per-project and global tool versions
- **Multiple backends**: Support for npm, pipx, cargo, go, ubi (GitHub releases), and more
- **Better performance**: Faster than asdf with native Rust implementation

### Benefits of mise Integration

1. **Simplified Installation**: Replace complex installation scripts with declarative TOML
2. **Version Management**: Easily switch between tool versions per-project
3. **Reproducible Environments**: Lock file support for consistent tool versions
4. **Unified Workflow**: Single tool for all language runtimes and CLI utilities
5. **Better Developer Experience**: Automatic activation, version switching, and updates

### mise-Powered Extension Pattern

Extensions that use mise follow this pattern:

1. **Prerequisite check**: Verify mise is installed (from `mise-config` extension)
2. **TOML selection**: Choose configuration based on `CI_MODE` environment variable
3. **Configuration copy**: Copy TOML to `~/.config/mise/conf.d/<extension>.toml`
4. **Tool installation**: Run `mise install` to install all defined tools
5. **Validation**: Verify tools are available and managed by mise

### Creating mise-Powered Extensions

#### Step 1: Create Extension Script

```bash
#!/bin/bash
# myextension.extension - Description
# Extension API v1.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/extensions-common.sh"

# ============================================================================
# METADATA
# ============================================================================

EXT_NAME="myextension"
EXT_VERSION="2.0.0"
EXT_DESCRIPTION="My tool via mise"
EXT_CATEGORY="language"

extension_init

# ============================================================================
# PREREQUISITES
# ============================================================================

prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."

  # Require mise
  if ! command_exists mise; then
    print_error "mise is required but not installed"
    print_status "Install with: extension-manager install mise-config"
    return 1
  fi

  print_success "All prerequisites met"
  return 0
}

# ============================================================================
# INSTALL
# ============================================================================

install() {
  print_status "Installing ${EXT_NAME} via mise..."

  # Determine TOML file based on CI_MODE
  local ext_dir="$SCRIPT_DIR"
  local toml_source
  local toml_dest="$HOME/.config/mise/conf.d/${EXT_NAME}.toml"

  if [[ "${CI_MODE:-false}" == "true" ]] && [[ -f "$ext_dir/${EXT_NAME}-ci.toml" ]]; then
    toml_source="$ext_dir/${EXT_NAME}-ci.toml"
    print_status "Using CI configuration"
  else
    toml_source="$ext_dir/${EXT_NAME}.toml"
    print_status "Using development configuration"
  fi

  # Validate and copy TOML
  if [[ ! -f "$toml_source" ]]; then
    print_error "Configuration not found: $toml_source"
    return 1
  fi

  mkdir -p "$HOME/.config/mise/conf.d"
  cp "$toml_source" "$toml_dest"
  print_success "Configuration copied to $toml_dest"

  # Install tools
  if mise install; then
    print_success "Tools installed successfully"
  else
    print_error "mise install failed"
    return 1
  fi

  return 0
}

# ============================================================================
# CONFIGURE
# ============================================================================

configure() {
  print_status "Configuring ${EXT_NAME}..."

  # Add any post-installation configuration here
  # (shell aliases, environment variables, etc.)

  print_success "Configuration complete"
  return 0
}

# ============================================================================
# VALIDATE
# ============================================================================

validate() {
  print_status "Validating ${EXT_NAME} installation..."

  # Activate mise environment
  eval "$(mise activate bash)"

  # Check if mise manages the tool
  if mise ls mytool &>/dev/null; then
    print_success "Tool managed by mise"
  else
    print_error "Tool not found in mise"
    return 1
  fi

  # Test tool functionality
  if mytool --version &>/dev/null; then
    print_success "Tool is functional"
  else
    print_error "Tool command failed"
    return 1
  fi

  return 0
}

# ============================================================================
# STATUS
# ============================================================================

status() {
  extension_status_header

  # Check mise management
  if command_exists mise; then
    eval "$(mise activate bash)"
    if mise ls mytool &>/dev/null; then
      local version
      version=$(mise current mytool 2>/dev/null || echo "unknown")
      print_success "Installed via mise (version: $version)"
    else
      print_warning "Not managed by mise"
    fi
  fi

  # Show tool version
  if command_exists mytool; then
    local tool_version
    tool_version=$(mytool --version 2>/dev/null | head -1)
    print_status "Tool version: $tool_version"
  else
    print_error "Tool not installed"
  fi
}

# ============================================================================
# REMOVE
# ============================================================================

remove() {
  print_status "Removing ${EXT_NAME}..."

  # Remove mise TOML configuration
  local toml_path="$HOME/.config/mise/conf.d/${EXT_NAME}.toml"
  if [[ -f "$toml_path" ]]; then
    rm -f "$toml_path"
    print_success "Removed mise configuration"
  fi

  # Uninstall tool via mise
  if command_exists mise; then
    eval "$(mise activate bash)"
    if mise ls mytool &>/dev/null; then
      mise uninstall mytool
      print_success "Uninstalled tool via mise"
    fi
  fi

  return 0
}
```

#### Step 2: Create TOML Configuration Files

**Development configuration** (`myextension.toml`):

```toml
# myextension.toml - Full development environment

[tools]
# Define tools to install
mytool = "latest"

# Additional tools via backends
"npm:some-npm-tool" = "latest"
"pipx:some-python-tool" = "latest"
"cargo:some-rust-tool" = "latest"

[env]
# Environment variables
MY_TOOL_ENV = "development"
_.file = ".env"

[settings]
experimental = true
verbose = false
```

**CI configuration** (`myextension-ci.toml`):

```toml
# myextension-ci.toml - Minimal CI environment

[tools]
# Only essential tools for CI
mytool = "latest"

[env]
MY_TOOL_ENV = "ci"

[settings]
experimental = true
verbose = false
```

#### Step 3: Register Extension

Add to `/workspace/scripts/extensions.d/active-extensions.conf`:

```
# Core extensions
workspace-structure
mise-config
ssh-environment

# Add your extension
myextension
```

### TOML Configuration Reference

#### Tools Section

Define tools to be managed by mise:

```toml
[tools]
# Language runtimes
node = "lts"              # Node.js LTS
python = "3.13"           # Python 3.13
rust = "stable"           # Rust stable
go = "1.24"              # Go 1.24

# npm-based tools (requires Node.js)
"npm:typescript" = "latest"
"npm:eslint" = "latest"
"npm:prettier" = "latest"

# pipx-based tools (requires Python)
"pipx:poetry" = "latest"
"pipx:black" = "latest"
"pipx:mypy" = "latest"

# cargo-based tools (requires Rust)
"cargo:ripgrep" = "latest"
"cargo:fd-find" = "latest"
"cargo:exa" = "latest"

# go-based tools (requires Go)
"go:golang.org/x/tools/gopls@latest" = "latest"

# ubi-based tools (GitHub releases)
"ubi:derailed/k9s" = "latest"

# Direct mise tools
terraform = "latest"
kubectl = "latest"
helm = "latest"
```

#### Environment Variables Section

```toml
[env]
# Load from .env file (if exists)
_.file = ".env"

# Custom environment variables
NODE_ENV = "development"
PYTHONUNBUFFERED = "1"
RUST_BACKTRACE = "1"
GO111MODULE = "on"

# Path modifications
PATH = ["${HOME}/.local/bin", "${HOME}/go/bin"]
```

#### Tasks Section

Define custom tasks/scripts:

```toml
[tasks.test]
description = "Run tests"
run = "npm test"

[tasks.build]
description = "Build project"
run = "npm run build"

[tasks.dev]
description = "Start development server"
run = "npm run dev"
```

Run tasks with: `mise run <task>`

#### Settings Section

```toml
[settings]
# Enable experimental features
experimental = true

# Logging verbosity
verbose = false

# Skip confirmation prompts
yes = false

# Number of parallel jobs (0 = CPU cores)
jobs = 4

# Tools to disable
disable_tools = []
```

### CI Mode and TOML Selection

Extensions support two configurations via `CI_MODE` environment variable:

| Environment | TOML File | Purpose |
|-------------|-----------|---------|
| Development | `<extension>.toml` | Full development environment with all tools |
| CI/Testing | `<extension>-ci.toml` | Minimal environment for faster CI builds |

**Setting CI_MODE:**

```bash
# On host machine (before deployment)
flyctl secrets set CI_MODE="true" -a <app-name>

# Or in deployment script
export CI_MODE="true"
./scripts/vm-setup.sh --app-name test-vm
```

**Extension behavior:**

```bash
# Development: Uses nodejs.toml (full environment)
extension-manager install nodejs

# CI: Uses nodejs-ci.toml (minimal environment)
CI_MODE=true extension-manager install nodejs
```

### mise Command Reference

Common mise commands for managing tools:

```bash
# List installed tools
mise ls

# List available versions
mise ls-remote <tool>

# Install specific version
mise use <tool>@<version>

# Install all tools from configuration
mise install

# Update all tools
mise upgrade

# Show current versions
mise current <tool>

# Check mise configuration
mise config

# Diagnose issues
mise doctor

# Search for tools
mise search <query>

# Run defined tasks
mise run <task>

# Activate mise in shell
eval "$(mise activate bash)"
```

### mise Environment Variables

Configure mise behavior with environment variables:

| Variable | Purpose | Default |
|----------|---------|---------|
| `MISE_EXPERIMENTAL` | Enable experimental features | `false` |
| `MISE_VERBOSE` | Enable verbose output | `false` |
| `MISE_YES` | Skip confirmation prompts | `false` |
| `MISE_JOBS` | Parallel installation jobs | CPU cores |
| `MISE_DATA_DIR` | Data directory | `~/.local/share/mise` |
| `MISE_CONFIG_DIR` | Config directory | `~/.config/mise` |
| `MISE_CACHE_DIR` | Cache directory | `~/.cache/mise` |

## Extension Activation Manifest

Extensions are executed in the order listed in `/workspace/scripts/extensions.d/active-extensions.conf`.

### Example Manifest

```
# Core extensions (always first)
workspace-structure
mise-config
nodejs
ssh-environment

# Language runtimes
python
golang
rust

# Infrastructure tools
docker
infra-tools

# Development tools
nodejs-devtools
claude-config

# Monitoring
monitoring
```

### Manifest Best Practices

1. **Order matters**: List dependencies before dependents
   - `mise-config` must come before mise-powered extensions
   - `nodejs` must come before `nodejs-devtools`
   - `nodejs` must come before `claude-config`

2. **Core first**: Install foundational extensions early
   ```
   workspace-structure  # Creates directory structure
   mise-config         # Enables mise for other extensions
   nodejs              # Core language runtime
   ssh-environment     # Essential for remote access
   ```

3. **Group by category**: Organize related extensions together
   ```
   # Languages
   python
   golang
   rust

   # Infrastructure
   docker
   infra-tools
   cloud-tools
   ```

4. **Comment liberally**: Document why extensions are included
   ```
   # Required for CI/CD pipelines
   docker
   infra-tools

   # Optional: AI development tools
   # ai-tools
   ```

## Extension Development Guidelines

### File Naming Conventions

| File Type | Pattern | Example |
|-----------|---------|---------|
| Extension script | `<name>.extension` | `nodejs.extension` |
| Development TOML | `<name>.toml` | `nodejs.toml` |
| CI TOML | `<name>-ci.toml` | `nodejs-ci.toml` |
| Legacy script | `<nn>-<name>.sh.example` | `20-nodejs.sh.example` |

### Version Numbering

Follow semantic versioning:
- **Major** (X.0.0): Breaking changes, different tool manager
  - Example: v2.x → v3.x (NVM → mise for nodejs)
- **Minor** (x.Y.0): New tools, features, configuration options
  - Example: v3.0 → v3.1 (added new npm tools)
- **Patch** (x.y.Z): Bug fixes, documentation updates
  - Example: v3.1.0 → v3.1.1 (fixed TOML syntax)

### Extension Categories

Use standard categories for consistency:

| Category | Purpose | Examples |
|----------|---------|----------|
| `language` | Language runtimes | nodejs, python, rust, golang |
| `devtools` | Development utilities | nodejs-devtools, monitoring |
| `infrastructure` | Infrastructure tools | docker, infra-tools, cloud-tools |
| `ai` | AI coding assistants | claude-config, ai-tools, agent-manager |
| `core` | Core system components | workspace-structure, ssh-environment |
| `utility` | General utilities | tmux-workspace, playwright |

### Error Handling

Extensions should handle errors gracefully:

```bash
# Check prerequisites before proceeding
prerequisites() {
  if ! command_exists required_tool; then
    print_error "required_tool not found"
    print_status "Install with: apt-get install required_tool"
    return 1
  fi
}

# Validate after installation
validate() {
  if ! mytool --version &>/dev/null; then
    print_error "Tool installation failed"
    print_status "Check logs at: /var/log/extension-manager.log"
    return 1
  fi
}
```

### Logging and Output

Use consistent output functions:

```bash
print_status "Starting installation..."    # Informational
print_debug "Debug info"                   # Verbose mode only
print_success "Installation complete"      # Success
print_warning "Low disk space detected"    # Warning
print_error "Installation failed"          # Error
```

## Troubleshooting

### Common Issues

#### mise Command Not Found

**Symptom**: `command not found: mise`

**Solution**:
```bash
# Install mise-config extension
extension-manager install mise-config

# Reload shell
exec bash -l

# Or manually activate
eval "$(mise activate bash)"
```

#### Tool Not Found After Installation

**Symptom**: Tool installed via mise but not in PATH

**Solution**:
```bash
# Ensure mise is activated
eval "$(mise activate bash)"

# Check if mise knows about the tool
mise ls

# Reinstall if missing
mise install
```

#### Version Conflicts

**Symptom**: Multiple versions of same tool

**Solution**:
```bash
# List all versions
mise ls <tool>

# Set specific version as default
mise use <tool>@<version>

# Or remove unwanted versions
mise uninstall <tool>@<unwanted-version>
```

#### TOML Configuration Errors

**Symptom**: `mise install` fails with parse error

**Solution**:
```bash
# Validate TOML syntax
mise config

# Check for typos in tool names
mise search <tool>

# Review TOML file
cat ~/.config/mise/conf.d/<extension>.toml
```

#### CI Mode Not Working

**Symptom**: CI TOML not being used

**Solution**:
```bash
# Verify CI_MODE is set
echo $CI_MODE

# Set it explicitly
export CI_MODE="true"

# Or via Fly.io secrets
flyctl secrets set CI_MODE="true" -a <app-name>
```

### Diagnostic Commands

```bash
# Check extension status
extension-manager status <extension>

# Check all extensions
extension-manager status-all

# Validate installation
extension-manager validate <extension>

# Check mise health
mise doctor

# View mise configuration
mise config

# Show mise environment
mise env

# List all installed tools
mise ls
```

### Getting Help

1. **Extension documentation**: `extension-manager status <name>`
2. **mise documentation**: https://mise.jdx.dev
3. **Project documentation**: `/workspace/docs/`
4. **Logs**: `/var/log/extension-manager.log`

## Migration from Traditional to mise

### Upgrade Path

Extensions can be migrated from traditional tool managers to mise:

1. **Install mise-config**: `extension-manager install mise-config`
2. **Uninstall traditional extension**: `extension-manager uninstall <name>`
3. **Install mise-powered version**: `extension-manager install <name>`
4. **Validate migration**: `extension-manager validate <name>`

### Coexistence Period

Traditional and mise extensions can coexist:

```bash
# Example: Ruby still uses rbenv, Node.js uses mise
workspace-structure
mise-config
nodejs        # v3.x (mise-powered)
ruby          # v1.x (rbenv-based)
python        # v2.x (mise-powered)
```

### Breaking Changes

When upgrading to mise-powered versions:

| Extension | Traditional | mise-Powered | Breaking Change |
|-----------|-------------|--------------|-----------------|
| nodejs | v2.x (NVM) | v3.x (mise) | NVM commands no longer available |
| python | v1.x (apt) | v2.x (mise) | System Python not used |
| rust | v1.x (rustup) | v2.x (mise) | rustup not installed |
| golang | v1.x (manual) | v2.x (mise) | Manual installation replaced |

## Performance Optimization

### mise Installation Performance

mise is optimized for speed:

- **Parallel downloads**: Install multiple tools concurrently
- **Binary caching**: Reuse downloaded binaries
- **Incremental updates**: Only update changed tools

### CI Mode Optimizations

Use CI TOML files for faster CI builds:

```toml
# nodejs-ci.toml - Minimal for testing
[tools]
node = "lts"  # Only Node.js, no extra tools
```

vs.

```toml
# nodejs.toml - Full development
[tools]
node = "lts"
"npm:typescript" = "latest"
"npm:eslint" = "latest"
"npm:prettier" = "latest"
"npm:nodemon" = "latest"
```

**Result**: 60-70% faster installation in CI

### Extension Installation Order

Order extensions by installation time:

1. **Fast** (< 1 min): workspace-structure, ssh-environment, mise-config
2. **Medium** (1-3 min): nodejs, python, golang
3. **Slow** (> 3 min): rust, docker, jvm

## Advanced Topics

### Per-Project Tool Versions

Use project-local `.mise.toml`:

```bash
cd /workspace/projects/myproject

# Create project-specific configuration
cat > .mise.toml << 'EOF'
[tools]
node = "18.20.0"  # Project needs older Node.js
python = "3.11"   # Project uses Python 3.11
EOF

# Install project tools
mise install
```

### Custom Tool Backends

Create custom backend for unsupported tools:

```toml
[tools]
# Use ubi backend for GitHub releases
"ubi:username/repo" = "latest"

# Use http backend for direct downloads
"http:https://example.com/tool.tar.gz" = "latest"
```

### Environment Inheritance

mise supports environment variable inheritance:

```toml
# Global: ~/.config/mise/config.toml
[env]
COMMON_VAR = "global-value"

# Extension: ~/.config/mise/conf.d/nodejs.toml
[env]
NODE_ENV = "development"
# COMMON_VAR is inherited
```

### Task Automation

Define tasks in TOML for common operations:

```toml
[tasks.setup]
description = "Setup development environment"
run = """
npm install
npm run build
npm test
"""

[tasks.deploy]
description = "Deploy to production"
depends = ["build", "test"]
run = "npm run deploy"
```

Run with: `mise run setup`

## References

- **Extension API**: Extension API v1.0 specification
- **mise documentation**: https://mise.jdx.dev
- **Tool backends**: https://mise.jdx.dev/dev-tools/backends.html
- **TOML configuration**: https://mise.jdx.dev/configuration.html
- **mise tasks**: https://mise.jdx.dev/tasks/
- **Template TOML**: `/workspace/scripts/extensions.d/template.toml`
- **CLAUDE.md**: Project-specific guidance
- **CONTRIBUTING.md**: Developer contribution guide
