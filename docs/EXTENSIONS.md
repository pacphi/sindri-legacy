# Extension System Documentation

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Extension Management Commands](#extension-management-commands)
- [Available Extensions](#available-extensions)
- [mise Integration Guide](#mise-integration-guide)
- [Troubleshooting](#troubleshooting)
- [Extension API Specification](#extension-api-specification)
- [Extension Versioning Strategy](EXTENSION_VERSIONING.md)
- [Creating Extensions](#creating-extensions)
- [Upgrading Extensions to API v2.0](#upgrading-extensions-to-api-v20)
- [TOML Configuration Reference](#toml-configuration-reference)
- [Extension Manifest](#extension-manifest)
- [Protected Extensions](#protected-extensions)
- [Development Guidelines](#development-guidelines)
- [Advanced Topics](#advanced-topics)

---

## Overview

Sindri uses a manifest-based extension system to manage development tools and environments. Extensions provide language
runtimes, development tools, infrastructure utilities, and AI coding assistants.

The extension system supports two approaches:

- **mise-powered extensions**: Using mise for unified version management (Node.js, Python, Rust, Go, Ruby)
- **Traditional extensions**: Using language-specific version managers (SDKMAN, etc.)
- **mise-powered extensions**: Using mise for unified tool management with declarative TOML configuration

### Extension API Versions

- **API v1.0**: Core functionality (prerequisites, install, configure, validate, status, remove)
- **API v2.0**: Adds standardized upgrade support with `upgrade()` function and installation metadata

All extensions implement the Extension API, providing consistent installation, validation, and upgrade experiences.

**Extension Versioning**: Extensions use semantic versioning with dual version tracking (`EXT_VERSION` and `EXT_API_VERSION`). See [Extension Versioning Strategy](EXTENSION_VERSIONING.md) for development and release workflows.

---

## Quick Start

### Installing Extensions

```bash
# Interactive setup (recommended for first-time)
extension-manager --interactive

# Install specific extension
extension-manager install nodejs

# Install all active extensions from manifest
extension-manager install-all
```

### Common Operations

```bash
# List available extensions
extension-manager list

# Check extension status
extension-manager status nodejs

# Validate installation
extension-manager validate nodejs

# Upgrade extension (API v2.0)
extension-manager upgrade nodejs

# Upgrade all extensions
extension-manager upgrade-all --dry-run  # Preview
extension-manager upgrade-all            # Execute
```

---

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

### Upgrade Operations (API v2.0)

```bash
# Upgrade single extension
extension-manager upgrade <name>

# Preview upgrades (dry-run)
extension-manager upgrade-all --dry-run

# Upgrade all extensions
extension-manager upgrade-all

# Check for available updates
extension-manager check-updates

# View upgrade history
extension-manager upgrade-history
extension-manager upgrade-history <name> 20  # Last 20 entries

# Rollback extension
extension-manager rollback <name>
```

### Advanced Operations

```bash
# Export status as JSON
extension-manager status-all --json

# Show version information
extension-manager --version

# Enable debug output
extension-manager install <name> --verbose
```

---

## Available Extensions

### Core Environment (Protected)

These extensions are **protected** and cannot be removed. They are automatically installed on first container startup.

| Extension             | Description                               | Tool Manager | Version |
| --------------------- | ----------------------------------------- | ------------ | ------- |
| `workspace-structure` | Base directory structure                  | N/A          | 2.0.0   |
| `mise-config`         | Unified tool version manager              | N/A          | 2.0.0   |
| `ssh-environment`     | SSH wrappers for non-interactive sessions | N/A          | 2.0.0   |

### Foundational Languages

While not protected, these are highly recommended as many tools depend on them.

| Extension | Description                                | Tool Manager | Version | Dependencies |
| --------- | ------------------------------------------ | ------------ | ------- | ------------ |
| `nodejs`  | Node.js LTS and npm                        | mise         | 2.0.0   | mise-config  |
| `python`  | Python 3.13 with pip, venv, uv, pipx tools | mise         | 2.0.0   | mise-config  |

### Claude AI Tools

| Extension         | Description                                   | Tool Manager       | Version | Dependencies        |
| ----------------- | --------------------------------------------- | ------------------ | ------- | ------------------- |
| `claude`          | Claude Code CLI with developer configuration  | native             | 2.0.0   | -                   |
| `nodejs-devtools` | TypeScript, ESLint, Prettier, nodemon, goalie | mise (npm backend) | 2.0.0   | nodejs, mise-config |

### Additional Language Runtimes

| Extension | Description                                    | Tool Manager     | Version | Dependencies |
| --------- | ---------------------------------------------- | ---------------- | ------- | ------------ |
| `rust`    | Rust toolchain with cargo, clippy, rustfmt     | mise             | 2.0.0   | mise-config  |
| `golang`  | Go 1.24 with gopls, delve, golangci-lint       | mise             | 2.0.0   | mise-config  |
| `ruby`    | Ruby 3.4.7 with mise, Rails, Bundler           | mise             | 2.0.0   | automatic    |
| `php`     | PHP 8.4 with Composer, Symfony CLI             | apt (Ondrej PPA) | 2.1.0   | automatic    |
| `jvm`     | SDKMAN with Java, Kotlin, Scala, Maven, Gradle | SDKMAN           | 2.0.0   | N/A          |
| `dotnet`  | .NET SDK 9.0/8.0 with ASP.NET Core             | apt (Microsoft)  | 2.0.0   | N/A          |

### Infrastructure & DevOps

| Extension     | Description                                        | Tool Manager        | Version |
| ------------- | -------------------------------------------------- | ------------------- | ------- |
| `docker`      | Docker Engine with compose, dive, ctop             | apt + binary        | 2.0.0   |
| `infra-tools` | Terraform, Ansible, kubectl, Helm, Carvel          | Mixed               | 2.0.0   |
| `cloud-tools` | AWS, Azure, GCP, Oracle, DigitalOcean CLIs         | Official installers | 2.0.0   |
| `ai-tools`    | AI coding assistants (Codex, Gemini, Ollama, etc.) | Mixed               | 2.0.0   |

### Monitoring & Utilities

| Extension        | Description                                         | Tool Manager  | Version |
| ---------------- | --------------------------------------------------- | ------------- | ------- |
| `monitoring`     | System monitoring tools (htop, glances, btop, etc.) | apt           | 2.0.0   |
| `tmux-workspace` | Tmux session management                             | apt           | 2.0.0   |
| `playwright`     | Browser automation testing                          | npm           | 2.0.0   |
| `agent-manager`  | Claude Code agent management                        | Custom        | 2.0.0   |
| `context-loader` | Context system for Claude                           | Custom        | 2.0.0   |
| `github-cli`     | GitHub CLI authentication and workflows             | Pre-installed | 2.0.0   |

---

## mise Integration Guide

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

### mise-Powered Extensions

The following extensions use mise for tool installation and version management (all require `mise-config`):

- **nodejs**: Node.js LTS via mise
- **python**: Python 3.13 + pipx tools via mise
- **rust**: Rust stable + cargo tools via mise
- **golang**: Go 1.24 + go tools via mise
- **nodejs-devtools**: npm global tools via mise

### Common mise Commands

```bash
# List all installed tools and versions
mise ls

# List versions of a specific tool
mise ls node
mise ls python

# Install or switch tool versions
mise use node@20          # Switch to Node.js 20
mise use python@3.11      # Switch to Python 3.11

# Update all tools to latest versions
mise upgrade

# Check for configuration issues
mise doctor

# View current environment
mise env

# Install tools from mise.toml
mise install
```

### Per-Project Tool Versions

Create a `mise.toml` file in your project root to specify tool versions:

```toml
[tools]
node = "20"
python = "3.11"
rust = "1.75"

[env]
NODE_ENV = "development"
```

mise automatically switches to the specified versions when you enter the directory.

### CI Mode and TOML Selection

Extensions support two configurations via `CI_MODE` environment variable:

| Environment | TOML File             | Purpose                                     |
| ----------- | --------------------- | ------------------------------------------- |
| Development | `<extension>.toml`    | Full development environment with all tools |
| CI/Testing  | `<extension>-ci.toml` | Minimal environment for faster CI builds    |

**Setting CI_MODE:**

```bash
# On host machine (before deployment)
flyctl secrets set CI_MODE="true" -a <app-name>

# Or in deployment script
export CI_MODE="true"
./scripts/vm-setup.sh --app-name test-vm
```

---

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

---

## Extension API Specification

### API v1.0 Functions

All extensions must implement these six standard functions:

| Function          | Purpose                                       | Required |
| ----------------- | --------------------------------------------- | -------- |
| `prerequisites()` | Check system requirements before installation | Yes      |
| `install()`       | Install packages and tools                    | Yes      |
| `configure()`     | Post-install configuration and setup          | Yes      |
| `validate()`      | Run smoke tests to verify installation        | Yes      |
| `status()`        | Check installation state and display metadata | Yes      |
| `remove()`        | Uninstall and cleanup                         | Yes      |

### API v2.0 Additions

API v2.0 adds standardized upgrade support:

| Function    | Purpose                              | Required   |
| ----------- | ------------------------------------ | ---------- |
| `upgrade()` | Upgrade installed tools and packages | Yes (v2.0) |

### Required Metadata Fields

#### API v1.0 Metadata

```bash
EXT_NAME="myextension"
EXT_VERSION="2.0.0"
EXT_DESCRIPTION="My tool via mise"
EXT_CATEGORY="language"
```

#### API v2.0 Metadata

```bash
EXT_NAME="myextension"
EXT_VERSION="2.0.0"
EXT_DESCRIPTION="My tool via mise"
EXT_CATEGORY="language"
EXT_INSTALL_METHOD="mise"          # New in v2.0
EXT_UPGRADE_STRATEGY="automatic"   # New in v2.0
```

### Installation Methods (API v2.0)

Valid values for `EXT_INSTALL_METHOD`:

- `mise` - Tools managed by mise (Node.js, Python, Rust, Go, etc.)
- `apt` - APT package manager (Docker, PHP, .NET, monitoring tools)
- `binary` - Direct binary downloads (GitHub releases, CDN, etc.)
- `git` - Git clone + manual build (Ollama, etc.)
- `native` - Pre-installed in Docker image (GitHub CLI, system tools)
- `mixed` - Multiple methods (Docker: APT + binaries)
- `manual` - Custom installation requiring manual intervention

### Upgrade Strategies (API v2.0)

Valid values for `EXT_UPGRADE_STRATEGY`:

- `automatic` - Upgrade to latest automatically without confirmation
- `manual` - Require explicit user confirmation before upgrading
- `pinned` - Never upgrade (version locked for compatibility)
- `security-only` - Only apply security patches, skip feature updates

### Return Codes

- `0` - Success
- `1` - Failure/Error
- `2` - Manual action required (API v2.0 upgrade only)

### Extension Categories

Use standard categories for consistency:

| Category         | Purpose                            | Examples                                          |
| ---------------- | ---------------------------------- | ------------------------------------------------- |
| `language`       | Language runtimes                  | nodejs, python, rust, golang                      |
| `devtools`       | Development utilities              | nodejs-devtools, monitoring                       |
| `infrastructure` | Infrastructure tools               | docker, infra-tools, cloud-tools                  |
| `ai`             | AI coding assistants               | claude, ai-tools, agent-manager                   |
| `core`           | Core system components (protected) | workspace-structure, mise-config, ssh-environment |
| `utility`        | General utilities                  | tmux-workspace, playwright                        |

---

## Creating Extensions

### File Naming Conventions

| File Type        | Pattern            | Example            |
| ---------------- | ------------------ | ------------------ |
| Extension script | `<name>.extension` | `nodejs.extension` |
| Development TOML | `<name>.toml`      | `nodejs.toml`      |
| CI TOML          | `<name>-ci.toml`   | `nodejs-ci.toml`   |

### Extension Template (API v2.0)

```bash
#!/bin/bash
# myextension.extension - My custom extension
# Extension API v2.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/extensions-common.sh"

# ============================================================================
# METADATA
# ============================================================================

EXT_NAME="myextension"
EXT_VERSION="2.0.0"
EXT_DESCRIPTION="My tool via mise"
EXT_CATEGORY="language"
EXT_INSTALL_METHOD="mise"
EXT_UPGRADE_STRATEGY="automatic"

extension_init

# ============================================================================
# PREREQUISITES
# ============================================================================

prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."

  # Require mise
  check_mise_prerequisite || return 1
  check_disk_space 500

  print_success "All prerequisites met"
  return 0
}

# ============================================================================
# INSTALL
# ============================================================================

install() {
  print_status "Installing ${EXT_NAME}..."

  # Install mise configuration (handles CI vs dev TOML selection)
  install_mise_config "${EXT_NAME}" || return 1

  print_success "Installation complete"
  return 0
}

# ============================================================================
# CONFIGURE
# ============================================================================

configure() {
  print_status "Configuring ${EXT_NAME}..."

  # Setup git aliases if needed
  setup_git_aliases "my-cmd:!mytool command"

  print_success "Configuration complete"
  return 0
}

# ============================================================================
# VALIDATE
# ============================================================================

validate() {
  print_status "Validating ${EXT_NAME}..."

  activate_mise_environment

  # Validate commands with version checks
  declare -A checks=([mytool]="--version")
  validate_commands checks
}

# ============================================================================
# STATUS
# ============================================================================

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

# ============================================================================
# REMOVE
# ============================================================================

remove() {
  print_status "Removing ${EXT_NAME}..."

  show_dependent_extensions_warning "mytool"
  remove_mise_config "${EXT_NAME}"
  cleanup_git_aliases "my-cmd"
  cleanup_bashrc "# ${EXT_NAME} - added by extension"

  print_success "Removed successfully"
  return 0
}

# ============================================================================
# UPGRADE - Extension API v2.0
# ============================================================================

upgrade() {
  print_status "Upgrading ${EXT_NAME}..."

  if ! command_exists mise; then
    print_error "mise not installed"
    return 1
  fi

  activate_mise_environment

  # Show current version
  print_status "Current version:"
  mise current mytool 2>/dev/null || true
  echo ""

  # Upgrade via mise
  if upgrade_mise_tools "${EXT_NAME}"; then
    print_success "Tools upgraded successfully"

    echo ""
    print_status "Updated version:"
    mise current mytool

    return 0
  else
    print_error "Upgrade failed"
    return 1
  fi
}

# ============================================================================
# MAIN
# ============================================================================

extension_main "$@"
```

### Available Helper Functions

All helper functions are in `extensions-common.sh`:

#### Environment Helpers

```bash
is_ci_mode                      # Check if running in CI mode
activate_mise_environment       # Activate mise in current shell
```

#### Prerequisite Checks

```bash
check_mise_prerequisite         # Verify mise is installed
check_disk_space 1000          # Check available disk space (MB)
```

#### Status Helpers

```bash
print_extension_header         # Print standard extension header
validate_commands checks       # Validate multiple commands with version checks
```

#### mise Helpers

```bash
install_mise_config "nodejs"   # Install mise configuration (handles CI vs dev TOML)
remove_mise_config "nodejs"    # Remove mise configuration
upgrade_mise_tools "nodejs"    # Upgrade all mise-managed tools
```

#### Git Helpers

```bash
setup_git_aliases "alias:!command" ...     # Setup git aliases
cleanup_git_aliases "alias1" "alias2" ...  # Remove git aliases
```

#### Cleanup Helpers

```bash
cleanup_bashrc "pattern"                   # Remove entries from .bashrc
prompt_confirmation "question"             # Show confirmation prompt
show_dependent_extensions_warning "cmd"    # Check dependent extensions
```

#### Upgrade Helpers (API v2.0)

```bash
supports_upgrade                           # Check if upgrade() exists
is_dry_run                                 # Check if DRY_RUN=true
dry_run_prefix                             # Get "[DRY-RUN] " prefix
upgrade_apt_packages "pkg1" "pkg2" ...     # Upgrade APT packages
upgrade_github_binary "repo" "bin" "path"  # Upgrade GitHub release binary
upgrade_git_repo "/path" "rebuild-cmd"     # Pull and rebuild git repo
check_native_update "tool" "--version"     # Check native tool version
version_gt "v2.0.0" "v1.9.0"              # Compare versions
```

#### Extension Initialization

```bash
extension_init                 # Initialize extension (loads all utilities)
extension_main "$@"           # Main execution wrapper
```

### TOML Configuration Files

#### Development Configuration

**File**: `myextension.toml`

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

#### CI Configuration

**File**: `myextension-ci.toml`

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

---

## Upgrading Extensions to API v2.0

### Why Upgrade?

Extension API v2.0 adds standardized upgrade support:

- Consistent upgrade experience across all extensions
- Automated upgrade via `extension-manager upgrade-all`
- Dry-run capability for testing
- Upgrade history tracking
- Rollback support

### Migration Checklist

#### Step 1: Add Metadata Fields

Add `EXT_INSTALL_METHOD` and `EXT_UPGRADE_STRATEGY` after `EXT_CATEGORY`:

```bash
EXT_CATEGORY="language"
EXT_INSTALL_METHOD="mise"          # Choose: mise, apt, binary, git, native, mixed, manual
EXT_UPGRADE_STRATEGY="automatic"   # Choose: automatic, manual, pinned, security-only
```

#### Step 2: Implement upgrade() Function

Add `upgrade()` function after `remove()`:

```bash
# ============================================================================
# UPGRADE - Extension API v2.0
# ============================================================================

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    # Use appropriate helper based on installation method
    case "${EXT_INSTALL_METHOD}" in
        mise)
            upgrade_mise_tools "${EXT_NAME}"
            ;;
        apt)
            upgrade_apt_packages "package1" "package2"
            ;;
        binary)
            upgrade_github_binary "repo/name" "binary" "/path"
            ;;
        git)
            upgrade_git_repo "/path/to/repo" "rebuild-cmd"
            ;;
        native)
            check_native_update "tool-name" "--version"
            return $?
            ;;
        mixed)
            # Custom logic combining multiple methods
            ;;
    esac
}
```

#### Step 3: Bump Version

Update to major version 2.0.0:

```bash
EXT_VERSION="2.0.0"  # Major bump for API v2.0
```

#### Step 4: Test

```bash
# Install extension
extension-manager install myextension

# Test dry-run upgrade
extension-manager upgrade myextension --dry-run

# Test actual upgrade
extension-manager upgrade myextension

# Validate
extension-manager validate myextension
```

### Upgrade Patterns by Installation Method

#### Pattern 1: mise-Managed Tools

```bash
EXT_INSTALL_METHOD="mise"
EXT_UPGRADE_STRATEGY="automatic"

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    if ! command_exists mise; then
        print_error "mise not installed"
        return 1
    fi

    activate_mise_environment

    # Show current version
    print_status "Current version:"
    mise current nodejs 2>/dev/null || true
    echo ""

    # Upgrade via mise
    if upgrade_mise_tools "${EXT_NAME}"; then
        print_success "Tools upgraded successfully"

        echo ""
        print_status "Updated version:"
        mise current nodejs

        return 0
    else
        print_error "Upgrade failed"
        return 1
    fi
}
```

#### Pattern 2: APT Packages

```bash
EXT_INSTALL_METHOD="apt"
EXT_UPGRADE_STRATEGY="automatic"

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    # List packages to upgrade
    local packages=(
        "docker-ce"
        "docker-ce-cli"
        "containerd.io"
    )

    if upgrade_apt_packages "${packages[@]}"; then
        print_success "Packages upgraded successfully"
        return 0
    else
        print_error "APT upgrade failed"
        return 1
    fi
}
```

#### Pattern 3: GitHub Binary Releases

```bash
EXT_INSTALL_METHOD="binary"
EXT_UPGRADE_STRATEGY="automatic"

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    # Upgrade mise binary
    if upgrade_github_binary \
        "jdx/mise" \
        "mise" \
        "/usr/local/bin/mise" \
        "--version"; then
        print_success "Binary upgraded successfully"
        return 0
    else
        print_error "Binary upgrade failed"
        return 1
    fi
}
```

#### Pattern 4: Git Repositories

```bash
EXT_INSTALL_METHOD="git"
EXT_UPGRADE_STRATEGY="automatic"

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    local repo_path="$HOME/.some-tool"
    local rebuild_cmd="cd $repo_path && src/configure && make -C src"

    if upgrade_git_repo "$repo_path" "$rebuild_cmd"; then
        print_success "Repository upgraded and rebuilt"
        return 0
    else
        print_error "Git upgrade failed"
        return 1
    fi
}
```

#### Pattern 5: Native Tools (Pre-installed)

```bash
EXT_INSTALL_METHOD="native"
EXT_UPGRADE_STRATEGY="manual"

upgrade() {
    print_status "Checking ${EXT_NAME}..."

    # Check version but can't upgrade (requires Docker rebuild)
    check_native_update "gh" "version"
    return $?  # Returns 2 (manual action required)
}
```

#### Pattern 6: Mixed Installation

```bash
EXT_INSTALL_METHOD="mixed"
EXT_UPGRADE_STRATEGY="automatic"

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    local upgrade_failed=0

    # Upgrade APT packages
    print_status "Upgrading APT packages..."
    if ! upgrade_apt_packages "docker-ce" "docker-ce-cli" "containerd.io"; then
        print_error "APT upgrade failed"
        upgrade_failed=1
    fi

    # Upgrade binaries
    print_status "Upgrading binaries..."
    if ! upgrade_github_binary "docker/compose" "docker-compose" "/usr/local/bin/docker-compose"; then
        print_error "Binary upgrade failed"
        upgrade_failed=1
    fi

    if [[ $upgrade_failed -eq 0 ]]; then
        print_success "${EXT_NAME} upgraded successfully"
        return 0
    else
        print_error "${EXT_NAME} upgrade partially failed"
        return 1
    fi
}
```

### Dry-Run Support

All upgrades must respect dry-run mode:

```bash
upgrade() {
    if is_dry_run; then
        print_status "Would upgrade: package-name"
        return 0
    fi

    # Actual upgrade logic
}
```

### Testing Requirements

#### Unit Testing

```bash
# Test upgrade() function directly
./extension-name.extension upgrade

# Test with dry-run
DRY_RUN=true ./extension-name.extension upgrade
```

#### Integration Testing

```bash
# Via extension-manager
extension-manager upgrade extension-name

# Validate after upgrade
extension-manager validate extension-name
```

### Expected Behavior

1. **Prerequisites check**: Verify dependencies before upgrading
2. **Version display**: Show current version before upgrade
3. **Progress feedback**: Provide status updates during upgrade
4. **Error handling**: Return appropriate exit codes
5. **Version verification**: Show new version after upgrade
6. **Idempotent**: Running multiple times should be safe

### Backward Compatibility

Extensions without `upgrade()` function:

- Will not break existing functionality
- Cannot be upgraded via `extension-manager upgrade`
- Will be skipped by `extension-manager upgrade-all`
- Should be migrated to v2.0 when possible

---

## TOML Configuration Reference

### Tools Section

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

### Environment Variables Section

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

### Tasks Section

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

### Settings Section

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

---

## Extension Manifest

Extensions are executed in the order listed in `/workspace/scripts/extensions.d/active-extensions.conf`.

### Example Manifest

```conf
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
claude

# Monitoring
monitoring
```

### Manifest Best Practices

1. **Order matters**: List dependencies before dependents
   - `mise-config` must come before mise-powered extensions
   - `nodejs` must come before `nodejs-devtools`

2. **Core first**: Protected extensions are automatically installed first

   ```conf
   # Protected extensions (required, cannot be removed):
   workspace-structure  # Creates directory structure
   mise-config         # Enables mise for other extensions
   ssh-environment     # Essential for CI/CD and remote access

   # Foundational languages (recommended):
   nodejs              # Required by many tools
   python              # Required by monitoring tools
   ```

3. **Group by category**: Organize related extensions together

   ```conf
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

   ```conf
   # Required for CI/CD pipelines
   docker
   infra-tools

   # Optional: AI development tools
   # ai-tools
   ```

---

## Protected Extensions

### What Are Protected Extensions?

Protected extensions are **core system components** that cannot be removed. They are automatically installed on first
container startup.

**Protected extensions:**

- `workspace-structure` - Base directory structure
- `mise-config` - Unified tool version manager
- `ssh-environment` - SSH configuration for non-interactive sessions

### Auto-Installation Architecture

#### How it Works

1. **Container Starts** (`entrypoint.sh`)
   - Detects if this is the first boot by checking `/workspace/scripts/lib`
   - Copies extension library from Docker image to persistent volume

2. **Manifest Setup**
   - In **CI mode** (`CI_MODE=true`): Uses `active-extensions.ci.conf` template
   - In **production mode**: Uses same template or existing manifest
   - Template pre-includes: `workspace-structure`, `mise-config`, `ssh-environment`

3. **Auto-Installation Triggered**
   - Checks if `mise` command is available (indicator of installation status)
   - If not found: Runs `extension-manager install-all` as developer user
   - Installs all protected extensions listed in manifest
   - Output visible in container startup logs

4. **Idempotency**
   - On subsequent restarts: Skips installation (mise already exists)
   - Volume persistence means protected extensions install only once
   - Manual reinstall available: `extension-manager uninstall <name>` then restart

### Why This Approach?

- ✅ Guarantees foundational tools (mise, workspace dirs, SSH config) are always available
- ✅ Works in both CI/CD and production environments
- ✅ Respects persistent volumes (doesn't reinstall unnecessarily)
- ✅ Provides clear feedback in logs for debugging

### Verification

```bash
# Check if protected extensions are installed
extension-manager list

# Should show:
#   1. ✓ workspace-structure [PROTECTED]
#   2. ✓ mise-config [PROTECTED]
#   3. ✓ ssh-environment [PROTECTED]

# Verify mise is available (from mise-config extension)
mise --version
```

### Protection Enforcement

- **Cannot be deactivated**: Attempting to deactivate shows error
- **Cannot be uninstalled**: Attempting to uninstall shows error
- **Auto-repair**: Missing protected extensions are auto-added to manifest
- **Visual markers**: Show `[PROTECTED]` in list output

---

## Development Guidelines

### Version Numbering

Follow semantic versioning:

- **Major** (X.0.0): Breaking changes, API version change
  - Example: v1.x → v2.x (API v1.0 → API v2.0)
- **Minor** (x.Y.0): New tools, features, configuration options
  - Example: v3.0 → v3.1 (added new npm tools)
- **Patch** (x.y.Z): Bug fixes, documentation updates
  - Example: v3.1.0 → v3.1.1 (fixed TOML syntax)

### Best Practices

1. **Always Check Existence**: Use `command_exists` before installing
2. **Handle Errors Gracefully**: Don't exit on minor failures
3. **Use Print Functions**: `print_status`, `print_success`, `print_error`
4. **Test Idempotency**: Extension should be safe to run multiple times
5. **Document Dependencies**: Note any required extensions
6. **Set Reasonable Timeouts**: Consider installation time
7. **Use Helper Functions**: Leverage `extensions-common.sh` for consistency
8. **Support Dry-Run**: Always check `is_dry_run` in upgrade()

### Helper Function Benefits

1. **Consistency**: All extensions behave the same way
2. **Maintainability**: Bug fixes in one place benefit all extensions
3. **Readability**: Less boilerplate, clearer intent
4. **Testing**: Shared functions have centralized tests
5. **Features**: Get new capabilities automatically (e.g., dependency checking)

---

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

### Performance Optimization

#### mise Installation Performance

mise is optimized for speed:

- **Parallel downloads**: Install multiple tools concurrently
- **Binary caching**: Reuse downloaded binaries
- **Incremental updates**: Only update changed tools

#### CI Mode Optimizations

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

#### Extension Installation Order

Order extensions by installation time:

1. **Fast** (< 1 min): workspace-structure, ssh-environment, mise-config
2. **Medium** (1-3 min): nodejs, python, golang
3. **Slow** (> 3 min): rust, docker, jvm

---

## References

- **Extension API**: Extension API v1.0 and v2.0 specifications (this document)
- **Extension Testing**: [EXTENSION_TESTING.md](EXTENSION_TESTING.md)
- **mise documentation**: https://mise.jdx.dev
- **Tool backends**: https://mise.jdx.dev/dev-tools/backends.html
- **TOML configuration**: https://mise.jdx.dev/configuration.html
- **mise tasks**: https://mise.jdx.dev/tasks/
- **Template TOML**: `/workspace/scripts/extensions.d/template.toml`
- **CLAUDE.md**: Project-specific guidance
- **CONTRIBUTING.md**: Developer contribution guide
