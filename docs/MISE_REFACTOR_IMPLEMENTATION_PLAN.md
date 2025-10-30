# mise Refactor Implementation Plan

## Executive Summary

**Timeline**: 7 days (1 week)
**Implementer**: Solo developer
**Scope**: Complete refactor of Extension API to use mise for tool management
**Approach**: Clean break - no backward compatibility, fresh deployments only
**Test Coverage**: 100% for all installed tools

### Tool Selection Strategy

| Category | Tool Manager | Extensions |
|----------|-------------|------------|
| **mise-powered** | mise | nodejs, python, rust, golang, nodejs-devtools |
| **Keep current** | rbenv | ruby |
| **Keep current** | sdkman | jvm |
| **Keep current** | native/apt | docker, cloud-tools, monitoring, php, dotnet |
| **Selective** | native + mise where applicable | ai-tools, infra-tools |

### Success Criteria

- ✅ All 25 extensions renamed to `.extension` suffix
- ✅ All mise-powered extensions use TOML configuration files
- ✅ All extensions have standardized `status()` output
- ✅ 100% test coverage for installed tools
- ✅ CI/CD workflows updated and passing
- ✅ Complete documentation updates
- ✅ Fresh deployments work end-to-end

---

## Daily Breakdown

### Day 1: Foundation Setup (Phase 0.0-0.1)
**Goal**: Rename extensions, create mise infrastructure, update tooling
**Estimated Time**: 8 hours

### Day 2: Status Standardization (Phase 0.2-0.3)
**Goal**: Standardize status() across all 25 extensions
**Estimated Time**: 8 hours

### Day 3: Core mise Extensions (Phase 1)
**Goal**: Refactor 5 high-value extensions to use mise
**Estimated Time**: 8 hours

### Day 4: Remaining Extensions (Phase 2)
**Goal**: Finalize ruby, ai-tools, infra-tools, and others
**Estimated Time**: 8 hours

### Day 5: Documentation & BOM (Phase 3)
**Goal**: Complete documentation and BOM reporting
**Estimated Time**: 8 hours

### Day 6: CI/CD & Testing
**Goal**: Update workflows, add validation, parallel execution
**Estimated Time**: 8 hours

### Day 7: Validation & Fixes
**Goal**: End-to-end testing, fixes, final validation
**Estimated Time**: 8 hours

---

## Phase 0: Foundation Setup

### Phase 0.0: File Renaming (2 hours)

**Objective**: Rename all `.sh.example` files to `.extension` suffix

**Tasks**:

1. **Automated Rename Script** (30 min)
   ```bash
   cd docker/lib/extensions.d
   for file in *.sh.example; do
     base=$(basename "$file" .sh.example)
     git mv "$file" "${base}.extension"
   done
   git commit -m "refactor: rename extensions from .sh.example to .extension"
   ```

2. **Update extension-manager.sh** (1 hour)
   - Change `get_extension_name()` to handle `.extension` suffix
   - Update all `*.sh.example` glob patterns to `*.extension`
   - Update activation logic (copy `.extension` → `.sh`)
   - Test: `bash extension-manager.sh list` should work

3. **Update CI Workflow Path Filters** (30 min)
   - `.github/workflows/validate.yml`
   - `.github/workflows/extension-tests.yml`
   - `.github/workflows/integration.yml`
   - `.github/workflows/integration-resilient.yml`
   - Change all `*.sh.example` paths to `*.extension`

**Success Criteria**:
- ✅ All 25 extensions renamed
- ✅ `extension-manager.sh list` works
- ✅ Git history preserved (using git mv)
- ✅ CI workflows reference correct file patterns

**Testing**:
```bash
# Verify all extensions renamed
ls -1 docker/lib/extensions.d/*.extension | wc -l  # Should be 25

# Verify extension-manager works
cd docker/lib
bash extension-manager.sh list
```

---

### Phase 0.1: Create mise Infrastructure (3 hours)

**Objective**: Create mise-config extension and TOML files

**Tasks**:

1. **Create mise-config.extension** (1 hour)

   Location: `docker/lib/extensions.d/mise-config.extension`

   Implement:
   - `prerequisites()`: Check curl exists
   - `install()`: Install mise via `curl https://mise.run | sh`
   - `configure()`: Add mise activation to `~/.bashrc`, create global config
   - `validate()`: Check `mise --version` works
   - `status()`: Show mise version and managed tools
   - `remove()`: Clean up mise files and bashrc entry

2. **Create TOML Files for Phase 1 Extensions** (1.5 hours)

   Create these files in `docker/lib/extensions.d/`:

   - `nodejs.toml` - Node.js LTS + npm
   - `nodejs-ci.toml` - Minimal Node.js for CI
   - `python.toml` - Python 3.13 + pipx tools
   - `python-ci.toml` - Minimal Python for CI
   - `rust.toml` - Rust stable + cargo tools
   - `rust-ci.toml` - Minimal Rust for CI
   - `golang.toml` - Go 1.24 + go tools
   - `golang-ci.toml` - Minimal Go for CI
   - `nodejs-devtools.toml` - npm global dev tools

   Use content from MISE_REFACTOR.md examples (lines 218-298)

3. **Create template.toml** (30 min)

   Location: `docker/lib/extensions.d/template.toml`

   Template for new mise-powered extensions with:
   - `[tools]` section with examples
   - `[env]` section with examples
   - `[settings]` section with examples
   - Comments explaining each section

**Success Criteria**:
- ✅ mise-config.extension created and validated
- ✅ 9 TOML files created (5 main + 4 CI variants)
- ✅ template.toml created
- ✅ TOML files are valid (no syntax errors)

**Testing**:
```bash
# Validate TOML syntax
pip install toml
for toml in docker/lib/extensions.d/*.toml; do
  python3 -c "import toml; toml.load(open('$toml'))" && echo "✅ $toml"
done

# Test mise-config extension
cd docker/lib
bash extension-manager.sh install mise-config
mise --version
```

---

### Phase 0.2: Update Extension Manager (2 hours)

**Objective**: Add status-all and enhanced reporting capabilities

**Tasks**:

1. **Add status-all Command** (1 hour)

   In `docker/lib/extension-manager.sh`, add:
   ```bash
   status_all() {
     local format="${1:-text}"  # text, json, or markdown

     if [[ "$format" == "json" ]]; then
       # JSON output for programmatic use
       echo '{'
       echo '  "generated": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",'
       echo '  "hostname": "'$(hostname)'",'
       echo '  "extensions": ['
       # ... iterate and generate JSON
       echo '  ]'
       echo '}'
     else
       # Human-readable text output
       echo "=== Extension Status Report ==="
       echo "Generated: $(date)"
       echo ""

       # Iterate through all active extensions
       for ext in $(cat extensions.d/active-extensions.conf | grep -v '^#'); do
         echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
         bash extension-manager.sh status "$ext"
         echo ""
       done
     fi
   }
   ```

2. **Add Supporting Commands** (1 hour)

   - `doctor`: Run `mise doctor` if mise available
   - `upgrade-all`: Run `mise upgrade` for all mise-managed tools
   - `status-export`: Alias for `status-all --json`

**Success Criteria**:
- ✅ `extension-manager status-all` works
- ✅ `extension-manager status-all --json` produces valid JSON
- ✅ `extension-manager doctor` works
- ✅ `extension-manager upgrade-all` works

**Testing**:
```bash
cd docker/lib
bash extension-manager.sh status-all
bash extension-manager.sh status-all --json | jq .
```

---

### Phase 0.3: Standardize status() Output (1 hour)

**Objective**: Update all 25 extensions with standardized status() format

**Standard Status Template**:
```bash
status() {
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

  # Extension-specific tool listing
  print_status "Installed tools:"
  # ... list tools with versions ...

  return 0
}
```

**Tasks**:

1. **Create Batch Update Script** (30 min)

   Create `scripts/update-status-functions.sh`:
   ```bash
   #!/bin/bash
   # Script to add standard status() format to all extensions
   # Lists extensions that need status() updates
   ```

2. **Update All 25 Extensions** (30 min)

   For each extension in `docker/lib/extensions.d/`:
   - Add metadata variables: `EXT_NAME`, `EXT_VERSION`, `EXT_DESCRIPTION`, `EXT_CATEGORY`
   - Update `status()` function to use standard format
   - Ensure proper tool version reporting

   **Parallel approach**: Group extensions by category and update in batches
   - Core (4): workspace-structure, ssh-environment, mise-config, post-cleanup
   - Languages (8): nodejs, python, rust, golang, ruby, php, jvm, dotnet
   - Infrastructure (4): docker, infra-tools, cloud-tools, monitoring
   - Dev Tools (9): github-cli, nodejs-devtools, claude-config, playwright, tmux-workspace, agent-manager, context-loader, ai-tools

**Success Criteria**:
- ✅ All 25 extensions have EXT_NAME, EXT_VERSION, EXT_DESCRIPTION, EXT_CATEGORY
- ✅ All status() functions follow standard format
- ✅ All status() functions return 0 if installed, 1 if not
- ✅ `extension-manager status-all` shows consistent formatting

**Testing**:
```bash
# Test each extension's status output
for ext in $(ls docker/lib/extensions.d/*.extension); do
  ext_name=$(basename "$ext" .extension)
  echo "Testing $ext_name..."
  # shellcheck "$ext"
done
```

---

## Phase 1: Core mise Extensions (Day 3)

### Phase 1.1: Refactor nodejs.extension (1.5 hours)

**Objective**: Convert nodejs from NVM to mise

**Current**: 377 lines with NVM installation
**Target**: ~150 lines using mise + TOML

**Tasks**:

1. **Update install() Function** (45 min)
   ```bash
   install() {
     print_status "Installing Node.js via mise..."

     if ! command_exists mise; then
       print_error "mise is required - install mise-config extension first"
       return 1
     fi

     # Determine paths
     local ext_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
     local toml_source
     local toml_dest="$HOME/.config/mise/conf.d/nodejs.toml"

     # Select config based on CI_MODE
     if [[ "${CI_MODE:-false}" == "true" ]] && [[ -f "$ext_dir/nodejs-ci.toml" ]]; then
       toml_source="$ext_dir/nodejs-ci.toml"
     else
       toml_source="$ext_dir/nodejs.toml"
     fi

     # Validate and copy TOML
     if [[ ! -f "$toml_source" ]]; then
       print_error "TOML configuration not found: $toml_source"
       return 1
     fi

     mkdir -p "$HOME/.config/mise/conf.d"
     cp "$toml_source" "$toml_dest"

     # Install all tools from configuration
     if mise install; then
       print_success "Node.js installed: $(node -v)"
     else
       print_error "mise install failed"
       return 1
     fi

     return 0
   }
   ```

2. **Update configure() Function** (15 min)
   - Keep SSH wrapper logic
   - Keep alias configurations
   - Remove NVM-specific configuration

3. **Update validate() Function** (15 min)
   ```bash
   validate() {
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
   ```

4. **Update status() Function** (15 min)
   ```bash
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
     mise ls node npm:* 2>/dev/null | sed 's/^/  • /'

     return 0
   }
   ```

5. **Update remove() Function** (15 min)
   ```bash
   remove() {
     print_warning "Removing nodejs..."

     # Remove mise configuration
     rm -f "$HOME/.config/mise/conf.d/nodejs.toml"

     # Optionally uninstall tools (they may be shared with other extensions)
     # mise prune  # Removes tools not referenced in any config

     # Clean up SSH wrappers, aliases, etc.
     # ... (keep existing cleanup logic)

     print_success "nodejs mise configuration removed"
     return 0
   }
   ```

**Success Criteria**:
- ✅ nodejs.extension uses mise for installation
- ✅ Node.js LTS installs correctly
- ✅ npm global packages work
- ✅ SSH wrappers still function
- ✅ CI_MODE uses nodejs-ci.toml
- ✅ Code reduced from 377 to ~150 lines

**Testing**:
```bash
# Deploy test VM
CI_MODE=true ./scripts/vm-setup.sh --app-name test-nodejs-mise

# SSH in and test
flyctl ssh console -a test-nodejs-mise
cd /workspace/scripts/lib
echo -e "mise-config\nnodejs" > extensions.d/active-extensions.conf
bash extension-manager.sh install-all

# Validate
node --version
npm --version
mise ls node
extension-manager status nodejs

# Cleanup
exit
flyctl apps destroy test-nodejs-mise --yes
```

---

### Phase 1.2: Refactor python.extension (1.5 hours)

**Objective**: Convert python to use mise + pipx backend

**Tasks**:

1. **Update install() Function** (45 min)
   - Copy python.toml or python-ci.toml to `~/.config/mise/conf.d/`
   - Run `mise install`
   - Verify Python 3.13 + pipx tools

2. **Update validate() Function** (15 min)
   - Check `mise ls python` shows Python
   - Check `mise ls pipx:*` shows pipx tools
   - Verify `python3`, `pip3`, `uv` commands exist

3. **Update status() Function** (15 min)
   - Show mise-managed Python version
   - Show mise-managed pipx tools
   - List installed Python packages

4. **Update remove() Function** (15 min)
   - Remove `~/.config/mise/conf.d/python.toml`
   - Clean up other python-specific files

**Success Criteria**:
- ✅ Python 3.13 installs via mise
- ✅ pipx tools install via mise
- ✅ virtualenv, poetry, flake8, mypy, black, jupyterlab available
- ✅ CI_MODE installs minimal python-ci.toml

**Testing**:
```bash
# Similar testing approach as nodejs
python3 --version
pip3 --version
poetry --version
black --version
mise ls python pipx:*
```

---

### Phase 1.3: Refactor rust.extension (1.5 hours)

**Objective**: Convert rust to use mise

**Tasks**:

1. **Update install() Function** (45 min)
   - Handle CI_MODE (skip cargo tools in CI)
   - Copy rust.toml or rust-ci.toml
   - Run `mise install`

2. **Update validate() Function** (15 min)
   - Check `mise ls rust` shows Rust stable
   - Check cargo tools if not CI_MODE
   - Verify `rustc`, `cargo` commands

3. **Update status() Function** (15 min)
   - Show mise-managed Rust version
   - Show cargo tools (if installed)

4. **Update remove() Function** (15 min)

**Success Criteria**:
- ✅ Rust stable installs via mise
- ✅ cargo tools install in non-CI mode
- ✅ ripgrep, fd-find, exa, bat, tokei available
- ✅ CI_MODE skips cargo tools

**Testing**:
```bash
rustc --version
cargo --version
rg --version
fd --version
mise ls rust cargo:*
```

---

### Phase 1.4: Refactor golang.extension (1.5 hours)

**Objective**: Convert golang to use mise

**Tasks**:

1. **Update install() Function** (45 min)
   - Copy golang.toml or golang-ci.toml
   - Pin Go version to 1.24.6
   - Install go tools via mise

2. **Update validate() Function** (15 min)
   - Check `mise ls go` shows Go 1.24.6
   - Check go tools (gopls, delve, goimports, golangci-lint, air, goreleaser)

3. **Update status() Function** (15 min)

4. **Update remove() Function** (15 min)

**Success Criteria**:
- ✅ Go 1.24.6 installs via mise
- ✅ Go tools install via mise go backend
- ✅ CI_MODE installs minimal golang-ci.toml

**Testing**:
```bash
go version
gopls version
dlv version
mise ls go go:*
```

---

### Phase 1.5: Refactor nodejs-devtools.extension (1.5 hours)

**Objective**: Convert nodejs-devtools to use mise npm backend

**Tasks**:

1. **Update install() Function** (45 min)
   - Verify nodejs extension is installed first
   - Copy nodejs-devtools.toml
   - Install TypeScript, ESLint, Prettier, nodemon, goalie

2. **Update validate() Function** (15 min)
   - Check all npm tools available: `tsc`, `eslint`, `prettier`, `nodemon`, `goalie`

3. **Update status() Function** (15 min)
   - Show mise-managed npm tools

4. **Update remove() Function** (15 min)

**Success Criteria**:
- ✅ All npm dev tools install via mise
- ✅ mise tasks available (format, lint, typecheck)
- ✅ Tools work: `tsc --version`, `eslint --version`, etc.

**Testing**:
```bash
tsc --version
eslint --version
prettier --version
nodemon --version
goalie --help
mise ls npm:*
mise run format  # Test mise tasks
```

---

## Phase 2: Remaining Extensions (Day 4)

### Phase 2.1: ruby.extension - Keep rbenv (30 min)

**Objective**: No changes except status() standardization (already done in Phase 0.3)

**Tasks**:
- Verify status() output is standardized
- No installation logic changes
- Keep rbenv as version manager

**Success Criteria**:
- ✅ ruby.extension status() follows standard format
- ✅ rbenv continues to work as before

---

### Phase 2.2: ai-tools.extension - Native + Selective mise (2 hours)

**Objective**: Install most tools natively, use mise where applicable

**Tool Installation Strategy**:
- **Native installs**: Ollama (native binary), Fabric (git clone)
- **mise npm backend**: codex-cli, @google/gemini-cli (if Node.js available)
- **mise go backend**: plandex, hector (if Go available)
- **mise ubi backend**: Test if applicable for binaries

**Tasks**:

1. **Update install() Function** (1 hour)
   ```bash
   install() {
     print_status "Installing AI tools..."

     # Ollama - Always native install
     print_status "Installing Ollama (native)..."
     curl -fsSL https://ollama.com/install.sh | sh

     # Fabric - Native git clone
     print_status "Installing Fabric..."
     git clone https://github.com/danielmiessler/fabric.git ~/.local/share/fabric
     cd ~/.local/share/fabric && go build
     ln -sf ~/.local/share/fabric/fabric ~/.local/bin/fabric

     # mise-based tools (if mise available)
     if command_exists mise; then
       local toml_dest="$HOME/.config/mise/conf.d/ai-tools.toml"

       cat > "$toml_dest" << 'EOF'
   [tools]
   # npm-based tools (requires nodejs extension)
   "npm:codex-cli" = "latest"
   "npm:@google/gemini-cli" = "latest"

   # Go-based tools (requires golang extension)
   "go:github.com/plandex-ai/plandex@latest" = "latest"
   "go:github.com/kadirpekel/hector/cmd/hector@latest" = "latest"
   EOF

       mise install
     else
       print_warning "mise not available, using fallback installations..."

       # Fallback: npm global installs if Node.js available
       if command_exists npm; then
         npm install -g codex-cli @google/gemini-cli
       fi

       # Fallback: go install if Go available
       if command_exists go; then
         go install github.com/plandex-ai/plandex@latest
         go install github.com/kadirpekel/hector/cmd/hector@latest
       fi
     fi

     return 0
   }
   ```

2. **Update validate() Function** (30 min)
   - Check Ollama: `ollama --version`
   - Check Fabric: `fabric --help`
   - Check codex-cli, gemini-cli if installed
   - Check plandex, hector if installed

3. **Update status() Function** (30 min)
   - List native tools (Ollama, Fabric)
   - List mise-managed tools if available
   - Show which tools require API keys

**Success Criteria**:
- ✅ Ollama installs natively
- ✅ Fabric installs natively
- ✅ npm/go tools install via mise (if available) or fallback
- ✅ No hard dependencies on nodejs/golang

**Testing**:
```bash
ollama --version
fabric --help
codex --version  # If Node.js installed
plandex --help   # If Go installed
mise ls npm:* go:*
```

---

### Phase 2.3: infra-tools.extension - Selective mise (2 hours)

**Objective**: Use mise for well-supported tools (Terraform, kubectl, Helm), native for specialized tools

**Tool Installation Strategy**:
- **mise-managed**: Terraform, kubectl, Helm, k9s
- **Native installs**: Ansible (apt), Carvel tools (custom script), Crossplane, Pulumi

**Tasks**:

1. **Update install() Function** (1 hour)
   ```bash
   install() {
     print_status "Installing infrastructure tools..."

     # mise-managed tools (if mise available)
     if command_exists mise; then
       local toml_dest="$HOME/.config/mise/conf.d/infra-tools.toml"

       cat > "$toml_dest" << 'EOF'
   [tools]
   terraform = "latest"
   kubectl = "latest"
   helm = "latest"

   # k9s via ubi backend (GitHub releases)
   "ubi:derailed/k9s" = "latest"
   EOF

       mise install
     else
       # Fallback: Native installations
       print_warning "mise not available, using native installations..."
       # ... (existing Terraform/kubectl/Helm install logic)
     fi

     # Specialized tools - always native
     print_status "Installing Ansible (apt)..."
     sudo apt-get update && sudo apt-get install -y ansible

     print_status "Installing Carvel tools..."
     # ... (existing Carvel install script)

     print_status "Installing Crossplane CLI..."
     # ... (existing Crossplane install logic)

     print_status "Installing Pulumi..."
     curl -fsSL https://get.pulumi.com | sh

     return 0
   }
   ```

2. **Update validate() Function** (30 min)
   - Check mise-managed tools: `terraform`, `kubectl`, `helm`, `k9s`
   - Check native tools: `ansible`, `kapp`, `ytt`, `kbld`, `crossplane`, `pulumi`

3. **Update status() Function** (30 min)
   - Show mise-managed tools
   - Show native tools
   - Group by installation method

**Success Criteria**:
- ✅ Terraform, kubectl, Helm, k9s install via mise
- ✅ Ansible, Carvel, Crossplane, Pulumi install natively
- ✅ All tools functional and validated

**Testing**:
```bash
terraform version
kubectl version --client
helm version
k9s version
ansible --version
kapp version
pulumi version
mise ls terraform kubectl helm
```

---

### Phase 2.4: Remaining Extensions - Status Only (3.5 hours)

**Objective**: Ensure all remaining extensions have standardized status() (should be done in Phase 0.3, verify here)

**Extensions to verify**:
- docker.extension (native - no changes)
- cloud-tools.extension (native - no changes)
- php.extension (native apt - no changes)
- dotnet.extension (native apt - no changes)
- jvm.extension (sdkman - no changes)
- github-cli.extension (pre-installed - no changes)
- claude-config.extension (npm - requires nodejs)
- playwright.extension (npm - requires nodejs)
- monitoring.extension (apt - no changes)
- tmux-workspace.extension (configuration - no changes)
- agent-manager.extension (custom - no changes)
- context-loader.extension (custom - no changes)
- workspace-structure.extension (mkdir - no changes)
- ssh-environment.extension (configuration - no changes)
- post-cleanup.extension (cleanup - no changes)

**Tasks**:
- Spot-check status() output for each extension (15 min each × 15 extensions = 3.75 hours, but can parallelize review)
- Fix any status() functions that don't follow standard format
- Ensure all have EXT_NAME, EXT_VERSION, EXT_DESCRIPTION, EXT_CATEGORY

**Success Criteria**:
- ✅ All 25 extensions have standardized status()
- ✅ No installation logic changes for non-mise extensions
- ✅ `extension-manager status-all` produces consistent output

---

## Phase 3: Documentation & BOM (Day 5)

### Phase 3.1: Update CLAUDE.md (1 hour)

**Objective**: Update project instructions with mise information

**Tasks**:

1. **Add mise Section** (30 min)
   ```markdown
   ## mise Tool Manager

   Sindri uses **mise** (https://mise.jdx.dev) for unified tool version management across multiple languages.

   ### mise-Managed Extensions

   - **nodejs**: Node.js LTS via mise (replaces NVM)
   - **python**: Python 3.13 + pipx tools via mise
   - **rust**: Rust stable + cargo tools via mise
   - **golang**: Go 1.24 + go tools via mise
   - **nodejs-devtools**: npm global tools via mise

   ### Common mise Commands

   ```bash
   mise ls                    # List all installed tools
   mise ls node               # List Node.js versions
   mise use node@20           # Switch Node.js version
   mise upgrade               # Update all tools
   mise doctor                # Check for issues
   ```

   ### Per-Project Tool Versions

   Create `mise.toml` in project root:
   ```toml
   [tools]
   node = "20"
   python = "3.11"
   ```

   mise automatically switches versions when entering the directory.
   ```

2. **Update Extension System Section** (30 min)
   - Update available extensions list with new descriptions
   - Add notes about mise-powered extensions
   - Update installation examples

**Success Criteria**:
- ✅ CLAUDE.md has comprehensive mise documentation
- ✅ Extension list updated
- ✅ Examples show mise usage

---

### Phase 3.2: Update README.md (1 hour)

**Objective**: Update main README with mise information

**Tasks**:

1. **Update Features Section** (15 min)
   - Add "Unified tool management via mise" to features list

2. **Update Quick Start** (15 min)
   - Mention mise for tool management
   - Update extension examples

3. **Update Extension System Section** (30 min)
   - Add mise-powered extensions callout
   - Update extension list with tool manager info

**Success Criteria**:
- ✅ README.md mentions mise prominently
- ✅ Quick start updated
- ✅ Extension system section accurate

---

### Phase 3.3: Update docs/ Files (2 hours)

**Objective**: Update all documentation files

**Files to update**:
- `docs/EXTENSIONS.md` - Add mise section, update extension details
- `docs/REFERENCE.md` - Add mise commands reference
- `docs/CONTRIBUTING.md` - Update development workflow with mise
- `docs/TROUBLESHOOTING.md` - Add mise troubleshooting section

**Tasks**:

1. **docs/EXTENSIONS.md** (45 min)
   - Add "mise-Powered Extensions" section
   - Document TOML configuration pattern
   - Add examples of creating mise-powered extensions
   - Update extension list with tool manager info

2. **docs/REFERENCE.md** (30 min)
   - Add mise commands section:
     - `mise ls`
     - `mise use`
     - `mise install`
     - `mise upgrade`
     - `mise doctor`
     - `mise config`
   - Document mise environment variables (MISE_EXPERIMENTAL, etc.)

3. **docs/CONTRIBUTING.md** (30 min)
   - Update development workflow with mise
   - Add section on creating mise-powered extensions
   - Document TOML file requirements

4. **docs/TROUBLESHOOTING.md** (15 min)
   - Add mise troubleshooting section:
     - Tool version conflicts
     - mise registry unavailable
     - Tool not found after installation
     - `mise doctor` output interpretation

**Success Criteria**:
- ✅ All docs/ files updated
- ✅ Comprehensive mise documentation
- ✅ No references to deprecated patterns

---

### Phase 3.4: Create BOM Reporting Scripts (2 hours)

**Objective**: Create scripts for Bill of Materials reporting

**Tasks**:

1. **Create scripts/generate-bom-report.sh** (1 hour)
   ```bash
   #!/bin/bash
   # Generate comprehensive BOM report

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
   if command -v mise >/dev/null 2>&1; then
     mise ls
   else
     echo "mise not installed"
   fi
   echo ""

   echo "=== Extension Status Report ==="
   cd /workspace/scripts/lib
   bash extension-manager.sh status-all
   ```

2. **Update extension-manager.sh with BOM Commands** (1 hour)

   Add these functions:
   - `bom()`: Generate BOM report
   - `bom-export()`: Export BOM as JSON
   - `bom-diff()`: Compare current BOM with previous snapshot

**Success Criteria**:
- ✅ `scripts/generate-bom-report.sh` works
- ✅ `extension-manager bom` generates report
- ✅ `extension-manager bom-export` produces JSON
- ✅ BOM report includes all installed tools with versions

**Testing**:
```bash
bash scripts/generate-bom-report.sh
extension-manager bom
extension-manager bom-export > bom.json
cat bom.json | jq .
```

---

### Phase 3.5: Update extension-manager.sh Final Features (2 hours)

**Objective**: Add remaining management features

**Tasks**:

1. **Add doctor Command** (30 min)
   ```bash
   doctor() {
     echo "=== Extension System Health Check ==="
     echo ""

     # Check mise
     if command_exists mise; then
       echo "Running mise doctor..."
       mise doctor
       echo ""
     else
       echo "⚠️  mise not installed"
     fi

     # Check active extensions
     echo "Validating all active extensions..."
     validate_all

     # Check for common issues
     echo ""
     echo "=== Common Issues Check ==="
     # Check disk space
     # Check permissions
     # Check network connectivity
     # etc.
   }
   ```

2. **Add upgrade-all Command** (30 min)
   ```bash
   upgrade_all() {
     echo "=== Upgrading All Tools ==="

     if command_exists mise; then
       echo "Upgrading mise-managed tools..."
       mise upgrade
       echo ""
     fi

     # Check for extension updates
     echo "Checking for extension updates..."
     # ... (check if extension versions have updates)
   }
   ```

3. **Add status-diff Command** (1 hour)
   ```bash
   status_diff() {
     local snapshot_file="${1:-/tmp/extension-status-snapshot.json}"

     if [[ ! -f "$snapshot_file" ]]; then
       echo "No snapshot found. Creating one now..."
       status_all --json > "$snapshot_file"
       echo "Snapshot saved to $snapshot_file"
       return 0
     fi

     # Compare current status with snapshot
     local current_status=$(mktemp)
     status_all --json > "$current_status"

     # Use jq to diff
     echo "=== Status Diff ==="
     # ... (show added/removed/changed tools)

     rm "$current_status"
   }
   ```

**Success Criteria**:
- ✅ `extension-manager doctor` checks system health
- ✅ `extension-manager upgrade-all` upgrades tools
- ✅ `extension-manager status-diff` compares snapshots
- ✅ All commands have proper error handling

---

## Phase 4: CI/CD & Testing (Day 6)

### Phase 4.1: Update validate.yml (30 min)

**Objective**: Add TOML validation

**Tasks**:

1. **Add TOML Validation Step** (30 min)
   ```yaml
   - name: Validate TOML syntax
     run: |
       echo "Validating extension TOML files..."
       pip install toml

       for toml in docker/lib/extensions.d/*.toml; do
         echo "Validating $toml..."
         python3 -c "import toml; toml.load(open('$toml'))" || exit 1
       done

       echo "✅ All TOML files are valid"

   - name: Verify extension-TOML pairs
     run: |
       echo "Checking mise-powered extensions have TOML files..."

       mise_extensions=("nodejs" "python" "rust" "golang" "nodejs-devtools")

       for ext in "${mise_extensions[@]}"; do
         if [[ ! -f "docker/lib/extensions.d/${ext}.toml" ]]; then
           echo "❌ Missing TOML for mise-powered extension: $ext"
           exit 1
         fi
         echo "✅ $ext.extension + $ext.toml pair verified"
       done
   ```

**Success Criteria**:
- ✅ TOML validation runs on all PRs
- ✅ Extension-TOML pairing verified
- ✅ Validation passes for all TOML files

---

### Phase 4.2: Update extension-tests.yml (3 hours)

**Objective**: Update matrix, add mise verification, optimize parallel execution

**Tasks**:

1. **Update Extension Matrix** (1 hour)
   ```yaml
   strategy:
     fail-fast: false
     max-parallel: 10  # Increase parallelism
     matrix:
       extension:
         # Core extensions
         - { name: 'workspace-structure', commands: 'mkdir,ls', key_tool: 'mkdir', timeout: '10m' }
         - { name: 'mise-config', commands: 'mise', key_tool: 'mise', timeout: '10m', uses_mise: 'true' }

         # mise-powered language extensions (faster with mise)
         - { name: 'nodejs', commands: 'node,npm', key_tool: 'node', timeout: '15m', depends_on: 'mise-config', uses_mise: 'true', version: '3.0.0' }
         - { name: 'python', commands: 'python3,pip3', key_tool: 'python3', timeout: '15m', depends_on: 'mise-config', uses_mise: 'true', version: '2.0.0' }
         - { name: 'rust', commands: 'rustc,cargo', key_tool: 'rustc', timeout: '20m', depends_on: 'mise-config', uses_mise: 'true', version: '2.0.0' }
         - { name: 'golang', commands: 'go', key_tool: 'go', timeout: '20m', depends_on: 'mise-config', uses_mise: 'true', version: '2.0.0' }
         - { name: 'nodejs-devtools', commands: 'tsc,eslint,prettier', key_tool: 'tsc', timeout: '15m', depends_on: 'mise-config,nodejs', uses_mise: 'true', version: '2.0.0' }

         # Traditional extensions (unchanged)
         - { name: 'ruby', commands: 'ruby,gem', key_tool: 'ruby', timeout: '25m', version: '1.0.0' }
         - { name: 'jvm', commands: 'java,sdk', key_tool: 'java', timeout: '30m', version: '1.0.0' }
         # ... rest of extensions
   ```

2. **Add mise Verification Steps** (1 hour)
   ```yaml
   - name: Verify mise-managed tools
     timeout-minutes: 2
     if: matrix.extension.uses_mise == 'true'
     run: |
       app_name="${{ steps.app-name.outputs.app_name }}"
       extension_name="${{ matrix.extension.name }}"

       flyctl ssh console --app $app_name --command "/bin/bash -lc '
         eval \"\$(mise activate bash)\"

         echo \"=== mise Tool Verification ===\"
         mise ls

         case \"$extension_name\" in
           nodejs)
             mise ls node && echo \"✅ Node.js managed by mise\"
             ;;
           python)
             mise ls python && echo \"✅ Python managed by mise\"
             mise ls pipx:* && echo \"✅ pipx tools managed by mise\"
             ;;
           rust)
             mise ls rust && echo \"✅ Rust managed by mise\"
             ;;
           golang)
             mise ls go && echo \"✅ Go managed by mise\"
             ;;
           nodejs-devtools)
             mise ls npm:* && echo \"✅ npm tools managed by mise\"
             ;;
         esac
       '"
   ```

3. **Add Status Output Validation** (1 hour)
   ```yaml
   - name: Test enhanced status() output
     timeout-minutes: 2
     run: |
       app_name="${{ steps.app-name.outputs.app_name }}"
       extension_name="${{ matrix.extension.name }}"

       status_output=$(flyctl ssh console --app $app_name --command "/bin/bash -c '
         cd /workspace/scripts/lib
         bash extension-manager.sh status $extension_name
       '")

       echo "$status_output"

       # Verify status output format
       if echo "$status_output" | grep -q "Extension:"; then
         echo "✅ Status shows extension metadata"
       else
         echo "❌ Status missing extension metadata"
         exit 1
       fi

       if echo "$status_output" | grep -q "Status:"; then
         echo "✅ Status shows installation status"
       else
         echo "❌ Status missing installation status"
         exit 1
       fi
   ```

**Success Criteria**:
- ✅ Extension matrix updated with mise flags
- ✅ mise verification runs for mise-powered extensions
- ✅ Status output validated for all extensions
- ✅ Parallel execution optimized (max-parallel: 10)
- ✅ Isolated volumes per test (no sharing)

---

### Phase 4.3: Update integration.yml (2 hours)

**Objective**: Add mise-stack combination testing

**Tasks**:

1. **Add mise-stack Combination** (1 hour)
   ```yaml
   matrix:
     combination:
       - { name: 'core-stack', extensions: 'workspace-structure,nodejs,ssh-environment', description: 'Core Infrastructure' }
       - { name: 'mise-stack', extensions: 'workspace-structure,mise-config,nodejs,python,rust,golang,ssh-environment', description: 'mise-Powered Languages' }
       - { name: 'full-node', extensions: 'workspace-structure,nodejs,nodejs-devtools,claude-config', description: 'Complete Node.js Development Stack' }
       # ... rest of combinations
   ```

2. **Add mise Verification in Cross-Extension Tests** (1 hour)
   ```yaml
   - name: Test cross-extension functionality
     run: |
       combo="${{ matrix.combination.name }}"

       case "$combo" in
         mise-stack)
           echo "Testing mise-Powered Language Stack..."

           # Verify mise is installed
           if ! command -v mise >/dev/null 2>&1; then
             echo "❌ mise not installed"
             exit 1
           fi
           echo "✅ mise: $(mise --version)"

           # Verify mise manages the tools
           echo ""
           echo "mise-managed tools:"
           mise ls

           # Test each language
           echo ""
           echo "Testing Node.js (via mise)..."
           node --version && npm --version
           mise ls node && echo "✅ Node.js managed by mise"

           echo ""
           echo "Testing Python (via mise)..."
           python3 --version
           mise ls python && echo "✅ Python managed by mise"

           echo ""
           echo "Testing Rust (via mise)..."
           rustc --version && cargo --version
           mise ls rust && echo "✅ Rust managed by mise"

           echo ""
           echo "Testing Go (via mise)..."
           go version
           mise ls go && echo "✅ Go managed by mise"

           echo "✅ mise-powered language stack verified"
           ;;
         # ... other cases
       esac
   ```

**Success Criteria**:
- ✅ mise-stack combination tests all Phase 1 extensions together
- ✅ Cross-extension functionality verified
- ✅ mise tool management validated

---

### Phase 4.4: Update integration-resilient.yml (1 hour)

**Objective**: Add mise retry logic

**Tasks**:

1. **Add mise Installation Retry** (1 hour)
   ```yaml
   - name: Install extensions with retry
     uses: nick-invision/retry@v2
     with:
       timeout_minutes: 30
       max_attempts: 3
       retry_on: error
       command: |
         flyctl ssh console --app ${{ steps.app-name.outputs.app_name }} --command "/bin/bash -c '
           cd /workspace/scripts/lib

           # Install with retry for mise-powered extensions
           if bash extension-manager.sh install-all; then
             echo \"✅ Extensions installed\"
           else
             echo \"⚠️  Installation failed, checking mise status...\"
             if command -v mise >/dev/null 2>&1; then
               mise doctor
             fi
             exit 1
           fi
         '"
   ```

**Success Criteria**:
- ✅ Retry logic handles mise installation failures
- ✅ mise doctor runs on failure for debugging

---

### Phase 4.5: Optimize CI Execution (1.5 hours)

**Objective**: Implement parallel execution with isolated volumes

**Tasks**:

1. **Update VM Creation Strategy** (1 hour)
   - Ensure each test creates its own VM with isolated volume
   - No volume sharing between tests
   - Use unique app names: `test-${extension}-${timestamp}`

2. **Increase Parallelism** (30 min)
   - Set `max-parallel: 10` in extension-tests.yml
   - Verify Fly.io account limits support 10 concurrent VMs
   - Add concurrency groups to prevent resource exhaustion

**Example**:
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}-${{ matrix.extension.name }}
  cancel-in-progress: true

strategy:
  fail-fast: false
  max-parallel: 10
```

**Success Criteria**:
- ✅ Each test has isolated VM + volume
- ✅ Up to 10 tests run in parallel
- ✅ CI execution time reduced (target: <60 min total)

---

## Phase 5: Validation & Fixes (Day 7)

### Phase 5.1: End-to-End Testing (4 hours)

**Objective**: Test complete workflow from fresh deployment to full stack

**Test Scenarios**:

1. **Minimal Stack Test** (1 hour)
   ```bash
   # Deploy with minimal extensions
   export APP_NAME="test-minimal-$(date +%s)"
   ./scripts/vm-setup.sh --app-name $APP_NAME

   # SSH in
   flyctl ssh console -a $APP_NAME

   # Install minimal stack
   cd /workspace/scripts/lib
   cat > extensions.d/active-extensions.conf << EOF
   workspace-structure
   mise-config
   nodejs
   ssh-environment
   EOF

   bash extension-manager.sh install-all

   # Validate
   node --version
   npm --version
   mise ls
   extension-manager status-all

   # Cleanup
   exit
   flyctl apps destroy $APP_NAME --yes
   ```

2. **Full Language Stack Test** (1 hour)
   ```bash
   # Deploy with all Phase 1 languages
   export APP_NAME="test-languages-$(date +%s)"
   ./scripts/vm-setup.sh --app-name $APP_NAME

   flyctl ssh console -a $APP_NAME

   cd /workspace/scripts/lib
   cat > extensions.d/active-extensions.conf << EOF
   workspace-structure
   mise-config
   nodejs
   python
   rust
   golang
   nodejs-devtools
   ssh-environment
   EOF

   bash extension-manager.sh install-all

   # Validate all languages
   node --version
   python3 --version
   rustc --version
   go version
   tsc --version

   mise ls
   extension-manager status-all
   extension-manager bom

   # Test mise operations
   mise doctor
   mise upgrade

   # Cleanup
   exit
   flyctl apps destroy $APP_NAME --yes
   ```

3. **Infrastructure Stack Test** (1 hour)
   ```bash
   # Deploy with infrastructure tools
   export APP_NAME="test-infra-$(date +%s)"
   ./scripts/vm-setup.sh --app-name $APP_NAME

   flyctl ssh console -a $APP_NAME

   cd /workspace/scripts/lib
   cat > extensions.d/active-extensions.conf << EOF
   workspace-structure
   mise-config
   infra-tools
   cloud-tools
   docker
   ssh-environment
   EOF

   bash extension-manager.sh install-all

   # Validate infrastructure tools
   terraform version
   kubectl version --client
   helm version
   k9s version
   ansible --version
   docker --version
   aws --version

   mise ls terraform kubectl helm
   extension-manager status-all

   # Cleanup
   exit
   flyctl apps destroy $APP_NAME --yes
   ```

4. **Complete Stack Test** (1 hour)
   ```bash
   # Deploy with ALL extensions
   export APP_NAME="test-complete-$(date +%s)"
   export VM_MEMORY="4096"  # Need more memory for everything
   ./scripts/vm-setup.sh --app-name $APP_NAME

   flyctl ssh console -a $APP_NAME

   cd /workspace/scripts/lib
   # Use default active-extensions.conf (all extensions)
   bash extension-manager.sh install-all

   # Validate everything
   extension-manager validate-all
   extension-manager status-all
   extension-manager bom > /tmp/bom-report.txt
   cat /tmp/bom-report.txt

   # Cleanup
   exit
   flyctl apps destroy $APP_NAME --yes
   ```

**Success Criteria**:
- ✅ All test scenarios pass
- ✅ No installation errors
- ✅ All tools functional
- ✅ mise operations work correctly
- ✅ BOM reporting accurate

---

### Phase 5.2: CI/CD Validation (2 hours)

**Objective**: Verify all CI workflows pass

**Tasks**:

1. **Trigger All Workflows** (30 min)
   - Push to feature branch
   - Create PR
   - Verify all workflows trigger

2. **Monitor Workflow Execution** (1 hour)
   - Watch validate.yml (should be ~5 min)
   - Watch extension-tests.yml (target: <60 min with parallelism)
   - Watch integration.yml (should be ~15 min)
   - Watch integration-resilient.yml (should be ~20 min)

3. **Fix Any Failures** (30 min)
   - Review logs for any failures
   - Fix issues found
   - Re-run failed workflows

**Success Criteria**:
- ✅ validate.yml passes
- ✅ extension-tests.yml passes (all 25 extensions)
- ✅ integration.yml passes (all combinations)
- ✅ integration-resilient.yml passes
- ✅ TOML validation passes
- ✅ Status output validation passes

---

### Phase 5.3: Test Coverage Verification (1 hour)

**Objective**: Ensure 100% test coverage for installed tools

**Tasks**:

1. **Create Coverage Report Script** (30 min)
   ```bash
   #!/bin/bash
   # scripts/test-coverage-report.sh

   echo "=== Extension Test Coverage Report ==="
   echo ""

   # For each extension, check if it's tested in CI
   extensions=$(ls docker/lib/extensions.d/*.extension)

   for ext_file in $extensions; do
     ext_name=$(basename "$ext_file" .extension)

     echo "Checking $ext_name..."

     # Check if extension is in extension-tests.yml matrix
     if grep -q "name: '$ext_name'" .github/workflows/extension-tests.yml; then
       echo "  ✅ In extension-tests.yml matrix"
     else
       echo "  ❌ NOT in extension-tests.yml matrix"
     fi

     # Check if tools are validated
     # ... (check validate() function exists and is comprehensive)
   done
   ```

2. **Run Coverage Report** (30 min)
   - Execute coverage report script
   - Verify 100% coverage
   - Fix any gaps found

**Success Criteria**:
- ✅ All 25 extensions in CI matrix
- ✅ All installed tools have validation tests
- ✅ 100% coverage achieved (excluding CI_MODE-skipped tools)

---

### Phase 5.4: Documentation Review (1 hour)

**Objective**: Final review of all documentation

**Tasks**:

1. **Review All Documentation Files** (1 hour)
   - CLAUDE.md - accurate and complete?
   - README.md - up-to-date?
   - docs/EXTENSIONS.md - comprehensive?
   - docs/REFERENCE.md - all commands documented?
   - docs/CONTRIBUTING.md - development workflow clear?
   - docs/TROUBLESHOOTING.md - common issues covered?

2. **Check for Inconsistencies**
   - No references to deprecated patterns (NVM in nodejs, etc.)
   - All mise extensions documented
   - All new commands documented
   - Examples accurate

**Success Criteria**:
- ✅ All documentation reviewed
- ✅ No inconsistencies found
- ✅ Examples tested and working

---

## Success Metrics & Criteria

### Phase 0 Success Criteria

- ✅ All 25 extensions renamed to `.extension`
- ✅ mise-config.extension created and working
- ✅ 9 TOML files created (5 main + 4 CI)
- ✅ extension-manager.sh updated for `.extension` handling
- ✅ extension-manager.sh has status-all, doctor, upgrade-all commands
- ✅ All 25 extensions have standardized status() output
- ✅ CI workflows updated with new file patterns

### Phase 1 Success Criteria

- ✅ nodejs.extension uses mise (code reduced ~60%)
- ✅ python.extension uses mise
- ✅ rust.extension uses mise
- ✅ golang.extension uses mise
- ✅ nodejs-devtools.extension uses mise
- ✅ All Phase 1 extensions functional and validated
- ✅ CI_MODE uses minimal TOML configs

### Phase 2 Success Criteria

- ✅ ruby.extension status() standardized (no other changes)
- ✅ ai-tools.extension uses native + selective mise
- ✅ infra-tools.extension uses selective mise
- ✅ All other extensions status() standardized
- ✅ No breaking changes to non-mise extensions

### Phase 3 Success Criteria

- ✅ CLAUDE.md fully updated
- ✅ README.md fully updated
- ✅ All docs/ files updated
- ✅ BOM reporting scripts created and working
- ✅ extension-manager has complete feature set

### CI/CD Success Criteria

- ✅ All CI workflows passing
- ✅ TOML validation working
- ✅ mise verification working
- ✅ Status output validation working
- ✅ Parallel execution optimized
- ✅ Test execution time acceptable

### Overall Success Criteria

- ✅ 100% test coverage for installed tools
- ✅ All 25 extensions working
- ✅ Fresh deployments work end-to-end
- ✅ mise-powered extensions functional
- ✅ Non-mise extensions unchanged (except status())
- ✅ Documentation complete and accurate
- ✅ No backward compatibility required
- ✅ Implementation completed in 7 days

---

## Risk Mitigation

### Risk 1: mise Installation Failures

**Mitigation**:
- Implement retry logic in install() functions
- Add mise doctor checks in validate() functions
- Fallback to native installation if mise unavailable (for hybrid extensions)

### Risk 2: TOML Configuration Errors

**Mitigation**:
- TOML validation in CI (validate.yml)
- Test TOML files manually before committing
- Use template.toml as reference

### Risk 3: Tool Version Conflicts

**Mitigation**:
- Pin specific versions in TOML where needed
- Test version switching with `mise use`
- Document version pinning strategy

### Risk 4: CI Pipeline Timeout

**Mitigation**:
- Increase parallelism (max-parallel: 10)
- Use isolated volumes (no sharing)
- Optimize extension installation (CI_MODE minimal configs)
- Monitor and adjust timeouts as needed

### Risk 5: Breaking Existing Deployments

**Mitigation**:
- Not a concern (fresh deployments only)
- Document breaking changes in CHANGELOG
- Provide clear upgrade instructions

---

## Rollback Procedures

### When to Rollback

**Stop immediately if**:
- mise installation consistently fails (>50% failure rate)
- Tool functionality broken after mise migration
- CI pipeline broken and can't be fixed within 2 hours
- Critical bug found in mise-powered extensions

### How to Rollback

Since there's no backward compatibility requirement:

1. **Revert Git Commits**
   ```bash
   git revert <commit-range>
   git push origin main
   ```

2. **Redeploy VMs**
   - All VMs must be redeployed with previous version
   - No migration needed (fresh deployments)

3. **Document Issues**
   - Create GitHub issue with failure details
   - Include logs, error messages, reproduction steps

---

## Timeline Summary

| Day | Phase | Tasks | Estimated Hours |
|-----|-------|-------|-----------------|
| **Day 1** | Phase 0.0-0.1 | File renaming, mise infrastructure | 8h |
| **Day 2** | Phase 0.2-0.3 | Extension manager updates, status() standardization | 8h |
| **Day 3** | Phase 1 | Refactor 5 core mise extensions | 8h |
| **Day 4** | Phase 2 | Remaining extensions (ruby, ai-tools, infra-tools, others) | 8h |
| **Day 5** | Phase 3 | Documentation & BOM reporting | 8h |
| **Day 6** | CI/CD | Update workflows, testing infrastructure | 8h |
| **Day 7** | Validation | End-to-end testing, fixes, final validation | 8h |

**Total**: 56 hours (7 days × 8 hours/day)

---

## Daily Checklist

### Day 1 Checklist

- [ ] Rename all 25 .sh.example → .extension files
- [ ] Update extension-manager.sh for .extension handling
- [ ] Update CI workflow path filters
- [ ] Create mise-config.extension
- [ ] Create 9 TOML files (5 main + 4 CI)
- [ ] Create template.toml
- [ ] Validate all TOML files
- [ ] Test mise-config installation
- [ ] Commit and push changes

### Day 2 Checklist

- [ ] Add status-all command to extension-manager.sh
- [ ] Add doctor, upgrade-all, status-export commands
- [ ] Standardize status() in all 25 extensions
- [ ] Add EXT_NAME, EXT_VERSION, EXT_DESCRIPTION, EXT_CATEGORY to all extensions
- [ ] Test status-all output
- [ ] Test status-all --json output
- [ ] Commit and push changes

### Day 3 Checklist

- [ ] Refactor nodejs.extension
- [ ] Refactor python.extension
- [ ] Refactor rust.extension
- [ ] Refactor golang.extension
- [ ] Refactor nodejs-devtools.extension
- [ ] Test each extension individually
- [ ] Verify CI_MODE uses minimal TOML
- [ ] Commit and push changes

### Day 4 Checklist

- [ ] Verify ruby.extension status() (no other changes)
- [ ] Refactor ai-tools.extension (native + selective mise)
- [ ] Refactor infra-tools.extension (selective mise)
- [ ] Verify all other extensions have standardized status()
- [ ] Test ruby, ai-tools, infra-tools
- [ ] Commit and push changes

### Day 5 Checklist

- [ ] Update CLAUDE.md
- [ ] Update README.md
- [ ] Update docs/EXTENSIONS.md
- [ ] Update docs/REFERENCE.md
- [ ] Update docs/CONTRIBUTING.md
- [ ] Update docs/TROUBLESHOOTING.md
- [ ] Create scripts/generate-bom-report.sh
- [ ] Add BOM commands to extension-manager.sh
- [ ] Test BOM reporting
- [ ] Commit and push changes

### Day 6 Checklist

- [ ] Update validate.yml (add TOML validation)
- [ ] Update extension-tests.yml (matrix, mise verification)
- [ ] Update integration.yml (mise-stack combination)
- [ ] Update integration-resilient.yml (mise retry)
- [ ] Optimize CI parallelism (max-parallel: 10)
- [ ] Test CI workflows on feature branch
- [ ] Fix any CI failures
- [ ] Commit and push changes

### Day 7 Checklist

- [ ] Run minimal stack test
- [ ] Run full language stack test
- [ ] Run infrastructure stack test
- [ ] Run complete stack test
- [ ] Verify all CI workflows pass
- [ ] Run test coverage report
- [ ] Review all documentation
- [ ] Fix any issues found
- [ ] Final commit and push
- [ ] Create PR to main
- [ ] Merge PR after approval

---

## Post-Implementation Tasks

After successful implementation:

1. **Announce Changes** (30 min)
   - Create CHANGELOG entry
   - Update version number
   - Notify users of breaking changes

2. **Monitor Deployments** (ongoing)
   - Watch for issues in new deployments
   - Collect feedback from users
   - Address any bugs found

3. **Optimization** (ongoing)
   - Monitor CI execution times
   - Optimize TOML configs if needed
   - Update documentation based on feedback

---

## Appendix A: Tool Decision Matrix

| Tool | Manager | Rationale |
|------|---------|-----------|
| **Node.js** | mise | Native support, replaces NVM cleanly |
| **Python** | mise | Native + pipx backend, better than system |
| **Rust** | mise | Native support, replaces rustup |
| **Go** | mise | Native + go backend for tools |
| **TypeScript/ESLint/etc** | mise | npm backend, clean global installs |
| **Ruby** | rbenv | Keep current - rbenv mature and stable |
| **Java** | sdkman | Keep current - sdkman superior for JVM |
| **PHP** | apt | Keep current - Ondrej PPA well-maintained |
| **.NET** | apt | Keep current - Microsoft repos stable |
| **Docker** | native | Keep current - requires system-level install |
| **Terraform** | mise | Well-supported, simple version management |
| **kubectl** | mise | Well-supported |
| **Helm** | mise | Well-supported |
| **k9s** | mise | Available via ubi backend |
| **Ansible** | apt | Native system package preferred |
| **Carvel** | native | Custom install script required |
| **Crossplane** | native | Specialized CLI |
| **Pulumi** | native | Has own version management |
| **Cloud CLIs** | native | Official installers preferred |
| **Ollama** | native | Binary install required |
| **Fabric** | native | Git clone + go build |
| **Monitoring tools** | apt | System tools, native preferred |

---

## Appendix B: File Structure After Refactor

```
docker/lib/extensions.d/
├── workspace-structure.extension
├── ssh-environment.extension
├── post-cleanup.extension
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
├── ruby.extension
├── php.extension
├── jvm.extension
├── dotnet.extension
├── docker.extension
├── infra-tools.extension
├── infra-tools.toml (selective tools)
├── cloud-tools.extension
├── ai-tools.extension
├── ai-tools.toml (selective tools)
├── github-cli.extension
├── claude-config.extension
├── playwright.extension
├── monitoring.extension
├── tmux-workspace.extension
├── agent-manager.extension
├── context-loader.extension
├── template.extension
├── template.toml
└── active-extensions.conf.example

scripts/
├── generate-bom-report.sh
├── update-status-functions.sh (temporary)
└── test-coverage-report.sh
```

---

## Appendix C: Key Commands Reference

### Extension Management
```bash
extension-manager list                # List all extensions
extension-manager install <name>      # Install extension
extension-manager install-all         # Install all active
extension-manager status <name>       # Show extension status
extension-manager status-all          # Show all statuses
extension-manager status-all --json   # JSON export
extension-manager validate <name>     # Validate installation
extension-manager validate-all        # Validate all
extension-manager doctor              # Health check
extension-manager upgrade-all         # Upgrade tools
extension-manager bom                 # Bill of materials
extension-manager bom-export          # BOM as JSON
extension-manager remove <name>       # Uninstall extension
```

### mise Commands
```bash
mise ls                   # List installed tools
mise ls <tool>            # List specific tool versions
mise use <tool>@<version> # Install and use version
mise install              # Install from TOML
mise upgrade              # Upgrade all tools
mise doctor               # Check for issues
mise config               # Show merged config
mise current <tool>       # Show active version
mise ls-remote <tool>     # List available versions
mise prune                # Remove unused tools
```

### Testing Commands
```bash
# Deploy test VM
CI_MODE=true ./scripts/vm-setup.sh --app-name test-vm

# Run BOM report
bash scripts/generate-bom-report.sh

# Run test coverage report
bash scripts/test-coverage-report.sh

# Validate TOML files
pip install toml
for toml in docker/lib/extensions.d/*.toml; do
  python3 -c "import toml; toml.load(open('$toml'))"
done
```

---

## Questions?

This implementation plan is comprehensive and actionable for a 1-week solo implementation. Each phase has clear tasks, time estimates, success criteria, and testing procedures.

**Ready to begin?** Start with Day 1, Phase 0.0 (File Renaming). Let me know if you need clarification on any section or want me to help with specific implementation tasks.
