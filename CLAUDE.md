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

- `/workspace/` - Persistent volume root (survives VM restarts)
- `/workspace/developer/` - Developer home directory (persistent)
- `/workspace/projects/active/` - Active development projects
- `/workspace/scripts/` - Utility and management scripts
- All user data (npm cache, configs, SSH keys) persists between VM restarts

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

### Available Extensions

**Core Extensions (Protected - Cannot be Removed):**

- `workspace-structure` - Base directory structure (must be first)
- `mise-config` - Unified tool version manager for all mise-powered extensions
- `ssh-environment` - SSH configuration for non-interactive sessions and CI/CD

**Foundational Languages:**

- `nodejs` - Node.js LTS via mise with npm (requires mise-config, recommended - many tools depend on it)
- `python` - Python 3.13 via mise with pip, venv, uv, pipx (requires mise-config)

**Claude AI:**

- `claude` - Claude Code CLI with developer configuration
- `claude-marketplace` - Plugin installer for https://claudecodemarketplace.com/ (requires claude, git)
- `openskills` - OpenSkills CLI for managing Claude Code skills from Anthropic's marketplace (requires nodejs, git)
- `nodejs-devtools` - TypeScript, ESLint, Prettier, nodemon, goalie (mise-powered, requires nodejs)

**Development Tools:**

- `github-cli` - GitHub CLI authentication and workflow configuration
- `rust` - Rust toolchain with cargo, clippy, rustfmt (requires mise-config)
- `golang` - Go 1.24 with gopls, delve, golangci-lint (requires mise-config)
- `ruby` - Ruby 3.4.7 via mise with Rails, Bundler (requires mise-config)
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

Extensions are executed in the order listed in `docker/lib/extensions.d/active-extensions.conf.example` (development)
or `active-extensions.ci.conf` (CI mode).

Example manifest:

```bash
# Protected extensions (required for system functionality):
workspace-structure
mise-config
ssh-environment

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

Each extension implements 6 standard functions:

- `prerequisites()` - Check system requirements
- `install()` - Install packages and tools
- `configure()` - Post-install configuration
- `validate()` - Run smoke tests
- `status()` - Check installation state
- `remove()` - Uninstall and cleanup

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

**claude** (Recommended):

```bash
extension-manager install claude
```

Provides:

- Claude Code CLI (`claude` command)
- Global preferences (~/.claude/CLAUDE.md)
- Auto-formatting hooks (Prettier, TypeScript)
- Authentication management

**claude-marketplace** (Optional):

```bash
extension-manager install claude-marketplace
```

Provides:

- Plugin marketplace integration for https://claudecodemarketplace.com/
- Automated plugin installation from `.plugins` configuration file
- Curated collection of high-quality Claude Code plugins
- Support for GitHub-hosted plugin repositories

Common workflow:

```bash
# Copy template and customize
cp /workspace/.plugins.example /workspace/.plugins
vim /workspace/.plugins

# Install extension (auto-installs plugins from .plugins file)
extension-manager install claude-marketplace

# Browse and install plugins interactively
claude /plugin

# List installed plugins
claude /plugin list

# Manage marketplaces
claude /plugin marketplace list
claude /plugin marketplace add owner/repo
```

Curated plugins in `.plugins.example`:

- `steveyegge/beads` - Natural language programming
- `croffasia/cc-blueprint-toolkit` - Project scaffolding templates
- `quant-sentiment-ai/claude-equity-research` - Financial analysis tools
- `czlonkowski/n8n-skills` - Workflow automation integration
- `anthropics/life-sciences` - Life sciences research plugins
- `ComposioHQ/awesome-claude-skills` - Community-curated skills collection

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
# Edit manifest to uncomment desired extensions
# docker/lib/extensions.d/active-extensions.conf.example

# Then install all at once
extension-manager install-all

# Or use interactive mode
extension-manager --interactive
```

## mise Tool Manager

Sindri uses **mise** (https://mise.jdx.dev) for unified tool version management across multiple languages and runtimes.
mise provides a single, consistent interface for managing Node.js, Python, Rust, Go, Ruby, and their associated tools,
replacing multiple version managers (NVM, pyenv, rbenv, rustup, etc.) with one tool.

**Note:** The `mise-config` extension is a **protected core extension** that is automatically installed and cannot be removed.
It must be installed before any mise-powered extensions.

### mise-Managed Extensions

The following extensions use mise for tool installation and version management (all require `mise-config`):

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

Sindri uses GitHub Actions for automated testing and validation. The workflows are designed to be maintainable and reusable.

### Available Workflows

**Extension Testing (`extension-tests.yml`)**

- Tests Extension API v1.0 and v2.0
- Validates extension manager functionality
- Tests individual extensions in parallel
- Verifies upgrade functionality
- Location: `.github/workflows/extension-tests.yml`

**Integration Testing (`integration.yml`)**

- End-to-end VM deployment tests
- Developer workflow validation
- mise-powered stack integration
- Location: `.github/workflows/integration.yml`

**Validation (`validate.yml`)**

- Shell script validation with shellcheck
- YAML syntax validation
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

- `setup-fly-test-env/` - Complete test environment setup
- `deploy-fly-app/` - Fly.io app deployment with retry logic and pre-built image support
- `build-push-image/` - Build and push Docker images to Fly registry
- `wait-fly-deployment/` - Wait for deployment completion
- `cleanup-fly-app/` - Cleanup test resources

### Test Scripts

Reusable test scripts in `.github/scripts/extension-tests/`:

- `verify-commands.sh` - Verify command availability
- `test-key-functionality.sh` - Test primary tool functionality
- `test-api-compliance.sh` - Validate Extension API compliance
- `test-idempotency.sh` - Test idempotent installation
- `lib/test-helpers.sh` - Shared utility functions (20+)
- `lib/assertions.sh` - Test assertion library (10+)

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
cp /workspace/templates/CLAUDE.md.example ./CLAUDE.md
# Edit with project-specific commands, architecture, conventions
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

# Plandex - Multi-step development tasks
plandex init                         # Initialize in project
plandex plan "add user auth"         # Plan task
plandex execute                      # Execute plan

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
flyctl secrets set GROK_API_KEY=... -a <app-name>

# Or in shell (temporary)
export GOOGLE_GEMINI_API_KEY=your_key
export GROK_API_KEY=your_key
```

**Get API keys:**

- Gemini: <https://makersuite.google.com/app/apikey>
- Grok: xAI account required

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
