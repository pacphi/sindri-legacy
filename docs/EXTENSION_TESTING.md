# Extension System Testing

## Table of Contents

- [Overview](#overview)
- [CI Environment Setup](#ci-environment-setup)
- [Test Coverage](#test-coverage)
- [Test Fixtures](#test-fixtures)
- [Workflow Triggers](#workflow-triggers)
- [Test Coverage Metrics](#test-coverage-metrics)
- [Resource Requirements](#resource-requirements)
- [Interpreting Results](#interpreting-results)
- [Adding New Extensions](#adding-new-extensions)
- [Best Practices](#best-practices)
- [Continuous Improvement](#continuous-improvement)

---

## Overview

The extension testing workflow [extension-tests](../.github/workflows/extension-tests.yml) provides automated validation and functional testing for all extensions in the `docker/lib/extensions.d/` directory.

This comprehensive testing ensures that users can confidently activate and use any extension through the `extension-manager` command without encountering issues. Each extension implements the **Extension API** (see [EXTENSIONS.md](EXTENSIONS.md#extension-api-specification)) with 6-7 required functions.

### Testing Philosophy

The test suite is designed to:

1. **Validate All API Functions** - Test all Extension API functions for compliance
2. **Enforce System Policies** - Verify protected extensions cannot be removed
3. **Test Edge Cases** - Cleanup ordering, dependency chains, manifest operations
4. **Ensure Reliability** - Idempotency, error handling, and conflict detection
5. **Maintain Quality** - Syntax validation, best practices, and documentation

### Test Statistics

- **Total Test Jobs**: 10
- **Extensions Tested**: 24 out of 25 (96%)
- **API Functions Coverage**: 100% (6/6 v1.0, 7/7 v2.0)
- **Feature Coverage**: 97%
- **Test Fixtures**: 4 manifest test files

---

## CI Environment Setup

### Extension Auto-Installation Architecture

The CI testing environment uses a two-phase approach to set up extensions:

#### Phase 1: Manifest Template Deployment (Build Time)

**File**: `docker/lib/extensions.d/active-extensions.ci.conf`

This pre-configured template is built into the Docker image and contains:

- All protected extensions (workspace-structure, mise-config, ssh-environment)
- Comprehensive documentation and comments
- Proper execution order (protected extensions first)

**Purpose**: Provides a blueprint of what extensions should be installed in CI mode.

#### Phase 2: Runtime Installation (Container Startup)

**File**: `docker/scripts/entrypoint.sh` (lines 52-97, 176-190)

When the container starts, entrypoint.sh executes in sequence:

1. **Copy Library to Persistent Volume** (lines 52-55)

   ```bash
   if [ ! -d "/workspace/scripts/lib" ]; then
       cp -r /docker/lib /workspace/scripts/
   ```

   - Only runs on first boot (volume empty)
   - Copies extension library and manager from Docker image

2. **Select Appropriate Manifest** (lines 57-89)

   ```bash
   if [ "$CI_MODE" = "true" ]; then
       cp /docker/lib/extensions.d/active-extensions.ci.conf \
          /workspace/scripts/extensions.d/active-extensions.conf
   ```

   - CI mode: Uses CI template (pre-configured with protected extensions)
   - Production mode: Uses CI template as default or existing manifest

3. **Auto-Install Protected Extensions** (lines 176-190)
   ```bash
   if ! sudo -u developer bash -c 'command -v mise' &>/dev/null; then
       sudo -u developer HOME=/workspace/developer bash -c \
           'cd /workspace/scripts/lib && extension-manager install-all'
   ```

   - Detects if extensions already installed (checks for `mise` command)
   - If not installed: Runs `extension-manager install-all`
   - Reads manifest created in Phase 2
   - Executes installation for all listed extensions
   - Runs as developer user with proper HOME environment

#### Why Two Phases?

**The Problem Solved:**

- Initial attempt only copied manifest → Extensions listed but never installed
- Tests failed with "mise not found" because mise-config never executed

**The Solution:**

1. **Template (Phase 1)**: Defines WHAT to install (declarative)
2. **Installation (Phase 2)**: Actually installs it (imperative)

**Benefits:**

- ✅ Idempotent: Only installs on first boot (checks `mise` presence)
- ✅ Transparent: Installation logs visible in container startup output
- ✅ Flexible: Works for both CI and production deployments
- ✅ Persistent: Volume storage means installs survive restarts

#### Manifest Flow Diagram

```
Docker Build
    │
    ├─→ active-extensions.ci.conf (template)
    │
    ▼
Container Startup (entrypoint.sh)
    │
    ├─→ Check: First boot? (/workspace/scripts/lib missing?)
    │   │
    │   ├─→ YES: Copy lib/ to /workspace/scripts/
    │   │         Copy active-extensions.ci.conf → active-extensions.conf
    │   │
    │   └─→ NO: Skip (volume already has lib/)
    │
    ├─→ Check: mise installed? (mise-config extension ran?)
    │   │
    │   ├─→ NO: Run extension-manager install-all
    │   │        └─→ Reads active-extensions.conf
    │   │            └─→ Installs: workspace-structure, mise-config, ssh-environment
    │   │
    │   └─→ YES: Skip (already installed on previous boot)
    │
    ▼
Container Ready
    │
    ├─→ Protected extensions: ✓ Installed and functional
    ├─→ mise: ✓ Available in PATH
    └─→ Workspace: ✓ Directory structure created
```

#### Testing Implications

**Workflow Verification Steps** (integration.yml, extension-tests.yml):

After deployment, workflows verify:

```bash
# 1. Manifest exists and has protected extensions
grep -q "^workspace-structure$" /workspace/scripts/extensions.d/active-extensions.conf
grep -q "^mise-config$" /workspace/scripts/extensions.d/active-extensions.conf
grep -q "^ssh-environment$" /workspace/scripts/extensions.d/active-extensions.conf

# 2. Extensions were actually installed (not just listed)
mise --version           # Proves mise-config ran
ls /workspace/projects   # Proves workspace-structure ran
```

**Key Difference from Production:**

- **CI**: Fresh volume every test → Always runs installation on first boot
- **Production**: Persistent volume → Installation runs once, then skipped

#### Debugging Extension Installation

**Check if auto-installation ran:**

```bash
# View container startup logs
flyctl logs --app <app-name> | grep "Installing protected extensions"

# Expected output:
# 🔧 Installing protected extensions...
# [INFO] Installing extension: workspace-structure
# [SUCCESS] Extension 'workspace-structure' installed successfully
# [INFO] Installing extension: mise-config
# [SUCCESS] Extension 'mise-config' installed successfully
# [INFO] Installing extension: ssh-environment
# [SUCCESS] Extension 'ssh-environment' installed successfully
# ✅ Protected extensions installed
```

**If mise not found:**

1. Check entrypoint logs for installation errors
2. Verify CI_MODE secret is set: `flyctl secrets list --app <name>`
3. Verify manifest was created: `flyctl ssh console -C "cat /workspace/scripts/extensions.d/active-extensions.conf"`
4. Manually trigger: `flyctl ssh console -C "extension-manager install-all"`

---

## Test Coverage

The extension testing workflow includes **10 comprehensive test jobs** covering all aspects of the Extension API:

### 1. Extension Manager Validation

Tests the core extension management system (**Extension API v1.0/v2.0**):

- **Script Syntax**: Validates `extension-manager.sh` with shellcheck
- **List Command**: Verifies extension listing functionality via `extension-manager list`
- **Name Extraction**: Tests extraction of extension names from `.extension` files
- **Manifest Operations**: Tests reading/writing `active-extensions.conf`
- **Basic Functionality**: Validates core extension-manager operations

**When It Runs**: On every push/PR affecting extension files

### 2. Extension Syntax Validation

Validates all extension scripts for code quality:

- **Shellcheck Analysis**: Static analysis of all `.extension` files
- **Common.sh Sourcing**: Verifies proper utility function imports
- **Shebang Verification**: Ensures all scripts have `#!/bin/bash`
- **Error Handling**: Checks for use of print functions and error handling
- **Best Practices**: Validates adherence to extension development guidelines
- **API Compliance**: Verifies all required API functions are defined

**When It Runs**: On every push/PR affecting extension files

### 3. Per-Extension Tests (Matrix)

Comprehensive functional testing for each extension individually using the Extension API.

For complete Extension API specification, see [EXTENSIONS.md - Extension API Specification](EXTENSIONS.md#extension-api-specification).

#### Tested Extensions (24 Total)

| Extension                    | Key Tools          | Dependencies        | Test Focus               |
| ---------------------------- | ------------------ | ------------------- | ------------------------ |
| **Core (Protected)**         |                    |                     |                          |
| workspace-structure          | mkdir, ls          | -                   | Directory creation       |
| mise-config                  | mise               | -                   | Tool version manager     |
| ssh-environment              | ssh, sshd          | -                   | SSH daemon config        |
| **Languages (mise-powered)** |                    |                     |                          |
| nodejs                       | node, npm          | mise-config         | Runtime, package manager |
| python                       | python3, pip3      | mise-config         | Execution, packages      |
| rust                         | rustc, cargo       | mise-config         | Compilation, cargo       |
| golang                       | go                 | mise-config         | Compilation, modules     |
| nodejs-devtools              | tsc, eslint        | mise-config, nodejs | TypeScript, linting      |
| **Languages (Traditional)**  |                    |                     |                          |
| ruby                         | ruby, gem, bundle  | -                   | Ruby execution, Rails    |
| php                          | php, composer      | -                   | PHP, Symfony             |
| jvm                          | java, sdk          | -                   | SDKMAN, Java             |
| dotnet                       | dotnet             | -                   | .NET SDK, ASP.NET        |
| **Claude AI**                |                    |                     |                          |
| claude-config                | claude             | nodejs              | CLI authentication       |
| **Infrastructure**           |                    |                     |                          |
| docker                       | docker, compose    | -                   | Container runtime        |
| infra-tools                  | terraform, ansible | -                   | IaC tools                |
| cloud-tools                  | aws                | -                   | Cloud CLIs               |
| ai-tools                     | codex, gemini      | nodejs              | AI assistants            |
| **Utilities**                |                    |                     |                          |
| playwright                   | playwright         | nodejs              | Browser automation       |
| monitoring                   | claude-monitor     | python, nodejs      | Usage tracking           |
| tmux-workspace               | tmux               | -                   | Session management       |
| agent-manager                | agent-manager      | -                   | Agent management         |
| context-loader               | context-load       | -                   | Context utilities        |
| github-cli                   | gh                 | -                   | GitHub CLI               |
| post-cleanup                 | echo               | -                   | Post-install cleanup     |

#### Test Steps

For each extension using `extension-manager`:

1. **Dependency Installation**: Auto-install dependencies based on `depends_on` field
2. **Manifest Addition**: Add extension to `active-extensions.conf`
3. **Installation**: `extension-manager install-all` (runs prerequisites, install, configure)
4. **Command Availability**: Verify all expected commands in PATH
5. **mise Verification**: For mise-powered extensions, verify managed by mise
6. **Key Functionality**: Test core capability (compilation, execution, etc.)
7. **Status Check**: `extension-manager status <name>` shows metadata
8. **Idempotency**: Re-run installation to verify safe re-execution
9. **Resource Cleanup**: Destroy test VM and volumes

**When It Runs**:

- On push/PR affecting extension files
- On workflow dispatch (all or specific extension)

### 4. Extension API Tests (CRITICAL)

Tests all Extension API functions for compliance.

For complete Extension API specification, see [EXTENSIONS.md - Extension API Specification](EXTENSIONS.md#extension-api-specification).

#### Functions Tested

- **validate()**: Verifies installed extension passes validation checks
- **status()**: Confirms output includes Extension name and Status fields
- **uninstall()**: Tests that remove() function is called and cleans up properly
- **deactivate()**: Verifies extension is removed from manifest
- **upgrade()** (v2.0): Tests upgrade functionality for API v2.0 extensions

#### Test Matrix

Representative sample of 6 extensions tested for full API compliance:

- nodejs (mise-powered language)
- python (mise-powered language)
- rust (mise-powered language)
- golang (mise-powered language)
- tmux-workspace (traditional utility)
- monitoring (multi-dependency extension)

**When It Runs**: On every push/PR affecting extension files

### 5. Protected Extensions Tests (CRITICAL)

Tests enforcement of protected extension policies.

For details on protected extensions, see [EXTENSIONS.md - Protected Extensions](EXTENSIONS.md#protected-extensions).

#### Protection Tests

- **Deactivation Prevention**: Protected extensions cannot be deactivated
  - Tests: workspace-structure, mise-config, ssh-environment
  - Verifies error message mentions "protected"
- **Uninstall Prevention**: Protected extensions cannot be uninstalled
  - Verifies error message mentions "cannot uninstall protected"
- **Auto-Repair**: Missing protected extensions are auto-added to manifest
  - Removes protected extensions from manifest
  - Runs `extension-manager list` to trigger repair
  - Verifies all protected extensions restored to top
- **Visual Markers**: Protected extensions show `[PROTECTED]` in list output

**When It Runs**: On every push/PR affecting extension files

### 6. Cleanup Extensions Tests (CRITICAL)

Tests automatic ordering of cleanup extensions:

#### Cleanup Ordering Tests

- **Auto-Move to End**: post-cleanup automatically moves to end of manifest
  - Uses test fixture with post-cleanup in middle
  - Triggers `ensure_cleanup_extensions_last()` via list command
  - Verifies post-cleanup is in last 3 lines
- **Protected Extensions Preserved**: Protected extensions stay at top during cleanup reordering
- **Installation Order**: Verifies cleanup extensions run after other extensions

**Test Fixtures Used**: `.github/workflows/test-fixtures/manifest-cleanup-middle.conf`

**When It Runs**: On every push/PR affecting extension files

### 7. Manifest Operations Tests

Tests manifest file operations and integrity:

#### Operations Tested

- **Reorder Functionality**:
  - Tests `extension-manager reorder <name> <position>`
  - Verifies extension moves to exact position
  - Uses test fixture with 6 extensions
- **Comment Preservation**:
  - Tests deactivate preserves user comments in manifest
  - Verifies header comments, section comments, inline comments preserved
  - Uses test fixture with multiple comment types

**Test Fixtures Used**:

- `.github/workflows/test-fixtures/manifest-reorder-test.conf`
- `.github/workflows/test-fixtures/manifest-with-comments.conf`

**When It Runs**: On every push/PR affecting extension files

### 8. Dependency Chain Tests

Tests dependency resolution and error handling:

#### Dependency Tests

- **Transitive Dependencies**:
  - Tests multi-level dependency chain (nodejs-devtools → nodejs → mise-config)
  - Adds only top-level extension to manifest
  - Verifies all dependencies auto-install
  - Uses test fixture with single extension
- **Missing Dependency Errors**:
  - Disables mise temporarily to break prerequisites
  - Attempts to install nodejs (which depends on mise-config)
  - Verifies installation fails with clear error message
  - Confirms error mentions "prerequisite" or "mise required"

**Test Fixtures Used**: `.github/workflows/test-fixtures/manifest-only-top-level.conf`

**When It Runs**: On every push/PR affecting extension files

### 9. Extension Combinations

Tests common extension combinations for conflicts using manifest-based activation:

#### Test Combinations

Each combination activates multiple extensions in `active-extensions.conf`:

- **core-stack**: workspace-structure, mise-config, ssh-environment (Protected Core Extensions)
- **mise-stack**: workspace-structure, mise-config, nodejs, python, rust, golang, ssh-environment (mise-Powered Languages)
- **full-node**: workspace-structure, nodejs, nodejs-devtools, claude-config (Complete Node.js Development Stack)
- **fullstack**: workspace-structure, nodejs, python, docker, cloud-tools (Python + Docker + Cloud)
- **systems**: workspace-structure, rust, golang, docker (Rust + Go + Docker)
- **enterprise**: workspace-structure, nodejs, jvm, docker, infra-tools (JVM + Docker + Infrastructure)
- **ai-dev**: workspace-structure, nodejs, python, ai-tools, monitoring (Python + AI Tools + Monitoring)

#### Validation

- All extensions activate successfully via `extension-manager install-all`
- Manifest processes extensions in correct order (protected first, cleanup last)
- No installation conflicts between extensions
- Cross-extension functionality works
- Tools from different extensions coexist
- Dependencies are properly resolved

**When It Runs**:

- Manual workflow dispatch
- Commit messages containing `[test-combinations]`

### 10. Results Reporting

Generates comprehensive test report summary:

- Job status for all test categories
- Success/failure indicators
- Links to detailed logs
- GitHub Actions summary

---

## Test Fixtures

To avoid complex heredoc escaping in GitHub Actions workflows, test fixtures are used for manifest testing:

### Available Fixtures

Located in `.github/workflows/test-fixtures/`:

| Fixture File                   | Purpose                                           | Used By                   |
| ------------------------------ | ------------------------------------------------- | ------------------------- |
| `manifest-cleanup-middle.conf` | post-cleanup in middle of manifest                | cleanup-extensions-tests  |
| `manifest-reorder-test.conf`   | 6 extensions for reorder testing                  | manifest-operations-tests |
| `manifest-with-comments.conf`  | Manifest with various comment types               | manifest-operations-tests |
| `manifest-only-top-level.conf` | Single top-level extension for dependency testing | dependency-chain-tests    |

### Benefits of Test Fixtures

1. **No Escaping Issues**: Avoid complex quote/heredoc escaping in nested SSH commands
2. **Version Controlled**: Fixtures tracked in git alongside tests
3. **Reusable**: Same fixture can be used across multiple test scenarios
4. **Maintainable**: Easy to update test data without touching workflow YAML
5. **Readable**: Clear separation between test logic and test data

### Using Fixtures in Tests

```yaml
- name: Copy test fixture to VM
  run: |
    flyctl ssh sftp shell --app $app_name <<'SFTP_EOF'
      put .github/workflows/test-fixtures/manifest-reorder-test.conf /tmp/manifest-reorder.conf
      bye
    SFTP_EOF

- name: Test with fixture
  run: |
    flyctl ssh console --app $app_name --command "/bin/bash -lc '
      cp /tmp/manifest-reorder.conf extensions.d/active-extensions.conf
      # Run tests...
    '"
```

---

## Workflow Triggers

### Automatic Triggers

```yaml
# On push to main/develop affecting extensions
push:
  branches: [main, develop]
  paths:
    # Deployment configuration
    - "fly.toml"
    - "Dockerfile"
    # CI scripts
    - "scripts/prepare-fly-config.sh"
    - "scripts/lib/fly-common.sh"
    # Extension system
    - "docker/lib/extensions.d/**"
    - "docker/lib/extension-manager.sh"
    - "docker/lib/common.sh"
    - "docker/lib/extensions-common.sh"
    # Workflow itself
    - ".github/workflows/extension-tests.yml"
    # Test fixtures
    - ".github/workflows/test-fixtures/**"

# On pull requests
pull_request:
  branches: [main, develop]
  paths: [same as above]
```

### Manual Triggers

```bash
# Test specific extension
gh workflow run extension-tests.yml \
  -f extension_name=rust \
  -f skip_cleanup=false

# Test all extensions with cleanup disabled (for debugging)
gh workflow run extension-tests.yml \
  -f skip_cleanup=true
```

---

## Test Coverage Metrics

### Extension API Coverage

| API Function       | Tested | Test Job                                    | Coverage |
| ------------------ | ------ | ------------------------------------------- | -------- |
| `prerequisites()`  | ✅     | per-extension-tests, dependency-chain-tests | 100%     |
| `install()`        | ✅     | per-extension-tests, extension-api-tests    | 100%     |
| `configure()`      | ✅     | per-extension-tests                         | 100%     |
| `validate()`       | ✅     | extension-api-tests                         | 100%     |
| `status()`         | ✅     | per-extension-tests, extension-api-tests    | 100%     |
| `remove()`         | ✅     | extension-api-tests                         | 100%     |
| `upgrade()` (v2.0) | ✅     | extension-api-tests                         | 100%     |

**Overall API Coverage: 100% (7/7 functions including v2.0)**

### Feature Coverage

| Feature                          | Tested | Test Job                   | Coverage |
| -------------------------------- | ------ | -------------------------- | -------- |
| Protected Extensions Enforcement | ✅     | protected-extensions-tests | 100%     |
| Cleanup Extensions Ordering      | ✅     | cleanup-extensions-tests   | 100%     |
| Manifest Auto-Repair             | ✅     | protected-extensions-tests | 100%     |
| Dependency Resolution            | ✅     | dependency-chain-tests     | 100%     |
| Manifest Comment Preservation    | ✅     | manifest-operations-tests  | 100%     |
| Extension Reordering             | ✅     | manifest-operations-tests  | 100%     |
| Error Handling                   | ✅     | dependency-chain-tests     | 75%      |
| Idempotency                      | ✅     | per-extension-tests        | 100%     |

**Overall Feature Coverage: ~97%**

### Extension Coverage

- **Total Extensions**: 25 (excluding template)
- **Extensions Tested**: 24
- **Coverage**: 96%
- **Untested**: template (intentionally excluded)

---

## Resource Requirements

### VM Specifications

Different test jobs use different VM sizes:

| Test Type            | Memory | CPUs | Disk | Timeout |
| -------------------- | ------ | ---- | ---- | ------- |
| Per-Extension        | 8GB    | 4    | 20GB | 60 min  |
| Extension API Tests  | 4GB    | 2    | 20GB | 45 min  |
| Protected Extensions | 2GB    | 1    | 10GB | 40 min  |
| Cleanup Extensions   | 2GB    | 1    | 10GB | 35 min  |
| Manifest Operations  | 2GB    | 1    | 10GB | 35 min  |
| Dependency Chain     | 4GB    | 2    | 15GB | 50 min  |
| Combinations         | 16GB   | 4    | 20GB | 90 min  |

### Cost Considerations

- Each VM deployment costs according to Fly.io pricing
- Tests run in CI_MODE (SSH daemon disabled) for faster deployment
- Automatic cleanup prevents lingering resources
- Use `skip_cleanup=true` only for debugging

### Test Environments

All tests use:

- **CI_MODE**: Enabled to prevent SSH port conflicts
- **Fly.io Region**: `sjc` (US West)
- **Deployment Strategy**: `immediate` (skip health checks)
- **Volume Encryption**: Disabled for faster setup

---

## Interpreting Results

### Success Criteria

A test passes when:

- ✅ Extension activates without errors
- ✅ `vm-configure.sh` completes successfully
- ✅ All expected commands are available
- ✅ Key functionality tests pass
- ✅ Idempotency check succeeds

### Common Failures

| Failure Type              | Likely Cause                    | Resolution                                                      |
| ------------------------- | ------------------------------- | --------------------------------------------------------------- |
| Configuration timeout     | Extension takes too long        | Increase timeout in matrix                                      |
| Command not found         | Installation incomplete         | Check installation steps in extension                           |
| Idempotency failure       | No existence check              | Add `command_exists` checks                                     |
| Conflict detected         | Duplicate installations         | Review extension interactions                                   |
| Prerequisites failed      | Missing dependency              | Add dependency to `depends_on` field                            |
| Protected extension error | Trying to remove core extension | Cannot remove workspace-structure, mise-config, ssh-environment |
| Dependency chain broken   | mise-config not installed       | Ensure mise-config in manifest before mise-powered extensions   |

### Debugging Failed Tests

1. **Check Workflow Logs**: Detailed output for each step
2. **Review VM Logs**: `flyctl logs -a <app-name>`
3. **Run with Skip Cleanup**: Keep VM alive for inspection
4. **Test Locally**: Activate extension on local test VM
5. **Enable Debug Mode**: Set `DEBUG=true` in extension script

---

## Adding New Extensions

When adding a new extension, ensure it will pass all 10 test jobs.

For complete extension development guide, see [EXTENSIONS.md - Creating Extensions](EXTENSIONS.md#creating-extensions).

### 1. Create Extension File

```bash
# Get into extensions directory
cd docker/lib/extensions.d

# Copy template from docs/templates
# Example: creating extension for R programming language
cp ../../../docs/templates/template.extension r.extension

# Implement all required API functions
vim r.extension
```

**Required API Functions:**

- `prerequisites()` - Check system requirements
- `install()` - Install packages and tools
- `configure()` - Post-install configuration
- `validate()` - Run smoke tests
- `status()` - Check installation state
- `remove()` - Uninstall and cleanup
- `upgrade()` - Upgrade tools (API v2.0)

See [EXTENSIONS.md - Extension API Specification](EXTENSIONS.md#extension-api-specification) for details.

### 2. Add to Test Matrix

Update `.github/workflows/extension-tests.yml`:

```yaml
matrix:
  extension:
    # ... existing extensions ...
    - { name: "r", commands: "R,Rscript", key_tool: "R", timeout: "20m", depends_on: "mise-config", uses_mise: "true" }
```

**Matrix Fields:**

- `name`: Extension name (matches .extension filename)
- `commands`: Comma-separated list of commands to verify
- `key_tool`: Primary command for functionality testing
- `timeout`: Max installation time
- `depends_on`: Comma-separated dependencies (optional)
- `uses_mise`: Set to 'true' if mise-powered (optional)
- `run_last`: Set to 'true' for cleanup extensions (optional)

### 3. Add Functionality Test

In the workflow, add test case to `Test key functionality` step:

```yaml
case "$key_tool" in
  # ... existing cases ...
  R)
    echo "Testing R..."
    R --version
    Rscript --version
    # Test basic R execution
    Rscript -e 'print("Hello from R")'
    ;;
esac
```

### 4. Test Locally First

```bash
# On test VM
cd /workspace/scripts/lib

# Add to manifest
echo "r" >> extensions.d/active-extensions.conf

# Install
bash extension-manager.sh install-all

# Validate
bash extension-manager.sh validate r

# Test all API functions
bash extension-manager.sh status r
bash extension-manager.sh uninstall r
bash extension-manager.sh deactivate r
```

### 5. Verify Passes All Checks

**Job 1: Extension Manager Validation**

- [ ] Extension shows in `extension-manager list`
- [ ] Name extraction works correctly

**Job 2: Extension Syntax Validation**

- [ ] Shellcheck validation passes
- [ ] All required API functions defined
- [ ] Proper shebang and sourcing

**Job 3: Per-Extension Tests**

- [ ] Installation completes within timeout
- [ ] All commands available after installation
- [ ] Key functionality test passes
- [ ] Idempotent (safe to run multiple times)

**Job 4: Extension API Tests** (if in sample)

- [ ] validate() returns 0
- [ ] status() outputs correct format
- [ ] uninstall() calls remove() correctly
- [ ] deactivate() removes from manifest
- [ ] upgrade() works (if API v2.0)

**Job 5-8: Protected/Cleanup/Manifest/Dependencies**

- [ ] Not a protected extension (unless adding new core)
- [ ] Doesn't interfere with cleanup ordering
- [ ] Works with manifest comment preservation
- [ ] Dependencies correctly declared and installed

---

## Best Practices

### For Extension Developers

1. **Always Check Existence**: Use `command_exists` before installing
2. **Handle Errors Gracefully**: Don't exit on minor failures
3. **Use Print Functions**: `print_status`, `print_success`, `print_error`
4. **Test Idempotency**: Extension should be safe to run multiple times
5. **Document Dependencies**: Note any required extensions
6. **Set Reasonable Timeouts**: Consider installation time
7. **Implement upgrade()**: Support API v2.0 for upgrade functionality

See [EXTENSIONS.md - Development Guidelines](EXTENSIONS.md#development-guidelines) for complete guidelines.

### For Extension Users

1. **Review Test Results**: Check workflow before activating new extensions
2. **Test Individually**: Activate one extension at a time initially
3. **Check Combinations**: Review combination tests for your stack
4. **Monitor Resources**: Extensions increase VM resource usage
5. **Validate Installation**: Run validation scripts after activation

---

## Continuous Improvement

The extension testing system continuously evolves:

### Metrics Tracked

- Test execution time per extension
- Success/failure rates
- Resource usage patterns
- Common failure modes
- API function compliance
- Dependency resolution success rates

### Recent Enhancements (Completed)

- [x] **Extension API Testing** - All 6 API functions now tested (100% coverage)
- [x] **Protected Extensions Testing** - Core extension enforcement fully tested
- [x] **Cleanup Extensions Testing** - Auto-ordering logic verified
- [x] **Manifest Operations Testing** - Reorder and comment preservation tested
- [x] **Dependency Chain Testing** - Transitive dependency resolution validated
- [x] **Test Fixtures** - Clean, maintainable test data approach
- [x] **Expanded Matrix** - 24 extensions tested (96% coverage)
- [x] **Error Handling** - Prerequisites failure testing added
- [x] **API v2.0 Testing** - Upgrade functionality tested

### Planned Enhancements

- [ ] Performance benchmarking for extensions
- [ ] Cross-platform testing (different VM sizes)
- [ ] Circular dependency detection testing
- [ ] Extension marketplace scoring
- [ ] Installation time optimization tracking
- [ ] Automated conflict detection across all combinations

### Test Job Workflow

#### Execution Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. Extension Manager Validation (Quick Checks)             │
│     ↓ Validates extension-manager.sh script                 │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  2. Extension Syntax Validation (Static Analysis)           │
│     ↓ Shellcheck all .extension files                       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Jobs 3-9 Run in Parallel (Matrix Tests)                    │
├─────────────────────────────────────────────────────────────┤
│  3. Per-Extension Tests (24 extensions × install/validate)  │
│  4. Extension API Tests (6 extensions × all API functions)  │
│  5. Protected Extensions (enforcement tests)                │
│  6. Cleanup Extensions (ordering tests)                     │
│  7. Manifest Operations (reorder, comments)                 │
│  8. Dependency Chain (transitive deps, errors)              │
│  9. Extension Combinations (7 common stacks)                │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  10. Results Reporting (Aggregate Results)                  │
│      ↓ Summary of all test outcomes                         │
└─────────────────────────────────────────────────────────────┘
```

#### Critical Path

**Must Pass Before Merge:**

- Job 1: Extension Manager Validation
- Job 2: Extension Syntax Validation
- Job 5: Protected Extensions Tests
- Job 6: Cleanup Extensions Tests

**Recommended Before Merge:**

- Job 3: Per-Extension Tests (for modified extensions)
- Job 4: Extension API Tests (validates API compliance)
- Job 7: Manifest Operations Tests (manifest integrity)
- Job 8: Dependency Chain Tests (dependency resolution)

**Optional (Manual Trigger):**

- Job 9: Extension Combinations (comprehensive stack testing)

---

## Support

For issues with extension testing:

1. **Review Logs**: Check GitHub Actions workflow logs
2. **Test Locally**: Reproduce on your own test VM
3. **Inspect Fixtures**: Review test fixtures in `.github/workflows/test-fixtures/`
4. **Open Issue**: Report problems with test workflow
5. **Contribute**: Submit PRs to improve testing

---

## Related Documentation

- **Extension Development**: [EXTENSIONS.md](EXTENSIONS.md) - Complete extension system documentation
- **Extension API**: [EXTENSIONS.md - Extension API Specification](EXTENSIONS.md#extension-api-specification)
- **Creating Extensions**: [EXTENSIONS.md - Creating Extensions](EXTENSIONS.md#creating-extensions)
- **Protected Extensions**: [EXTENSIONS.md - Protected Extensions](EXTENSIONS.md#protected-extensions)
- **Extension Manager Script**: `docker/lib/extension-manager.sh`
- **Integration Testing Workflow**: `.github/workflows/integration.yml`
- **Validation Testing Workflow**: `.github/workflows/validate.yml`
- **Extension Tests Workflow**: `.github/workflows/extension-tests.yml`
