# Extension System v1.0

Sindri uses a manifest-based extension system to manage development tools and environments.
Extensions follow a standardized API with explicit dependency management and activation control.

## Overview

**Extension API v1.0** provides:

- **Manifest-based activation**: Control which extensions install via `active-extensions.conf`
- **Standardized API**: All extensions implement 6 required functions
- **Dependency management**: Explicit prerequisites checking before installation
- **CLI management**: `extension-manager` tool for activation and installation
- **Idempotent operations**: Safe to re-run installations
- **Clean removal**: Proper uninstall with dependency warnings

## Quick Start

```bash
# List all available extensions
extension-manager list

# Install an extension (auto-activates if needed)
extension-manager install nodejs

# Or use interactive mode for guided setup
extension-manager --interactive

# Or manually edit manifest then install all
# Edit: /workspace/scripts/lib/extensions.d/active-extensions.conf
extension-manager install-all

# Check installation status
extension-manager status nodejs

# Validate installation
extension-manager validate nodejs
```

## Extension API v1.0

All extensions must implement these 6 functions:

### 1. `prerequisites()`

**Purpose**: Check system requirements before installation

**Returns**: `0` if all prerequisites met, `1` otherwise

**Checks**:

- Required system packages
- Commands available in PATH
- Disk space and memory
- Network connectivity
- Dependent extensions

**Example**:

```bash
prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."

  if ! command_exists curl; then
    print_error "curl is required but not installed"
    return 1
  fi

  print_success "All prerequisites met"
  return 0
}
```

### 2. `install()`

**Purpose**: Install packages and tools

**Returns**: `0` on success, `1` on failure

**Actions**:

- Download and install packages
- Compile from source if needed
- Verify installation success
- Handle already-installed gracefully

**Example**:

```bash
install() {
  print_status "Installing ${EXT_NAME}..."

  if command_exists rust; then
    print_warning "Rust already installed"
    return 0
  fi

  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

  print_success "Rust installed successfully"
  return 0
}
```

### 3. `configure()`

**Purpose**: Post-installation configuration

**Returns**: `0` on success, `1` on failure

**Actions**:

- Add to PATH in .bashrc
- Create configuration files
- Set environment variables
- Create SSH wrappers for non-interactive sessions

**Example**:

```bash
configure() {
  print_status "Configuring ${EXT_NAME}..."

  if ! grep -q "cargo/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
    print_success "Added cargo to PATH"
  fi

  return 0
}
```

### 4. `validate()`

**Purpose**: Run smoke tests to verify installation

**Returns**: `0` if valid, `1` if validation fails

**Tests**:

- Command availability
- Version checks
- Basic functionality tests
- Configuration validation

**Example**:

```bash
validate() {
  print_status "Validating ${EXT_NAME}..."

  if ! command_exists rustc; then
    print_error "rustc command not found"
    return 1
  fi

  print_success "Rust: $(rustc --version)"
  return 0
}
```

### 5. `status()`

**Purpose**: Display current installation state

**Returns**: `0` if installed, `1` if not installed

**Shows**:

- Installed version
- Configuration status
- Component availability
- Helpful diagnostics

**Example**:

```bash
status() {
  print_status "Checking ${EXT_NAME} status..."

  if ! command_exists rustc; then
    print_warning "Rust is not installed"
    return 1
  fi

  print_success "Rust: $(rustc --version)"
  print_success "Cargo: $(cargo --version)"
  return 0
}
```

### 6. `remove()`

**Purpose**: Uninstall and clean up

**Returns**: `0` on success, `1` on failure

**Actions**:

- Check for dependent extensions
- Prompt for confirmation
- Remove packages and files
- Clean up configuration
- Remove PATH modifications

**Example**:

```bash
remove() {
  print_warning "Uninstalling ${EXT_NAME}..."

  read -p "Remove Rust toolchain? (y/N): " -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    return 1
  fi

  rustup self uninstall -y
  print_success "Rust uninstalled"
  return 0
}
```

## Available Extensions

Extensions are organized by category in the activation manifest.

### Core Infrastructure

- **workspace-structure** - Base /workspace directory structure
- **nodejs** - Node.js LTS via NVM (Node Version Manager)
- **ssh-environment** - SSH wrappers for non-interactive sessions

### Claude AI

- **claude-config** - Claude Code CLI with developer configuration
- **nodejs-devtools** - TypeScript, ESLint, Prettier, nodemon, goalie

### Development Tools

- **monitoring** - System monitoring tools (htop, ncdu, glances)
- **playwright** - Browser automation testing framework
- **tmux-workspace** - Tmux session manager
- **agent-manager** - Claude Code agent management
- **context-loader** - Context management for Claude

### Programming Languages

- **python** - Python 3.13 with pip, venv, uv
- **rust** - Rust toolchain with cargo, clippy, rustfmt
- **golang** - Go 1.24 with gopls, delve, golangci-lint
- **ruby** - Ruby 3.4/3.3 with rbenv, Rails, Bundler
- **php** - PHP 8.3 with Composer, Symfony CLI
- **jvm** - SDKMAN with Java, Kotlin, Scala, Maven, Gradle
- **dotnet** - .NET SDK 9.0/8.0 with ASP.NET Core

### Infrastructure, Cloud, and AI

- **docker** - Docker Engine with compose, dive, ctop
- **infra-tools** - Terraform, Ansible, kubectl, Helm, Carvel, Pulumi
- **cloud-tools** - AWS, Azure, GCP, Oracle, DigitalOcean CLIs
- **ai-tools** - AI coding assistants (Codex, Gemini, Ollama, Fabric, Plandex)

### Post-Installation

- **post-cleanup** - Clean caches, set permissions, create tools summary (run LAST)

## Activation Manifest

Extensions are controlled via `/workspace/scripts/extensions.d/active-extensions.conf`:

```bash
# Protected extensions (required, cannot be removed):
workspace-structure
mise-config
ssh-environment

# Foundational languages (recommended):
nodejs
python

# Claude AI
claude-config
nodejs-devtools

# Languages
python
golang

# Infrastructure
docker
infra-tools

# Post-installation (always last)
post-cleanup
```

**Order matters**: Extensions execute top to bottom. List dependencies before dependents.

## Extension Manager

The `extension-manager` CLI tool manages extension lifecycle:

### List Extensions

```bash
# Show all available extensions
extension-manager list

# Shows: [ACTIVE] or [inactive] status for each extension
```

### Activate Extension

```bash
# Manually add to manifest (doesn't install yet)
# Edit: /workspace/scripts/lib/extensions.d/active-extensions.conf
# Add lines: nodejs, claude-config

# Or install directly (auto-activates)
extension-manager install nodejs
extension-manager install claude-config
```

### Install Extension

```bash
# Install single extension
extension-manager install nodejs

# Install all activated extensions
extension-manager install-all
```

### Check Status

```bash
# Show installation status
extension-manager status nodejs

# Shows version and component availability
```

### Validate Installation

```bash
# Run smoke tests
extension-manager validate nodejs

# Returns 0 if valid, 1 if issues found
```

### Uninstall Extension

```bash
# Remove extension and clean up
extension-manager uninstall nodejs

# Checks for dependent extensions first
```

### Reorder Priority

```bash
# Change execution order in manifest
extension-manager reorder nodejs 5

# Moves nodejs to position 5
```

## Creating Extensions

### 1. Copy Template

```bash
cp ../../../docs/templates/template.extension my-extension.extension
```

### 2. Update Metadata

```bash
#!/bin/bash
# my-extension.extension - Brief description
# Extension API v1.0

EXT_NAME="my-extension"
EXT_VERSION="1.0.0"
EXT_DESCRIPTION="What this extension provides"
EXT_CATEGORY="utility"  # utility, language, infrastructure
```

### 3. Source Shared Helper Functions

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$(dirname "$SCRIPT_DIR")")/extensions-common.sh"

# Initialize extension (loads common.sh and sets up environment)
extension_init
```

**Available Helper Functions:**

The `extensions-common.sh` library provides these helper functions to eliminate code duplication:

**Environment Helpers:**

- `is_ci_mode()` - Check if running in CI
- `activate_mise_environment()` - Activate mise in current shell

**Prerequisite Checks:**

- `check_mise_prerequisite()` - Verify mise is installed
- `check_disk_space [mb]` - Check available disk space (default 600MB)

**Status Helpers:**

- `print_extension_header()` - Print standard extension header with metadata

**Validation Helpers:**

- `validate_commands <array>` - Validate multiple commands with version checks

**mise Helpers:**

- `install_mise_config "name"` - Install mise TOML configuration (handles CI vs dev selection)
- `remove_mise_config "name"` - Remove mise configuration

**Git Helpers:**

- `setup_git_aliases "alias:command" ...` - Setup git aliases
- `cleanup_git_aliases "alias1" "alias2" ...` - Remove git aliases

**Cleanup Helpers:**

- `cleanup_bashrc "marker"` - Remove extension entries from .bashrc
- `prompt_confirmation "question"` - Standardized yes/no prompt
- `show_dependent_extensions_warning "cmd1" "cmd2"` - Check and display dependent extensions

**Main Execution Wrapper:**

- `extension_main "$@"` - Standard main execution block (replaces manual case statement)

### 4. Implement Required Functions

Implement all 6 API functions: `prerequisites()`, `install()`, `configure()`, `validate()`, `status()`, `remove()`

**Use helper functions to reduce boilerplate:**

```bash
prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."
  check_mise_prerequisite || return 1
  check_disk_space 500
  print_success "All prerequisites met"
  return 0
}

install() {
  print_status "Installing ${EXT_NAME}..."
  install_mise_config "${EXT_NAME}" || return 1
  return 0
}

configure() {
  print_status "Configuring ${EXT_NAME}..."
  setup_git_aliases "my-test:!mytool test"
  print_success "Configuration complete"
  return 0
}

validate() {
  print_status "Validating ${EXT_NAME}..."
  activate_mise_environment
  declare -A checks=([mytool]="--version")
  validate_commands checks
}

status() {
  print_extension_header
  if command_exists mytool; then
    print_success "Installed: $(mytool --version)"
    return 0
  else
    print_warning "Not installed"
    return 1
  fi
}

remove() {
  print_status "Removing ${EXT_NAME}..."
  show_dependent_extensions_warning "mytool"
  remove_mise_config "${EXT_NAME}"
  cleanup_git_aliases "my-test"
  cleanup_bashrc "# ${EXT_NAME} - added by extension"
  print_success "Removed successfully"
  return 0
}
```

### 5. Add Main Execution Block

```bash
# Use helper instead of manual case statement
extension_main "$@"
```

### 6. Test Extension

```bash
# Test each function individually
./my-extension.extension prerequisites
./my-extension.extension install
./my-extension.extension configure
./my-extension.extension validate
./my-extension.extension status

# Or use extension-manager (install auto-activates)
extension-manager install my-extension
extension-manager validate my-extension
```

### Helper Function Reference

See `docs/templates/template.extension` for comprehensive examples of using all helper functions. Key benefits:

1. **Less Code**: Helper functions eliminate 50-100 lines of boilerplate per extension
2. **Consistency**: All extensions use the same patterns
3. **Maintainability**: Bug fixes in helpers benefit all extensions
4. **New Features**: Get new capabilities automatically (e.g., dependency checking)
5. **Testing**: Shared functions have centralized tests

## Best Practices

### 1. Idempotent Operations

Extensions must be safe to re-run:

```bash
install() {
  if command_exists my-tool; then
    print_warning "Already installed"
    return 0
  fi

  # Install logic here
}
```

### 2. Explicit Dependencies

Declare dependencies in `prerequisites()`:

```bash
prerequisites() {
  if ! command_exists npm; then
    print_error "nodejs extension required"
    print_status "Run: extension-manager install nodejs"
    return 1
  fi
  return 0
}
```

### 3. Graceful Error Handling

Don't exit on minor failures:

```bash
install() {
  npm install -g tool1 || print_warning "tool1 failed"
  npm install -g tool2 || print_warning "tool2 failed"

  # Return success if at least one tool installed
  command_exists tool1 || command_exists tool2
}
```

### 4. Consistent Logging

Use provided print functions:

- `print_status` - Informational messages
- `print_success` - Success messages
- `print_error` - Error messages
- `print_warning` - Warning messages
- `print_debug` - Debug output (only when DEBUG=true)

### 5. User-Space Installation

Avoid sudo when possible. Use version managers and user-space installation methods:

```bash
# Good: Use version managers (recommended pattern)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash  # Node.js
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh                 # Rust
curl -s "https://get.sdkman.io" | bash                                          # JVM languages

# Good: Language package managers with user flags
# Note: Replace "package" with actual package name (e.g., requests, ripgrep, rails)
pip install --user package            # Python
cargo install package                 # Rust (installs to ~/.cargo/bin)
gem install --user-install package    # Ruby

# Avoid: System-wide installation requiring sudo
sudo npm install -g package
sudo pip install package
sudo gem install package
```

**Important for Node.js/NVM**: Do NOT set npm prefix when using NVM:

```bash
# WRONG: Conflicts with NVM
npm config set prefix "$HOME/.npm-global"

# CORRECT: Let NVM manage global packages
# NVM already provides user-space global installs without sudo
# Global packages install to: $NVM_DIR/versions/node/vX.X.X/bin
npm install -g package  # No sudo needed, installs to NVM directory
```

### 6. SSH Session Support

Create wrappers for non-interactive SSH:

```bash
configure() {
  if command_exists create_tool_wrapper 2>/dev/null; then
    create_tool_wrapper "my-tool" "$(which my-tool)"
  fi
}
```

### 7. Clean Configuration

Add comments when modifying .bashrc:

```bash
echo "" >> "$HOME/.bashrc"
echo "# ${EXT_NAME} - description" >> "$HOME/.bashrc"
echo "export PATH=\"$HOME/.local/bin:\$PATH\"" >> "$HOME/.bashrc"
```

### 8. Manifest Ordering

Consider dependencies when ordering in manifest:

```bash
# Good: nodejs before claude-config
nodejs
claude-config

# Bad: claude-config will fail prerequisites
claude-config
nodejs
```

## Debugging

### Enable Debug Output

```bash
# Set DEBUG environment variable
DEBUG=true extension-manager install nodejs

# Or for full vm-configure
DEBUG=true /workspace/scripts/vm-configure.sh
```

### Test Individual Functions

```bash
# Run specific function
bash -x my-extension.sh.example install

# Check prerequisites only
my-extension.sh.example prerequisites && echo "OK" || echo "FAIL"
```

### Check Logs

```bash
# Extension-manager logs to stdout/stderr
extension-manager install nodejs 2>&1 | tee install.log

# Check what's activated
cat /workspace/scripts/extensions.d/active-extensions.conf
```

### Validate Manually

```bash
# Check installation state
extension-manager status my-extension

# Run validation tests
extension-manager validate my-extension

# List all active extensions
extension-manager list | grep ACTIVE
```

## Migration from legacy extensions

If you have custom extensions using the old numbered prefix system (e.g., `50-my-tool.sh`):

### 1. Rename File

```bash
mv 50-my-tool.sh my-tool.sh.example
```

### 2. Add Metadata

Add `EXT_NAME`, `EXT_VERSION`, `EXT_DESCRIPTION`, `EXT_CATEGORY` at the top.

### 3. Wrap in Functions

Convert script body into `install()` function. Add other 5 API functions.

### 4. Install Extension

```bash
# Install command will auto-activate the extension
extension-manager install my-tool

# Or manually add to active-extensions.conf then run install-all
```

### 5. Test

```bash
extension-manager validate my-tool
```

## Troubleshooting

### Extension Won't Activate

```bash
# Check file exists
ls -l /workspace/scripts/lib/extensions.d/my-extension.sh.example

# Check file permissions
chmod +x my-extension.sh.example

# Check syntax
bash -n my-extension.sh.example
```

### Prerequisites Fail

```bash
# Run prerequisites manually
./my-extension.sh.example prerequisites

# Check what's missing
extension-manager status dependency-name
```

### Installation Fails

```bash
# Enable debug mode
DEBUG=true extension-manager install my-extension

# Check disk space
df -h /workspace

# Check network
curl -I https://github.com
```

### Validation Fails

```bash
# See what failed
extension-manager validate my-extension

# Check command availability
which expected-command

# Check PATH
echo $PATH
```

## Reference

- **Extension Template**: `template.sh.example` - Complete reference implementation
- **Extension Manager**: `/workspace/scripts/lib/extension-manager.sh` - CLI tool source
- **Active Manifest**: `/workspace/scripts/extensions.d/active-extensions.conf` - Activation list
- **Common Functions**: `/workspace/scripts/lib/common.sh` - Shared utilities
- **Documentation**: `/workspace/projects/active/sindri/CLAUDE.md` - Full project docs
