# CLAUDE.md

Project-specific guidance for Claude Code when working with this repository.

## Project Overview

Sindri is a complete AI-powered cloud development forge running on Fly.io infrastructure. It provides cost-optimized,
secure virtual machines with persistent storage for AI-assisted development without requiring local installation.
Like the legendary Norse blacksmith, Sindri forges powerful development environments from cloud infrastructure,
AI tools, and developer workflows.

## Development Commands

### VM Management

```bash
./scripts/vm-setup.sh --app-name <name>  # Deploy new VM
./scripts/vm-suspend.sh                  # Suspend to save costs
./scripts/vm-resume.sh                   # Resume VM
./scripts/vm-teardown.sh                 # Remove VM and volumes
flyctl status -a <app-name>             # Check VM status

# CI/Testing deployment (disables SSH daemon, health checks)
CI_MODE=true ./scripts/vm-setup.sh --app-name <test-name>
flyctl deploy --strategy immediate --wait-timeout 60s  # Skip health checks
```

### On-VM Commands

```bash
extension-manager list                            # List available extensions
extension-manager --interactive                   # Interactive extension setup
extension-manager install <name>                  # Install specific extension
extension-manager install-all                     # Install all active extensions
claude                                            # Authenticate Claude Code
npx claude-flow@alpha init --force               # Initialize Claude Flow in project
new-project <name> [--type <type>]               # Create new project with enhancements
clone-project <url> [options]                    # Clone and enhance repository
```

## Key Directories

### User Workspace (developer-owned, writable)

- `/workspace/developer/` - Developer home directory (persistent)
- `/workspace/scripts/` - User scripts and extension-generated helpers
- `/workspace/projects/active/` - Active development projects
- `/workspace/config/` - User configuration files
- `/workspace/bin/` - User binaries (in PATH)
- `/workspace/docs/` - Workspace-wide documentation

### System Directories (managed by Sindri)

- `/docker/lib/` - System libraries and extension definitions (immutable, from Docker image)
- `/docker/lib/extensions.d/` - Extension definitions and templates
- `/workspace/.system/` - System runtime files (do not modify directly)
  - `bin/` - System binaries (symlinked to /docker)
  - `lib/` - System libraries (symlinked to /docker)
  - `manifest/` - Extension activation configuration

All user data in `/workspace` persists between VM restarts. System files in `/docker` are immutable
and updated only via Docker image rebuilds. The `.system/` directory uses symlinks for efficiency.

## Development Workflow

### Daily Tasks

1. Connect via SSH: `ssh developer@<app-name>.fly.dev -p 10022`
   - Alternative: `flyctl ssh console -a <app-name>` (uses Fly.io's hallpass service)
2. Work in `/workspace/` (all data persists)
3. VM auto-suspends when idle
4. VM auto-resumes on next connection

### Project Creation

```bash
# New project
new-project my-app --type node

# Clone existing
clone-project https://github.com/user/repo --feature my-feature

# Both automatically:
# - Create CLAUDE.md context
# - Initialize Claude Flow
# - Install dependencies
```

## Extension System (v1.0)

Sindri uses a manifest-based extension system to manage development tools and environments.

### Extension Management

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

# Validate extension installation
extension-manager validate <name>

# Validate all installed extensions
extension-manager validate-all

# Uninstall extension
extension-manager uninstall <name>

# Reorder extension priority
extension-manager reorder <name> <position>

# Upgrade commands (Extension API v2.0)
extension-manager upgrade <name>         # Upgrade specific extension
extension-manager upgrade-all            # Upgrade all extensions
extension-manager upgrade-all --dry-run  # Preview upgrades
extension-manager check-updates          # Check for updates
extension-manager upgrade-history        # View upgrade history
```

### Automatic Dependency Resolution (Extension API v2.2)

Extensions automatically install their dependencies without manual intervention:

```bash
# Example: Install openskills (requires nodejs + git)
extension-manager install openskills
# → Auto-installs nodejs first
# → Auto-installs git
# → Installs openskills

# Show dependency tree without installing
extension-manager resolve playwright
# Output: nodejs, playwright
```

**Dependency Graph:**

- `openskills` → nodejs, git
- `monitoring` → python
- `playwright` → nodejs
- `nodejs-devtools` → nodejs

**How It Works:**

1. System detects `EXT_DEPENDENCIES` metadata from extension files
2. Builds dependency graph with cycle detection
3. Performs topological sort to determine install order
4. Adds all dependencies to manifest in correct order
5. Installs dependencies first, then target extension

**Benefits:**

- No manual dependency management required
- Prevents "missing prerequisite" errors
- Ensures correct installation order
- Automatically updates manifest

### Available Extensions

**Baked Base System (Pre-installed in Docker Image):**

The following components are pre-installed in every Sindri instance:

- **Workspace Structure** - `/workspace` directory layout (projects/, scripts/, config/, etc.)
- **mise** - Unified tool version manager for Node.js, Python, Rust, Go, Ruby
- **SSH Environment** - Non-interactive session support for CI/CD workflows
- **Claude Code** - AI-powered development CLI with global preferences
- **SOPS + age** - Transparent secrets management with automatic encryption

These are baked into the Docker image for faster startup (~10s vs ~90-120s) and improved reliability.

**Foundational Languages:**

- `nodejs` - Node.js LTS via mise with npm (recommended - many tools depend on it)
- `python` - Python 3.13 via mise with pip, venv, uv, pipx

**Claude AI Extensions:**

- `claude-auth-with-api-key` - Claude Code authentication via API key (optional - for API key users only, not Pro/Max)
- `claude-marketplace` - YAML-based marketplace configuration for Claude Code
- `openskills` - OpenSkills CLI for managing Claude Code skills from Anthropic's marketplace (requires nodejs, git)
- `nodejs-devtools` - TypeScript, ESLint, Prettier, nodemon, goalie (requires nodejs)

**Additional Languages:**

- `rust` - Rust toolchain with cargo, clippy, rustfmt (mise-powered)
- `golang` - Go 1.24 with gopls, delve, golangci-lint (mise-powered)
- `ruby` - Ruby 3.4.7 via mise with Rails, Bundler (mise-powered)

**Development Tools:**

- `github-cli` - GitHub CLI authentication and workflow configuration
- `php` - PHP 8.4 with Composer, Symfony CLI
- `jvm` - SDKMAN with Java, Kotlin, Scala, Maven, Gradle
- `dotnet` - .NET SDK 9.0/8.0 with ASP.NET Core

**Infrastructure:**

- `docker` - Docker Engine with compose, dive, ctop
- `infra-tools` - Terraform, Ansible, kubectl, Helm
- `cloud-tools` - AWS, Azure, GCP, Oracle, DigitalOcean CLIs
- `ai-tools` - AI coding assistants (Codex, Gemini, Ollama, etc.)

**Monitoring & Utilities:**

- `monitoring` - System monitoring tools
- `tmux-workspace` - Tmux session management
- `playwright` - Browser automation testing
- `agent-manager` - Claude Code agent management
- `context-loader` - Context system for Claude

### Activation Manifest

Extensions are defined in the Docker image at `/docker/lib/extensions.d/`. Your active extensions are
configured in `/workspace/.system/manifest/active-extensions.conf`, which is initialized from
`docker/lib/extensions.d/active-extensions.conf.example` (development) or `active-extensions.ci.conf` (CI mode).

Example manifest:

```bash
# Base system (pre-installed in Docker image, always available):
# - Workspace structure (/workspace directories)
# - mise (tool version manager)
# - SSH environment (non-interactive session support)
# - Claude Code CLI

# Foundational languages
nodejs
python

# Additional language runtimes
golang
rust

# Infrastructure tools
docker
infra-tools
```

### Extension API

Each extension implements 6 standard functions (API v1.0) or 7 functions (API v2.0):

- `prerequisites()` - Check system requirements
- `install()` - Install packages and tools
- `configure()` - Post-install configuration
- `validate()` - Run smoke tests
- `status()` - Check installation state
- `remove()` - Uninstall and cleanup
- `upgrade()` - Upgrade installed tools (API v2.0+)

#### DNS Checks (API v2.1+)

Extensions can declare required domains via the `EXT_REQUIRED_DOMAINS` metadata field:

```bash
EXT_REQUIRED_DOMAINS="example.com github.com registry.npmjs.org"
```

These domains are:

- Automatically checked in `prerequisites()` via `check_required_domains()` helper
- Aggregated and checked once upfront during `extension-manager install-all`
- Used to provide clear DNS error messages before installation attempts

Extensions without external domain dependencies can simply omit this field

### Node.js Development Stack

Sindri provides multiple extensions for Node.js development:

**nodejs** (Core - mise-powered):

```bash
extension-manager install nodejs
```

Provides:

- Node.js LTS via mise (replaces NVM)
- Multiple Node version support
- npm with user-space global packages
- No sudo required for global installs
- Per-project version management via mise.toml

**nodejs-devtools** (Optional - mise-powered):

```bash
extension-manager install nodejs-devtools
```

Provides:

- TypeScript (`tsc`, `ts-node`)
- ESLint with TypeScript support
- Prettier code formatter
- nodemon for auto-reload
- goalie AI research assistant
- Tools managed via mise npm plugin

**claude-auth-with-api-key** (Optional - API key users only):

```bash
extension-manager install claude-auth-with-api-key
```

Provides:

- API key authentication for Claude Code CLI
- Automatic configuration using encrypted secrets (ANTHROPIC_API_KEY)
- **Not needed** if you authenticate via Pro or Max subscription
- **Only for users** who authenticate with an API key

Note: Claude Code CLI is pre-installed in the base image. This extension only handles API key authentication.

**claude-marketplace** (Optional):

```bash
extension-manager install claude-marketplace
```

Provides:

- YAML-based marketplace configuration integrated with settings.json
- Automated plugin installation via Claude Code's official mechanism
- Curated collection of high-quality Claude Code marketplaces
- Support for GitHub, Git, and local marketplace sources

Common workflow:

```bash
# Copy template and customize
cp /workspace/config/marketplaces.yml.example /workspace/config/marketplaces.yml
vim /workspace/config/marketplaces.yml

# Install extension (processes YAML → settings.json)
extension-manager install claude-marketplace

# Invoke Claude (automatic marketplace and plugin installation)
claude

# List installed plugins
claude /plugin list

# Check status
extension-manager status claude-marketplace
```

Curated marketplaces in `marketplaces.yml.example`:

- `beads-marketplace` (steveyegge/beads) - Natural language programming
- `cc-blueprint-toolkit` (croffasia/cc-blueprint-toolkit) - Project scaffolding templates
- `claude-equity-research-marketplace` (quant-sentiment-ai/claude-equity-research) - Financial analysis
- `n8n-mcp-skills` (czlonkowski/n8n-skills) - Workflow automation integration
- `life-sciences` (anthropics/life-sciences) - Life sciences research plugins
- `awesome-claude-skills` (ComposioHQ/awesome-claude-skills) - Community-curated skills collection

Configuration format:

```yaml
extraKnownMarketplaces:
  marketplace-name:
    source:
      source: github
      repo: owner/repository

enabledPlugins:
  plugin-name@marketplace-name: true
```

**openskills** (Optional):

```bash
extension-manager install openskills
```

Provides:

- OpenSkills CLI (`openskills` command, aliased as `skills`)
- Install and manage Claude Code skills from Anthropic's marketplace
- Progressive skill disclosure (loads instructions only when needed)
- SKILL.md format support with YAML frontmatter
- Skills installed to ~/.openskills/

Common commands:

```bash
# Install skills from Anthropic's marketplace (interactive)
openskills install anthropics/anthropic-skills-marketplace

# List installed skills
openskills list

# Sync skills to AGENTS.md
openskills sync

# Read skill content for agents
openskills read <skill-name>

# Remove skills interactively
openskills manage
```

Shell aliases available:

- `skills` - Short alias for openskills
- `skill-install` - Install skills
- `skill-list` - List skills
- `skill-sync` - Sync to AGENTS.md
- `skill-marketplace` - Quick install from Anthropic's marketplace

**Typical Setup**:

```bash
# Edit manifest to activate desired extensions (auto-created on first boot)
# /workspace/.system/manifest/active-extensions.conf

# Then install all at once
extension-manager install-all

# Or use interactive mode
extension-manager --interactive
```

## mise Tool Manager

Sindri uses **mise** (https://mise.jdx.dev) for unified tool version management across multiple languages and runtimes.
mise provides a single, consistent interface for managing Node.js, Python, Rust, Go, Ruby, and their associated tools,
replacing multiple version managers (NVM, pyenv, rbenv, rustup, etc.) with one tool.

**Note:** mise is pre-installed in the Docker image and is always available.
It does not need to be installed manually.

### mise-Managed Extensions

The following extensions use mise for tool installation and version management (mise is pre-installed):

- **nodejs**: Node.js LTS via mise (replaces NVM)
  - Manages Node.js versions
  - npm package manager
  - Per-project version configuration

- **python**: Python 3.13 + pipx tools via mise
  - Python runtime versions
  - pipx-installed tools (uv, black, ruff, etc.)
  - Virtual environment support

- **rust**: Rust stable + cargo tools via mise
  - Rust toolchain versions
  - Cargo package manager
  - Development tools (clippy, rustfmt)

- **golang**: Go 1.24 + go tools via mise
  - Go language versions
  - Go toolchain utilities
  - Development tools (gopls, delve, golangci-lint)

- **ruby**: Ruby 3.4.7 + Rails + gems via mise
  - Ruby runtime versions
  - gem and bundle package managers
  - Rails framework (development mode only)
  - Development gems (rubocop, rspec, pry, etc.)

- **nodejs-devtools**: npm global tools via mise
  - TypeScript, ESLint, Prettier
  - nodemon, goalie
  - Managed via mise npm plugin

### Common mise Commands

```bash
# List all installed tools and versions
mise ls

# List versions of a specific tool
mise ls node
mise ls python
mise ls rust
mise ls go
mise ls ruby

# Install or switch tool versions
mise use node@20          # Switch to Node.js 20
mise use python@3.11      # Switch to Python 3.11
mise use rust@stable      # Switch to stable Rust
mise use go@1.24          # Switch to Go 1.24
mise use ruby@3.4.7       # Switch to Ruby 3.4.7

# Update all tools to latest versions
mise upgrade

# Check for configuration issues
mise doctor

# View current environment
mise env

# Install tools from mise.toml
mise install

# Uninstall a tool version
mise uninstall node@18
```

### Per-Project Tool Versions

Create a `mise.toml` file in your project root to specify tool versions:

```toml
[tools]
node = "20"
python = "3.11"
rust = "1.75"
go = "1.24"

[env]
NODE_ENV = "development"
```

mise automatically switches to the specified versions when you enter the directory:

```bash
# Create project with specific versions
cd /workspace/projects/active/my-project
cat > mise.toml << 'EOF'
[tools]
node = "20"
python = "3.11"

[env]
NODE_ENV = "production"
EOF

# mise automatically detects and switches versions
node --version    # v20.x.x
python --version  # Python 3.11.x
```

### Benefits of mise

- **Unified Interface**: One tool for all language runtimes
- **Automatic Switching**: Changes versions based on directory
- **Fast**: Written in Rust, faster than shell-based managers
- **Cross-Platform**: Works on Linux, macOS, Windows
- **Per-Project Config**: Each project defines its own versions
- **Global Fallback**: Global versions used when no project config exists
- **Plugin Ecosystem**: Supports 100+ tools via plugins
- **Backwards Compatible**: Works with .nvmrc, .python-version, etc.

## Testing and Validation

No specific test framework enforced - check each project's README for:

- Test commands (npm test, pytest, go test, etc.)
- Linting requirements
- Build processes

Always run project-specific linting/formatting before commits.

## CI/CD & GitHub Actions

Sindri uses a unified GitHub Actions workflow for automated testing with a sequential, fail-fast testing strategy.

### Unified Integration Testing Architecture

**Single Entry Point**: All CI/CD testing flows through `integration.yml`, which
orchestrates 6 sequential phases with controlled concurrency (max 3 jobs).

**Sequential Execution Flow**:

```text
quick-checks (inline, fail-fast ✗)
    ↓
manifest-validation (static, fail-fast ✗)
    ↓
dependency-chain (3 VMs, fail-fast ✗)
    ↓
infrastructure (1 VM, fail-fast ✗)
    ↓
individual-extensions (N VMs, 3 max concurrent, fail-after-all-complete ⚠)
    ↓
extension-combinations (N VMs, 3 max concurrent, fail-after-all-complete ⚠)
```

**Legend**:

- ✗ = Fail immediately, stop entire workflow
- ⚠ = Let all running jobs complete, then fail workflow

### Testing Phases

#### Phase 1: Quick Checks (2-5 minutes, inline)

- Shellcheck validation for all shell scripts
- YAML syntax validation for workflows and actions
- Extension manager syntax check
- Fails immediately on any validation error

#### Phase 2: Manifest Validation (2 minutes, no VM)

- Static validation of extension syntax
- Static dependency chain verification (files exist)
- Manifest template validation
- Extension metadata validation
- Fails immediately if validation errors found

#### Phase 2.5: Dependency Chain Tests (3-5 minutes, max 3 VMs)

- Runtime testing of automatic dependency resolution
- Tests: nodejs-devtools→nodejs, openskills→nodejs+git, playwright→nodejs
- Verifies extension manager automatically installs dependencies
- Fails immediately if dependency resolution broken

#### Phase 3: Infrastructure Tests (5-7 minutes, 1 VM)

- VM deployment and configuration (minimal tier: 1GB/1CPU)
- SSH connectivity verification
- Volume mount and persistence testing
- Auto-suspend functionality
- Secrets management (SOPS + age)
- Basic developer workflow validation
- Fails immediately if infrastructure issues found

#### Phase 4: Individual Extensions (15-20 minutes, N VMs, 3 max concurrent)

- Matrix of all 20+ extensions
- Each extension runs complete test suite:
  - Installation with dependencies
  - Validation
  - API compliance (validate, status functions)
  - Key functionality testing
  - Idempotency verification
  - Upgrade functionality (API v2.0+)
- Tier-based resources (minimal/standard/heavy/xheavy)
- **Fail behavior**: Let all running jobs complete before failing

#### Phase 5: Extension Combinations (10-12 minutes, N VMs, 3 max concurrent)

- Multi-extension scenario testing
- Common stacks: mise-stack, full-node, fullstack, systems, enterprise, ai-dev
- Performance tier resources (16GB/4CPU)
- **Fail behavior**: Let all running jobs complete before failing

### Main Workflow

**Integration Tests (`integration.yml`)**

- Single entry point for all CI/CD testing
- Runs on: push to main/develop, pull requests, weekly schedule (Saturday 2:00 AM UTC)
- Orchestrates 5 sequential phases with controlled concurrency
- Provides comprehensive test summary at the end
- Location: `.github/workflows/integration.yml`

### Reusable workflow_call Workflows

**Manifest Validation (`manifest-validation.yml`)**

- Static validation without VM deployment
- Called by integration.yml after quick-checks
- Location: `.github/workflows/manifest-validation.yml`

**Dependency Chain Tests (`dependency-chain-tests.yml`)**

- Runtime testing of automatic dependency resolution
- Tests 3 representative dependency chains with max 3 concurrent VMs
- Verifies extension manager auto-installs dependencies
- Called by integration.yml after manifest-validation
- Location: `.github/workflows/dependency-chain-tests.yml`

**Infrastructure Tests (`infrastructure-tests.yml`)**

- Single VM for infrastructure validation
- Consolidates: VM deployment, SSH, volumes, persistence, secrets, mise-stack
- Called by integration.yml after manifest-validation
- Location: `.github/workflows/infrastructure-tests.yml`

**Per-Extension Tests (`per-extension-tests.yml`)**

- Matrix of all extensions with complete test suite
- Max 3 concurrent extension tests
- Called by integration.yml after infrastructure tests
- Location: `.github/workflows/per-extension-tests.yml`

**Extension Combinations (`extension-combinations.yml`)**

- Multi-extension scenario testing
- Max 3 concurrent combinations
- Called by integration.yml after individual extensions
- Location: `.github/workflows/extension-combinations.yml`

**Validation (`validate.yml`)**

- Shell script validation with shellcheck
- YAML syntax validation
- Docker build validation
- Security scanning (Trivy, GitLeaks)
- Location: `.github/workflows/validate.yml`

**Documentation Linting (`test-documentation.yml`)**

- Markdown file linting with markdownlint
- Validates formatting and style consistency across all .md files
- Runs on PR changes to markdown files
- Location: `.github/workflows/test-documentation.yml`

**Release (`release.yml`)**

- Automated release creation
- Changelog generation
- Version tagging
- Location: `.github/workflows/release.yml`

**Build Docker Images (`build-image.yml`)**

- Builds and pushes Docker images to Fly.io registry
- Automatic triggers on Dockerfile/docker/\* changes
- Tags: PR-specific, branch-specific, and latest
- Enables ~75% faster CI/CD by reusing images
- Location: `.github/workflows/build-image.yml`

### Concurrency Control

**Maximum 3 Jobs Concurrent**:

- Quick checks, manifest validation, infrastructure: Run sequentially (1 job at a time)
- Individual extensions: Max 3 extensions tested concurrently
- Extension combinations: Max 3 combinations tested concurrently
- **Result**: Controlled resource usage, predictable cost

**Fail-Fast Behavior**:

- Early phases (quick-checks, manifest-validation, infrastructure): Stop immediately on failure
- Extension phases (individual-extensions, extension-combinations): Let all running jobs
  complete before failing
- **Benefit**: Save CI time on early failures, get complete results for extension testing

### Weekly Scheduled Testing

The unified integration workflow runs weekly on Saturday at 2:00 AM UTC, ensuring regular
quality gates without slowing down daily development.

### Pre-Built Docker Images

Sindri uses pre-built Docker images to dramatically improve CI/CD performance:

**Setup (First-Time Only)**:

```bash
# Create registry app (one-time setup)
flyctl apps create sindri-registry --org personal
```

**How It Works**:

- Images are built once and reused across all test jobs
- Automatic rebuilding when Dockerfile or docker/\* files change
- Conditional reuse when no Docker changes detected
- ~75% reduction in workflow execution time

**Image Tags**:

- Pull Requests: `registry.fly.io/sindri-registry:pr-<number>-<sha>`
- Branch Builds: `registry.fly.io/sindri-registry:<branch>-<sha>`
- Latest (main): `registry.fly.io/sindri-registry:latest`

**Performance Impact**:

- Integration Tests: 15min → 4min (**73% faster**)
- Extension Tests: 45min → 12min (**73% faster**)
- Per-Extension Tests: 6min → 1.5min (**75% faster**)

**Documentation**:

- Setup Guide: `docs/PREBUILT_IMAGES_SETUP.md`
- Architecture: `.github/actions/build-push-image/README.md`

### Composite Actions

Reusable workflow components in `.github/actions/`:

**Infrastructure Actions:**

- `setup-fly-test-env/` - Complete test environment setup
- `deploy-fly-app/` - Fly.io app deployment with retry logic and pre-built image support
- `build-push-image/` - Build and push Docker images to Fly registry
- `wait-fly-deployment/` - Wait for deployment completion
- `cleanup-fly-app/` - Cleanup test resources

**Test Actions:**

- `test-ssh-connectivity/` - Verify SSH access via Fly.io hallpass
- `test-vm-configuration/` - Validate VM setup and resources
- `test-volume-mount/` - Verify volume mount and permissions
- `test-volume-persistence/` - Validate data persistence across restarts
- `test-machine-lifecycle/` - Test auto-suspend/resume functionality

**Extension Test Actions (NEW):**

- `test-extension-complete/` - Complete extension test suite (API + integration)
- `install-extension/` - Install extension with dependencies
- `upload-test-libs/` - Upload shared test libraries to VM

**Utilities:**

- `run-vm-script/` - Execute scripts on VM via SSH

### Test Scripts

Organized by concern in `.github/scripts/`:

**Shared Libraries (`lib/`):**

- `test-helpers.sh` - 20+ utility functions (environment, commands, extension manager)
- `assertions.sh` - 10+ test assertion functions
- `ssh-helpers.sh` - SSH/SFTP utilities with retry logic
- `retry-utils.sh` - Retry and backoff utilities

**Infrastructure Tests (`infrastructure/`):**

- `test-vm-deployment.sh` - VM, SSH, volumes, extension system (consolidated)
- `test-secrets-management.sh` - SOPS + age encryption testing
- `verify-volume.sh` - Volume mount verification

**Extension Tests (`extensions/`):**

- `test-extension-complete.sh` - Complete test suite (API + integration + idempotency)
- `verify-commands.sh` - Command availability checks
- `test-key-functionality.sh` - Tool-specific functionality tests (30+ tools)

**Validation (`validation/`):**

- `verify-manifest.sh` - Manifest validation
- `check-syntax.sh` - Extension syntax validation
- `verify-dependencies.sh` - Dependency chain validation
- `setup-manifest.sh` - Manifest setup utilities

### Documentation

For detailed information about workflows and testing:

- `.github/actions/README.md` - Composite actions usage guide
- `.github/scripts/extension-tests/README.md` - Test scripts reference

## Agent Configuration

Agents extend Claude's capabilities for specialized tasks. Configuration:

- `/workspace/config/agents-config.yaml` - Agent sources and settings
- `/workspace/.agent-aliases` - Shell aliases for agent commands

Common agent commands:

```bash
agent-manager update       # Update all agents
agent-search "keyword"     # Search available agents
agent-install <name>       # Install specific agent
cf-with-context <agent>    # Run agent with project context
```

## Memory and Context Management

### Project Context

Each project should have its own CLAUDE.md file:

```bash
# Create project-specific CLAUDE.md
cat > CLAUDE.md << 'EOF'
# [PROJECT_NAME]

## Project Overview
[Brief description of the project]

## Development Commands
[Add common commands here]

## Architecture Notes
[Add architectural decisions and patterns]

## Important Files
[List key files and their purposes]
EOF
```

### Claude Flow Memory

- Persistent memory in `.swarm/memory.db`
- Multi-agent coordination and context retention
- Memory survives VM restarts via persistent volume

### Global Preferences

Store user preferences in `/workspace/developer/.claude/CLAUDE.md`:

- Coding style preferences
- Git workflow preferences
- Testing preferences

## Secrets Management

Sindri uses automatic, transparent secrets management with SOPS + age encryption. Secrets are encrypted at rest
and never exposed in environment variables or process lists.

### Adding Secrets

Secrets are automatically synced from Fly.io secrets to an encrypted file on every VM boot:

```bash
# On host machine - set secrets via Fly.io
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... -a myapp
flyctl secrets set GITHUB_TOKEN=ghp_... -a myapp
flyctl secrets set PERPLEXITY_API_KEY=pplx-... -a myapp

# VM restarts automatically
# Secrets are encrypted and tools are pre-authenticated
```

**Supported Secrets:**

**AI/Development Tools:**

- `ANTHROPIC_API_KEY` - Claude Code authentication
- `GITHUB_TOKEN` - GitHub CLI authentication
- `PERPLEXITY_API_KEY` - Goalie research assistant
- `OPENROUTER_API_KEY` - OpenRouter API access
- `GOOGLE_GEMINI_API_KEY` - Gemini CLI
- `XAI_API_KEY` - xAI Grok SDK

**Cloud Provider Credentials:**

- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` - AWS CLI
- `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` - Azure CLI

### Using Tools with Secrets

```bash
# SSH to VM
ssh developer@myapp.fly.dev -p 10022

# Everything just works - secrets already configured
claude              # Already authenticated
gh pr create        # Already authenticated
goalie "research"   # API key pre-configured
```

### Advanced: Direct Secret Management

```bash
# View decrypted secrets
view-secrets

# Edit secrets without VM restart
edit-secrets

# Load secrets into current shell (temporary)
load-secrets

# Run command with secrets loaded
with-secrets some-command
```

### Security Features

- **Encrypted at rest**: Secrets stored in `~/.secrets/secrets.enc.yaml` (600 permissions)
- **age encryption**: Modern cryptography, more secure than PGP
- **No environment exposure**: Secrets never in `ps aux`, `env`, or shell history
- **No plaintext**: Secrets not stored in `.bashrc` or configuration files
- **Automatic cleanup**: Environment variables cleared after encryption

### Workflow Example

```bash
# 1. On host: Add API key
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-abc123 -a sindri-dev

# 2. VM restarts (automatic or manual)
flyctl machine restart <machine-id> -a sindri-dev

# 3. SSH to VM
ssh developer@sindri-dev.fly.dev -p 10022

# 4. Use Claude - already authenticated
claude

# Secret is encrypted in ~/.secrets/secrets.enc.yaml
# Never appears in environment or process list
```

## Common Operations

### Troubleshooting

```bash
flyctl status -a <app-name>          # Check VM health
flyctl logs -a <app-name>            # View system logs
flyctl machine restart <id>          # Restart if unresponsive
ssh -vvv developer@<app>.fly.dev -p 10022  # Debug SSH
```

### Cost Monitoring

```bash
./scripts/cost-monitor.sh            # Check usage and costs
./scripts/vm-suspend.sh              # Manual suspend
```

### AI Research Tools

```bash
# Goalie - AI-powered research assistant with GOAP planning
goalie "research question"           # Perform research with Perplexity API
goalie --help                        # View available options

# Requires PERPLEXITY_API_KEY environment variable
# Set via: flyctl secrets set PERPLEXITY_API_KEY=pplx-... -a <app-name>
# Get API key from: https://www.perplexity.ai/settings/api
```

### AI CLI Tools

Additional AI coding assistants available via the `ai-tools` extension:

#### Autonomous Coding Agents

```bash
# Codex CLI - Multi-mode AI assistant
codex suggest "optimize this function"
codex edit file.js
codex run "create REST API"

# Hector - Declarative AI agent platform
hector serve --config agent.yaml     # Start agent server
hector chat assistant                # Interactive chat
hector call assistant "task"         # Execute single task
hector list                          # List available agents
```

#### Platform CLIs

```bash
# Gemini CLI (requires GOOGLE_GEMINI_API_KEY)
gemini chat "explain this code"
gemini generate "write unit tests"

# GitHub Copilot CLI (requires gh and GitHub account)
gh copilot suggest "git command to undo"
gh copilot explain "docker-compose up"

# AWS Q Developer (requires AWS CLI from 85-cloud-tools.sh)
aws q chat
aws q explain "lambda function"
```

#### Local AI (No API Keys)

```bash
# Ollama - Run LLMs locally
nohup ollama serve > ~/ollama.log 2>&1 &   # Start service
ollama pull llama3.2                        # Pull model
ollama run llama3.2                         # Interactive chat
ollama list                                 # List installed models

# Fabric - AI framework with patterns
fabric --setup                              # First-time setup
echo "code" | fabric --pattern explain     # Use pattern
fabric --list                               # List patterns
```

#### API Keys Setup

```bash
# Via Fly.io secrets (recommended)
flyctl secrets set GOOGLE_GEMINI_API_KEY=... -a <app-name>
flyctl secrets set XAI_API_KEY=... -a <app-name>

# Or in shell (temporary)
export GOOGLE_GEMINI_API_KEY=your_key
export XAI_API_KEY=your_key
```

**Get API keys:**

- Gemini: <https://makersuite.google.com/app/apikey>
- xAI Grok: xAI account required

**Enable the extension:**

```bash
extension-manager install ai-tools
```

See `/workspace/ai-tools/README.md` for complete documentation.

### AI Model Management with agent-flow

Agent-flow provides cost-optimized multi-model AI routing for development tasks:

#### Available Providers

- **Anthropic Claude** (default, requires ANTHROPIC_API_KEY)
- **OpenRouter** (100+ models, requires OPENROUTER_API_KEY)
- **Gemini** (free tier, requires GOOGLE_GEMINI_API_KEY)

#### Common Commands

```bash
# Agent-specific tasks
af-coder "Create REST API with OAuth2"       # Use coder agent
af-reviewer "Review code for vulnerabilities" # Use reviewer agent
af-researcher "Research best practices"      # Use researcher agent

# Provider selection
af-openrouter "Build feature"                # OpenRouter provider
af-gemini "Analyze code"                     # Free Gemini tier
af-claude "Write tests"                      # Anthropic Claude

# Optimization modes
af-cost "Simple task"                        # Cost-optimized model
af-quality "Complex refactoring"             # Quality-optimized model
af-speed "Quick analysis"                    # Speed-optimized model

# Utility functions
af-task coder "Create API endpoint"          # Balanced optimization
af-provider openrouter "Generate docs"       # Provider wrapper
```

#### Setting API Keys

```bash
# On host machine (before deployment)
flyctl secrets set OPENROUTER_API_KEY=sk-or-... -a <app-name>
flyctl secrets set GOOGLE_GEMINI_API_KEY=... -a <app-name>
```

**Get API keys:**

- OpenRouter: <https://openrouter.ai/keys>
- Gemini: <https://makersuite.google.com/app/apikey>

**Benefits:**

- **Cost savings**: 85-99% reduction using OpenRouter's low-cost models
- **Flexibility**: Switch between 100+ models based on task complexity
- **Free tier**: Use Gemini for development/testing
- **Seamless integration**: Works alongside existing Claude Flow setup

See [Cost Management Guide](docs/COST_MANAGEMENT.md) for detailed pricing.

## SSH Architecture Notes

The environment provides dual SSH access:

- **Production SSH**: External port 10022 → Internal port 2222 (custom daemon)
- **Hallpass SSH**: `flyctl ssh console` via Fly.io's built-in service (port 22)

In CI mode (`CI_MODE=true`), the custom SSH daemon is disabled to prevent port conflicts with Fly.io's hallpass service,
ensuring reliable automated deployments.

### CI Mode Limitations and Troubleshooting

**SSH Command Execution in CI Mode:**

- Complex multi-line shell commands may fail after machine restarts
- Always use explicit shell invocation: `/bin/bash -c 'command'`
- Avoid nested quotes and complex variable substitution
- Use retry logic for commands executed immediately after restart

**Volume Persistence Verification:**

- Volumes persist correctly, but SSH environment may need time to initialize after restart
- Add machine readiness checks before testing persistence
- Use simple commands to verify mount points and permissions

**Common Issues:**

- `exec: "if": executable file not found in $PATH` - Use explicit bash invocation
- SSH connection timeouts after restart - Add retry logic with delays
- Environment variables not available - Check shell environment setup

**Best Practices for CI Testing:**

- Always verify machine status before running tests
- Use explicit error handling and debugging output
- Split complex operations into simple, atomic commands
- Add volume mount verification before persistence tests

## Important Instructions

- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files to creating new ones
- NEVER proactively create documentation files unless explicitly requested
- Only use emojis if explicitly requested by the user
