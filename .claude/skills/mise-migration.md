---
name: mise-migration
description: Migrate projects from legacy version managers (NVM, pyenv, rbenv, rustup) to mise with automated configuration generation
---

# Mise Migration Skill

This skill helps migrate projects and systems from legacy version managers to mise, Sindri's unified tool manager.

## What is mise?

mise (https://mise.jdx.dev) is a unified tool version manager that replaces:

- **nvm** (Node.js)
- **pyenv** (Python)
- **rbenv** (Ruby)
- **rustup** (Rust)
- **gvm** (Go)
- And 100+ other tools

**Benefits**:

- Single tool for all language runtimes
- Automatic version switching per directory
- Faster than shell-based managers (written in Rust)
- Cross-platform (Linux, macOS, Windows)
- Per-project configuration
- Global fallback versions
- Plugin ecosystem

## Migration Scenarios

### 1. Project Migration

Migrate a project from legacy version managers to mise configuration.

**Detected Files**:

- `.nvmrc` (Node.js)
- `.node-version` (Node.js)
- `.python-version` (Python)
- `.ruby-version` (Ruby)
- `rust-toolchain` or `rust-toolchain.toml` (Rust)
- `.go-version` (Go)

**Migration Steps**:

```bash
# Scan project for version files
find . -maxdepth 2 -name ".nvmrc" -o -name ".python-version" -o -name ".ruby-version"

# Extract versions
NODE_VERSION=$(cat .nvmrc 2>/dev/null || cat .node-version 2>/dev/null)
PYTHON_VERSION=$(cat .python-version 2>/dev/null)
RUBY_VERSION=$(cat .ruby-version 2>/dev/null)

# Generate mise.toml
cat > mise.toml << EOF
[tools]
node = "${NODE_VERSION}"
python = "${PYTHON_VERSION}"
ruby = "${RUBY_VERSION}"

[env]
# Add project-specific environment variables here
EOF

# Install tools
mise install

# Verify
mise ls
```

### 2. System Migration

Migrate from system-level version managers to mise.

**From NVM to mise**:

```bash
# Check current NVM version
nvm current

# List all installed Node versions
nvm list

# Install equivalent versions with mise
nvm list | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | while read version; do
  mise use "node@${version#v}"
done

# Set global default
mise use --global "node@$(nvm current | sed 's/v//')"

# Verify
mise ls node

# Optional: Remove NVM
# rm -rf ~/.nvm
# Remove NVM lines from ~/.bashrc or ~/.zshrc
```

**From pyenv to mise**:

```bash
# List installed Python versions
pyenv versions

# Install with mise
pyenv versions --bare | while read version; do
  mise use "python@$version"
done

# Set global default
mise use --global "python@$(pyenv global)"

# Verify
mise ls python

# Optional: Remove pyenv
# rm -rf ~/.pyenv
# Remove pyenv lines from shell config
```

**From rbenv to mise**:

```bash
# List installed Ruby versions
rbenv versions

# Install with mise
rbenv versions --bare | while read version; do
  mise use "ruby@$version"
done

# Set global
mise use --global "ruby@$(rbenv global)"

# Verify
mise ls ruby

# Optional: Remove rbenv
# rm -rf ~/.rbenv
```

**From rustup to mise**:

```bash
# Check current Rust version
rustc --version

# Install with mise
mise use --global rust@stable

# Verify
mise ls rust

# Optional: Remove rustup
# rustup self uninstall
```

### 3. Generate mise.toml for New Project

Create a mise.toml configuration from scratch:

**Interactive Mode**:

```bash
# Initialize mise in project
cd /path/to/project

# Create configuration interactively
cat > mise.toml << 'EOF'
[tools]
# Specify tool versions
node = "20"              # Node.js LTS
python = "3.11"          # Python 3.11
go = "1.21"              # Go 1.21
rust = "stable"          # Latest stable Rust

# Optional: npm global packages via mise
# typescript = "npm:typescript@latest"
# eslint = "npm:eslint@latest"

[env]
# Project-specific environment variables
NODE_ENV = "development"
# DATABASE_URL = "postgres://localhost/mydb"

[tasks]
# Define project tasks (mise run task-name)
# dev = "npm run dev"
# test = "npm test"
# build = "npm run build"

[plugins]
# Custom plugins if needed
# my-tool = "https://github.com/user/mise-my-tool"
EOF

# Install tools
mise install

# Activate in current shell
eval "$(mise activate bash)"  # or zsh

# Verify
mise ls
```

**Common Configurations**:

```toml
# Node.js + TypeScript project
[tools]
node = "20"
typescript = "npm:typescript@latest"
eslint = "npm:eslint@latest"

# Python data science project
[tools]
python = "3.11"

[env]
PYTHONPATH = "src"

# Go project
[tools]
go = "1.21"
golangci-lint = "1.55"

# Rust project
[tools]
rust = "stable"

# Full-stack project
[tools]
node = "20"
python = "3.11"
go = "1.21"
terraform = "1.6"
```

## Migration Validation

**Check Tool Availability**:

```bash
# Verify all tools are available
mise doctor

# Test version switching
cd project-with-mise-toml
node --version  # Should match mise.toml
python --version  # Should match mise.toml

# Check environment
mise env

# View active configuration
mise current
```

**Common Issues**:

1. **Tool Not Switching**:
   - Ensure shell activation: `eval "$(mise activate bash)"`
   - Check mise.toml syntax
   - Verify in correct directory

2. **Command Not Found**:
   - Run `mise install` to install tools
   - Check PATH includes mise shims
   - Verify mise is activated in shell

3. **Version Conflict**:
   - Old version manager still in PATH
   - Remove old manager from shell config
   - Restart shell or re-source config

## Shell Integration

**Bash** (`~/.bashrc`):

```bash
# mise activation
eval "$(mise activate bash)"

# Optional: mise completions
eval "$(mise completion bash)"
```

**Zsh** (`~/.zshrc`):

```bash
# mise activation
eval "$(mise activate zsh)"

# Optional: mise completions
eval "$(mise completion zsh)"
```

**Fish** (`~/.config/fish/config.fish`):

```fish
# mise activation
mise activate fish | source

# Optional: mise completions
mise completion fish | source
```

## Advanced Features

### Per-Directory Tool Versions

```bash
# Global defaults
mise use --global node@20 python@3.11

# Project-specific (creates/updates mise.toml)
cd my-project
mise use node@18 python@3.9

# Automatically switches when entering directory
cd my-project
node --version  # 18.x.x
cd ..
node --version  # 20.x.x (global)
```

### Environment Variables

```toml
# In mise.toml
[env]
DATABASE_URL = "postgres://localhost/mydb"
API_KEY = { file = ".env.local" }
PATH = ["./node_modules/.bin", "$PATH"]
```

### Task Runner

```toml
# In mise.toml
[tasks]
dev = "npm run dev"
test = "npm test"
build = "npm run build"
deploy = { run = "./scripts/deploy.sh", depends = ["build"] }
```

```bash
# Run tasks
mise run dev
mise run test
mise run deploy
```

### Tool Aliases

```bash
# Create version alias
mise alias set node lts 20
mise use node@lts

# List aliases
mise alias ls
```

## Sindri-Specific Migration

### Extension Migration

For Sindri extensions using legacy version managers:

**Before** (NVM-based):

```bash
# In nodejs extension
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install --lts
nvm use --lts
```

**After** (mise-based):

```bash
# Depends on mise-config extension
check_extension_installed "mise-config"

# Install Node.js via mise
mise use --global node@20

# Verify
mise list node
```

### Global Configuration

Sindri's global mise config (`~/.config/mise/config.toml`):

```toml
[tools]
# Global tool versions (fallback when no projet config)
node = "20"
python = "3.11"
go = "1.21"
rust = "stable"

[settings]
# mise settings
experimental = true
legacy_version_file = true  # Support .nvmrc, .python-version, etc.
```

## Migration Checklist

- [ ] Identify current version managers in use
- [ ] List all installed tool versions
- [ ] Install mise (via mise-config extension)
- [ ] Create mise.toml in projects
- [ ] Install tools via mise
- [ ] Activate mise in shell
- [ ] Verify version switching works
- [ ] Update CI/CD to use mise
- [ ] Remove old version managers
- [ ] Update documentation

## Comparison Table

| Feature | NVM | pyenv | rbenv | rustup | mise |
|---------|-----|-------|-------|--------|------|
| Node.js | ✓ | ✗ | ✗ | ✗ | ✓ |
| Python | ✗ | ✓ | ✗ | ✗ | ✓ |
| Ruby | ✗ | ✗ | ✓ | ✗ | ✓ |
| Rust | ✗ | ✗ | ✗ | ✓ | ✓ |
| Go | ✗ | ✗ | ✗ | ✗ | ✓ |
| 100+ tools | ✗ | ✗ | ✗ | ✗ | ✓ |
| Auto-switch | ✗ | ✓ | ✓ | ✓ | ✓ |
| Performance | Slow | Medium | Medium | Fast | Fast |
| Written in | Bash | Python | Bash | Rust | Rust |

## Resources

- mise documentation: https://mise.jdx.dev
- mise GitHub: https://github.com/jdx/mise
- Sindri mise-config extension: `docker/lib/extensions.d/mise-config/`
- Supported tools registry: https://mise.jdx.dev/registry.html

## Quick Reference

```bash
# Install tool
mise use node@20

# Install all tools from mise.toml
mise install

# List installed tools
mise ls

# List available versions
mise ls-remote node

# Update tools
mise upgrade

# Uninstall version
mise uninstall node@18

# Show current versions
mise current

# Check for issues
mise doctor

# Clear cache
mise cache clear

# View config
mise config

# Get help
mise help
```

This skill helps transition smoothly from legacy version managers to mise's unified approach.
