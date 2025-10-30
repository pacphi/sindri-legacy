# Upgrade Support for Extensions - Proposal

## Executive Summary

This proposal outlines a comprehensive extension upgrade abstraction for the Sindri extension system. Currently, the `extension-manager upgrade-all` command only upgrades mise-managed tools, leaving apt packages, binary downloads, git-cloned repositories, and native installations without upgrade support.

This document proposes extending the Extension API from v1.0 to v2.0 by adding a standardized `upgrade()` function, introducing explicit installation method metadata, and providing helper utilities for common upgrade patterns.

**Goals:**
- Standardize upgrade behavior across all installation methods
- Enable per-extension and system-wide upgrades
- Maintain backward compatibility with Extension API v1.0
- Provide clear upgrade status and version tracking
- Support dry-run and version pinning capabilities

## Current State Analysis

### Extension API v1.0

All extensions currently implement six standard functions:

| Function | Purpose | Required |
|----------|---------|----------|
| `prerequisites()` | Check system requirements | Yes |
| `install()` | Install packages and tools | Yes |
| `configure()` | Post-install configuration | Yes |
| `validate()` | Run smoke tests | Yes |
| `status()` | Check installation state | Yes |
| `remove()` | Uninstall and cleanup | Yes |

### Existing Upgrade Implementation

**Location**: `docker/lib/extension-manager.sh:1254-1286`

```bash
upgrade_all_tools() {
    print_status "Upgrading all mise-managed tools..."

    if ! command -v mise >/dev/null 2>&1; then
        print_warning "mise is not installed"
        return 1
    fi

    if mise upgrade; then
        print_success "mise upgrade completed successfully"
    else
        print_error "mise upgrade failed"
        return 1
    fi

    print_status "Extension files are managed via git repository updates"

    return 0
}
```

**Limitations:**
- Only handles mise-managed tools
- No per-extension upgrade capability
- No version tracking or changelog reporting
- No support for other installation methods
- No dry-run or rollback capabilities

### Installation Methods Inventory

Through comprehensive codebase analysis, five distinct installation methods have been identified:

#### 1. mise-Based (Language Runtimes)

**Extensions**: nodejs, python, rust, golang, nodejs-devtools

**Installation Pattern**:
```bash
install() {
    # Select TOML config (development vs CI)
    local toml_source="$ext_dir/${EXT_NAME}.toml"
    if [[ "${CI_MODE:-false}" == "true" ]]; then
        toml_source="$ext_dir/${EXT_NAME}-ci.toml"
    fi

    # Copy to mise config directory
    mkdir -p "$HOME/.config/mise/conf.d"
    cp "$toml_source" "$HOME/.config/mise/conf.d/${EXT_NAME}.toml"

    # Install via mise
    mise install
}
```

**Upgrade Approach**: `mise upgrade` for all tools defined in TOML configuration

**Files**:
- `docker/lib/extensions.d/nodejs.extension`
- `docker/lib/extensions.d/python.extension`
- `docker/lib/extensions.d/rust.extension`
- `docker/lib/extensions.d/golang.extension`
- `docker/lib/extensions.d/nodejs-devtools.extension`

#### 2. APT Package Manager (System Packages)

**Extensions**: docker, ruby (build deps), monitoring

**Installation Pattern**:
```bash
install() {
    # Add repository and GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) \
        signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update and install packages
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
}
```

**Upgrade Approach**: `apt-get update && apt-get upgrade` for managed packages

**Files**:
- `docker/lib/extensions.d/docker.extension` (lines 70-105)
- `docker/lib/extensions.d/ruby.extension` (build dependencies)
- `docker/lib/extensions.d/monitoring.extension`

#### 3. Git Clone + Manual Build (Version Managers)

**Extensions**: ruby (rbenv)

**Installation Pattern**:
```bash
install() {
    # Clone repository
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    git clone https://github.com/rbenv/ruby-build.git \
        ~/.rbenv/plugins/ruby-build

    # Setup environment
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init - bash)"

    # Build and install
    rbenv install "3.4.5"
    rbenv global 3.4.5
}
```

**Upgrade Approach**: `git pull` on repository, rebuild if needed

**Files**:
- `docker/lib/extensions.d/ruby.extension` (lines 86-100)

#### 4. Direct Binary Downloads (Pre-Built Binaries)

**Extensions**: docker (compose, dive, ctop)

**Installation Pattern**:
```bash
install() {
    local url="https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m)"
    local temp_file="/tmp/docker-compose"

    # Download binary
    curl -L "$url" -o "$temp_file"

    # Install to system location
    sudo mv "$temp_file" /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
}
```

**Upgrade Approach**: Check GitHub releases API, download if newer version available

**Files**:
- `docker/lib/extensions.d/docker.extension` (lines 108-126)

#### 5. Native/Pre-Installed (Already Available)

**Extensions**: github-cli, mise-config

**Installation Pattern**:
```bash
install() {
    # Tool is pre-installed via Docker image or system
    local version
    version=$(gh version 2>/dev/null | head -n1)
    print_success "GitHub CLI already installed: $version"

    # Focus on configuration only
    configure_tool
    return 0
}
```

**Upgrade Approach**: Depends on how tool was installed (Docker rebuild, system package manager)

**Files**:
- `docker/lib/extensions.d/github-cli.extension` (lines 70-82)
- `docker/lib/extensions.d/mise-config.extension`

### Installation Method Distribution

| Method | Count | Extensions |
|--------|-------|------------|
| mise | 5 | nodejs, python, rust, golang, nodejs-devtools |
| apt | 3+ | docker, ruby (deps), monitoring, php, dotnet |
| git+build | 1 | ruby (rbenv) |
| binary | 1 | docker (compose, dive, ctop) |
| native | 2+ | github-cli, mise-config |
| mixed | 2+ | docker (apt + binary), ruby (apt + git) |

### Key Challenges Identified

1. **No Standardized Metadata**: Extensions don't declare their installation method
2. **No Version Tracking**: No system-wide version history or changelog
3. **Mixed Installation Methods**: Some extensions use multiple methods (e.g., docker uses both apt and binary downloads)
4. **Implicit Dependencies**: Upgrade order matters but isn't tracked
5. **No Rollback**: Cannot downgrade to previous versions
6. **No Dry-Run**: Cannot preview upgrades before executing

## Problem Statement

### User Pain Points

1. **Inconsistent Upgrade Experience**
   - Users can upgrade mise tools but not apt packages
   - No single command to upgrade all system components
   - Unclear which extensions support upgrades

2. **Manual Upgrade Management**
   - Users must manually track versions
   - No notification of available updates
   - Security updates may be missed

3. **Lack of Visibility**
   - Cannot see what versions are installed
   - Cannot preview what would be upgraded
   - No upgrade history or audit trail

4. **Risk Management**
   - No ability to test upgrades before applying
   - Cannot easily rollback problematic upgrades
   - Upgrade failures may leave system in inconsistent state

### Technical Debt

1. **API Incompleteness**: Extension API v1.0 lacks upgrade lifecycle function
2. **Scattered Logic**: Upgrade logic embedded in extension-manager, not extensions
3. **Implicit Contracts**: Installation methods inferred from code, not declared
4. **Limited Extensibility**: Adding new installation methods requires core changes

## Proposed Solution

### Extension API v2.0

Add `upgrade()` as the seventh standard function in the Extension API:

| Function | Purpose | Required | Added In |
|----------|---------|----------|----------|
| `prerequisites()` | Check system requirements | Yes | v1.0 |
| `install()` | Install packages and tools | Yes | v1.0 |
| `configure()` | Post-install configuration | Yes | v1.0 |
| `validate()` | Run smoke tests | Yes | v1.0 |
| `status()` | Check installation state | Yes | v1.0 |
| `remove()` | Uninstall and cleanup | Yes | v1.0 |
| **`upgrade()`** | **Upgrade installed tools** | **Yes** | **v2.0** |

### Metadata Extensions

Add explicit installation method declaration to extension metadata:

```bash
# ============================================================================
# METADATA
# ============================================================================

EXT_NAME="nodejs"
EXT_VERSION="3.0.0"
EXT_DESCRIPTION="Node.js LTS and npm via mise"
EXT_CATEGORY="language"
EXT_INSTALL_METHOD="mise"          # NEW: Explicit installation method
EXT_UPGRADE_STRATEGY="automatic"   # NEW: Upgrade behavior
```

### Supported Installation Methods

| Method | Value | Description | Upgrade Strategy |
|--------|-------|-------------|------------------|
| mise | `mise` | Tools managed by mise | `mise upgrade` |
| apt | `apt` | APT package manager | `apt-get upgrade` |
| binary | `binary` | Direct binary downloads | Check GitHub releases, download if newer |
| git | `git` | Git clone + manual build | `git pull` + rebuild |
| native | `native` | Pre-installed in Docker image | Requires Docker rebuild |
| mixed | `mixed` | Multiple installation methods | Extension implements custom logic |
| manual | `manual` | No automatic upgrade | User must upgrade manually |

### Upgrade Strategies

| Strategy | Behavior | Use Case |
|----------|----------|----------|
| `automatic` | Upgrade to latest version automatically | Development tools, language runtimes |
| `manual` | Require explicit user confirmation | Critical infrastructure, databases |
| `pinned` | Never upgrade (version locked) | Legacy dependencies, specific versions |
| `security-only` | Only apply security updates | Production systems |

## Technical Design

### 1. Helper Functions Library

Create `docker/lib/upgrade-helpers.sh` with common upgrade utilities:

```bash
#!/bin/bash
# upgrade-helpers.sh - Common upgrade utilities for extensions
# Extension API v2.0

# ============================================================================
# MISE UPGRADE HELPERS
# ============================================================================

upgrade_mise_tools() {
    local extension_name="$1"

    print_status "Upgrading mise-managed tools for ${extension_name}..."

    if ! command -v mise >/dev/null 2>&1; then
        print_error "mise is not installed"
        return 1
    fi

    # Get tools managed by this extension's TOML
    local toml_path="$HOME/.config/mise/conf.d/${extension_name}.toml"
    if [[ ! -f "$toml_path" ]]; then
        print_warning "No mise configuration found for ${extension_name}"
        return 1
    fi

    # Upgrade tools
    if mise upgrade; then
        print_success "Tools upgraded successfully"
        return 0
    else
        print_error "mise upgrade failed"
        return 1
    fi
}

# ============================================================================
# APT UPGRADE HELPERS
# ============================================================================

upgrade_apt_packages() {
    local -a packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        print_error "No packages specified"
        return 1
    fi

    print_status "Upgrading APT packages: ${packages[*]}"

    # Update package lists
    sudo apt-get update -qq

    # Check which packages have updates available
    local has_updates=0
    local -a upgradeable=()

    for pkg in "${packages[@]}"; do
        if apt list --upgradable 2>/dev/null | grep -q "^${pkg}/"; then
            upgradeable+=("$pkg")
            has_updates=1
        fi
    done

    if [[ $has_updates -eq 0 ]]; then
        print_success "All packages are up to date"
        return 0
    fi

    print_status "Upgradeable packages: ${upgradeable[*]}"

    # Upgrade packages
    if sudo apt-get install --only-upgrade -y "${upgradeable[@]}"; then
        print_success "Packages upgraded successfully"
        return 0
    else
        print_error "Package upgrade failed"
        return 1
    fi
}

check_apt_updates() {
    local -a packages=("$@")

    sudo apt-get update -qq >/dev/null 2>&1

    local has_updates=0
    for pkg in "${packages[@]}"; do
        if apt list --upgradable 2>/dev/null | grep -q "^${pkg}/"; then
            local current_ver
            local available_ver
            current_ver=$(dpkg -l "$pkg" 2>/dev/null | awk '/^ii/ {print $3}')
            available_ver=$(apt-cache policy "$pkg" | awk '/Candidate:/ {print $2}')

            print_status "${pkg}: ${current_ver} → ${available_ver}"
            has_updates=1
        fi
    done

    return $has_updates
}

# ============================================================================
# BINARY UPGRADE HELPERS
# ============================================================================

upgrade_github_binary() {
    local repo="$1"           # e.g., "docker/compose"
    local binary_name="$2"    # e.g., "docker-compose"
    local install_path="$3"   # e.g., "/usr/local/bin/docker-compose"

    print_status "Checking for updates to ${binary_name}..."

    # Get current version
    local current_version
    if [[ -f "$install_path" ]]; then
        current_version=$("$install_path" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)
    else
        print_error "Binary not found: ${install_path}"
        return 1
    fi

    # Get latest release from GitHub API
    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | \
        grep -oP '"tag_name": "\K[^"]+' | sed 's/^v//')

    if [[ -z "$latest_version" ]]; then
        print_error "Failed to fetch latest version from GitHub"
        return 1
    fi

    # Compare versions
    if [[ "$current_version" == "$latest_version" ]]; then
        print_success "${binary_name} is up to date (${current_version})"
        return 0
    fi

    print_status "Update available: ${current_version} → ${latest_version}"

    # Download and install
    local download_url="https://github.com/${repo}/releases/download/v${latest_version}/${binary_name}-$(uname -s)-$(uname -m)"
    local temp_file="/tmp/${binary_name}-${latest_version}"

    if curl -L "$download_url" -o "$temp_file"; then
        sudo mv "$temp_file" "$install_path"
        sudo chmod +x "$install_path"
        print_success "${binary_name} upgraded to ${latest_version}"
        return 0
    else
        print_error "Failed to download ${binary_name}"
        return 1
    fi
}

# ============================================================================
# GIT UPGRADE HELPERS
# ============================================================================

upgrade_git_repo() {
    local repo_path="$1"
    local rebuild_cmd="${2:-}"

    if [[ ! -d "$repo_path" ]]; then
        print_error "Repository not found: ${repo_path}"
        return 1
    fi

    print_status "Updating git repository: ${repo_path}"

    cd "$repo_path" || return 1

    # Get current commit
    local current_commit
    current_commit=$(git rev-parse HEAD)

    # Pull latest changes
    if ! git pull --ff-only; then
        print_error "Failed to update repository"
        return 1
    fi

    local new_commit
    new_commit=$(git rev-parse HEAD)

    if [[ "$current_commit" == "$new_commit" ]]; then
        print_success "Repository is up to date"
        return 0
    fi

    print_status "Repository updated: ${current_commit:0:8} → ${new_commit:0:8}"

    # Rebuild if command provided
    if [[ -n "$rebuild_cmd" ]]; then
        print_status "Rebuilding..."
        if eval "$rebuild_cmd"; then
            print_success "Rebuild successful"
            return 0
        else
            print_error "Rebuild failed"
            return 1
        fi
    fi

    return 0
}

# ============================================================================
# NATIVE/MANUAL UPGRADE HELPERS
# ============================================================================

check_native_update() {
    local tool_name="$1"
    local version_cmd="${2:---version}"

    if ! command -v "$tool_name" >/dev/null 2>&1; then
        print_error "${tool_name} not found"
        return 1
    fi

    local current_version
    current_version=$($tool_name $version_cmd 2>/dev/null | head -1)

    print_status "${tool_name}: ${current_version}"
    print_warning "Native tools require Docker image rebuild to upgrade"
    print_status "Run: docker build --no-cache to rebuild image"

    return 2  # Special code: update requires manual action
}

# ============================================================================
# VERSION COMPARISON UTILITIES
# ============================================================================

version_gt() {
    # Compare semantic versions: version_gt "2.0.0" "1.9.0" returns 0 if first > second
    local ver1="$1"
    local ver2="$2"

    if [[ "$ver1" == "$ver2" ]]; then
        return 1
    fi

    printf '%s\n%s\n' "$ver1" "$ver2" | sort -V | head -n1 | grep -q "^${ver2}$"
}

# ============================================================================
# DRY-RUN SUPPORT
# ============================================================================

is_dry_run() {
    [[ "${DRY_RUN:-false}" == "true" ]]
}

dry_run_prefix() {
    if is_dry_run; then
        echo "[DRY-RUN] "
    fi
}
```

### 2. Extension Implementation Example

#### nodejs.extension with upgrade() Function

```bash
#!/bin/bash
# nodejs.extension - Node.js LTS and npm via mise
# Extension API v2.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/extensions-common.sh"
source "$(dirname "$SCRIPT_DIR")/upgrade-helpers.sh"  # NEW

# ============================================================================
# METADATA
# ============================================================================

EXT_NAME="nodejs"
EXT_VERSION="4.0.0"  # Bumped for API v2.0 support
EXT_DESCRIPTION="Node.js LTS and npm via mise"
EXT_CATEGORY="language"
EXT_INSTALL_METHOD="mise"          # NEW
EXT_UPGRADE_STRATEGY="automatic"   # NEW

extension_init

# ... (prerequisites, install, configure, validate, status functions unchanged) ...

# ============================================================================
# UPGRADE - NEW IN API v2.0
# ============================================================================

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    # Check if installed
    if ! command_exists mise; then
        print_error "mise not installed, cannot upgrade"
        return 1
    fi

    eval "$(mise activate bash)"

    # Get current versions
    print_status "Current versions:"
    mise current node 2>/dev/null || echo "  node: not installed"

    # Use helper function for mise upgrades
    if upgrade_mise_tools "$EXT_NAME"; then
        print_success "Upgrade completed successfully"

        # Show new versions
        print_status "Updated versions:"
        mise current node

        return 0
    else
        print_error "Upgrade failed"
        return 1
    fi
}

# ... (remove function unchanged) ...
```

#### docker.extension with Mixed Installation Method

```bash
#!/bin/bash
# docker.extension - Docker Engine with compose, dive, ctop
# Extension API v2.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/extensions-common.sh"
source "$(dirname "$SCRIPT_DIR")/upgrade-helpers.sh"  # NEW

# ============================================================================
# METADATA
# ============================================================================

EXT_NAME="docker"
EXT_VERSION="2.0.0"
EXT_DESCRIPTION="Docker Engine with compose, dive, ctop"
EXT_CATEGORY="infrastructure"
EXT_INSTALL_METHOD="mixed"  # apt (docker-ce) + binary (compose, dive, ctop)
EXT_UPGRADE_STRATEGY="automatic"

extension_init

# ... (prerequisites, install, configure, validate, status functions unchanged) ...

# ============================================================================
# UPGRADE - NEW IN API v2.0
# ============================================================================

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    local upgrade_failed=0

    # Part 1: Upgrade APT packages (docker-ce, docker-ce-cli, containerd.io)
    print_status "Upgrading Docker packages via APT..."
    if upgrade_apt_packages "docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin"; then
        print_success "Docker packages upgraded"
    else
        print_warning "Docker package upgrade failed or skipped"
        upgrade_failed=1
    fi

    # Part 2: Upgrade standalone Docker Compose binary
    print_status "Upgrading standalone Docker Compose..."
    if upgrade_github_binary "docker/compose" "docker-compose" "/usr/local/bin/docker-compose"; then
        print_success "Docker Compose upgraded"
    else
        print_warning "Docker Compose upgrade failed"
        upgrade_failed=1
    fi

    # Part 3: Upgrade dive binary
    print_status "Upgrading dive..."
    if upgrade_github_binary "wagoodman/dive" "dive" "/usr/local/bin/dive"; then
        print_success "dive upgraded"
    else
        print_warning "dive upgrade failed"
        upgrade_failed=1
    fi

    # Part 4: Upgrade ctop binary
    print_status "Upgrading ctop..."
    if upgrade_github_binary "bcicen/ctop" "ctop" "/usr/local/bin/ctop"; then
        print_success "ctop upgraded"
    else
        print_warning "ctop upgrade failed"
        upgrade_failed=1
    fi

    if [[ $upgrade_failed -eq 0 ]]; then
        print_success "All Docker components upgraded successfully"
        return 0
    else
        print_warning "Some Docker components failed to upgrade"
        return 1
    fi
}

# ... (remove function unchanged) ...
```

#### ruby.extension with Git + APT

```bash
#!/bin/bash
# ruby.extension - Ruby 3.4/3.3 with rbenv, Rails, Bundler
# Extension API v2.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/extensions-common.sh"
source "$(dirname "$SCRIPT_DIR")/upgrade-helpers.sh"  # NEW

# ============================================================================
# METADATA
# ============================================================================

EXT_NAME="ruby"
EXT_VERSION="2.0.0"
EXT_DESCRIPTION="Ruby 3.4/3.3 with rbenv, Rails, Bundler"
EXT_CATEGORY="language"
EXT_INSTALL_METHOD="mixed"  # apt (build deps) + git (rbenv)
EXT_UPGRADE_STRATEGY="automatic"

extension_init

# ... (prerequisites, install, configure, validate, status functions unchanged) ...

# ============================================================================
# UPGRADE - NEW IN API v2.0
# ============================================================================

upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    local upgrade_failed=0

    # Part 1: Upgrade build dependencies via APT
    print_status "Upgrading Ruby build dependencies..."
    local build_deps=(
        "build-essential"
        "libssl-dev"
        "libreadline-dev"
        "zlib1g-dev"
        "libyaml-dev"
        "libffi-dev"
    )

    if upgrade_apt_packages "${build_deps[@]}"; then
        print_success "Build dependencies upgraded"
    else
        print_warning "Build dependency upgrade failed"
        upgrade_failed=1
    fi

    # Part 2: Upgrade rbenv and ruby-build
    print_status "Upgrading rbenv..."
    if upgrade_git_repo "$HOME/.rbenv" ""; then
        print_success "rbenv upgraded"
    else
        print_warning "rbenv upgrade failed"
        upgrade_failed=1
    fi

    print_status "Upgrading ruby-build..."
    if upgrade_git_repo "$HOME/.rbenv/plugins/ruby-build" ""; then
        print_success "ruby-build upgraded"
    else
        print_warning "ruby-build upgrade failed"
        upgrade_failed=1
    fi

    # Part 3: Check for Ruby version updates (informational only)
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init - bash)"

    local current_ruby
    current_ruby=$(rbenv version | awk '{print $1}')

    print_status "Current Ruby version: ${current_ruby}"
    print_status "To upgrade Ruby itself, run:"
    print_status "  rbenv install <version>"
    print_status "  rbenv global <version>"

    if [[ $upgrade_failed -eq 0 ]]; then
        print_success "Ruby toolchain upgraded successfully"
        return 0
    else
        print_warning "Some Ruby components failed to upgrade"
        return 1
    fi
}

# ... (remove function unchanged) ...
```

### 3. Extension-Manager Updates

Add new commands to `docker/lib/extension-manager.sh`:

```bash
# ============================================================================
# UPGRADE COMMANDS
# ============================================================================

upgrade_extension() {
    local extension_name="$1"
    local extension_file
    extension_file=$(find_extension_file "$extension_name")

    if [[ -z "$extension_file" ]]; then
        print_error "Extension not found: ${extension_name}"
        return 1
    fi

    # Source extension
    source "$extension_file"

    # Check if extension is installed
    if ! is_extension_installed "$extension_name"; then
        print_error "Extension not installed: ${extension_name}"
        print_status "Install with: extension-manager install ${extension_name}"
        return 1
    fi

    # Check if extension implements upgrade()
    if ! declare -f upgrade >/dev/null 2>&1; then
        print_warning "Extension ${extension_name} does not support upgrades (API v1.0)"
        print_status "This extension may require reinstallation to update"
        return 2
    fi

    # Show current status
    print_status "Current status:"
    status
    echo

    # Run upgrade
    print_status "Starting upgrade..."
    if upgrade; then
        print_success "Upgrade completed successfully"

        # Validate after upgrade
        print_status "Validating installation..."
        if validate; then
            print_success "Validation passed"
            return 0
        else
            print_warning "Validation failed after upgrade"
            return 1
        fi
    else
        print_error "Upgrade failed"
        return 1
    fi
}

upgrade_all_extensions() {
    local dry_run="${1:-false}"

    if [[ "$dry_run" == "true" ]]; then
        export DRY_RUN="true"
        print_status "DRY RUN MODE - No changes will be made"
        echo
    fi

    print_status "Upgrading all installed extensions..."
    echo

    # Read manifest
    local manifest="${EXTENSIONS_DIR}/active-extensions.conf"
    if [[ ! -f "$manifest" ]]; then
        print_error "Manifest not found: ${manifest}"
        return 1
    fi

    local -a extensions=()
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue

        extensions+=("$line")
    done < "$manifest"

    if [[ ${#extensions[@]} -eq 0 ]]; then
        print_warning "No extensions found in manifest"
        return 0
    fi

    local total=${#extensions[@]}
    local upgraded=0
    local skipped=0
    local failed=0

    for extension in "${extensions[@]}"; do
        print_header "Upgrading: ${extension}"

        if upgrade_extension "$extension"; then
            ((upgraded++))
        elif [[ $? -eq 2 ]]; then
            # Extension doesn't support upgrades
            ((skipped++))
        else
            ((failed++))
        fi

        echo
    done

    # Summary
    print_header "Upgrade Summary"
    print_status "Total extensions: ${total}"
    print_success "Upgraded: ${upgraded}"

    if [[ $skipped -gt 0 ]]; then
        print_warning "Skipped (no upgrade support): ${skipped}"
    fi

    if [[ $failed -gt 0 ]]; then
        print_error "Failed: ${failed}"
        return 1
    fi

    print_success "All upgrades completed successfully"
    return 0
}

check_updates() {
    print_status "Checking for available updates..."
    echo

    # Read manifest
    local manifest="${EXTENSIONS_DIR}/active-extensions.conf"
    local -a extensions=()

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        extensions+=("$line")
    done < "$manifest"

    local has_updates=0

    for extension in "${extensions[@]}"; do
        local extension_file
        extension_file=$(find_extension_file "$extension")

        if [[ -z "$extension_file" ]]; then
            continue
        fi

        # Source extension
        source "$extension_file"

        # Check if upgrade() exists
        if ! declare -f upgrade >/dev/null 2>&1; then
            continue
        fi

        # Get installation method
        local method="${EXT_INSTALL_METHOD:-unknown}"

        case "$method" in
            mise)
                if command -v mise >/dev/null 2>&1; then
                    # Check for mise updates
                    if mise outdated 2>/dev/null | grep -q .; then
                        print_status "${extension}: Updates available"
                        mise outdated | sed 's/^/  /'
                        has_updates=1
                    fi
                fi
                ;;
            apt)
                # Would need to parse extension for package list
                print_status "${extension}: Check with apt list --upgradable"
                ;;
            *)
                print_status "${extension}: Manual check required (${method})"
                ;;
        esac
    done

    if [[ $has_updates -eq 0 ]]; then
        print_success "All extensions are up to date"
    fi

    return 0
}
```

### 4. Command-Line Interface

#### New Commands

```bash
# Upgrade specific extension
extension-manager upgrade <name>

# Upgrade all extensions
extension-manager upgrade-all

# Dry-run (show what would be upgraded)
extension-manager upgrade-all --dry-run

# Check for available updates
extension-manager check-updates

# Show upgrade history
extension-manager upgrade-history

# Rollback last upgrade
extension-manager rollback <name>
```

#### Usage Examples

```bash
# Check what updates are available
$ extension-manager check-updates
[*] Checking for available updates...

nodejs: Updates available
  node: 20.10.0 → 20.11.0

docker: Updates available
  docker-ce: 24.0.7 → 24.0.8
  docker-compose: 2.23.0 → 2.24.0

[✓] 2 extensions have updates available

# Dry-run upgrade
$ extension-manager upgrade-all --dry-run
[*] DRY RUN MODE - No changes will be made

[=== Upgrading: nodejs ===]
[*] Upgrading nodejs...
[*] Current versions:
  node: 20.10.0
[DRY-RUN] Would upgrade node to 20.11.0
[✓] Upgrade would complete successfully

[=== Upgrading: docker ===]
[*] Upgrading docker...
[DRY-RUN] Would upgrade docker-ce: 24.0.7 → 24.0.8
[DRY-RUN] Would upgrade docker-compose: 2.23.0 → 2.24.0
[✓] Upgrade would complete successfully

[=== Upgrade Summary ===]
[*] Total extensions: 2
[✓] Would upgrade: 2
[!] Would skip: 0
[✗] Would fail: 0

# Actual upgrade
$ extension-manager upgrade-all
[=== Upgrading: nodejs ===]
[*] Upgrading nodejs...
[*] Current versions:
  node: 20.10.0
[*] Running mise upgrade...
[✓] Tools upgraded successfully
[*] Updated versions:
  node: 20.11.0
[✓] Upgrade completed successfully

# Upgrade single extension
$ extension-manager upgrade docker
[*] Current status:
  Docker: 24.0.7
  Compose: 2.23.0

[*] Starting upgrade...
[*] Upgrading Docker packages via APT...
[✓] Docker packages upgraded
[*] Upgrading standalone Docker Compose...
[✓] Docker Compose upgraded to 2.24.0
[✓] Upgrade completed successfully

[*] Validating installation...
[✓] Validation passed
```

## Implementation Plan

### Phase 1: Foundation (Week 1)

**Goals**: Create infrastructure for upgrade support

**Tasks**:
1. Create `docker/lib/upgrade-helpers.sh` with helper functions
2. Update `docker/lib/extensions-common.sh` to source upgrade helpers
3. Add metadata fields (`EXT_INSTALL_METHOD`, `EXT_UPGRADE_STRATEGY`) to template
4. Document Extension API v2.0 specification
5. Create unit tests for helper functions

**Deliverables**:
- `docker/lib/upgrade-helpers.sh` (fully implemented)
- Updated `docker/lib/extensions.d/template.extension`
- `docs/EXTENSION_API_V2.md` specification
- Test suite for upgrade helpers

### Phase 2: Core Extensions (Week 2)

**Goals**: Implement upgrade() for core/protected extensions

**Tasks**:
1. Add `upgrade()` to `workspace-structure.extension` (no-op)
2. Add `upgrade()` to `mise-config.extension` (upgrade mise itself)
3. Add `upgrade()` to `ssh-environment.extension` (no-op)
4. Test protected extensions upgrade workflow

**Deliverables**:
- All protected extensions support API v2.0
- Upgrade tests pass for protected extensions

### Phase 3: Mise-Powered Extensions (Week 2)

**Goals**: Implement upgrade() for all mise-powered extensions

**Tasks**:
1. Add `upgrade()` to `nodejs.extension`
2. Add `upgrade()` to `python.extension`
3. Add `upgrade()` to `rust.extension`
4. Add `upgrade()` to `golang.extension`
5. Add `upgrade()` to `nodejs-devtools.extension`
6. Test mise upgrade workflow end-to-end

**Deliverables**:
- All mise-powered extensions support API v2.0
- Integration tests pass

### Phase 4: APT-Based Extensions (Week 3)

**Goals**: Implement upgrade() for APT package-based extensions

**Tasks**:
1. Add `upgrade()` to `docker.extension` (mixed: apt + binary)
2. Add `upgrade()` to `ruby.extension` (mixed: apt + git)
3. Add `upgrade()` to `monitoring.extension`
4. Add `upgrade()` to `php.extension`
5. Add `upgrade()` to `dotnet.extension`
6. Test APT upgrade workflows

**Deliverables**:
- All APT-based extensions support API v2.0
- APT upgrade tests pass

### Phase 5: Extension-Manager Commands (Week 3)

**Goals**: Add new commands to extension-manager CLI

**Tasks**:
1. Implement `upgrade <name>` command
2. Implement `upgrade-all` command (replace existing)
3. Implement `upgrade-all --dry-run` command
4. Implement `check-updates` command
5. Update help text and documentation
6. Add command-line tests

**Deliverables**:
- All new commands functional
- CLI tests pass
- Updated `docs/EXTENSIONS.md`

### Phase 6: Remaining Extensions (Week 4)

**Goals**: Complete upgrade support for all extensions

**Tasks**:
1. Add `upgrade()` to `github-cli.extension` (native)
2. Add `upgrade()` to `infra-tools.extension` (mixed)
3. Add `upgrade()` to `cloud-tools.extension` (mixed)
4. Add `upgrade()` to `ai-tools.extension` (mixed)
5. Add `upgrade()` to remaining extensions
6. Full system integration test

**Deliverables**:
- All extensions support API v2.0
- Complete test coverage

### Phase 7: Advanced Features (Week 5)

**Goals**: Implement advanced upgrade features

**Tasks**:
1. Add version tracking/history
2. Add rollback capability
3. Add upgrade notifications
4. Add security-only upgrade mode
5. Add version pinning support
6. Performance optimization

**Deliverables**:
- Advanced features functional
- Performance benchmarks met
- Documentation complete

### Phase 8: Documentation & Testing (Week 6)

**Goals**: Complete documentation and comprehensive testing

**Tasks**:
1. Update `docs/EXTENSIONS.md` with upgrade documentation
2. Create `docs/EXTENSION_API_V2.md` specification
3. Update all extension templates
4. Write migration guide (v1.0 → v2.0)
5. Create video tutorials/demos
6. Comprehensive testing in CI/CD

**Deliverables**:
- Complete documentation
- Migration guide published
- CI/CD tests passing
- Ready for production deployment

## Migration Strategy

### Backward Compatibility

Extension API v2.0 is **fully backward compatible** with v1.0:

- Extensions without `upgrade()` continue to work
- `extension-manager upgrade <name>` detects missing upgrade() and provides helpful message
- `extension-manager upgrade-all` skips v1.0 extensions with warning
- No breaking changes to existing extension functions

### Migration Path for Extension Developers

#### Step 1: Add Metadata

```bash
# Add to extension metadata section
EXT_INSTALL_METHOD="mise"          # or apt, binary, git, native, mixed
EXT_UPGRADE_STRATEGY="automatic"   # or manual, pinned, security-only
```

#### Step 2: Implement upgrade() Function

```bash
upgrade() {
    print_status "Upgrading ${EXT_NAME}..."

    # Use appropriate helper based on installation method
    case "${EXT_INSTALL_METHOD}" in
        mise)
            upgrade_mise_tools "$EXT_NAME"
            ;;
        apt)
            upgrade_apt_packages "package1" "package2" "package3"
            ;;
        binary)
            upgrade_github_binary "repo/name" "binary-name" "/path/to/binary"
            ;;
        git)
            upgrade_git_repo "/path/to/repo" "rebuild command"
            ;;
        native)
            check_native_update "tool-name" "--version"
            ;;
        mixed)
            # Custom logic combining multiple methods
            ;;
    esac
}
```

#### Step 3: Bump Version

```bash
# Update version to indicate API v2.0 support
EXT_VERSION="4.0.0"  # Major bump for API change
```

#### Step 4: Test

```bash
# Install extension
extension-manager install myextension

# Test upgrade (dry-run)
extension-manager upgrade myextension --dry-run

# Test upgrade (actual)
extension-manager upgrade myextension

# Validate
extension-manager validate myextension
```

### Timeline for Extension Migration

| Week | Extensions to Migrate | Owner |
|------|----------------------|-------|
| 1-2 | Protected + mise-powered (8 extensions) | Core team |
| 3-4 | APT-based + popular tools (6 extensions) | Core team |
| 5-6 | Remaining extensions (8+ extensions) | Community |

### Migration Tracking

Create migration tracking in `docs/EXTENSION_API_V2_MIGRATION.md`:

```markdown
# Extension API v2.0 Migration Status

## Completed (API v2.0)
- [x] workspace-structure - v1.1.0 (no-op upgrade)
- [x] mise-config - v1.1.0 (upgrade mise binary)
- [x] ssh-environment - v1.1.0 (no-op upgrade)
- [x] nodejs - v4.0.0 (mise upgrade)
- [x] python - v3.0.0 (mise upgrade)

## In Progress
- [ ] rust - Target: v3.0.0
- [ ] golang - Target: v3.0.0
- [ ] docker - Target: v2.0.0

## Pending
- [ ] ruby
- [ ] php
- [ ] dotnet
- [ ] jvm
- [ ] infra-tools
- [ ] cloud-tools
- [ ] ai-tools
```

## Testing Strategy

### Unit Tests

Test individual helper functions in isolation:

```bash
# Test upgrade-helpers.sh functions
./tests/unit/test-upgrade-helpers.sh

Tests:
- upgrade_mise_tools() with valid/invalid extension
- upgrade_apt_packages() with upgradable/up-to-date packages
- upgrade_github_binary() with valid/invalid repo
- upgrade_git_repo() with clean/dirty repo
- version_gt() with various version strings
- is_dry_run() in different modes
```

### Integration Tests

Test complete upgrade workflows:

```bash
# Test extension upgrade lifecycle
./tests/integration/test-extension-upgrade.sh

Tests:
- Install extension → upgrade → validate
- Upgrade with no updates available
- Upgrade with updates available
- Upgrade failure handling
- Dry-run mode
- Rollback after failed upgrade
```

### System Tests

Test full system upgrade scenarios:

```bash
# Test upgrade-all workflow
./tests/system/test-upgrade-all.sh

Tests:
- upgrade-all with all extensions up-to-date
- upgrade-all with some extensions outdated
- upgrade-all with mixed API versions (v1.0 + v2.0)
- upgrade-all --dry-run
- upgrade-all with failures (partial success)
- check-updates command
```

### CI/CD Tests

Automated testing in `.github/workflows/extension-upgrades.yml`:

```yaml
name: Extension Upgrade Tests

on:
  push:
    paths:
      - 'docker/lib/upgrade-helpers.sh'
      - 'docker/lib/extension-manager.sh'
      - 'docker/lib/extensions.d/*.extension'

jobs:
  test-upgrades:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Deploy test VM
        run: |
          CI_MODE=true ./scripts/vm-setup.sh --app-name test-upgrades-${{ github.run_id }}

      - name: Install extensions
        run: |
          flyctl ssh console -a test-upgrades-${{ github.run_id }} -C "extension-manager install-all"

      - name: Check for updates
        run: |
          flyctl ssh console -a test-upgrades-${{ github.run_id }} -C "extension-manager check-updates"

      - name: Dry-run upgrade
        run: |
          flyctl ssh console -a test-upgrades-${{ github.run_id }} -C "extension-manager upgrade-all --dry-run"

      - name: Perform upgrade
        run: |
          flyctl ssh console -a test-upgrades-${{ github.run_id }} -C "extension-manager upgrade-all"

      - name: Validate all extensions
        run: |
          flyctl ssh console -a test-upgrades-${{ github.run_id }} -C "extension-manager validate-all"

      - name: Teardown
        if: always()
        run: |
          ./scripts/vm-teardown.sh test-upgrades-${{ github.run_id }}
```

### Performance Benchmarks

Set performance targets for upgrade operations:

| Operation | Target Time | Measurement |
|-----------|-------------|-------------|
| `upgrade <mise-extension>` | < 30 seconds | Time to upgrade single mise extension |
| `upgrade <apt-extension>` | < 60 seconds | Time to upgrade APT packages |
| `upgrade <binary-extension>` | < 45 seconds | Time to download and install binary |
| `upgrade-all` (8 extensions) | < 5 minutes | Time to upgrade all extensions |
| `upgrade-all --dry-run` | < 30 seconds | Time to check all extensions |
| `check-updates` | < 15 seconds | Time to check all update availability |

### Edge Case Testing

Test boundary conditions and error scenarios:

1. **Network failures**: Simulate network interruption during upgrade
2. **Disk space**: Test upgrade behavior with low disk space
3. **Permission errors**: Test upgrade with insufficient permissions
4. **Concurrent upgrades**: Test locking mechanism for simultaneous upgrades
5. **Version downgrades**: Test behavior when "upgrade" would downgrade
6. **Partial failures**: Test upgrade-all with some extensions failing

## Risk Assessment

### High Risk

1. **Breaking Changes to Existing Extensions**
   - **Mitigation**: Full backward compatibility, thorough testing
   - **Rollback**: Revert to v1.0 API if issues detected

2. **Data Loss During Upgrades**
   - **Mitigation**: Backup mechanism before upgrades, atomic operations
   - **Rollback**: Restore from backup if upgrade fails

3. **System Instability After Upgrades**
   - **Mitigation**: Validation step after each upgrade, rollback capability
   - **Rollback**: Revert to previous versions if validation fails

### Medium Risk

4. **Performance Degradation**
   - **Mitigation**: Performance benchmarks, optimization phase
   - **Rollback**: Optimize or disable slow upgrade methods

5. **Incompatible Version Upgrades**
   - **Mitigation**: Version compatibility checks, pinning support
   - **Rollback**: Downgrade to compatible versions

6. **User Experience Confusion**
   - **Mitigation**: Clear documentation, helpful error messages
   - **Rollback**: Improve UX based on user feedback

### Low Risk

7. **Extension API v2.0 Adoption**
   - **Mitigation**: Migration guide, community engagement
   - **Rollback**: v1.0 extensions continue to work indefinitely

8. **Testing Coverage**
   - **Mitigation**: Comprehensive test suite, CI/CD integration
   - **Rollback**: Add tests for discovered edge cases

## Open Questions

### 1. Version Pinning Granularity

**Question**: Should version pinning be per-extension or per-tool within an extension?

**Options**:
- **A)** Extension-level: Pin entire extension (e.g., "never upgrade nodejs extension")
- **B)** Tool-level: Pin individual tools (e.g., "keep node@18, upgrade npm")

**Recommendation**: Start with extension-level (simpler), add tool-level if requested

### 2. Upgrade Notifications

**Question**: How should users be notified of available updates?

**Options**:
- **A)** On SSH login (MOTD message)
- **B)** Daily email report
- **C)** CLI command only (`check-updates`)
- **D)** All of the above

**Recommendation**: Start with CLI command, add MOTD in Phase 7

### 3. Rollback Implementation

**Question**: How should rollback be implemented?

**Options**:
- **A)** Store previous versions in backup directory
- **B)** Use tool-specific rollback (e.g., `mise uninstall && mise install <old-version>`)
- **C)** Full system snapshot before upgrade
- **D)** No automatic rollback (manual only)

**Recommendation**: Tool-specific rollback (B) with future enhancement to (A)

### 4. Security Update Prioritization

**Question**: Should security updates be treated differently?

**Options**:
- **A)** Same as regular updates
- **B)** Auto-apply security updates (opt-in)
- **C)** Separate `upgrade-security` command
- **D)** Flag security updates in `check-updates`

**Recommendation**: Start with (D), add (B) in Phase 7

### 5. Multi-Version Support

**Question**: Should extensions support multiple versions of the same tool simultaneously?

**Example**: Keep Node.js 18 and 20 installed, allow project-specific selection

**Options**:
- **A)** Yes, for mise-managed tools only (already supported)
- **B)** Yes, for all tools (requires abstraction)
- **C)** No, single version per tool
- **D)** Only for language runtimes

**Recommendation**: (A) - mise already handles this well

### 6. Upgrade History Retention

**Question**: How long should upgrade history be retained?

**Options**:
- **A)** Forever (unlimited)
- **B)** Last 30 days
- **C)** Last 10 upgrades per extension
- **D)** Until manual cleanup

**Recommendation**: (C) - Last 10 upgrades per extension

### 7. Dependency Order for Upgrades

**Question**: Should extensions be upgraded in dependency order?

**Example**: Upgrade `nodejs` before `nodejs-devtools`

**Options**:
- **A)** Yes, respect manifest order
- **B)** Yes, compute dependency graph
- **C)** No, upgrade in any order
- **D)** User-configurable

**Recommendation**: (A) - Manifest order already represents dependencies

### 8. Upgrade Failure Recovery

**Question**: If `upgrade-all` fails partway through, what happens?

**Options**:
- **A)** Continue with remaining extensions
- **B)** Stop immediately, rollback all
- **C)** Stop immediately, keep successful upgrades
- **D)** User-configurable (--continue-on-error flag)

**Recommendation**: (D) - Default to (C), allow (A) with flag

## Success Criteria

### Functionality

- ✅ All extensions support Extension API v2.0
- ✅ `upgrade <name>` works for all installation methods
- ✅ `upgrade-all` upgrades all extensions successfully
- ✅ `upgrade-all --dry-run` shows accurate preview
- ✅ `check-updates` identifies all available updates
- ✅ Rollback works for failed upgrades
- ✅ Version history tracks all upgrades

### Quality

- ✅ 100% of extensions have passing upgrade tests
- ✅ 90%+ test coverage for upgrade-helpers.sh
- ✅ All CI/CD tests pass
- ✅ No regressions in existing functionality
- ✅ Performance benchmarks met

### Documentation

- ✅ Extension API v2.0 specification complete
- ✅ Migration guide published
- ✅ All extensions documented with upgrade support
- ✅ Troubleshooting guide for upgrade issues
- ✅ Video tutorials/demos created

### User Experience

- ✅ Clear, helpful error messages
- ✅ Progress indicators for long operations
- ✅ Intuitive command-line interface
- ✅ Comprehensive help text
- ✅ Positive user feedback

## Conclusion

This proposal outlines a comprehensive, backward-compatible abstraction for extension upgrades in the Sindri system. By extending the Extension API to v2.0 with a standardized `upgrade()` function, introducing explicit installation method metadata, and providing reusable helper utilities, we can enable consistent upgrade experiences across all extension types.

The phased implementation plan spreads work across 6 weeks, prioritizing core/protected extensions first, then expanding to all extensions. The migration strategy ensures zero disruption to existing users while providing clear paths for extension developers to adopt API v2.0.

With comprehensive testing, clear documentation, and careful risk mitigation, this enhancement will significantly improve the maintainability and user experience of the Sindri development environment.

## Next Steps

1. **Review & Approval**: Gather feedback from stakeholders
2. **Prototype**: Implement Phase 1 (Foundation) as proof-of-concept
3. **Iterate**: Refine design based on prototype learnings
4. **Execute**: Follow implementation plan (Phases 1-8)
5. **Deploy**: Roll out to production with monitoring
6. **Support**: Assist extension developers with migration

---

**Document Version**: 1.0
**Last Updated**: 2025-10-30
**Author**: Claude Code (with Chris Phillipson)
**Status**: Proposal - Pending Review
