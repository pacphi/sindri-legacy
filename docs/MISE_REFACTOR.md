# Extension API mise Refactor Plan

## Overview

This document outlines the detailed refactoring plan to integrate **mise** (https://mise.jdx.dev) into Sindri's Extension API. The refactor will be executed in phases to minimize risk and allow for validation at each step.

See [MISE_STANDARDIZATION.md](./MISE_STANDARDIZATION.md) for the complete analysis and rationale.

## Goals

1. **Reduce code complexity** by ~70-80% in language runtime extensions
2. **Standardize tool management** across all extensions
3. **Enhance status() function** to provide comprehensive Bill of Materials reporting
4. **Maintain backward compatibility** with existing deployments
5. **Improve developer experience** with unified tooling

## Architectural Decision: mise.toml vs mise use Commands

### The Question

Should extensions use:
- **Option A**: Declarative `mise.toml` configuration files?
- **Option B**: Imperative `mise use -g` commands?
- **Option C**: Hybrid approach?

### Analysis

#### Option A: mise.toml Configuration Files (RECOMMENDED)

Each extension creates a dedicated TOML config file in `~/.config/mise/conf.d/`:

```bash
# nodejs.sh.example - install() function
install() {
  if ! command_exists mise; then
    print_error "mise is required"
    return 1
  fi

  # Create nodejs-specific mise config
  mkdir -p ~/.config/mise/conf.d

  cat > ~/.config/mise/conf.d/nodejs.toml << 'EOF'
[tools]
node = "lts"
"npm:npm" = "latest"

[env]
NODE_ENV = "development"

[settings]
legacy_version_file = true  # Support .nvmrc files
EOF

  # Install all tools from config
  mise install

  print_success "Node.js installed via mise config"
  return 0
}
```

**Benefits**:
1. ✅ **Declarative** - Clear manifest of exactly what's installed
2. ✅ **Version locking** - `mise.lock` generated automatically for reproducibility
3. ✅ **Atomic operations** - `mise install` reads entire config
4. ✅ **Git-trackable** - Can version control configs
5. ✅ **Auditable** - Single source of truth in `~/.config/mise/conf.d/`
6. ✅ **Separation of concerns** - Each extension owns its TOML file
7. ✅ **Tool options** - Can specify `postinstall`, `install_env`, `os` restrictions
8. ✅ **Easy merging** - mise automatically merges all `conf.d/*.toml` files
9. ✅ **Rollback friendly** - Just remove/edit TOML file
10. ✅ **Better for CI/CD** - Config files can be cached

**Example Structure**:
```
~/.config/mise/
├── config.toml              # Global defaults (created by mise-config)
├── conf.d/
│   ├── nodejs.toml          # Created by nodejs extension
│   ├── python.toml          # Created by python extension
│   ├── rust.toml            # Created by rust extension
│   ├── golang.toml          # Created by golang extension
│   └── nodejs-devtools.toml # Created by nodejs-devtools extension
└── mise.lock                # Auto-generated lockfile
```

**Tradeoffs**:
1. ⚠️ Need to handle TOML file creation in bash (simple with heredoc)
2. ⚠️ Need to clean up TOML files in remove() function
3. ⚠️ Slightly more complex than single commands

#### Option B: mise use Commands (Simpler but Less Powerful)

Extensions run commands directly:

```bash
install() {
  if ! command_exists mise; then
    print_error "mise is required"
    return 1
  fi

  mise use -g node@lts
  mise use -g npm:typescript
  mise use -g npm:eslint

  return 0
}
```

**Benefits**:
1. ✅ Simple bash code
2. ✅ No TOML file management
3. ✅ Immediate feedback per command

**Tradeoffs**:
1. ❌ **No central manifest** - Can't see all tools in one place
2. ❌ **No version locking** - No mise.lock benefit
3. ❌ **Slower** - Each command runs separately
4. ❌ **Less reproducible** - Commands run imperatively
5. ❌ **Harder to audit** - Must run `mise ls` to see what's installed
6. ❌ **No tool options** - Can't specify postinstall, install_env, etc.
7. ❌ **Harder rollback** - Need to track what was installed

#### Option C: Hybrid Approach

Use mise.toml for primary tools, mise use for one-offs:

```bash
install() {
  # Create core config
  cat > ~/.config/mise/conf.d/nodejs.toml << 'EOF'
[tools]
node = "lts"
EOF

  mise install

  # Add optional tools via commands
  if [[ "$CI_MODE" != "true" ]]; then
    mise use -g npm:typescript
    mise use -g npm:eslint
  fi

  return 0
}
```

**Benefits**: Flexibility for different scenarios
**Tradeoffs**: Inconsistent approach, harder to maintain

### Recommendation: **Option A (mise.toml)**

Use **conf.d/\*.toml** pattern for all extensions.

**Rationale**:
1. mise's `conf.d/` directory was designed for exactly this use case
2. Automatic merging eliminates complexity
3. Lockfile provides reproducibility across VMs
4. Better developer experience (can read configs)
5. Easier to debug (inspect TOML files)
6. Supports advanced features (tool options, env vars, tasks)
7. Only ~5-10 extra lines of bash per extension

### Implementation Pattern

**Standard Extension Template**:

```bash
install() {
  print_status "Installing ${EXT_NAME} via mise..."

  if ! command_exists mise; then
    print_error "mise is required - install mise-config extension first"
    return 1
  fi

  # Create extension-specific mise configuration
  local mise_config_dir="$HOME/.config/mise/conf.d"
  mkdir -p "$mise_config_dir"

  cat > "$mise_config_dir/${EXT_NAME}.toml" << 'EOF'
[tools]
# Extension-specific tools
primary-tool = "version"
"backend:tool" = "version"

[env]
# Extension-specific environment variables (optional)
TOOL_ENV = "value"
EOF

  # Install all tools from configuration
  if mise install; then
    print_success "${EXT_NAME} tools installed via mise"
  else
    print_error "mise install failed"
    return 1
  fi

  return 0
}

remove() {
  # Remove extension's mise configuration
  rm -f "$HOME/.config/mise/conf.d/${EXT_NAME}.toml"

  # Optionally uninstall tools (they may be used by other extensions)
  # mise uninstall <tool> ...

  print_success "${EXT_NAME} mise configuration removed"
}
```

### Extension-Specific Examples

#### nodejs.toml (created by nodejs extension)

```toml
# ~/.config/mise/conf.d/nodejs.toml
[tools]
node = "lts"
"npm:npm" = "latest"

[settings]
legacy_version_file = true  # Support .nvmrc files
node_build_mirror_url = "https://nodejs.org/dist"

[env]
# npm configuration
NPM_CONFIG_LOGLEVEL = "warn"
```

#### python.toml (created by python extension)

```toml
# ~/.config/mise/conf.d/python.toml
[tools]
python = "3.13"
"pipx:virtualenv" = "latest"
"pipx:poetry" = "latest"
"pipx:flake8" = "latest"
"pipx:mypy" = "latest"
"pipx:black" = "latest"
"pipx:jupyterlab" = "latest"

[settings]
legacy_version_file = true  # Support .python-version files

[env]
PYTHON_CONFIGURE_OPTS = "--enable-shared"
```

#### rust.toml (created by rust extension)

```toml
# ~/.config/mise/conf.d/rust.toml
[tools]
rust = "stable"

# Only install cargo tools in non-CI environments
# (CI_MODE handling done in extension install() via conditional config generation)

[tools."cargo:ripgrep"]
version = "latest"
os = ["linux", "darwin"]  # Restrict to supported platforms

[tools."cargo:fd-find"]
version = "latest"

[tools."cargo:exa"]
version = "latest"

[tools."cargo:bat"]
version = "latest"

[tools."cargo:tokei"]
version = "latest"

[settings]
legacy_version_file = true  # Support rust-toolchain files
```

#### nodejs-devtools.toml (created by nodejs-devtools extension)

```toml
# ~/.config/mise/conf.d/nodejs-devtools.toml
[tools]
"npm:typescript" = "latest"
"npm:ts-node" = "latest"
"npm:eslint" = "latest"
"npm:prettier" = "latest"
"npm:nodemon" = "latest"
"npm:@typescript-eslint/parser" = "latest"
"npm:@typescript-eslint/eslint-plugin" = "latest"
"npm:goalie" = "latest"
```

### Configuration Management in Extensions

#### CI_MODE Handling

For CI-optimized installations, extensions can generate different configs:

```bash
install() {
  # ... prerequisite checks ...

  local mise_config="$HOME/.config/mise/conf.d/${EXT_NAME}.toml"

  if [[ "$CI_MODE" == "true" ]]; then
    # Minimal config for CI
    cat > "$mise_config" << 'EOF'
[tools]
rust = "stable"
# Skip cargo tools in CI to save time
EOF
  else
    # Full config for development
    cat > "$mise_config" << 'EOF'
[tools]
rust = "stable"
"cargo:ripgrep" = "latest"
"cargo:fd-find" = "latest"
"cargo:bat" = "latest"
# ... more tools ...
EOF
  fi

  mise install
  return 0
}
```

#### Version Pinning

Extensions can pin specific versions when needed:

```bash
cat > ~/.config/mise/conf.d/golang.toml << 'EOF'
[tools]
go = "1.24.6"  # Specific version instead of "latest"

[tools."go:golang.org/x/tools/gopls@latest"]
# Latest gopls is fine, but Go version is pinned
EOF
```

### Benefits Over mise use Commands

| Aspect | mise use -g | mise.toml (conf.d) | Winner |
|--------|-------------|-------------------|--------|
| **Declarative** | ❌ Imperative | ✅ Declarative | mise.toml |
| **Version Locking** | ❌ No mise.lock | ✅ Generates mise.lock | mise.toml |
| **Auditability** | ❌ Need to run mise ls | ✅ Read TOML files | mise.toml |
| **Reproducibility** | ⚠️ Commands may vary | ✅ Lockfile ensures same versions | mise.toml |
| **Rollback** | ❌ Hard to undo | ✅ Delete/edit TOML | mise.toml |
| **Tool Options** | ❌ Limited | ✅ Full options (postinstall, etc.) | mise.toml |
| **Performance** | ⚠️ Serial execution | ✅ Batch install | mise.toml |
| **Simplicity** | ✅ Simple commands | ⚠️ TOML file management | mise use |
| **Extension Isolation** | ❌ All mixed in global | ✅ Separate files in conf.d | mise.toml |
| **CI/CD Caching** | ❌ Cache mise ls output? | ✅ Cache TOML + lock files | mise.toml |

**Winner: mise.toml (conf.d pattern) - 9 out of 10 criteria**

### Real-World Example Comparison

**Current nodejs extension (NVM)**:
```bash
# 70+ lines of installation logic
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
nvm alias default lts/*
npm install -g npm@latest
```

**Option B: mise use commands**:
```bash
# 5 lines of installation logic
mise use -g node@lts
mise use -g npm:npm@latest
# But: no version locking, no central manifest
```

**Option A: mise.toml (RECOMMENDED)**:
```bash
# 8 lines of installation logic
cat > ~/.config/mise/conf.d/nodejs.toml << 'EOF'
[tools]
node = "lts"
"npm:npm" = "latest"
EOF
mise install
# Plus: version locking, declarative, auditable
```

**Code reduction: ~90%** compared to current
**Additional benefits**: Version locking, reproducibility, auditability

### Tradeoffs Worth Making

**Simple TOML Creation**:
- Bash heredoc syntax is straightforward
- No TOML parsing needed (just create files)
- mise handles reading/merging automatically

**File Cleanup**:
- remove() function just deletes one TOML file
- Cleaner than tracking multiple `mise use` commands

**Config Inspection**:
```bash
# See all extension configs
ls -1 ~/.config/mise/conf.d/

# See specific extension config
cat ~/.config/mise/conf.d/nodejs.toml

# See what mise sees (merged config)
mise config

# See locked versions
cat ~/.config/mise/mise.lock
```

### Advanced Features Enabled by mise.toml

#### 1. Tool-Specific Options

```toml
# golang.toml
[tools.go]
version = "1.24.6"
install_env = { GOROOT_BOOTSTRAP = "$HOME/.local/go-bootstrap" }
postinstall = "go install golang.org/x/tools/gopls@latest"
```

#### 2. Platform-Specific Installations

```toml
# docker-tools.toml
[tools."ubi:wagoodman/dive"]
version = "latest"
os = ["linux"]  # Only install on Linux

[tools."ubi:bcicen/ctop"]
version = "latest"
os = ["linux", "darwin"]
```

#### 3. Environment Variables Per Tool

```toml
# python.toml
[env]
PYTHON_CONFIGURE_OPTS = "--enable-shared --enable-optimizations"
PIP_REQUIRE_VIRTUALENV = "true"
UV_PYTHON_PREFERENCE = "only-managed"
```

#### 4. Task Definitions (Bonus)

```toml
# nodejs-devtools.toml
[tools]
"npm:prettier" = "latest"
"npm:eslint" = "latest"

[tasks.format]
run = "prettier --write ."

[tasks.lint]
run = "eslint ."
```

Then developers can run: `mise run format` or `mise run lint`

### Recommendation: Use conf.d Pattern

**Architecture**:
```
~/.config/mise/
├── config.toml              # Global defaults (mise-config extension)
├── conf.d/                  # Extension-specific configs (auto-merged by mise)
│   ├── nodejs.toml
│   ├── python.toml
│   ├── rust.toml
│   ├── golang.toml
│   └── nodejs-devtools.toml
└── mise.lock                # Auto-generated lockfile
```

**Why This is Superior**:
1. **Zero merge complexity** - mise handles it automatically
2. **Clean separation** - Each extension manages one file
3. **Easy debugging** - Inspect individual extension configs
4. **Atomic operations** - `mise install` installs everything
5. **Version locking** - mise.lock ensures reproducibility
6. **No cross-extension conflicts** - Each extension in its own namespace

**Implementation Overhead**: Minimal (~8 extra lines per extension vs mise use)
**Benefit**: Massive improvement in maintainability, auditability, and reproducibility

### Special Cases

#### Dynamic Configuration (CI_MODE)

Extensions can generate different configs based on environment:

```bash
install() {
  local config_file="$HOME/.config/mise/conf.d/${EXT_NAME}.toml"

  if [[ "$CI_MODE" == "true" ]]; then
    # Minimal CI config
    cat > "$config_file" << 'EOF'
[tools]
rust = "stable"
# Skip cargo tools in CI
EOF
  else
    # Full development config
    cat > "$config_file" << 'EOF'
[tools]
rust = "stable"
"cargo:ripgrep" = "latest"
"cargo:fd-find" = "latest"
"cargo:bat" = "latest"
# ... more tools ...
EOF
  fi

  mise install
}
```

#### Tool Version Overrides

Users can override extension defaults:

```bash
# User creates ~/.config/mise/config.local.toml (higher priority)
[tools]
node = "18"  # Override nodejs extension's "lts" default
```

### Migration from mise use to mise.toml

If we start with `mise use` in early development, migration is simple:

```bash
# Convert existing mise-managed tools to config
mise use -g node@lts          →  Add to nodejs.toml
mise use -g python@3.13       →  Add to python.toml
mise use -g npm:typescript    →  Add to nodejs-devtools.toml

# Then run
mise install  # Installs from all conf.d/*.toml files
```

### Final Recommendation

**Use mise.toml configuration files (conf.d pattern)** for all extensions because:

1. **10x better auditability** - `ls ~/.config/mise/conf.d/` shows all extensions
2. **Version locking** via mise.lock - critical for reproducibility
3. **Clean architecture** - Each extension owns its config
4. **Future-proof** - Supports advanced features (tasks, env, options)
5. **Only ~8 extra lines** per extension vs mise use
6. **mise does the heavy lifting** - Auto-merges configs, generates lockfile

The conf.d pattern is a **clear architectural win** with minimal implementation overhead.

### Summary: Why conf.d Pattern is Worth It

**Developer Experience**:
```bash
# See what's installed across all extensions
ls ~/.config/mise/conf.d/
# Output: nodejs.toml  python.toml  rust.toml  golang.toml  nodejs-devtools.toml

# Inspect specific extension
cat ~/.config/mise/conf.d/python.toml

# See all tools at once
mise ls

# See exact locked versions
cat ~/.config/mise/mise.lock
```

**Operations**:
```bash
# Backup entire mise configuration
tar -czf mise-backup.tar.gz ~/.config/mise/

# Restore on new VM
tar -xzf mise-backup.tar.gz -C ~/
mise install  # Installs everything from configs

# Audit installed tools
mise ls > vm-inventory-$(date +%Y%m%d).txt
```

**Extension Management**:
```bash
# Remove extension cleanly
rm ~/.config/mise/conf.d/nodejs.toml
mise prune  # Remove unused tools

# Update all tools
mise upgrade  # Updates to latest versions in config

# Lock specific versions
mise install --lock  # Updates mise.lock with exact versions
```

**CI/CD Benefits**:
- ✅ Cache `~/.config/mise/` directory in CI
- ✅ `mise install --frozen` uses lockfile (like npm ci)
- ✅ Reproducible builds across all pipeline runs
- ✅ Fast installs (mise caches downloads)

**The conf.d pattern delivers**:
1. **Better UX** - Clear, inspectable configuration
2. **Better DX** - Easy debugging and troubleshooting
3. **Better Ops** - Reproducible, auditable, cacheable
4. **Better Architecture** - Clean separation of concerns

**Cost**: ~8 extra lines of bash per extension
**Value**: 10x improvement in maintainability and reproducibility

This is absolutely worth doing.

## File Structure: .extension + .toml Pairs

### The Opportunity

Currently, extensions use `.sh.example` suffix and would embed TOML via heredoc. We can do better:

**Proposed**: Rename `.sh.example` → `.extension` and maintain separate `.toml` files as first-class artifacts.

### Current Structure (Pre-mise)
```
docker/lib/extensions.d/
├── nodejs.sh.example          # Extension script
├── python.sh.example
├── rust.sh.example
└── active-extensions.conf     # Manifest
```

### Proposed Structure (With mise + .extension)
```
docker/lib/extensions.d/
├── nodejs.extension           # Renamed from .sh.example
├── nodejs.toml                # New: mise tool configuration
├── nodejs-ci.toml             # Optional: CI-specific config
├── python.extension
├── python.toml
├── python-ci.toml
├── rust.extension
├── rust.toml
├── rust-ci.toml
├── template.extension         # Template for new extensions
├── template.toml              # Template TOML
└── active-extensions.conf     # Manifest (unchanged)
```

### File Pairing Pattern

Each mise-powered extension has:
- `<name>.extension` - Bash script with Extension API v1.0 functions
- `<name>.toml` - mise tool configuration (development/full install)
- `<name>-ci.toml` - Optional: Minimal config for CI_MODE

Non-mise extensions (like docker, jvm) only have `.extension` file.

### Benefits of This Approach

#### 1. Separation of Concerns
```bash
# Extension logic (bash)        # Tool manifest (TOML)
nodejs.extension         ←→     nodejs.toml
  ├── prerequisites()            ├── [tools]
  ├── install()                  ├── node = "lts"
  ├── configure()                ├── [env]
  ├── validate()                 └── [settings]
  ├── status()
  └── remove()
```

#### 2. No Heredoc Complexity

**Before (heredoc)**:
```bash
install() {
  cat > ~/.config/mise/conf.d/nodejs.toml << 'EOF'
[tools]
node = "lts"
"npm:npm" = "latest"

[settings]
legacy_version_file = true
EOF
  mise install
}
```

**After (file copy)**:
```bash
install() {
  local ext_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local toml_file="${CI_MODE:-false}" == "true" && echo "nodejs-ci.toml" || echo "nodejs.toml"

  cp "$ext_dir/$toml_file" "$HOME/.config/mise/conf.d/nodejs.toml"
  mise install
}
```

**Advantages**:
- ✅ No bash string escaping issues
- ✅ Real TOML files can be validated independently
- ✅ IDE syntax highlighting and validation
- ✅ Easier to edit and maintain
- ✅ Git diffs are cleaner

#### 3. Template Distribution

TOML files become **first-class templates**:

```bash
# Extension can offer TOML as project template
configure() {
  # ... other config ...

  # Copy TOML to workspace templates
  local ext_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cp "$ext_dir/nodejs.toml" /workspace/templates/mise-nodejs.toml

  print_status "Template available: /workspace/templates/mise-nodejs.toml"
  print_status "Use in projects: cp /workspace/templates/mise-nodejs.toml ./mise.toml"
}
```

Users can initialize new projects with curated configs!

#### 4. Independent Testing

```yaml
# .github/workflows/validate.yml
- name: Validate TOML syntax
  run: |
    # Install TOML validator
    pip install toml

    # Validate all extension TOML files
    for toml in docker/lib/extensions.d/*.toml; do
      echo "Validating $toml..."
      python3 -c "import toml; toml.load(open('$toml'))"
    done
```

#### 5. User Customization

Users can edit TOML files directly without touching bash:

```bash
# User workflow
cd ~/.config/mise/conf.d
vim nodejs.toml       # Edit directly
mise install          # Apply changes
```

Much safer than editing bash scripts!

#### 6. Clearer File Semantics

`.extension` is more descriptive than `.sh.example`:
- **extension** = "extends the system with functionality"
- **sh.example** = "shell script that's an example"

### Implementation Details

#### Extension Manager Updates

Update `extension-manager.sh` to handle `.extension` files:

```bash
# OLD: Look for *.sh.example
get_extension_name() {
  local filename="$1"
  local base=$(basename "$filename" .sh.example)
  echo "$base" | sed 's/^[0-9]*-//'
}

# NEW: Look for *.extension
get_extension_name() {
  local filename="$1"
  local base=$(basename "$filename" .extension)
  echo "$base" | sed 's/^[0-9]*-//'  # Still handle legacy numbered prefixes
}

# Update activation logic
activate_extension() {
  local ext_name=$1
  local ext_file="$EXTENSIONS_BASE/${ext_name}.extension"
  local toml_file="$EXTENSIONS_BASE/${ext_name}.toml"
  local toml_ci_file="$EXTENSIONS_BASE/${ext_name}-ci.toml"

  # Validate extension file exists
  if [[ ! -f "$ext_file" ]]; then
    print_error "Extension not found: $ext_file"
    return 1
  fi

  # Copy extension script (activated as .sh for backward compat)
  cp "$ext_file" "$EXTENSIONS_BASE/${ext_name}.sh"
  print_debug "Activated: $ext_file → ${ext_name}.sh"

  # If TOML config exists, make it available to extension
  if [[ -f "$toml_file" ]]; then
    # Extensions can reference this in their install() function
    print_debug "TOML config available: $toml_file"
  fi

  return 0
}

# Update deactivation logic
deactivate_extension() {
  local ext_name=$1

  # Remove activated script
  rm -f "$EXTENSIONS_BASE/${ext_name}.sh"

  # Optionally clean up mise config (extensions handle this in remove())
  # Extension's remove() function will delete ~/.config/mise/conf.d/${ext_name}.toml

  print_success "Deactivated: $ext_name"
  return 0
}

# Update list command
list_extensions() {
  local show_all="${1:-false}"

  # Find all extension files (look for *.extension now)
  local extensions
  if [[ "$show_all" == "true" ]]; then
    extensions=$(find "$EXTENSIONS_BASE" -maxdepth 1 -name "*.extension" -type f | sort)
  else
    extensions=$(find "$EXTENSIONS_BASE" -maxdepth 1 -name "*.extension" -type f ! -name "template.extension" | sort)
  fi

  # ... rest of list logic
}
```

#### Extension Script Changes

**Standard install() pattern**:

```bash
install() {
  print_status "Installing ${EXT_NAME} via mise..."

  if ! command_exists mise; then
    print_error "mise is required - install mise-config extension first"
    return 1
  fi

  # Determine paths
  local ext_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local toml_source
  local toml_dest="$HOME/.config/mise/conf.d/${EXT_NAME}.toml"

  # Select config based on CI_MODE
  if [[ "${CI_MODE:-false}" == "true" ]] && [[ -f "$ext_dir/${EXT_NAME}-ci.toml" ]]; then
    toml_source="$ext_dir/${EXT_NAME}-ci.toml"
    print_debug "Using CI config: ${EXT_NAME}-ci.toml"
  else
    toml_source="$ext_dir/${EXT_NAME}.toml"
    print_debug "Using full config: ${EXT_NAME}.toml"
  fi

  # Validate TOML file exists
  if [[ ! -f "$toml_source" ]]; then
    print_error "TOML configuration not found: $toml_source"
    return 1
  fi

  # Copy TOML to mise conf.d
  mkdir -p "$HOME/.config/mise/conf.d"
  if ! cp "$toml_source" "$toml_dest"; then
    print_error "Failed to copy TOML config"
    return 1
  fi

  print_success "Configuration copied: $toml_dest"

  # Install all tools from configuration
  if mise install; then
    print_success "${EXT_NAME} tools installed"
  else
    print_error "mise install failed"
    return 1
  fi

  return 0
}
```

**Standard remove() pattern**:

```bash
remove() {
  print_warning "Removing ${EXT_NAME}..."

  # Remove mise configuration
  local toml_file="$HOME/.config/mise/conf.d/${EXT_NAME}.toml"
  if [[ -f "$toml_file" ]]; then
    rm -f "$toml_file"
    print_success "Removed mise configuration: $toml_file"
  fi

  # Optionally uninstall tools (be careful - may be shared)
  # mise prune  # Removes tools not referenced in any config

  # Clean up other extension-specific files
  # ... (aliases, SSH wrappers, etc.)

  return 0
}
```

### Example TOML Files

#### nodejs.toml (Full Development Config)

```toml
# nodejs.toml - Full Node.js development configuration
# Created by: nodejs extension
# Usage: Copied to ~/.config/mise/conf.d/ during installation

[tools]
node = "lts"
"npm:npm" = "latest"

[settings]
# Support legacy .nvmrc files for backward compatibility
legacy_version_file = true
node_build_mirror_url = "https://nodejs.org/dist"

[env]
# npm configuration
NPM_CONFIG_LOGLEVEL = "warn"
NPM_CONFIG_UPDATE_NOTIFIER = "false"

[tasks.npm-update]
description = "Update npm to latest"
run = "npm install -g npm@latest"

[tasks.clean-cache]
description = "Clean npm cache"
run = "npm cache clean --force"
```

#### nodejs-ci.toml (Minimal CI Config)

```toml
# nodejs-ci.toml - Minimal Node.js for CI environments
# Created by: nodejs extension
# Usage: Used when CI_MODE=true

[tools]
node = "lts"
# Skip npm update in CI - use bundled version

[settings]
legacy_version_file = false  # Don't need .nvmrc support in CI
```

#### python.toml (Full Development Config)

```toml
# python.toml - Full Python development environment
# Created by: python extension

[tools]
python = "3.13"
"pipx:virtualenv" = "latest"
"pipx:poetry" = "latest"
"pipx:flake8" = "latest"
"pipx:mypy" = "latest"
"pipx:black" = "latest"
"pipx:jupyterlab" = "latest"

[settings]
legacy_version_file = true  # Support .python-version files
python_compile = true
python_configure_opts = "--enable-shared --enable-optimizations"

[env]
PYTHON_CONFIGURE_OPTS = "--enable-shared"
PIP_REQUIRE_VIRTUALENV = "false"  # Allow global installs for pipx
UV_PYTHON_PREFERENCE = "only-managed"

[tasks.test]
description = "Run Python tests"
run = "pytest tests/"

[tasks.format]
description = "Format Python code"
run = "black ."

[tasks.lint]
description = "Lint Python code"
run = "flake8 . && mypy ."
```

#### python-ci.toml (Minimal CI Config)

```toml
# python-ci.toml - Minimal Python for CI
[tools]
python = "3.13"
"pipx:pytest" = "latest"
# Skip Jupyter, poetry, dev tools in CI
```

### File Naming Convention

#### Pattern
```
<extension-name>.extension       # Required: Extension script
<extension-name>.toml           # Optional: mise config (if mise-powered)
<extension-name>-ci.toml        # Optional: CI-specific mise config
```

#### Examples
```
mise-config.extension           # Core mise extension (no TOML needed)
workspace-structure.extension   # No TOML (doesn't install tools)
ssh-environment.extension       # No TOML (configuration only)

nodejs.extension + nodejs.toml + nodejs-ci.toml
python.extension + python.toml + python-ci.toml
rust.extension + rust.toml + rust-ci.toml
golang.extension + golang.toml + golang-ci.toml
nodejs-devtools.extension + nodejs-devtools.toml

ruby.extension + ruby.toml      # Only created if USE_MISE_FOR_RUBY=true
jvm.extension                   # No TOML (uses SDKMAN)
docker.extension                # No TOML (system packages)
```

### Glob Pattern Updates

Update scripts that find extensions:

```bash
# OLD
find extensions.d -name "*.sh.example"

# NEW
find extensions.d -name "*.extension"

# Find extension + TOML pairs
for ext in extensions.d/*.extension; do
  ext_name=$(basename "$ext" .extension)
  toml_file="extensions.d/${ext_name}.toml"

  if [[ -f "$toml_file" ]]; then
    echo "mise-powered: $ext_name (has TOML)"
  else
    echo "traditional: $ext_name (no TOML)"
  fi
done
```

### Workflow Validation Updates

```yaml
# .github/workflows/validate.yml
- name: Validate extension TOML files
  run: |
    echo "Validating extension TOML configurations..."

    # Install TOML validator
    pip install toml

    # Find all TOML files in extensions.d
    toml_files=$(find docker/lib/extensions.d -name "*.toml" -type f)

    failed_files=()
    for toml in $toml_files; do
      echo "Validating $toml..."
      if ! python3 -c "import toml; toml.load(open('$toml'))"; then
        failed_files+=("$toml")
      fi
    done

    if [[ ${#failed_files[@]} -gt 0 ]]; then
      echo "❌ Invalid TOML files:"
      printf '%s\n' "${failed_files[@]}"
      exit 1
    fi

    echo "✅ All TOML files are valid"

- name: Verify extension-TOML pairs
  run: |
    echo "Checking for proper extension-TOML pairing..."

    # For each mise-powered extension, verify TOML exists
    mise_extensions=("nodejs" "python" "rust" "golang" "nodejs-devtools")

    for ext in "${mise_extensions[@]}"; do
      if [[ ! -f "docker/lib/extensions.d/${ext}.toml" ]]; then
        echo "❌ Missing TOML for mise-powered extension: $ext"
        exit 1
      else
        echo "✅ $ext.extension + $ext.toml pair verified"
      fi
    done
```

### Advantages Over Heredoc Approach

| Aspect | Heredoc | Separate .toml Files | Winner |
|--------|---------|---------------------|--------|
| **Syntax Validation** | ❌ Only at runtime | ✅ CI validates before deploy | .toml files |
| **IDE Support** | ❌ No highlighting in bash strings | ✅ Full TOML highlighting | .toml files |
| **Editability** | ❌ Edit bash, find heredoc | ✅ Edit TOML directly | .toml files |
| **Git Diffs** | ❌ Shows bash + TOML changes | ✅ TOML changes isolated | .toml files |
| **Reusability** | ❌ Embedded in script | ✅ Can copy to projects | .toml files |
| **Testing** | ❌ Bash execution needed | ✅ Parse TOML independently | .toml files |
| **Documentation** | ⚠️ Comments in heredoc | ✅ TOML is self-documenting | .toml files |
| **User Override** | ❌ Must edit bash script | ✅ Edit TOML, extension untouched | .toml files |
| **Simplicity** | ✅ Everything in one file | ⚠️ Two files per extension | Heredoc |
| **Line Count** | ✅ Fewer bash lines | ⚠️ Slightly more total files | Heredoc |

**Winner: Separate .toml files - 8 out of 10 criteria**

The only advantages of heredoc are slightly fewer files and everything in one place. The benefits of separate TOML files vastly outweigh these minor conveniences.

### File Extension Semantics

#### Why .extension is Better

Current: `.sh.example`
- "example" implies "not real" or "template only"
- Confusing: Is it an example of a shell script, or an example extension?
- Hidden semantics: Gets activated by copying to `.sh`

Proposed: `.extension`
- Clear purpose: "This is an extension"
- Professional: Matches common patterns (`.plugin`, `.module`, `.addon`)
- Self-documenting: No confusion about what it is
- Activated cleanly: Copy `.extension` → `.sh` or keep as `.extension`

#### Activation Options

**Option A**: Keep .sh activation (backward compatible)
```bash
# Activated file
nodejs.extension → nodejs.sh
```

**Option B**: Use .extension for activated files
```bash
# Activated file
nodejs.extension → nodejs.extension  # Copy to itself or mark as active
```

**Recommendation**: **Option A** for backward compatibility with existing scripts that source `*.sh` files.

### Migration Strategy

#### Phase 0.1: Rename Files

```bash
# Automated rename script
for file in docker/lib/extensions.d/*.sh.example; do
  base=$(basename "$file" .sh.example)
  new_name="docker/lib/extensions.d/${base}.extension"
  git mv "$file" "$new_name"
done
```

#### Phase 0.2: Create TOML Files

For Phase 1 mise-powered extensions:

```bash
# Extract TOML from current docs and create files
cat > docker/lib/extensions.d/nodejs.toml << 'EOF'
[tools]
node = "lts"
"npm:npm" = "latest"
# ... (from documentation)
EOF

cat > docker/lib/extensions.d/nodejs-ci.toml << 'EOF'
[tools]
node = "lts"
# Minimal for CI
EOF
```

#### Phase 0.3: Update Extension Manager

Update all references:
- `*.sh.example` → `*.extension`
- Update glob patterns
- Update documentation

#### Phase 0.4: Update CI Workflows

Update all workflow files:
- `*.sh.example` → `*.extension` in path filters
- Add TOML validation steps

### Documentation in TOML Files

TOML files can be richly documented:

```toml
# nodejs.toml - Node.js Development Environment
# Managed by: nodejs extension
# API Version: Extension API v1.0
# Last Updated: 2025-01-15
#
# This configuration provides:
# - Node.js LTS version
# - Latest npm package manager
# - Support for .nvmrc files (for projects still using NVM)
#
# To customize:
# 1. Edit this file directly: ~/.config/mise/conf.d/nodejs.toml
# 2. Run: mise install
# 3. Verify: mise ls node

[tools]
# Node.js LTS - Long Term Support version
# See available versions: mise ls-remote node
node = "lts"

# npm - Node Package Manager
# Keep updated to latest for security and features
"npm:npm" = "latest"

[settings]
# Enable .nvmrc file support for backward compatibility
# Projects with .nvmrc will use that version instead
legacy_version_file = true

# Use official Node.js mirror
node_build_mirror_url = "https://nodejs.org/dist"

[env]
# Reduce npm output noise
NPM_CONFIG_LOGLEVEL = "warn"

# Disable update notifier in automated environments
NPM_CONFIG_UPDATE_NOTIFIER = "false"

[tasks.npm-update]
description = "Update npm to latest version"
run = "npm install -g npm@latest"

[tasks.clean]
description = "Clean npm cache"
run = "npm cache clean --force"

[tasks.doctor]
description = "Check npm configuration"
run = "npm doctor"
```

### Repository Structure Impact

```
docker/lib/extensions.d/
├── README.md                           # Extension system documentation
├── template.extension                  # Template for new extensions
├── template.toml                       # Template for mise configs
├── active-extensions.conf.example      # Manifest template
│
# Core extensions (no TOML - no tools to install)
├── workspace-structure.extension
├── ssh-environment.extension
├── post-cleanup.extension
│
# mise-powered extensions (have .toml)
├── mise-config.extension
├── nodejs.extension
├── nodejs.toml
├── nodejs-ci.toml
├── python.extension
├── python.toml
├── python-ci.toml
├── rust.extension
├── rust.toml
├── rust-ci.toml
├── golang.extension
├── golang.toml
├── golang-ci.toml
├── nodejs-devtools.extension
├── nodejs-devtools.toml
│
# Traditional extensions (no TOML - use existing methods)
├── ruby.extension
├── ruby.toml                           # Only if USE_MISE_FOR_RUBY=true
├── php.extension
├── jvm.extension
├── dotnet.extension
├── docker.extension
├── infra-tools.extension
├── infra-tools.toml                    # Partial: only Terraform/kubectl/Helm
├── cloud-tools.extension
├── ai-tools.extension
├── ai-tools.toml                       # Partial: npm/go tools
│
# Utility extensions (no TOML)
├── github-cli.extension
├── claude-config.extension
├── playwright.extension
├── monitoring.extension
├── tmux-workspace.extension
├── agent-manager.extension
└── context-loader.extension
```

**File count**: 25 extensions + ~8 TOML files (Phase 1) + ~8 CI TOMLs = ~41 files
**Current**: 25 .sh.example files
**Increase**: +16 files (+64%)

**Value**: Massively improved maintainability, testability, and user experience

### Summary: Is This Worth Doing?

**Absolutely YES.**

**Costs**:
1. ⚠️ ~16 additional files in repository (+64% file count)
2. ⚠️ Extension manager needs updates for .extension suffix
3. ⚠️ Migration effort to rename all .sh.example files

**Benefits**:
1. ✅ **Zero heredoc complexity** - Real TOML files are cleaner
2. ✅ **IDE validation** - Catch TOML errors before deployment
3. ✅ **CI validation** - Test TOML syntax independently
4. ✅ **User-friendly** - Edit TOML without touching bash
5. ✅ **Template distribution** - Ship configs as project templates
6. ✅ **Better semantics** - `.extension` is clearer than `.sh.example`
7. ✅ **Separation of concerns** - Config (TOML) vs logic (bash)
8. ✅ **Git-friendly** - Cleaner diffs, easier reviews
9. ✅ **Self-documenting** - TOML files explain what they install
10. ✅ **Professional** - Matches patterns in npm (package.json), cargo (Cargo.toml), etc.

**Code Impact**:
- **install()**: Simpler (copy file vs heredoc)
- **remove()**: Simpler (delete one TOML file)
- **Total bash lines**: Actually fewer (no heredoc content)

**The .extension + .toml pair pattern is architecturally superior** and follows best practices from modern package managers.

**Recommendation**: Implement this as part of Phase 0.

### Best Practices for TOML File Handling

#### Preferred: Copy Pre-existing TOML Files

When possible, maintain TOML files in the repository and copy them:

```bash
install() {
  local ext_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local toml_source="$ext_dir/nodejs.toml"
  local toml_dest="$HOME/.config/mise/conf.d/nodejs.toml"

  # Simple copy
  cp "$toml_source" "$toml_dest"
  mise install
}
```

**Benefits**:
- ✅ TOML validated in CI before deployment
- ✅ IDE syntax checking during development
- ✅ Git tracking of TOML changes
- ✅ No runtime string generation

#### When Dynamic Generation is Needed

For CI_MODE conditionals, use `cat` with heredoc (NOT `echo`):

**✅ CORRECT - Use cat with heredoc**:
```bash
install() {
  local toml_dest="$HOME/.config/mise/conf.d/nodejs.toml"

  if [[ "$CI_MODE" == "true" ]]; then
    cat > "$toml_dest" << 'EOF'
[tools]
node = "lts"
# Minimal for CI
EOF
  else
    cat > "$toml_dest" << 'EOF'
[tools]
node = "lts"
"npm:typescript" = "latest"
"npm:eslint" = "latest"
# Full dev environment
EOF
  fi

  mise install
}
```

**❌ WRONG - Don't use echo for multiline TOML**:
```bash
# Bad: Multiple echo commands
echo "[tools]" > "$toml_dest"
echo "node = \"lts\"" >> "$toml_dest"
echo "\"npm:npm\" = \"latest\"" >> "$toml_dest"
# Problems: Escaping hell, harder to read, error-prone
```

**Why cat is better**:
1. ✅ Clean heredoc syntax
2. ✅ No escaping needed with `'EOF'`
3. ✅ Multi-line naturally
4. ✅ Reads like actual TOML
5. ✅ Copy-paste friendly

#### Hybrid Approach: Copy with Fallback

Best of both worlds - copy if file exists, generate if needed:

```bash
install() {
  local ext_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local toml_dest="$HOME/.config/mise/conf.d/nodejs.toml"

  # Try to copy pre-existing TOML
  local toml_source
  if [[ "$CI_MODE" == "true" ]] && [[ -f "$ext_dir/nodejs-ci.toml" ]]; then
    toml_source="$ext_dir/nodejs-ci.toml"
  elif [[ -f "$ext_dir/nodejs.toml" ]]; then
    toml_source="$ext_dir/nodejs.toml"
  fi

  if [[ -n "$toml_source" ]]; then
    # Use pre-existing TOML (preferred)
    cp "$toml_source" "$toml_dest"
  else
    # Fallback: generate via cat (not echo!)
    cat > "$toml_dest" << 'EOF'
[tools]
node = "lts"
EOF
  fi

  mise install
}
```

#### Template Variable Substitution

If TOML needs variables, use cat with variable expansion:

```bash
# Use double quotes for variable expansion
cat > "$toml_dest" << EOF
[tools]
node = "${NODE_VERSION:-lts}"

[env]
NODE_ENV = "${NODE_ENV:-development}"
EOF
```

**Security note**: Use `'EOF'` (single quotes) when no variables needed to prevent accidental expansion.

**Recommendation**:
1. **Primary**: Maintain `.toml` files in repo, copy them
2. **Secondary**: Use `cat` with heredoc for dynamic generation
3. **Never**: Use multiple `echo` commands for TOML generation

## Extension API Changes

### Enhanced `status()` Function

The existing `status()` function will be standardized across all extensions to provide BOM-quality reporting:

```bash
# ============================================================================
# FUNCTION 5: STATUS (Enhanced for BOM)
# ============================================================================
# Check current installation status and provide bill of materials
# Returns: 0 if installed, 1 if not installed
#
# Enhanced Purpose:
# - Show extension metadata (name, version, category)
# - Report installation status (INSTALLED / NOT INSTALLED / PARTIAL)
# - List all tools with versions
# - Provide summary information suitable for auditing
#
# Standard Output Format:
# 1. Extension header (name, version, description, category)
# 2. Installation status
# 3. Tool list with versions
# 4. Configuration details (optional)
#
# Example usage:
#   ./extension.sh.example status
#   extension-manager status nodejs

status() {
  # Header with metadata
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Extension: ${EXT_NAME} v${EXT_VERSION}"
  echo "Description: ${EXT_DESCRIPTION}"
  echo "Category: ${EXT_CATEGORY}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Check installation status
  if ! command_exists primary-tool; then
    echo "Status: ✗ NOT INSTALLED"
    return 1
  fi

  echo "Status: ✓ INSTALLED"
  echo ""

  # List tools and versions
  print_status "Installed tools:"
  # Extension-specific tool listing

  echo ""
  return 0
}
```

**Example Enhanced Status for nodejs**:
```bash
status() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Extension: nodejs v2.0.0"
  echo "Description: Node.js LTS and npm via NVM"
  echo "Category: language"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Load NVM
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  # Check installation
  if ! command_exists node; then
    echo "Status: ✗ NOT INSTALLED"
    return 1
  fi

  echo "Status: ✓ INSTALLED"
  echo ""

  print_status "Version Manager:"
  echo "  • NVM: $(nvm --version 2>/dev/null || echo 'installed')"
  echo ""

  print_status "Language Runtime:"
  echo "  • Node.js: $(node -v)"
  echo "  • npm: v$(npm -v)"
  echo ""

  print_status "Global Packages:"
  npm list -g --depth=0 2>/dev/null | grep -v "npm@" | sed 's/^/  • /'

  return 0
}
```

### No API Version Change

The Extension API remains at **v1.0** - we're enhancing an existing function, not adding new ones.

## Implementation Phases

### Phase 0: Foundation (Weeks 1-2)

**Objective**: Set up mise infrastructure, rename to .extension suffix, create TOML files, and standardize status() output

#### 0.0 Rename Extensions and Create TOML Files (Prerequisite)

**Tasks**:

1. **Rename all .sh.example → .extension**
   ```bash
   # Automated rename
   cd docker/lib/extensions.d
   for file in *.sh.example; do
     base=$(basename "$file" .sh.example)
     git mv "$file" "${base}.extension"
   done
   ```

2. **Create TOML files for Phase 1 extensions**
   ```bash
   # Create nodejs.toml, nodejs-ci.toml
   # Create python.toml, python-ci.toml
   # Create rust.toml, rust-ci.toml
   # Create golang.toml, golang-ci.toml
   # Create nodejs-devtools.toml
   # Create template.toml (example TOML)
   ```

3. **Update extension-manager.sh**
   - Change `*.sh.example` → `*.extension` in all functions
   - Update `get_extension_name()` to handle `.extension` suffix
   - Update activation to copy `.extension` → `.sh`
   - No changes to manifest or activation logic

4. **Update CI workflows**
   - Change `*.sh.example` → `*.extension` in path filters
   - Add TOML validation steps
   - Add extension-TOML pairing verification

5. **Update Dockerfile** (if needed)
   - Ensure `COPY docker/lib/extensions.d/*.toml` includes TOML files
   - Should work automatically with `COPY docker/lib/extensions.d/`

**Deliverables**:
- ✅ All 25 extensions renamed to .extension
- ✅ 5-8 TOML files created for Phase 1 extensions
- ✅ template.toml created
- ✅ extension-manager.sh updated
- ✅ CI workflows updated with TOML validation
- ✅ All tests pass with new file structure

**Testing**:
```bash
# Verify renaming worked
ls -1 docker/lib/extensions.d/*.extension | wc -l  # Should be 25

# Verify TOML files created
ls -1 docker/lib/extensions.d/*.toml               # Should show mise TOMLs

# Test extension-manager still works
cd docker/lib
bash extension-manager.sh list

# Validate all TOML files
for toml in extensions.d/*.toml; do
  python3 -c "import toml; toml.load(open('$toml'))" && echo "✅ $toml"
done
```

#### 0.1 Create `mise-config` Extension

Create `docker/lib/extensions.d/mise-config.extension`:

```bash
#!/bin/bash
# mise-config.sh.example - mise tool version manager
# Extension API v1.0

EXT_NAME="mise-config"
EXT_VERSION="1.0.0"
EXT_DESCRIPTION="mise - polyglot tool version manager"
EXT_CATEGORY="core"

prerequisites() {
  command_exists curl || return 1
  return 0
}

install() {
  # Install mise
  curl https://mise.run | sh

  # Verify installation
  command_exists mise || return 1
  return 0
}

configure() {
  # Add mise to PATH
  if ! grep -q "mise activate" "$HOME/.bashrc"; then
    echo 'eval "$(mise activate bash)"' >> "$HOME/.bashrc"
  fi

  # Create global config
  mkdir -p ~/.config/mise
  cat > ~/.config/mise/config.toml << 'EOF'
[settings]
experimental = true
verbose = false

[tools]
# Global tool defaults
# Add tools here that should be available system-wide
EOF

  return 0
}

validate() {
  command_exists mise || return 1
  mise --version >/dev/null 2>&1 || return 1
  return 0
}

status() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Extension: mise-config v1.0.0"
  echo "Description: mise - polyglot tool version manager"
  echo "Category: core"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if ! command_exists mise; then
    echo "Status: ✗ NOT INSTALLED"
    return 1
  fi

  echo "Status: ✓ INSTALLED"
  echo ""

  print_status "mise Version:"
  echo "  • $(mise --version)"
  echo ""

  print_status "Managed Tools:"
  mise ls | sed 's/^/  • /'

  return 0
}

remove() {
  rm -rf ~/.local/bin/mise
  rm -rf ~/.local/share/mise
  rm -rf ~/.config/mise
  sed -i '/mise activate/d' "$HOME/.bashrc"
  return 0
}
```

#### 0.2 Update Extension Manager

Update `scripts/extension-manager` to support aggregated status reporting:

```bash
# New commands in extension-manager
extension-manager status-all              # Show status for all active extensions
extension-manager status-all --json       # Export as JSON
extension-manager status-all --category language  # Filter by category
```

**Example JSON output**:
```json
{
  "generated": "2025-01-15T10:30:00Z",
  "hostname": "sindri-vm-01",
  "extensions": [
    {
      "name": "nodejs",
      "version": "2.0.0",
      "category": "language",
      "status": "installed",
      "tools": [
        {"name": "nvm", "version": "0.40.3"},
        {"name": "node", "version": "v22.11.0"},
        {"name": "npm", "version": "10.9.0"}
      ]
    }
  ]
}
```

#### 0.3 Standardize status() Output in All Extensions

Create PRs to standardize `status()` output format across all extensions:

**PR 1: Core Infrastructure Extensions**
- mise-config.extension (new)
- workspace-structure.extension
- ssh-environment.extension
- monitoring.extension

**PR 2: Development Tool Extensions**
- github-cli.extension
- nodejs-devtools.extension
- claude-config.extension
- playwright.extension
- agent-manager.extension
- context-loader.extension
- tmux-workspace.extension
- post-cleanup.extension

**PR 3: Language Extensions**
- nodejs.extension
- python.extension
- rust.extension
- golang.extension
- ruby.extension
- php.extension
- jvm.extension
- dotnet.extension

**PR 4: Infrastructure Extensions**
- docker.extension
- infra-tools.extension
- cloud-tools.extension
- ai-tools.extension

Each extension's enhanced `status()` should:
1. Show extension metadata header
2. Display clear installation status
3. List all tools with versions
4. Use consistent formatting (bullets, sections)

**Deliverables**:
- ✅ All extensions renamed from .sh.example to .extension
- ✅ TOML files created for Phase 1 mise-powered extensions
- ✅ mise-config extension created
- ✅ extension-manager.sh updated to handle .extension files
- ✅ extension-manager updated with status-all commands
- ✅ All 25 extensions have standardized status() output
- ✅ CI workflows updated with TOML validation
- ✅ Documentation updated
- ✅ All tests pass with new file structure

### Phase 1: High-Value mise Refactors (Weeks 3-6)

**Objective**: Refactor extensions with 100% mise compatibility

#### 1.1 Refactor `nodejs.sh.example`

**Current**: 377 lines with NVM installation and configuration
**Target**: ~100 lines using mise with conf.d pattern

```bash
install() {
  print_status "Installing Node.js via mise..."

  if ! command_exists mise; then
    print_error "mise is required - install mise-config extension first"
    return 1
  fi

  # Create nodejs mise configuration
  local mise_config_dir="$HOME/.config/mise/conf.d"
  mkdir -p "$mise_config_dir"

  cat > "$mise_config_dir/nodejs.toml" << 'EOF'
[tools]
node = "lts"
"npm:npm" = "latest"

[settings]
legacy_version_file = true  # Support .nvmrc files

[env]
NPM_CONFIG_LOGLEVEL = "warn"
EOF

  # Install all tools from configuration
  if mise install; then
    print_success "Node.js installed: $(node -v)"
  else
    print_error "mise install failed"
    return 1
  fi

  return 0
}

configure() {
  # Keep existing aliases and SSH wrapper logic
  # ... (configuration unchanged)
}

validate() {
  # Use mise to check Node.js
  if ! mise ls node | grep -q "node"; then
    print_error "Node.js not installed via mise"
    return 1
  fi

  command_exists node || return 1
  command_exists npm || return 1

  print_success "node: $(node -v)"
  print_success "npm: v$(npm -v)"
  return 0
}

status() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Extension: nodejs v3.0.0 (mise-powered)"
  echo "Description: Node.js LTS via mise"
  echo "Category: language"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if ! command_exists node; then
    echo "Status: ✗ NOT INSTALLED"
    return 1
  fi

  echo "Status: ✓ INSTALLED"
  echo ""

  print_status "Version Manager:"
  echo "  • mise (managing Node.js)"
  echo ""

  print_status "mise-Managed Tools:"
  mise ls node npm:* | sed 's/^/  • /'
  echo ""

  print_status "Global npm Packages:"
  npm list -g --depth=0 2>/dev/null | grep -v "npm@" | sed 's/^/  • /'

  return 0
}
```

**Testing Strategy**:
1. Create test VM with mise-config + nodejs (mise version)
2. Validate all functionality (install, configure, validate, status)
3. Compare with current nodejs extension output
4. Ensure SSH wrappers work
5. Test in CI mode
6. Benchmark installation time

**Success Criteria**:
- ✅ Node.js installs and runs correctly
- ✅ npm global packages work
- ✅ `node`, `npm`, `npx` commands available
- ✅ SSH wrappers function properly
- ✅ status() shows comprehensive information
- ✅ Installation time ≤ current approach

#### 1.2 Refactor `python.sh.example`

```bash
install() {
  if ! command_exists mise; then
    print_error "mise is required"
    return 1
  fi

  # Create python mise configuration
  local mise_config_dir="$HOME/.config/mise/conf.d"
  mkdir -p "$mise_config_dir"

  cat > "$mise_config_dir/python.toml" << 'EOF'
[tools]
python = "3.13"
"pipx:virtualenv" = "latest"
"pipx:poetry" = "latest"
"pipx:flake8" = "latest"
"pipx:mypy" = "latest"
"pipx:black" = "latest"
"pipx:jupyterlab" = "latest"

[settings]
legacy_version_file = true  # Support .python-version files

[env]
PYTHON_CONFIGURE_OPTS = "--enable-shared"
EOF

  # Install all tools from configuration
  if mise install; then
    print_success "Python installed: $(python3 --version)"
  else
    print_error "mise install failed"
    return 1
  fi

  return 0
}

status() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Extension: python v2.0.0 (mise-powered)"
  echo "Description: Python 3.13 via mise with pipx tools"
  echo "Category: language"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if ! command_exists python3; then
    echo "Status: ✗ NOT INSTALLED"
    return 1
  fi

  echo "Status: ✓ INSTALLED"
  echo ""

  print_status "mise-Managed Tools:"
  mise ls python pipx:* | sed 's/^/  • /'

  return 0
}
```

#### 1.3 Refactor `rust.sh.example`

```bash
install() {
  if ! command_exists mise; then
    print_error "mise is required"
    return 1
  fi

  # Create rust mise configuration
  local mise_config_dir="$HOME/.config/mise/conf.d"
  mkdir -p "$mise_config_dir"

  # Generate config based on CI_MODE
  if [[ "$CI_MODE" == "true" ]]; then
    cat > "$mise_config_dir/rust.toml" << 'EOF'
[tools]
rust = "stable"
# Skip cargo tools in CI to save time and space
EOF
  else
    cat > "$mise_config_dir/rust.toml" << 'EOF'
[tools]
rust = "stable"
"cargo:cargo-watch" = "latest"
"cargo:cargo-edit" = "latest"
"cargo:ripgrep" = "latest"
"cargo:fd-find" = "latest"
"cargo:exa" = "latest"
"cargo:bat" = "latest"
"cargo:tokei" = "latest"

[settings]
legacy_version_file = true  # Support rust-toolchain files
EOF
  fi

  # Install all tools from configuration
  if mise install; then
    print_success "Rust installed: $(rustc --version)"
  else
    print_error "mise install failed"
    return 1
  fi

  return 0
}

status() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Extension: rust v2.0.0 (mise-powered)"
  echo "Description: Rust toolchain via mise"
  echo "Category: language"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if ! command_exists rustc; then
    echo "Status: ✗ NOT INSTALLED"
    return 1
  fi

  echo "Status: ✓ INSTALLED"
  echo ""

  print_status "mise-Managed Tools:"
  mise ls rust cargo:* | sed 's/^/  • /'

  return 0
}
```

#### 1.4 Refactor `golang.sh.example`

```bash
install() {
  if ! command_exists mise; then
    print_error "mise is required"
    return 1
  fi

  # Create golang mise configuration
  local mise_config_dir="$HOME/.config/mise/conf.d"
  mkdir -p "$mise_config_dir"

  # Generate config based on CI_MODE
  if [[ "$CI_MODE" == "true" ]]; then
    cat > "$mise_config_dir/golang.toml" << 'EOF'
[tools]
go = "1.24.6"
# Skip Go tools in CI
EOF
  else
    cat > "$mise_config_dir/golang.toml" << 'EOF'
[tools]
go = "1.24.6"
"go:golang.org/x/tools/gopls@latest" = "latest"
"go:github.com/go-delve/delve/cmd/dlv@latest" = "latest"
"go:golang.org/x/tools/cmd/goimports@latest" = "latest"
"go:github.com/golangci/golangci-lint/cmd/golangci-lint@latest" = "latest"
"go:github.com/air-verse/air@latest" = "latest"
"go:github.com/goreleaser/goreleaser@latest" = "latest"

[settings]
legacy_version_file = true  # Support .go-version files
EOF
  fi

  # Install all tools from configuration
  if mise install; then
    print_success "Go installed: $(go version)"
  else
    print_error "mise install failed"
    return 1
  fi

  return 0
}
```

#### 1.5 Refactor `nodejs-devtools.sh.example`

```bash
install() {
  if ! command_exists mise; then
    print_error "mise is required"
    return 1
  fi

  # Create nodejs-devtools mise configuration
  local mise_config_dir="$HOME/.config/mise/conf.d"
  mkdir -p "$mise_config_dir"

  cat > "$mise_config_dir/nodejs-devtools.toml" << 'EOF'
[tools]
"npm:typescript" = "latest"
"npm:ts-node" = "latest"
"npm:nodemon" = "latest"
"npm:prettier" = "latest"
"npm:eslint" = "latest"
"npm:@typescript-eslint/parser" = "latest"
"npm:@typescript-eslint/eslint-plugin" = "latest"
"npm:goalie" = "latest"

[tasks.format]
description = "Format code with Prettier"
run = "prettier --write ."

[tasks.lint]
description = "Lint code with ESLint"
run = "eslint ."

[tasks.typecheck]
description = "Type check with TypeScript"
run = "tsc --noEmit"
EOF

  # Install all tools from configuration
  if mise install; then
    print_success "Node.js dev tools installed"
  else
    print_error "mise install failed"
    return 1
  fi

  return 0
}
```

**Bonus**: Developers can now run `mise run format`, `mise run lint`, `mise run typecheck`!

**Phase 1 Deliverables**:
- ✅ 5 extensions refactored to use mise
- ✅ ~70% code reduction in install functions
- ✅ All tests passing
- ✅ Documentation updated
- ✅ Backward compatibility maintained

### Phase 2: Hybrid Approach (Weeks 7-10)

**Objective**: Add mise support where feasible, keep existing for edge cases

#### 2.1 Refactor `ruby.sh.example` (Conditional mise)

```bash
install() {
  # Offer choice: rbenv (traditional) or mise (modern)
  local use_mise="${USE_MISE_FOR_RUBY:-false}"

  if [[ "$use_mise" == "true" ]]; then
    if ! command_exists mise; then
      print_error "mise is required for USE_MISE_FOR_RUBY=true"
      return 1
    fi

    # Create ruby mise configuration
    local mise_config_dir="$HOME/.config/mise/conf.d"
    mkdir -p "$mise_config_dir"

    if [[ "$CI_MODE" == "true" ]]; then
      cat > "$mise_config_dir/ruby.toml" << 'EOF'
[tools]
ruby = "3.4"
"gem:bundler" = "latest"
# Skip Rails and dev gems in CI
EOF
    else
      cat > "$mise_config_dir/ruby.toml" << 'EOF'
[tools]
ruby = "3.4"
"gem:bundler" = "latest"
"gem:rails" = "latest"
"gem:rubocop" = "latest"
"gem:rspec" = "latest"
"gem:pry" = "latest"

[settings]
legacy_version_file = true  # Support .ruby-version files
EOF
    fi

    # Install from config
    mise install
  else
    # Existing rbenv installation
    # ... (keep current logic)
  fi

  return 0
}

status() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Extension: ruby v1.0.0"
  echo "Description: Ruby with rbenv or mise"
  echo "Category: language"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if ! command_exists ruby; then
    echo "Status: ✗ NOT INSTALLED"
    return 1
  fi

  echo "Status: ✓ INSTALLED"
  echo ""

  # Detect which version manager is in use
  if mise ls ruby &>/dev/null; then
    print_status "Version Manager:"
    echo "  • mise (managing Ruby)"
    echo ""
    print_status "mise-Managed Tools:"
    mise ls ruby gem:* | sed 's/^/  • /'
  else
    print_status "Version Manager:"
    echo "  • rbenv"
    echo ""
    print_status "Ruby Versions:"
    rbenv versions | sed 's/^/  • /'
  fi

  return 0
}
```

#### 2.2 Refactor `ai-tools.sh.example` (Hybrid)

```bash
install() {
  # Use mise if available, fallback to traditional
  if command_exists mise; then
    print_status "Installing AI tools via mise..."

    local mise_config_dir="$HOME/.config/mise/conf.d"
    mkdir -p "$mise_config_dir"

    cat > "$mise_config_dir/ai-tools.toml" << 'EOF'
[tools]
# npm-based tools
"npm:codex-cli" = "latest"
"npm:@google/gemini-cli" = "latest"

# Go-based tools (if Go is available)
"go:github.com/plandex-ai/plandex@latest" = "latest"
"go:github.com/kadirpekel/hector/cmd/hector@latest" = "latest"

# Binary tools via ubi backend
"ubi:ollama/ollama" = "latest"
"ubi:danielmiessler/fabric" = "latest"
EOF

    # Install from config
    mise install
  else
    # Fallback to traditional installation methods
    print_warning "mise not available, using traditional installation..."

    # npm-based tools
    npm install -g codex-cli @google/gemini-cli

    # Go-based tools (if Go available)
    if command_exists go; then
      go install github.com/plandex-ai/plandex@latest
      go install github.com/kadirpekel/hector/cmd/hector@latest
    fi

    # Binary tools via curl
    # ... (existing curl-based install logic)
  fi

  return 0
}
```

#### 2.3 Refactor `infra-tools.sh.example` (Selective mise)

```bash
install() {
  # Use mise for well-supported infrastructure tools
  if command_exists mise; then
    print_status "Installing infrastructure tools via mise..."

    local mise_config_dir="$HOME/.config/mise/conf.d"
    mkdir -p "$mise_config_dir"

    cat > "$mise_config_dir/infra-tools.toml" << 'EOF'
[tools]
terraform = "latest"
kubectl = "latest"
helm = "latest"

# Optional: k9s via ubi backend if available
"ubi:derailed/k9s" = "latest"
EOF

    # Install mise-managed tools
    mise install
  else
    # Fallback to traditional installation
    # ... (existing Terraform/kubectl/Helm install logic)
  fi

  # Keep current approach for specialized tools not in mise:
  # - Carvel tools (custom install script)
  print_status "Installing Carvel tools (traditional method)..."
  # ... (existing Carvel installation logic)

  # - Crossplane (specialized install)
  print_status "Installing Crossplane CLI (traditional method)..."
  # ... (existing Crossplane installation logic)

  # - Pulumi (has own version management)
  print_status "Installing Pulumi (traditional method)..."
  # ... (existing Pulumi installation logic)

  # - Ansible (apt package)
  print_status "Installing Ansible (apt)..."
  # ... (existing Ansible installation logic)

  return 0
}
```

**Phase 2 Deliverables**:
- ✅ 3 extensions with hybrid mise/traditional support
- ✅ User choice for ruby (rbenv vs mise)
- ✅ Fallback logic for missing mise
- ✅ Tests covering both paths

### Phase 3: Documentation & Tooling (Weeks 11-12)

**Objective**: Complete documentation and enhance BOM reporting

#### 3.1 Update Documentation

- ✅ CLAUDE.md - Add mise usage examples
- ✅ README.md - Update extension system section
- ✅ Extension development guide - Add mise integration patterns
- ✅ Migration guide - For existing Sindri VMs

#### 3.2 Create BOM Report Generator

```bash
#!/bin/bash
# scripts/generate-bom-report.sh
# Generates comprehensive BOM report for Sindri VM

echo "=== Sindri VM Bill of Materials ==="
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo ""

echo "=== System Information ==="
uname -a
df -h / | tail -1
free -h | grep "Mem:"
echo ""

echo "=== mise-Managed Tools ==="
if command_exists mise; then
  mise ls
else
  echo "mise not installed"
fi
echo ""

echo "=== Extension Status Report ==="
extension-manager status-all
```

#### 3.3 Enhance extension-manager

```bash
# New commands
extension-manager doctor              # Check for issues (calls mise doctor if available)
extension-manager upgrade-all         # Upgrade all mise-managed tools
extension-manager status-export       # Export status as JSON
extension-manager status-diff <file>  # Compare current vs previous status
```

**Phase 3 Deliverables**:
- ✅ Complete documentation update
- ✅ Enhanced extension-manager with new commands
- ✅ BOM reporting scripts
- ✅ JSON export capability

## Migration Path for Existing VMs

### Option A: Fresh Deployment
Recommended for new VMs:
1. Deploy with mise-config extension active
2. Use mise-powered extensions from start

### Option B: In-Place Upgrade
For existing VMs:
1. Install mise-config extension
2. Keep existing tools working (don't uninstall NVM, rbenv, etc.)
3. Gradually migrate to mise-powered extensions on next major update
4. Use `extension-manager status-all` to track both old and new tools

### Option C: Parallel Testing
For risk-averse users:
1. Keep existing extensions unchanged
2. Add mise-config as optional extension
3. Users can opt-in via `USE_MISE_FOR_<TOOL>=true` environment variables
4. Example: `USE_MISE_FOR_RUBY=true extension-manager install ruby`

## GitHub Workflows Changes

The mise integration requires updates to CI/CD workflows. See [MISE_WORKFLOWS.md](./MISE_WORKFLOWS.md) for complete details.

### Summary of Workflow Changes

**Phase 0**:
- Add mise-config to extension-tests.yml matrix
- Create new mise-compatibility.yml workflow
- Add status-all validation tests

**Phase 1**:
- Update extension dependencies (depends_on: 'mise-config')
- Add mise verification steps in extension tests
- Create performance comparison workflow

**Phase 2**:
- Add hybrid extension testing (USE_MISE_FOR_<TOOL> env vars)
- Add fallback scenario tests
- Update combination matrices

**Phase 3**:
- Add BOM/status reporting validation
- Create reusable GitHub Actions for mise setup
- Add automated mise upgrade tests

**New Workflows**:
- `.github/workflows/mise-compatibility.yml` - Test mise-specific functionality
- `.github/actions/setup-mise/` - Reusable mise setup action
- `.github/actions/extension-status-report/` - Generate status reports

**Updated Workflows**:
- `extension-tests.yml` - Add mise-config, update matrix with mise flags
- `integration.yml` - Add mise-stack combination testing
- `integration-resilient.yml` - Add mise retry logic

See [MISE_WORKFLOWS.md](./MISE_WORKFLOWS.md) for detailed workflow changes, code examples, and testing strategies.

## Testing Strategy

### Unit Tests
- Each refactored extension has test suite
- Tests cover install, configure, validate, status, remove
- Tests run in both normal and CI_MODE
- **New**: Tests verify mise manages tools correctly

### Integration Tests
- End-to-end tests for common workflows
- Multi-extension dependencies (nodejs + nodejs-devtools)
- SSH wrapper functionality
- mise tool version switching
- **New**: Traditional vs mise coexistence testing
- **New**: Migration path testing (NVM → mise)

### Performance Tests
- Installation time comparison (current vs mise)
- Docker image size comparison
- Tool execution speed (ensure no overhead)
- **New**: Automated performance comparison in CI

### Compatibility Tests
- Existing VMs can install mise-config without breaking
- mise-powered extensions work alongside traditional ones
- Upgrade path from traditional to mise works
- **New**: Hybrid extension testing (USE_MISE_FOR_RUBY etc.)
- **New**: mise registry availability fallback testing

## Rollback Plan

### If Issues Arise in Phase 1
1. Revert mise-powered extensions to v2.x (traditional)
2. Keep mise-config available but optional
3. Document issues and reassess approach
4. Extensions have version tags: v2.x (traditional), v3.x (mise)

### Version Strategy
- **v1.x**: Original extensions (deprecated)
- **v2.x**: Current extensions with enhanced status() (stable)
- **v3.x**: mise-powered extensions (new)

Users can pin to specific versions if needed:
```bash
# Pin nodejs to v2.x (traditional)
extension-manager install nodejs@2.0

# Use newest nodejs v3.x (mise-powered)
extension-manager install nodejs@3.0
```

## Success Metrics

### Code Quality
- [ ] 70-80% reduction in install function LOC for Phase 1 extensions
- [ ] All extensions have standardized status() output
- [ ] CI tests pass with >95% coverage

### User Experience
- [ ] Installation time ≤ current approach (or faster)
- [ ] Single command to see all tool versions: `extension-manager status-all`
- [ ] Clear documentation for mise vs traditional approaches

### Operational
- [ ] Docker image size unchanged or smaller
- [ ] No breaking changes for existing VMs
- [ ] Smooth migration path documented

## Timeline Summary

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Phase 0 | Weeks 1-2 | mise-config extension, standardized status() in all extensions |
| Phase 1 | Weeks 3-6 | 5 core language extensions refactored to mise |
| Phase 2 | Weeks 7-10 | Hybrid mise support in 3 additional extensions |
| Phase 3 | Weeks 11-12 | Documentation, BOM tooling, reporting |

**Total Duration**: ~12 weeks (3 months)

## Next Steps

1. **Review this plan** with stakeholders
2. **Approve Phase 0** to begin work on mise-config and status() standardization
3. **Create GitHub issues** for each phase milestone
4. **Set up test environment** for mise integration testing
5. **Begin implementation** starting with Phase 0

## References

- mise documentation: https://mise.jdx.dev
- mise GitHub: https://github.com/jdx/mise
- Extension API Specification: Extension API v1.0
- Tool inventory: [MISE_STANDARDIZATION.md](./MISE_STANDARDIZATION.md)
