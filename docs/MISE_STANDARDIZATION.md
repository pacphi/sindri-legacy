# mise Standardization Analysis

## Executive Summary

This document analyzes the feasibility of refactoring Sindri's Extension API to delegate tool installation and version management to **mise** (https://mise.jdx.dev), a modern polyglot tool version manager.

## Current State: Tool Inventory

### Language Runtimes & Version Managers

| Extension | Current Approach | Tools Installed | Version Manager |
|-----------|-----------------|-----------------|-----------------|
| **nodejs** | NVM (Node Version Manager) | Node.js LTS, npm | NVM v0.40.3 |
| **python** | System Python + pipx | Python 3.13, pip, pipx, virtualenv, poetry, flake8, mypy, jupyterlab, uv | Native apt + pipx |
| **rust** | rustup | rustc, cargo, cargo-watch, cargo-edit, ripgrep, fd, exa, bat, tokei | rustup |
| **golang** | Direct download + go install | Go 1.24.6, gopls, delve, goimports, golangci-lint, air, goreleaser | Native install |
| **ruby** | rbenv | Ruby 3.4/3.3, bundler, Rails, Sinatra, rubocop, rspec, pry | rbenv |
| **php** | apt + ondrej PPA | PHP 8.3, Composer, Symfony CLI, phpstan, psalm, phpunit, php-cs-fixer | Native apt |
| **jvm** | SDKMAN | Java (25/21/17/11), Maven, Gradle, Kotlin, Scala, Clojure, JBang, Spring Boot, Micronaut | SDKMAN |
| **dotnet** | Microsoft apt repository | .NET SDK 9.0/8.0, ASP.NET Core, dotnet-ef, NuGet CLI | Native apt |

### Infrastructure & DevOps Tools

| Extension | Installation Method | Tools |
|-----------|-------------------|-------|
| **docker** | Docker apt repository | Docker Engine, docker-compose, dive, ctop |
| **infra-tools** | Mixed (apt, curl, git) | Terraform, Ansible, kubectl, Helm, Carvel suite (kapp, ytt, kbld, vendir, imgpkg), Crossplane, Pulumi, k9s, kubectx/kubens |
| **cloud-tools** | Official installers | AWS CLI, Azure CLI, Google Cloud CLI, Oracle Cloud CLI, Alibaba Cloud CLI, DigitalOcean CLI, IBM Cloud CLI |

### Development Tools & Utilities

| Extension | Installation Method | Tools |
|-----------|-------------------|-------|
| **ai-tools** | npm, go install, curl | Codex CLI, Gemini CLI, Ollama, Fabric, Plandex, Hector, Grok CLI |
| **nodejs-devtools** | npm global | TypeScript, ts-node, ESLint, Prettier, nodemon, goalie |
| **claude-config** | npm global | Claude Code CLI (@anthropic-ai/claude-code) |
| **github-cli** | Pre-installed (Docker) | GitHub CLI (gh) |
| **playwright** | npm global | Playwright browser automation |
| **monitoring** | apt + binaries | htop, glances, iotop, duf, ncdu, btop |

### Supporting Extensions

| Extension | Purpose |
|-----------|---------|
| **workspace-structure** | Creates base directory structure |
| **ssh-environment** | SSH wrapper creation for non-interactive sessions |
| **tmux-workspace** | Tmux session management |
| **agent-manager** | Claude Code agent management |
| **context-loader** | Context system for Claude |
| **post-cleanup** | Post-installation cleanup |

## mise Capabilities Analysis

### What mise Can Manage

Based on mise documentation (https://mise.jdx.dev), mise supports:

#### Backend Systems (15 total)
1. **asdf** - Plugin-based tools
2. **aqua** - Security-focused package manager
3. **cargo** - Rust ecosystem
4. **dotnet** - (experimental)
5. **gem** - Ruby ecosystem
6. **github** - GitHub releases
7. **gitlab** - GitLab releases
8. **go** - Go package manager
9. **http** - Direct downloads
10. **npm** - Node.js ecosystem
11. **pipx** - Python CLI tools
12. **spm** - (experimental)
13. **ubi** - Universal Binary Installer for GitHub/GitLab
14. **vfox** - Plugin-based tools
15. **Custom backends** - Extensible plugin system

#### Core Language Support
- **Node.js** - Native support (replaces NVM)
- **Python** - Native support (replaces pyenv)
- **Ruby** - Native support (replaces rbenv)
- **Go** - Native support
- **Rust** - Native support (replaces rustup)
- **Java** - Via asdf or aqua
- **Elixir, Erlang** - Native support
- **Deno, Bun** - Native support
- **Zig** - Native support

#### Tool Categories Available
- **Cloud CLIs**: AWS, Azure, GCP, Terraform, Pulumi
- **Kubernetes**: kubectl, helm, kustomize, k9s
- **Code Quality**: golangci-lint, prettier, black, eslint, hadolint
- **DevOps**: GitHub CLI, GitLab CLI, ArgoCD, Flux
- **Containers**: Docker, containerd, Podman

### mise Tool Installation Patterns

```bash
# Language runtimes
mise use node@22
mise use python@3.13
mise use ruby@3.4
mise use go@1.24
mise use rust@1.80

# Tools via package ecosystems
mise use npm:typescript
mise use npm:prettier
mise use pipx:black
mise use cargo:ripgrep
mise use cargo:fd-find

# Tools via GitHub releases (ubi backend)
mise use ubi:wagoodman/dive
mise use ubi:bcicen/ctop

# Infrastructure tools
mise use terraform@1.9
mise use kubectl@1.31
mise use helm@3.16
```

## Compatibility Matrix

### ✅ High Compatibility (Direct mise Support)

| Current Extension | mise Backend | Confidence | Notes |
|------------------|-------------|-----------|-------|
| nodejs | core | 100% | Native Node.js support, replaces NVM |
| python | core + pipx | 100% | Native Python + pipx backend for tools |
| rust | core | 100% | Native Rust support, replaces rustup |
| golang | core + go | 95% | Native Go + go backend for tools |
| ruby | core + gem | 95% | Native Ruby support, replaces rbenv |
| nodejs-devtools | npm backend | 100% | All tools available via npm: backend |
| ai-tools | npm + go + ubi | 90% | Most tools via npm/go backends, Ollama via ubi |

### ⚠️ Partial Compatibility (Requires Hybrid Approach)

| Current Extension | mise Backend | Confidence | Challenges |
|------------------|-------------|-----------|------------|
| jvm | asdf/aqua | 70% | SDKMAN manages Java versions well; mise asdf backend may work |
| php | asdf | 60% | Ondrej PPA provides PHP 8.3; mise asdf-php plugin available but less tested |
| dotnet | dotnet (exp) | 50% | mise dotnet backend is experimental; Microsoft repos more reliable |
| infra-tools | ubi + aqua + http | 75% | Mix of tools; kubectl/helm/terraform well-supported, Carvel tools via ubi |
| cloud-tools | http + ubi | 65% | AWS/Azure/GCP have specific install methods; ubi may work for some |
| docker | system packages | 30% | Docker Engine requires system-level installation (apt), compose via mise |

### ❌ Low Compatibility (Keep Current Approach)

| Current Extension | Reason to Keep Current | Alternative |
|------------------|----------------------|------------|
| workspace-structure | No tool installation involved | N/A |
| ssh-environment | SSH wrapper logic, not tools | N/A |
| github-cli | Pre-installed in Docker image | Could use mise for version management |
| claude-config | npm package, already simple | Could use `mise use npm:@anthropic-ai/claude-code` |
| monitoring | System monitoring tools (apt) | Some tools (btop) available via aqua |
| playwright | npm package | Could use `mise use npm:playwright` |
| tmux-workspace | Configuration, not installation | N/A |
| agent-manager | Custom Claude Code logic | N/A |
| context-loader | Custom Claude Code logic | N/A |
| post-cleanup | Cleanup logic, not tools | N/A |

## Key Commands Comparison

### Current Approach
```bash
# nodejs extension
nvm install --lts
nvm use --lts
npm install -g typescript

# python extension
pipx install poetry
pipx install black

# rust extension
rustup install stable
cargo install ripgrep
```

### With mise
```bash
# All in one place
mise use node@lts
mise use npm:typescript
mise use pipx:poetry
mise use pipx:black
mise use rust@stable
mise use cargo:ripgrep

# Or via config file (mise.toml)
[tools]
node = "lts"
python = "3.13"
rust = "stable"
"npm:typescript" = "latest"
"pipx:poetry" = "latest"
"cargo:ripgrep" = "latest"
```

## Benefits of mise Integration

### Unified Tool Management
- **Single command** for all tool installations: `mise install`
- **Consistent versioning** across all languages and tools
- **Lock file** (`mise.lock`) for reproducible environments
- **Less code** to maintain (no custom install logic per language)

### Version Management
- **Per-project versions** via `mise.toml` in project directories
- **Global defaults** via `~/.config/mise/config.toml`
- **Easy upgrades**: `mise upgrade` updates all tools
- **Version switching**: `mise use node@18` vs `mise use node@22`

### Developer Experience
- **Automatic activation** via `mise activate` in shell
- **Less context switching** between version managers (nvm, rbenv, rustup, etc.)
- **Better discoverability**: `mise ls-remote node` shows all available versions
- **Faster than asdf** - mise is optimized for performance

### Operational Benefits
- **Smaller Docker images** - One tool manager instead of many
- **Faster builds** - mise can cache across projects
- **Better CI/CD** - `mise install` installs everything from config
- **Standardized BOM** - `mise ls` shows all installed versions

## Challenges & Considerations

### 1. Docker Image Size
- **Current**: Each language brings its own version manager (nvm, rbenv, rustup, SDKMAN)
- **With mise**: Single binary (~20MB) replaces all version managers
- **Trade-off**: May need to keep some tools for compatibility (e.g., rubygems needs gem)

### 2. Migration Complexity
- Extensions have accumulated custom configuration logic
- SSH wrappers, PATH management, aliases would need refactoring
- Some tools (Docker Engine, system packages) must stay as-is

### 3. Edge Cases
- **JVM**: SDKMAN is mature and well-tested; mise asdf-java plugin may not be as robust
- **PHP**: Ondrej PPA provides cutting-edge PHP; mise php support is via asdf plugin
- **.NET**: Experimental mise support; Microsoft repos are production-ready

### 4. Backward Compatibility
- Existing Sindri VMs have tools installed via current methods
- Migration strategy needed for existing deployments
- Documentation and user communication

## Recommendations

### Phase 1: High-Value Targets (Quick Wins)
Refactor extensions with 100% mise compatibility:
1. **nodejs** → mise core
2. **python** → mise core + pipx backend
3. **rust** → mise core
4. **nodejs-devtools** → mise npm backend
5. **golang** → mise core + go backend

**Impact**: ~40% of tool installations, significant code reduction

### Phase 2: Hybrid Approach (Mixed Compatibility)
Maintain existing installation but add mise as option:
6. **ruby** → mise core (replace rbenv)
7. **ai-tools** → mise npm/go/ubi backends
8. **infra-tools** → mise for kubectl/helm/terraform, keep current for others

**Impact**: ~30% additional coverage

### Phase 3: Keep Current (Low ROI)
Extensions to keep as-is:
- **jvm** (SDKMAN is superior)
- **php** (Ondrej PPA works well)
- **dotnet** (experimental in mise)
- **docker** (system-level requirement)
- **cloud-tools** (official installers are best)
- **monitoring** (apt packages)

**Rationale**: High risk, low benefit for these tools

## Implementation Strategy

### 1. New Extension: `mise-config`
Create a new core extension that:
- Installs mise binary
- Sets up shell integration (`mise activate`)
- Configures global defaults
- Provides BOM function to list all mise-managed tools

### 2. Refactor Target Extensions
For high-confidence tools (nodejs, python, rust):
- Replace custom install logic with `mise use <tool>`
- Keep configuration/aliases logic
- Add `bom()` function that calls `mise ls` for that tool
- Update validation to check mise-managed versions

### 3. Gradual Migration Path
```bash
# Example: nodejs.sh.example refactored
install() {
  if ! command_exists mise; then
    print_error "mise is required - install mise-config extension first"
    return 1
  fi

  mise use node@lts
  mise use npm:typescript npm:eslint npm:prettier
}

bom() {
  print_status "Node.js tools managed by mise:"
  mise ls node
  mise ls npm:*
}
```

## Proof of Concept

### Test Case: nodejs Extension

**Before** (current):
```bash
# 70+ lines of install logic
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
nvm alias default lts/*
npm install -g npm@latest
```

**After** (with mise):
```bash
# 5 lines of install logic
mise use node@lts
mise use npm:npm@latest

# Version info available via:
mise ls node npm:*
```

**Code Reduction**: ~93% fewer lines in install function

## Conclusion

mise integration offers significant benefits for Sindri's Extension API:
- **70-80% code reduction** for language runtime extensions
- **Unified tooling** - one command to rule them all
- **Better versioning** - per-project and global tool versions
- **Modern developer experience** - active, well-maintained project

**Recommended Action**:
1. Create `mise-config` extension as foundation
2. Refactor `nodejs`, `python`, `rust` extensions first (Phase 1)
3. Evaluate results and expand to Phase 2 if successful
4. Add `bom()` function to all extensions (mise-managed or not)

The refactor should be **incremental and opt-in**, allowing existing extensions to coexist with mise-powered ones during transition.
