# Customization

## Table of Contents

- [Extension System](#extension-system)
  - [Extension API v1.0 & v2.0](#extension-api-v10--v20)
  - [Available Extensions](#available-extensions)
- [Extension Management](#extension-management)
  - [Managing Extensions](#managing-extensions)
  - [Activation Manifest](#activation-manifest)
- [Creating Custom Extensions](#creating-custom-extensions)
  - [Extension Structure](#extension-structure)
  - [Extension Functions](#extension-functions)
- [Configuration Examples](#configuration-examples)
  - [Custom Development Environment](#custom-development-environment)
  - [Agent Configuration](#agent-configuration)
- [Environment Variables](#environment-variables)
  - [Setting Development Variables](#setting-development-variables)
  - [API Keys and Authentication](#api-keys-authentication-and-llm-provider-configuration)
- [IDE Customization](#ide-customization)
  - [VSCode Settings](#vscode-settings)
  - [Claude Code Hooks](#claude-code-hooks)
- [Project Templates](#project-templates)
  - [Creating Custom Templates](#creating-custom-templates)
  - [CI/CD Integration](#cicd-integration)

## Extension System

Sindri uses a **manifest-based extension system** to manage development tools and environments. Extensions follow a
standardized API (v1.0) with explicit dependency management and activation control.

### Extension API v1.0 & v2.0

The Extension API provides:

- **Manifest-based activation**: Control which extensions install via `active-extensions.conf`
- **Standardized API**: All extensions implement 6 required functions (v1.0) or 7 functions (v2.0)
- **Dependency management**: Explicit prerequisites checking before installation
- **CLI management**: `extension-manager` tool for activation and installation
- **Idempotent operations**: Safe to re-run installations
- **Clean removal**: Proper uninstall with dependency warnings
- **Upgrade support (v2.0+)**: Extensions can implement `upgrade()` for updating installed tools

**Key Concepts:**

1. **Extension Files**: Located in `docker/lib/extensions.d/` as `.sh.example` files
2. **Activation**: Extensions are activated by adding their name to `active-extensions.conf`
3. **Installation**: Activated extensions are installed using `extension-manager install`
4. **Execution Order**: Controlled by line order in the manifest, not file naming

### Available Extensions

Extensions are organized by category:

#### Core Infrastructure (Protected)

These extensions are **protected** and cannot be removed:

- **workspace-structure** - Creates /workspace directory structure (src, tests, docs, scripts, etc.)
- **mise-config** - Unified tool version manager for mise-powered extensions
- **ssh-environment** - Configures SSH daemon for non-interactive sessions (required for CI/CD)

#### Foundational Languages

While not protected, these are highly recommended:

- **nodejs** - Node.js LTS via mise and npm (required by many tools, depends on mise-config)
- **python** - Python 3.13 with pip, venv, uv (required by monitoring tools, depends on mise-config)

#### Claude AI

Note: Claude Code CLI is pre-installed in the base Docker image.

- **claude-auth-with-api-key** - API key authentication for Claude Code (optional - only for API key users, not Pro/Max)
- **claude-marketplace** - Plugin installer for https://claudecodemarketplace.com/
  (depends on claude-auth-with-api-key or manual auth, git)
- **openskills** - OpenSkills CLI for managing Claude Code skills from Anthropic's marketplace
  (depends on nodejs 20.6+, git)
- **nodejs-devtools** - TypeScript, ESLint, Prettier, nodemon, goalie (depends on nodejs)

#### Language Runtimes

- **rust** - Rust toolchain with cargo, clippy, rustfmt
- **golang** - Go 1.24 with gopls, delve, golangci-lint
- **ruby** - Ruby 3.4/3.3 with rbenv, Rails, Bundler
- **php** - PHP 8.4 with Composer, Symfony CLI
- **jvm** - SDKMAN with Java, Kotlin, Scala, Maven, Gradle
- **dotnet** - .NET SDK 9.0/8.0 with ASP.NET Core

#### Infrastructure Tools

- **docker** - Docker Engine with compose, dive, ctop
- **infra-tools** - Terraform, Ansible, kubectl, Helm
- **cloud-tools** - AWS, Azure, GCP, Oracle, DigitalOcean, Alibaba, IBM CLIs
- **ai-tools** - AI coding assistants (Gemini, xAI Grok SDK, Goalie, Hector, Ollama, Fabric, Codex)

#### Development Utilities

- **monitoring** - System monitoring tools (htop, iotop, glances)
- **tmux-workspace** - Tmux session management with helper scripts
- **playwright** - Browser automation testing (depends on nodejs)
- **agent-manager** - Claude Code agent management (depends on curl, jq)
- **context-loader** - Context management utilities for Claude Code

## Extension Management

### Managing Extensions

The `extension-manager` utility provides comprehensive management for activating and installing extensions.

**List all available extensions:**

```bash
# Show all extensions and their activation status
extension-manager list

# Example output:
# Available extensions in docker/lib/extensions.d:
#
#   ✓ nodejs (nodejs.sh.example) - activated
#   ○ rust (rust.sh.example) - not activated
#   ○ golang (golang.sh.example) - not activated
#   ✓ docker (docker.sh.example) - activated
```

**Install extensions (auto-activates):**

```bash
# Install Rust toolchain
extension-manager install rust

# Install Python development tools
extension-manager install python

# Install Docker utilities
extension-manager install docker

# Or use interactive mode for guided setup
extension-manager --interactive
```

**Install all extensions from manifest:**

```bash
# Install a specific activated extension
extension-manager install rust

# Install all activated extensions
extension-manager install-all
```

**Check extension status:**

```bash
# Check if extension is installed and configured
extension-manager status nodejs

# Validate installation (runs smoke tests)
extension-manager validate nodejs
```

**Uninstall extensions:**

```bash
# Uninstall extension (prompts for confirmation)
extension-manager uninstall golang

# Remove from manifest without uninstalling
extension-manager deactivate golang
```

**Reorder extensions:**

```bash
# Change execution order in manifest
extension-manager reorder python 5
```

> [!TIP]
> After activating extensions, run `extension-manager install-all` to install them. Extensions execute in the order
> listed in `active-extensions.conf`.
>
> [!NOTE]
> Protected extensions (workspace-structure, mise-config, ssh-environment) are automatically installed first and
> cannot be removed.

### Activation Manifest

Extensions are executed in the order listed in `/workspace/scripts/.system/manifest/active-extensions.conf`.

**Example manifest:**

```conf
# Protected extensions (required, cannot be removed):
workspace-structure
mise-config
ssh-environment

# Claude AI tools
claude
nodejs-devtools

# Language runtimes
python
golang
rust

# Infrastructure tools
docker
infra-tools

# Utilities
monitoring
```

**Managing the manifest:**

```bash
# View current manifest
cat /workspace/scripts/.system/manifest/active-extensions.conf

# Install extension (auto-activates and adds to manifest)
extension-manager install <name>

# Deactivate extension (removes from manifest, but doesn't uninstall)
extension-manager deactivate <name>

# Manually edit manifest (for advanced users)
nano /workspace/scripts/.system/manifest/active-extensions.conf
```

## Creating Custom Extensions

### Extension Structure

Extensions follow the Extension API v1.0 specification. All extensions must implement 6 required functions.

**Create a new extension:**

```bash
# Use the template as starting point
cp docker/lib/extensions.d/template.sh.example docker/lib/extensions.d/mycustomtool.sh.example

# Edit the extension
nano docker/lib/extensions.d/mycustomtool.sh.example
```

**Basic extension structure:**

```bash
#!/bin/bash
# mycustomtool.sh.example - Custom tool extension
# Extension API v1.0

# Source shared extension library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/extensions-common.sh"

# ============================================================================
# METADATA
# ============================================================================

EXT_NAME="mycustomtool"
EXT_VERSION="1.0.0"
EXT_DESCRIPTION="My custom development tool"
EXT_CATEGORY="utility"

# Initialize extension environment
extension_init

# ============================================================================
# REQUIRED FUNCTIONS (implement all 6)
# ============================================================================

prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."

  # Check for required commands
  if ! command_exists curl; then
    print_error "curl is required but not installed"
    return 1
  fi

  print_success "All prerequisites met"
  return 0
}

install() {
  print_status "Installing ${EXT_NAME}..."

  # Check if already installed
  if command_exists mycustomtool; then
    print_warning "Tool already installed"
    return 0
  fi

  # Install your tool
  curl -sSL https://example.com/install.sh | bash

  print_success "${EXT_NAME} installed successfully"
  return 0
}

configure() {
  print_status "Configuring ${EXT_NAME}..."

  # Add to PATH
  local tool_path="/usr/local/bin/mycustomtool"
  if [[ -d "$tool_path" ]]; then
    add_to_path "$tool_path"
  fi

  # Create configuration file
  mkdir -p "$HOME/.mycustomtool"
  cat > "$HOME/.mycustomtool/config" << 'EOF'
# Custom tool configuration
option1=value1
option2=value2
EOF

  print_success "${EXT_NAME} configured successfully"
  return 0
}

validate() {
  print_status "Validating ${EXT_NAME} installation..."

  # Test the installation
  if ! command_exists mycustomtool; then
    print_error "mycustomtool command not found"
    return 1
  fi

  # Run version check
  if ! mycustomtool --version >/dev/null 2>&1; then
    print_error "mycustomtool version check failed"
    return 1
  fi

  print_success "${EXT_NAME} validation passed"
  return 0
}

status() {
  print_status "Checking ${EXT_NAME} status..."

  if command_exists mycustomtool; then
    print_success "mycustomtool is installed: $(mycustomtool --version)"
    return 0
  else
    print_warning "mycustomtool is not installed"
    return 1
  fi
}

remove() {
  print_status "Removing ${EXT_NAME}..."

  # Uninstall the tool
  if command_exists mycustomtool; then
    mycustomtool uninstall
  fi

  # Remove configuration
  rm -rf "$HOME/.mycustomtool"

  print_success "${EXT_NAME} removed successfully"
  return 0
}
```

### Extension Functions

All extensions must implement these functions:

- **Extension API v1.0**: 6 required functions
- **Extension API v2.0**: 7 required functions (adds `upgrade()`)

#### 1. prerequisites()

Check system requirements before installation.

**Returns**: `0` if all prerequisites met, `1` otherwise

**Common checks**:

- System packages (build-essential, curl, etc.)
- Commands available in PATH
- Disk space and memory
- Dependent extensions

```bash
prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."

  # Check for required packages
  if ! command_exists gcc; then
    print_error "GCC required - install build-essential"
    return 1
  fi

  # Check disk space
  local available_space
  available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
  if [[ $available_space -lt 5 ]]; then
    print_warning "Low disk space: ${available_space}GB available"
  fi

  print_success "All prerequisites met"
  return 0
}
```

#### 2. install()

Install packages and tools.

**Returns**: `0` on success, `1` on failure

**Actions**:

- Download and install packages
- Compile from source if needed
- Verify installation success
- Handle already-installed gracefully

```bash
install() {
  print_status "Installing ${EXT_NAME}..."

  # Check if already installed
  if command_exists mytool; then
    print_warning "Already installed: $(mytool --version)"
    return 0
  fi

  # Install system dependencies
  sudo apt-get update -qq
  sudo apt-get install -y required-package

  # Download and install binary
  curl -fsSL https://example.com/tool.tar.gz -o /tmp/tool.tar.gz
  tar -xzf /tmp/tool.tar.gz -C /usr/local/bin/
  rm -f /tmp/tool.tar.gz

  print_success "${EXT_NAME} installed successfully"
  return 0
}
```

#### 3. configure()

Post-installation configuration.

**Returns**: `0` on success, `1` on failure

**Tasks**:

- Add to PATH
- Create SSH wrappers (for non-interactive sessions)
- Setup shell aliases
- Create configuration files
- Initialize user settings

```bash
configure() {
  print_status "Configuring ${EXT_NAME}..."

  # Add to PATH
  local bin_path="/usr/local/mytool/bin"
  if [[ -d "$bin_path" ]]; then
    add_to_path "$bin_path"
  fi

  # Create configuration
  mkdir -p "$HOME/.mytool"
  cat > "$HOME/.mytool/config.yaml" << 'EOF'
setting1: value1
setting2: value2
EOF

  # Setup shell alias
  add_alias "mt" "mytool"

  print_success "${EXT_NAME} configured successfully"
  return 0
}
```

#### 4. validate()

Run smoke tests to verify installation.

**Returns**: `0` if validation passes, `1` otherwise

**Tests**:

- Command availability
- Version checks
- Basic functionality
- Configuration validation

```bash
validate() {
  print_status "Validating ${EXT_NAME} installation..."

  # Check command exists
  if ! command_exists mytool; then
    print_error "mytool command not found"
    return 1
  fi

  # Run version check
  if ! mytool --version >/dev/null 2>&1; then
    print_error "mytool version check failed"
    return 1
  fi

  # Test basic functionality
  if ! mytool test >/dev/null 2>&1; then
    print_warning "mytool test command failed (non-critical)"
  fi

  print_success "${EXT_NAME} validation passed"
  return 0
}
```

#### 5. status()

Check installation state and report status.

**Returns**: `0` if installed, `1` otherwise

**Reports**:

- Installation status
- Version information
- Configuration state
- Service status (if applicable)

```bash
status() {
  print_status "Checking ${EXT_NAME} status..."

  if command_exists mytool; then
    local version=$(mytool --version 2>/dev/null || echo "unknown")
    print_success "mytool is installed: $version"

    # Additional status checks
    if [[ -f "$HOME/.mytool/config.yaml" ]]; then
      print_success "Configuration found"
    else
      print_warning "Configuration missing"
    fi

    return 0
  else
    print_warning "mytool is not installed"
    return 1
  fi
}
```

#### 6. remove()

Uninstall and cleanup.

**Returns**: `0` on success, `1` on failure

**Actions**:

- Uninstall packages
- Remove configuration files
- Clean up caches
- Restore system state

```bash
remove() {
  print_status "Removing ${EXT_NAME}..."

  # Uninstall the tool
  if command_exists mytool; then
    sudo rm -f /usr/local/bin/mytool
  fi

  # Remove configuration
  rm -rf "$HOME/.mytool"

  # Remove from PATH (if added)
  remove_from_path "/usr/local/mytool/bin"

  # Remove aliases
  remove_alias "mt"

  print_success "${EXT_NAME} removed successfully"
  return 0
}
```

#### 7. upgrade() (Extension API v2.0+)

Upgrade installed tools to latest versions.

**Returns**: `0` on success, `1` on failure

**Actions**:

- Check for available updates
- Upgrade packages/tools
- Verify upgraded versions
- Handle upgrade failures gracefully

```bash
upgrade() {
  print_status "Upgrading ${EXT_NAME}..."

  # Check current version
  local current_version=$(mytool --version 2>/dev/null || echo "unknown")
  print_info "Current version: $current_version"

  # Check for updates
  print_info "Checking for updates..."
  local latest_version=$(curl -s https://api.example.com/latest-version)

  if [ "$current_version" = "$latest_version" ]; then
    print_success "Already at latest version"
    return 0
  fi

  # Perform upgrade
  curl -fsSL https://example.com/upgrade.sh | bash

  # Verify upgrade
  local new_version=$(mytool --version 2>/dev/null)
  if [ "$new_version" = "$latest_version" ]; then
    print_success "Successfully upgraded to $new_version"
    return 0
  else
    print_error "Upgrade verification failed"
    return 1
  fi
}
```

**Note**: The `upgrade()` function is optional for v1.0 extensions but required for v2.0 extensions.

## Configuration Examples

### Custom Development Environment

**Full-stack JavaScript:**

```bash
#!/bin/bash
# fullstack-js.sh.example - Full-stack JavaScript development environment
# Extension API v1.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/extensions-common.sh"

EXT_NAME="fullstack-js"
EXT_VERSION="1.0.0"
EXT_DESCRIPTION="Full-stack JavaScript development environment"
EXT_CATEGORY="language"

extension_init

prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."

  # Requires nodejs extension
  if ! command_exists node; then
    print_error "Node.js is required - activate 'nodejs' extension first"
    return 1
  fi

  print_success "All prerequisites met"
  return 0
}

install() {
  print_status "Installing ${EXT_NAME}..."

  # Node.js is available globally via mise (from nodejs extension)
  # No need to load NVM - mise handles version management

  # Global packages
  print_status "Installing global npm packages..."
  npm install -g \
    typescript \
    '@typescript-eslint/parser' \
    '@typescript-eslint/eslint-plugin' \
    prettier \
    nodemon \
    pm2 \
    create-react-app \
    create-next-app \
    '@nestjs/cli'

  # Database tools
  print_status "Installing database clients..."
  sudo apt-get update -qq
  sudo apt-get install -y postgresql-client redis-tools

  print_success "${EXT_NAME} installed successfully"
  return 0
}

configure() {
  print_status "Configuring ${EXT_NAME}..."

  # Setup prettier config
  cat > "$HOME/.prettierrc" << 'EOF'
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2
}
EOF

  print_success "${EXT_NAME} configured successfully"
  return 0
}

validate() {
  print_status "Validating ${EXT_NAME} installation..."

  local tools=("tsc" "prettier" "nodemon" "pm2")
  for tool in "${tools[@]}"; do
    if ! command_exists "$tool"; then
      print_error "$tool not found"
      return 1
    fi
  done

  print_success "${EXT_NAME} validation passed"
  return 0
}

status() {
  print_status "Checking ${EXT_NAME} status..."

  if command_exists tsc && command_exists prettier; then
    print_success "Full-stack JavaScript environment installed"
    print_success "TypeScript: $(tsc --version)"
    print_success "Prettier: $(prettier --version)"
    return 0
  else
    print_warning "Full-stack JavaScript environment not fully installed"
    return 1
  fi
}

remove() {
  print_status "Removing ${EXT_NAME}..."

  # Uninstall global packages
  npm uninstall -g typescript prettier nodemon pm2 create-react-app create-next-app @nestjs/cli

  # Remove config
  rm -f "$HOME/.prettierrc"

  print_success "${EXT_NAME} removed successfully"
  return 0
}
```

**Data Science Setup:**

```bash
#!/bin/bash
# datascience.sh.example - Data science environment with Python
# Extension API v1.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/extensions-common.sh"

EXT_NAME="datascience"
EXT_VERSION="1.0.0"
EXT_DESCRIPTION="Data science environment with Python and Jupyter"
EXT_CATEGORY="language"

extension_init

prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."

  # Requires python extension
  if ! command_exists python3; then
    print_error "Python 3 is required - activate 'python' extension first"
    return 1
  fi

  print_success "All prerequisites met"
  return 0
}

install() {
  print_status "Installing ${EXT_NAME}..."

  # Core data science packages
  print_status "Installing Python data science packages..."
  pip3 install --user \
    jupyter \
    pandas \
    numpy \
    matplotlib \
    seaborn \
    scikit-learn \
    tensorflow \
    torch

  print_success "${EXT_NAME} installed successfully"
  return 0
}

configure() {
  print_status "Configuring ${EXT_NAME}..."

  # Jupyter setup
  jupyter notebook --generate-config

  # Configure Jupyter for remote access
  cat >> "$HOME/.jupyter/jupyter_notebook_config.py" << 'EOF'
c.NotebookApp.ip = '0.0.0.0'
c.NotebookApp.open_browser = False
c.NotebookApp.port = 8888
EOF

  print_success "${EXT_NAME} configured successfully"
  return 0
}

validate() {
  print_status "Validating ${EXT_NAME} installation..."

  # Test imports
  python3 -c "import pandas, numpy, matplotlib, seaborn, sklearn" 2>/dev/null
  if [[ $? -ne 0 ]]; then
    print_error "Failed to import data science packages"
    return 1
  fi

  # Test Jupyter
  if ! command_exists jupyter; then
    print_error "jupyter command not found"
    return 1
  fi

  print_success "${EXT_NAME} validation passed"
  return 0
}

status() {
  print_status "Checking ${EXT_NAME} status..."

  if command_exists jupyter; then
    print_success "Data science environment installed"
    print_success "Jupyter: $(jupyter --version 2>&1 | head -1)"
    return 0
  else
    print_warning "Data science environment not installed"
    return 1
  fi
}

remove() {
  print_status "Removing ${EXT_NAME}..."

  # Uninstall packages
  pip3 uninstall -y jupyter pandas numpy matplotlib seaborn scikit-learn tensorflow torch

  # Remove Jupyter config
  rm -rf "$HOME/.jupyter"

  print_success "${EXT_NAME} removed successfully"
  return 0
}
```

### Agent Configuration

To customize AI agent sources and behavior visit [agents-config.yaml](../docker/config/agents-config.yaml)

> [!Note]
> If you're curious about what is facilitating agent curation, visit [pacphi/claude-code-agent-manager](https://github.com/pacphi/claude-code-agent-manager).

### Tmux Workspace

Customize development workspace layout:

```bash
#!/bin/bash
# custom-tmux.sh.example - Custom tmux workspace configuration
# Extension API v1.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/extensions-common.sh"

EXT_NAME="custom-tmux"
EXT_VERSION="1.0.0"
EXT_DESCRIPTION="Custom tmux workspace configuration"
EXT_CATEGORY="utility"

extension_init

prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."

  if ! command_exists tmux; then
    print_error "tmux is required but not installed"
    return 1
  fi

  print_success "All prerequisites met"
  return 0
}

install() {
  print_status "Installing ${EXT_NAME}..."
  # No installation needed - just configuration
  print_success "${EXT_NAME} ready for configuration"
  return 0
}

configure() {
  print_status "Configuring ${EXT_NAME}..."

  # Custom tmux configuration
  cat > "$HOME/.tmux.conf" << 'EOF'
# Custom key bindings
bind-key r source-file ~/.tmux.conf \; display-message "Config reloaded"
bind-key | split-window -h
bind-key - split-window -v

# Custom status bar
set -g status-bg colour235
set -g status-fg colour136
set -g status-left '#[fg=colour166]#S #[fg=colour245]|'
set -g status-right '#[fg=colour245]%Y-%m-%d %H:%M'

# Window numbering
set -g base-index 1
setw -g pane-base-index 1
EOF

  # Custom workspace launcher
  mkdir -p /workspace/.system/lib
  cat > /workspace/.system/lib/my-workspace.sh << 'EOF'
#!/bin/bash
# Custom workspace layout

SESSION_NAME="dev-workspace"

# Create session if it doesn't exist
if ! tmux has-session -t $SESSION_NAME 2>/dev/null; then
    # Main development session
    tmux new-session -d -s $SESSION_NAME -n main

    # Code editing window
    tmux new-window -t $SESSION_NAME -n code
    tmux send-keys -t $SESSION_NAME:code "cd /workspace/projects/active" Enter

    # Server/build window
    tmux new-window -t $SESSION_NAME -n server
    tmux send-keys -t $SESSION_NAME:server "cd /workspace/projects/active" Enter

    # Git/terminal window
    tmux new-window -t $SESSION_NAME -n git
    tmux send-keys -t $SESSION_NAME:git "cd /workspace/projects/active" Enter

    # Select main window
    tmux select-window -t $SESSION_NAME:main
fi

# Attach to session
tmux attach-session -t $SESSION_NAME
EOF

  chmod +x /workspace/.system/lib/my-workspace.sh

  print_success "${EXT_NAME} configured successfully"
  return 0
}

validate() {
  print_status "Validating ${EXT_NAME} installation..."

  if [[ ! -f "$HOME/.tmux.conf" ]]; then
    print_error "tmux config not found"
    return 1
  fi

  print_success "${EXT_NAME} validation passed"
  return 0
}

status() {
  print_status "Checking ${EXT_NAME} status..."

  if [[ -f "$HOME/.tmux.conf" ]]; then
    print_success "Custom tmux configuration installed"
    return 0
  else
    print_warning "Custom tmux configuration not installed"
    return 1
  fi
}

remove() {
  print_status "Removing ${EXT_NAME}..."

  rm -f "$HOME/.tmux.conf"
  rm -f /workspace/.system/lib/my-workspace.sh

  print_success "${EXT_NAME} removed successfully"
  return 0
}
```

## Environment Variables

### Setting Development Variables

**Project-specific variables:**

```bash
# Create environment file
cat > /workspace/projects/active/my-app/.env << 'EOF'
NODE_ENV=development
API_URL=http://localhost:3000
DATABASE_URL=postgresql://localhost:5432/myapp
REDIS_URL=redis://localhost:6379
EOF

# Load automatically in shell
echo 'if [ -f .env ]; then export $(cat .env | xargs); fi' >> /workspace/developer/.bashrc
```

**Global development variables:**

```bash
# Add to bashrc for all projects
cat >> /workspace/developer/.bashrc << 'EOF'
export EDITOR=code
export PAGER=less
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
EOF
```

### API Keys, Authentication, and LLM Provider Configuration

This section covers secret management patterns, API key configuration for cloud providers and AI tools, and
comprehensive guidance for configuring Claude Code to work with alternate LLM providers.

#### Fly.io Secrets Management

Fly.io secrets are injected as runtime environment variables into your VM, providing secure storage for sensitive
credentials.

**Basic Commands:**

```bash
# Set individual secrets
flyctl secrets set API_KEY=value -a <app-name>

# Set multiple secrets at once
flyctl secrets set \
  ANTHROPIC_API_KEY=sk-ant-... \
  GITHUB_TOKEN=ghp_... \
  PERPLEXITY_API_KEY=pplx-... \
  -a <app-name>

# List secret names (values hidden)
flyctl secrets list -a <app-name>

# Remove a secret
flyctl secrets unset API_KEY -a <app-name>

# Verify secrets are accessible in VM
flyctl ssh console -a <app-name>
echo $ANTHROPIC_API_KEY
```

**Best Practices:**

- **Secrets vs fly.toml [env]**: Use `flyctl secrets set` for sensitive data (API keys, passwords). Use `fly.toml`
  [env] section for non-sensitive configuration (feature flags, endpoints).
- **Persistence**: Secrets persist across VM restarts and are only accessible at runtime inside the VM.
- **Deployment**: Set secrets before first deployment or updates will trigger a new deployment.

#### Cloud Provider CLI Authentication

The **cloud-tools.sh.example** extension installs multiple cloud provider CLIs. Here's how to configure
authentication for each:

**AWS CLI:**

```bash
# Option 1: Access keys via Fly.io secrets
flyctl secrets set AWS_ACCESS_KEY_ID=AKIA... -a <app-name>
flyctl secrets set AWS_SECRET_ACCESS_KEY=... -a <app-name>
flyctl secrets set AWS_DEFAULT_REGION=us-east-1 -a <app-name>

# Option 2: Interactive configuration inside VM
flyctl ssh console -a <app-name>
aws configure

# Option 3: IAM roles (if running on AWS)
# No explicit credentials needed
```

**Azure CLI:**

```bash
# Option 1: Service principal via secrets
flyctl secrets set AZURE_CLIENT_ID=... -a <app-name>
flyctl secrets set AZURE_CLIENT_SECRET=... -a <app-name>
flyctl secrets set AZURE_TENANT_ID=... -a <app-name>

# Option 2: Interactive login inside VM
flyctl ssh console -a <app-name>
az login
```

**Google Cloud CLI:**

```bash
# Option 1: Service account key (create base64-encoded JSON)
# Upload service account JSON to /workspace/gcp-credentials.json
flyctl secrets set GOOGLE_APPLICATION_CREDENTIALS=/workspace/gcp-credentials.json -a <app-name>

# Option 2: Interactive authentication
flyctl ssh console -a <app-name>
gcloud auth login
gcloud config set project PROJECT_ID
```

**Oracle Cloud Infrastructure:**

```bash
# Requires config file at ~/.oci/config
# Run setup inside VM
flyctl ssh console -a <app-name>
oci setup config
```

**Alibaba Cloud:**

```bash
flyctl secrets set ALIBABA_CLOUD_ACCESS_KEY_ID=... -a <app-name>
flyctl secrets set ALIBABA_CLOUD_ACCESS_KEY_SECRET=... -a <app-name>

# Or interactive
flyctl ssh console -a <app-name>
aliyun configure
```

**DigitalOcean:**

```bash
flyctl secrets set DIGITALOCEAN_ACCESS_TOKEN=... -a <app-name>

# Or interactive
flyctl ssh console -a <app-name>
doctl auth init
```

**IBM Cloud:**

```bash
flyctl secrets set IBMCLOUD_API_KEY=... -a <app-name>

# Or interactive
flyctl ssh console -a <app-name>
ibmcloud login
```

#### AI Tool API Keys

The **ai-tools.sh.example** extension provides various AI coding assistants. Here's how to configure their API keys:

**Google Gemini CLI:**

```bash
# Get API key: https://makersuite.google.com/app/apikey
flyctl secrets set GOOGLE_GEMINI_API_KEY=... -a <app-name>

# Usage
gemini chat "explain this code"
gemini generate "write unit tests"
```

**Grok CLI:**

```bash
# Requires xAI account
flyctl secrets set GROK_API_KEY=... -a <app-name>

# Usage
grok chat
grok ask "what's the latest in AI?"
```

**Perplexity API (Goalie):**

```bash
# Get API key: https://www.perplexity.ai/settings/api
flyctl secrets set PERPLEXITY_API_KEY=pplx-... -a <app-name>

# Usage
goalie "research topic"
```

**GitHub Copilot:**

```bash
# Requires GitHub account with Copilot subscription
flyctl ssh console -a <app-name>
gh auth login
gh copilot suggest "git command to undo"
```

**AWS Q Developer:**

```bash
# Uses AWS credentials (see AWS CLI section above)
aws q chat
aws q explain "lambda function"
```

**Hector:**

```bash
# Pure A2A-Native declarative AI agent platform
# Requires Go (install via golang extension)
# Supports multiple LLM providers via API keys
flyctl secrets set OPENAI_API_KEY=sk-... -a <app-name>
# Or ANTHROPIC_API_KEY, GOOGLE_GEMINI_API_KEY, etc.

# Create YAML config (example: agent.yaml)
# Define agents, LLMs, and tools in pure YAML

# Usage
hector serve --config agent.yaml     # Start server
hector chat assistant                # Interactive chat
hector call assistant "prompt"       # Single call
hector list                          # List agents
```

**Ollama:**

```bash
# No API keys needed - runs locally
nohup ollama serve > ~/ollama.log 2>&1 &
ollama pull llama3.2
ollama run llama3.2
```

#### Claude Code LLM Provider Configuration

Claude Code natively supports only Anthropic's Claude models. However, you can configure it to work with alternate LLM
providers through environment variables and proxy solutions.

##### Native Anthropic Configuration (Default)

```bash
# Set via environment variable (takes priority over Claude.ai subscription)
export ANTHROPIC_API_KEY=sk-ant-...

# Or via Fly.io secrets (recommended)
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... -a <app-name>

# Get API key: https://console.anthropic.com/
```

**Important:** If `ANTHROPIC_API_KEY` is set, Claude Code will use API-based billing instead of your Claude.ai
subscription (Pro/Max/Team/Enterprise).

##### OpenAI-Compatible Providers (Direct Method)

Some providers offer Anthropic-compatible API endpoints that work directly with Claude Code via `ANTHROPIC_BASE_URL`:

**Core Pattern:**

```bash
export ANTHROPIC_BASE_URL=https://api.provider.com/path
export ANTHROPIC_API_KEY=provider-api-key
```

**Z.ai GLM-4.6 (Direct API):**

```bash
# Via Z.ai's native API
flyctl secrets set ANTHROPIC_BASE_URL=https://api.z.ai/api/paas/v4 -a <app-name>
flyctl secrets set ANTHROPIC_API_KEY=your-z-ai-api-key -a <app-name>

# Get API key: https://z.ai (sign up for account)
# Models: glm-4.6, glm-4.5, glm-4.5-air
# Cost: Competitive pricing, check Z.ai pricing page
```

**Z.ai via OpenRouter (Easier):**

```bash
# Access 400+ models including Z.ai through single API
flyctl secrets set ANTHROPIC_BASE_URL=https://openrouter.ai/api/v1 -a <app-name>
flyctl secrets set ANTHROPIC_API_KEY=sk-or-... -a <app-name>

# Get API key: https://openrouter.ai/keys
# Models available:
# - z-ai/glm-4.6
# - z-ai/glm-4.5
# - z-ai/glm-4.5-air:free (free tier!)
```

**DeepSeek (Native Anthropic-Compatible):**

```bash
# DeepSeek offers native Anthropic-compatible API
flyctl secrets set ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic -a <app-name>
flyctl secrets set ANTHROPIC_API_KEY=your-deepseek-key -a <app-name>
flyctl secrets set ANTHROPIC_MODEL=deepseek-chat -a <app-name>
flyctl secrets set ANTHROPIC_SMALL_FAST_MODEL=deepseek-chat -a <app-name>

# Get API key: https://platform.deepseek.com/
# Cost: ~$1/M tokens (85-95% cheaper than Claude)
```

**Other OpenAI-Compatible Providers:**

```bash
# Groq (ultra-fast inference)
export ANTHROPIC_BASE_URL=https://api.groq.com/openai/v1
export ANTHROPIC_API_KEY=gsk-...  # Get from https://console.groq.com

# Together AI (200+ models)
export ANTHROPIC_BASE_URL=https://api.together.xyz/v1
export ANTHROPIC_API_KEY=...  # Get from https://api.together.xyz

# Mistral AI
export ANTHROPIC_BASE_URL=https://api.mistral.ai/v1
export ANTHROPIC_API_KEY=...  # Get from https://console.mistral.ai

# Fireworks AI
export ANTHROPIC_BASE_URL=https://api.fireworks.ai/inference/v1
export ANTHROPIC_API_KEY=fw-...  # Get from https://fireworks.ai
```

##### Proxy Solutions for Advanced Use Cases

When providers don't offer Anthropic-compatible APIs, or when you need advanced features like model-specific routing,
fallback chains, or cost optimization, use a proxy solution.

**When to Use Proxies:**

- Provider doesn't have native Anthropic-compatible format (OpenAI, Gemini, etc.)
- Need different models for sonnet vs haiku requests
- Want fallback chains (e.g., AWS Bedrock → Anthropic if quota exceeded)
- Cost optimization across multiple providers
- Enterprise features (monitoring, rate limiting, multi-tenancy)

### Option 1: claude-code-proxy (Simple & Fast)

A lightweight proxy that translates Claude API requests to OpenAI-compatible APIs.

```bash
# Install on development machine or inside VM
npm install -g claude-code-proxy

# Configure environment variables
export OPENAI_API_KEY=your-provider-key
export OPENAI_BASE_URL=https://api.provider.com/v1
export BIG_MODEL=gpt-4o          # Used for sonnet requests
export SMALL_MODEL=gpt-4o-mini   # Used for haiku requests
export PREFERRED_PROVIDER=openai  # openai, google, or anthropic

# Start proxy (runs on localhost:8082 by default)
claude-code-proxy &

# Configure Claude Code to use proxy
export ANTHROPIC_BASE_URL=http://localhost:8082
export ANTHROPIC_API_KEY=dummy  # Proxy uses OPENAI_API_KEY

# Run Claude Code
claude
```

**Example: Using claude-code-proxy with GLM-4.6 via OpenRouter:**

```bash
# On Fly.io VM
flyctl secrets set OPENAI_API_KEY=sk-or-... -a <app-name>
flyctl secrets set OPENAI_BASE_URL=https://openrouter.ai/api/v1 -a <app-name>
flyctl secrets set BIG_MODEL=z-ai/glm-4.6 -a <app-name>
flyctl secrets set SMALL_MODEL=z-ai/glm-4.5-air:free -a <app-name>
flyctl secrets set ANTHROPIC_BASE_URL=http://localhost:8082 -a <app-name>

# Inside VM (add to startup script)
claude-code-proxy &
```

### Option 2: LiteLLM Proxy (Enterprise-Grade)

LiteLLM provides a unified API gateway for 100+ LLM providers with advanced features:

- Centralized authentication and usage tracking
- Cost controls and budget limits
- Fallback chains for high availability
- Load balancing across providers
- Multi-tenancy support

```yaml
# /workspace/litellm-config.yaml
model_list:
  # Map Claude models to various providers
  - model_name: claude-sonnet-4
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-v2
      aws_access_key_id: os.environ/AWS_ACCESS_KEY_ID
      aws_secret_access_key: os.environ/AWS_SECRET_ACCESS_KEY

  - model_name: claude-haiku-3
    litellm_params:
      model: gemini/gemini-2.0-flash
      api_key: os.environ/GOOGLE_GEMINI_API_KEY

  # Fallback configuration
  - model_name: claude-sonnet-fallback
    litellm_params:
      model: anthropic/claude-3-5-sonnet
      api_key: os.environ/ANTHROPIC_API_KEY
```

```bash
# Install LiteLLM
pip install litellm[proxy]

# Start proxy with config
litellm --config /workspace/litellm-config.yaml --port 4000

# Configure Claude Code
export ANTHROPIC_BASE_URL=http://localhost:4000
export ANTHROPIC_API_KEY=$LITELLM_MASTER_KEY  # From config

# Run Claude Code
claude
```

**Example: Cost-Optimized Multi-Provider Setup:**

```yaml
# litellm-config.yaml - Route to cheapest provider per task
model_list:
  - model_name: claude-sonnet-4
    litellm_params:
      model: deepseek/deepseek-chat # $1/M tokens
      api_key: os.environ/DEEPSEEK_API_KEY

  - model_name: claude-haiku-3
    litellm_params:
      model: gemini/gemini-2.0-flash # Free tier
      api_key: os.environ/GOOGLE_GEMINI_API_KEY

  # Fallback to Anthropic for complex tasks
  - model_name: claude-opus-4
    litellm_params:
      model: anthropic/claude-opus-4
      api_key: os.environ/ANTHROPIC_API_KEY
```

### Option 3: Claude Code Router (Multi-Provider Management)

Claude Code Router provides intelligent routing with support for multiple providers:

```json
{
  "providers": [
    {
      "name": "openrouter",
      "api_base_url": "https://openrouter.ai/api/v1/chat/completions",
      "api_key": "${OPENROUTER_API_KEY}",
      "models": ["z-ai/glm-4.6", "anthropic/claude-3.5-sonnet"]
    },
    {
      "name": "deepseek",
      "api_base_url": "https://api.deepseek.com/chat/completions",
      "api_key": "${DEEPSEEK_API_KEY}",
      "models": ["deepseek-chat", "deepseek-reasoner"]
    },
    {
      "name": "groq",
      "api_base_url": "https://api.groq.com/openai/v1/chat/completions",
      "api_key": "${GROQ_API_KEY}",
      "models": ["llama-3.1-70b-versatile", "mixtral-8x7b-32768"]
    }
  ]
}
```

#### Complete Setup Examples

##### Example 1: Pure Anthropic (Standard)

```bash
# Simplest setup - just use Anthropic API
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... -a <app-name>
```

##### Example 2: Z.ai GLM-4.6 Direct

```bash
# Use Z.ai's GLM-4.6 model directly
flyctl secrets set ANTHROPIC_BASE_URL=https://api.z.ai/api/paas/v4 -a <app-name>
flyctl secrets set ANTHROPIC_API_KEY=your-z-ai-key -a <app-name>
```

##### Example 3: Z.ai via OpenRouter (Easiest)

```bash
# Access GLM-4.6 plus 400+ other models
flyctl secrets set ANTHROPIC_BASE_URL=https://openrouter.ai/api/v1 -a <app-name>
flyctl secrets set ANTHROPIC_API_KEY=sk-or-... -a <app-name>
```

##### Example 4: Cost-Optimized (DeepSeek + Gemini)

```bash
# Set up claude-code-proxy with cheap providers
flyctl secrets set OPENAI_API_KEY=your-deepseek-key -a <app-name>
flyctl secrets set OPENAI_BASE_URL=https://api.deepseek.com/v1 -a <app-name>
flyctl secrets set BIG_MODEL=deepseek-chat -a <app-name>
flyctl secrets set SMALL_MODEL=gemini-2.0-flash -a <app-name>
flyctl secrets set GOOGLE_GEMINI_API_KEY=... -a <app-name>
flyctl secrets set ANTHROPIC_BASE_URL=http://localhost:8082 -a <app-name>

# Add to extension startup script:
# claude-code-proxy &
```

##### Example 5: Enterprise Multi-Cloud (LiteLLM)

```bash
# Set all provider keys
flyctl secrets set AWS_ACCESS_KEY_ID=... -a <app-name>
flyctl secrets set AWS_SECRET_ACCESS_KEY=... -a <app-name>
flyctl secrets set GOOGLE_GEMINI_API_KEY=... -a <app-name>
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... -a <app-name>
flyctl secrets set LITELLM_MASTER_KEY=$(openssl rand -hex 16) -a <app-name>
flyctl secrets set ANTHROPIC_BASE_URL=http://localhost:4000 -a <app-name>

# Deploy litellm-config.yaml to /workspace/
# Add to startup: litellm --config /workspace/litellm-config.yaml --port 4000 &
```

#### Security Best Practices

1. **Never Commit Secrets**: Add API keys to `.gitignore`. Use `.env.example` templates without actual keys.

2. **Use Fly.io Secrets for Production**: Secrets are encrypted at rest and only accessible inside the VM at
   runtime.

3. **Rotate Secrets Regularly**: Establish a rotation schedule, especially after team changes or suspected
   compromise.

4. **Principle of Least Privilege**: Use read-only or limited-scope API keys when possible. For cloud providers,
   create service accounts with minimal permissions.

5. **Separate Environments**: Use different API keys for development, staging, and production.

6. **Monitor Usage**: Track API usage and costs per provider to detect anomalies or abuse.

7. **Local Development**: For local dev, use `.env` files (add to `.gitignore`) or environment-specific profiles.

```bash
# .env.example (commit this)
ANTHROPIC_API_KEY=sk-ant-your_key_here
GOOGLE_GEMINI_API_KEY=your_key_here
OPENROUTER_API_KEY=sk-or-your_key_here

# .env (DON'T commit this)
ANTHROPIC_API_KEY=sk-ant-actual_secret_key
GOOGLE_GEMINI_API_KEY=actual_secret_key
OPENROUTER_API_KEY=sk-or-actual_secret_key
```

#### Cost Optimization Strategies

1. **Use Cheaper Models for Simple Tasks**: Route haiku/fast-tier requests to cheaper providers like DeepSeek
   ($1/M) or Gemini Flash (free tier).

2. **Local Models for Development**: Use Ollama with Llama 3.2 or CodeLlama during development to avoid API
   costs.

3. **Provider Comparison** (per 1M tokens, approximate):
   - **DeepSeek**: $1
   - **Gemini Flash**: Free tier, then $0.35
   - **GLM-4.5-Air**: Free (via OpenRouter)
   - **Claude Haiku**: $3
   - **GPT-4o-mini**: $0.30
   - **Claude Sonnet**: $15
   - **GPT-4o**: $10

4. **Use OpenRouter**: Access 400+ models with unified pricing, often cheaper than going direct.

5. **Implement Caching**: Some providers (Anthropic, OpenAI) support prompt caching to reduce costs on repeated queries.

6. **Free Tiers**: Take advantage of free tiers for development:
   - Gemini 2.0 Flash: Free with limits
   - GLM-4.5-Air: Free via OpenRouter
   - Ollama: Free, runs locally

#### Troubleshooting

**Secrets Not Accessible in VM:**

```bash
# Verify secrets are set
flyctl secrets list -a <app-name>

# Check if secrets are injected
flyctl ssh console -a <app-name>
env | grep API_KEY

# View deployment logs for errors
flyctl logs -a <app-name>

# Secrets require a deployment to take effect
# If you just set them, restart the machine:
flyctl machine restart <machine-id> -a <app-name>
```

**Provider Authentication Fails:**

```bash
# Verify API key format matches provider
# Anthropic: sk-ant-...
# OpenRouter: sk-or-...
# OpenAI: sk-...
# Perplexity: pplx-...

# Test with curl before using with Claude Code
curl -H "Authorization: Bearer $ANTHROPIC_API_KEY" \
  https://api.anthropic.com/v1/messages

# Check base URL (trailing slashes matter!)
echo $ANTHROPIC_BASE_URL
```

**Model Not Found:**

```bash
# Verify model name matches provider's catalog
# Z.ai: glm-4.6, glm-4.5, glm-4.5-air
# DeepSeek: deepseek-chat, deepseek-reasoner
# Groq: llama-3.1-70b-versatile, mixtral-8x7b-32768

# Check provider documentation for model availability
# Some models require special access or approval

# Test model availability with provider's CLI or API docs
```

**Proxy Connection Issues:**

```bash
# Verify proxy is running
ps aux | grep -E 'claude-code-proxy|litellm'
netstat -tuln | grep -E '8082|4000'

# Check proxy logs
tail -f /var/log/claude-code-proxy.log

# Test proxy endpoint
curl http://localhost:8082/health  # or :4000

# Restart proxy if needed
pkill -f claude-code-proxy
claude-code-proxy &
```

**High API Costs:**

```bash
# Review usage by provider
# Most providers offer usage dashboards

# Implement rate limiting with LiteLLM
# Set up budget alerts in provider dashboards

# Switch to cheaper providers for non-critical tasks
# Use local models (Ollama) during development

# Enable prompt caching where supported
# Optimize prompts to reduce token usage
```

**Region-Specific Issues:**

```bash
# Some providers restrict access by region
# Use VPN or region-specific endpoints if needed

# Example: AWS Bedrock requires specific regions
# Set AWS_DEFAULT_REGION appropriately

# Check provider status pages for regional outages
```

## IDE Customization

### VSCode Settings

**Workspace settings:**

```json
// /workspace/projects/active/my-app/.vscode/settings.json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  "typescript.preferences.importModuleSpecifier": "relative",
  "files.associations": {
    "*.css": "postcss"
  }
}
```

**Remote development settings:**

```json
// ~/.vscode-server/data/Machine/settings.json
{
  "terminal.integrated.shell.linux": "/bin/bash",
  "remote.SSH.remotePlatform": {
    "my-sindri-dev.fly.dev": "linux"
  },
  "workbench.colorTheme": "Dark+ (default dark)",
  "editor.minimap.enabled": false
}
```

### Claude Code Hooks

**Automated code formatting:**

```json
// /workspace/developer/.claude/settings.json
{
  "hooks": {
    "user-prompt-submit": "prettier --write .",
    "tool-use-start": "git add -A",
    "tool-use-end": "npm run lint --fix"
  },
  "outputStyles": {
    "default": {
      "codeBlock": {
        "showLineNumbers": true,
        "theme": "github-dark"
      }
    }
  }
}
```

## Project Templates

### Creating Custom Templates

**Template directory structure:**

```bash
mkdir -p /workspace/templates/my-stack
cd /workspace/templates/my-stack

# Project structure
mkdir -p src tests docs config
touch src/index.js tests/index.test.js README.md

# Package.json template
cat > package.json << 'EOF'
{
    "name": "{{PROJECT_NAME}}",
    "version": "1.0.0",
    "scripts": {
        "dev": "nodemon src/index.js",
        "test": "jest",
        "lint": "eslint src/"
    }
}
EOF

# Configuration files
cp /workspace/templates/common/.eslintrc.js .
cp /workspace/templates/common/.gitignore .
```

### CI/CD Integration

**GitHub Actions Setup:**

```bash
#!/bin/bash
# github-actions.sh.example - GitHub Actions development tools
# Extension API v1.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/extensions-common.sh"

EXT_NAME="github-actions"
EXT_VERSION="1.0.0"
EXT_DESCRIPTION="GitHub Actions development tools"
EXT_CATEGORY="ci-cd"

extension_init

prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."

  if ! command_exists curl; then
    print_error "curl is required but not installed"
    return 1
  fi

  print_success "All prerequisites met"
  return 0
}

install() {
  print_status "Installing ${EXT_NAME}..."

  # Install Act for local testing
  curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

  # GitHub CLI for workflow management
  if ! command_exists gh; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
      sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
      sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update && sudo apt-get install -y gh
  fi

  print_success "${EXT_NAME} installed successfully"
  return 0
}

configure() {
  print_status "Configuring ${EXT_NAME}..."

  # Create GitHub Actions templates
  mkdir -p /workspace/templates/github-workflows

  cat > /workspace/templates/github-workflows/remote-dev-test.yml << 'EOF'
name: Remote Development Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test-on-fly:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Setup Fly CLI
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Deploy test environment
        run: |
          flyctl deploy --remote-only \
            --build-arg ENVIRONMENT=test \
            -a test-claude-dev

      - name: Run tests
        run: |
          flyctl ssh console -a test-claude-dev \
            "cd /workspace/projects/active && npm test"

      - name: Cleanup
        if: always()
        run: |
          flyctl apps destroy test-claude-dev --yes
EOF

  cat > /workspace/templates/github-workflows/deploy.yml << 'EOF'
name: Deploy to Development

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Setup Fly CLI
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Deploy to development
        run: |
          flyctl deploy --remote-only -a my-sindri-dev
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
EOF

  print_success "${EXT_NAME} configured successfully"
  return 0
}

validate() {
  print_status "Validating ${EXT_NAME} installation..."

  if ! command_exists act; then
    print_error "act command not found"
    return 1
  fi

  if ! command_exists gh; then
    print_error "gh command not found"
    return 1
  fi

  print_success "${EXT_NAME} validation passed"
  return 0
}

status() {
  print_status "Checking ${EXT_NAME} status..."

  if command_exists act && command_exists gh; then
    print_success "GitHub Actions tools installed"
    print_success "act: $(act --version)"
    print_success "gh: $(gh --version | head -1)"
    return 0
  else
    print_warning "GitHub Actions tools not installed"
    return 1
  fi
}

remove() {
  print_status "Removing ${EXT_NAME}..."

  # Uninstall act
  sudo rm -f /usr/local/bin/act

  # Uninstall gh
  sudo apt-get remove -y gh

  # Remove templates
  rm -rf /workspace/templates/github-workflows

  print_success "${EXT_NAME} removed successfully"
  return 0
}
```

### Kubernetes Development

**Local Kubernetes Setup:**

```bash
#!/bin/bash
# kubernetes.sh.example - Kubernetes development tools
# Extension API v1.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/extensions-common.sh"

EXT_NAME="kubernetes"
EXT_VERSION="1.0.0"
EXT_DESCRIPTION="Kubernetes development tools"
EXT_CATEGORY="infrastructure"

extension_init

prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."

  if ! command_exists curl; then
    print_error "curl is required but not installed"
    return 1
  fi

  print_success "All prerequisites met"
  return 0
}

install() {
  print_status "Installing ${EXT_NAME}..."

  # Install k3s lightweight Kubernetes
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--data-dir /workspace/k3s" sh -

  # Install kubectl
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl

  # Install Helm
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  print_success "${EXT_NAME} installed successfully"
  return 0
}

configure() {
  print_status "Configuring ${EXT_NAME}..."

  # Configure kubeconfig
  mkdir -p "$HOME/.kube"
  sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
  sudo chown $(id -u):$(id -g) "$HOME/.kube/config"

  print_success "${EXT_NAME} configured successfully"
  return 0
}

validate() {
  print_status "Validating ${EXT_NAME} installation..."

  if ! command_exists kubectl; then
    print_error "kubectl command not found"
    return 1
  fi

  if ! command_exists helm; then
    print_error "helm command not found"
    return 1
  fi

  print_success "${EXT_NAME} validation passed"
  return 0
}

status() {
  print_status "Checking ${EXT_NAME} status..."

  if command_exists kubectl && command_exists helm; then
    print_success "Kubernetes tools installed"
    print_success "kubectl: $(kubectl version --client --short 2>/dev/null || echo 'unknown')"
    print_success "helm: $(helm version --short)"
    return 0
  else
    print_warning "Kubernetes tools not installed"
    return 1
  fi
}

remove() {
  print_status "Removing ${EXT_NAME}..."

  # Stop k3s
  sudo systemctl stop k3s
  sudo systemctl disable k3s

  # Uninstall k3s
  sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true

  # Remove kubectl
  sudo rm -f /usr/local/bin/kubectl

  # Uninstall helm
  sudo rm -f /usr/local/bin/helm

  # Remove config
  rm -rf "$HOME/.kube"

  print_success "${EXT_NAME} removed successfully"
  return 0
}
```

### Monitoring and Observability

**Monitoring Stack Setup:**

```bash
#!/bin/bash
# monitoring-stack.sh.example - Comprehensive monitoring stack
# Extension API v1.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/extensions-common.sh"

EXT_NAME="monitoring-stack"
EXT_VERSION="1.0.0"
EXT_DESCRIPTION="Prometheus, Grafana, and ELK stack"
EXT_CATEGORY="monitoring"

extension_init

prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."

  if ! command_exists wget; then
    print_error "wget is required but not installed"
    return 1
  fi

  if ! command_exists docker; then
    print_error "Docker is required - activate 'docker' extension first"
    return 1
  fi

  print_success "All prerequisites met"
  return 0
}

install() {
  print_status "Installing ${EXT_NAME}..."

  # Prometheus
  wget https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-amd64.tar.gz
  tar xvfz prometheus-*.tar.gz
  sudo mv prometheus-*/prometheus /usr/local/bin/
  sudo mv prometheus-*/promtool /usr/local/bin/
  rm -rf prometheus-*

  # Node Exporter
  wget https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz
  tar xvfz node_exporter-*.tar.gz
  sudo mv node_exporter-*/node_exporter /usr/local/bin/
  rm -rf node_exporter-*

  # Grafana
  sudo apt-get install -y software-properties-common apt-transport-https
  sudo mkdir -p /etc/apt/keyrings/
  wget -q -O - https://apt.grafana.com/gpg.key | \
    gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
  echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | \
    sudo tee /etc/apt/sources.list.d/grafana.list
  sudo apt-get update
  sudo apt-get install -y grafana

  print_success "${EXT_NAME} installed successfully"
  return 0
}

configure() {
  print_status "Configuring ${EXT_NAME}..."

  # Create Docker Compose for ELK stack
  mkdir -p /workspace/docker/monitoring
  cat > /workspace/docker/monitoring/docker-compose.yml << 'EOF'
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:9.1.3
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - /workspace/data/elasticsearch:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"

  kibana:
    image: docker.elastic.co/kibana/kibana:9.1.3
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

  logstash:
    image: docker.elastic.co/logstash/logstash:9.1.3
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    depends_on:
      - elasticsearch
EOF

  # Enable and start Grafana
  sudo systemctl enable grafana-server
  sudo systemctl start grafana-server

  print_success "${EXT_NAME} configured successfully"
  print_success "Grafana available at http://localhost:3000 (admin/admin)"
  return 0
}

validate() {
  print_status "Validating ${EXT_NAME} installation..."

  if ! command_exists prometheus; then
    print_error "prometheus command not found"
    return 1
  fi

  if ! systemctl is-active --quiet grafana-server; then
    print_error "Grafana service not running"
    return 1
  fi

  print_success "${EXT_NAME} validation passed"
  return 0
}

status() {
  print_status "Checking ${EXT_NAME} status..."

  if command_exists prometheus; then
    print_success "Prometheus installed: $(prometheus --version 2>&1 | head -1)"
  fi

  if systemctl is-active --quiet grafana-server; then
    print_success "Grafana is running"
  else
    print_warning "Grafana is not running"
  fi

  return 0
}

remove() {
  print_status "Removing ${EXT_NAME}..."

  # Stop and remove Grafana
  sudo systemctl stop grafana-server
  sudo systemctl disable grafana-server
  sudo apt-get remove -y grafana

  # Remove Prometheus
  sudo rm -f /usr/local/bin/prometheus /usr/local/bin/promtool

  # Remove Node Exporter
  sudo rm -f /usr/local/bin/node_exporter

  # Remove Docker Compose files
  rm -rf /workspace/docker/monitoring

  print_success "${EXT_NAME} removed successfully"
  return 0
}
```

This comprehensive customization system allows you to tailor the development environment to your specific needs
while maintaining consistency and automation through the Extension API v1.0.
