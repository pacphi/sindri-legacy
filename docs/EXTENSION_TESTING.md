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

The extension testing workflow [extension-tests](../.github/workflows/extension-tests.yml) provides automated validation
and functional testing for all extensions in the `docker/lib/extensions.d/` directory.

This comprehensive testing ensures that users can confidently activate and use any extension through the
`extension-manager` command without encountering issues. Each extension implements the **Extension API** (see
[EXTENSIONS.md](EXTENSIONS.md#extension-api-specification)) with 6-7 required functions.

### Testing Philosophy

The test suite is designed to:

1. **Validate All API Functions** - Test all Extension API functions for compliance
2. **Test Edge Cases** - Cleanup ordering, dependency chains, manifest operations
3. **Ensure Reliability** - Idempotency, error handling, and conflict detection
4. **Maintain Quality** - Syntax validation, best practices, and documentation

### Test Statistics

- **Total Test Jobs**: 10
- **Extensions Tested**: 21 out of 21 (100%)
- **API Functions Coverage**: 100% (6/6 v1.0, 7/7 v2.0, 7/7 v2.1)
- **Feature Coverage**: 96%
- **Test Fixtures**: 3 manifest test files
- **Base System Components**: 4 (mise, workspace, SSH, Claude) - pre-installed and always available

---

## CI Environment Setup

### Extension Auto-Installation Architecture

The CI testing environment uses a pre-installed base system with optional extension installation:

#### Pre-Installed Base System (Build Time)

**Built into Docker image** (`Dockerfile`):

The following components are baked into the Docker image and always available:

- **workspace-structure** - `/workspace` directory layout
- **mise** - Unified tool version manager
- **ssh-environment** - Non-interactive SSH session support
- **claude** - Claude Code CLI

**Benefits**: ~10-12 second startup vs ~90-120 seconds with extension-based installation.

#### Optional Extensions (Runtime)

**File**: `docker/lib/extensions.d/active-extensions.ci.conf`

This manifest template defines additional extensions to install in CI mode.

#### Runtime Installation (Container Startup)

**File**: `docker/scripts/entrypoint.sh`

When the container starts, entrypoint.sh copies the extension library to the persistent volume:

1. **Copy Library to Persistent Volume**

   ```bash
   if [ ! -d "/workspace/scripts/lib" ]; then
       cp -r /docker/lib /workspace/scripts/
   ```

   - Only runs on first boot (volume empty)
   - Copies extension library and manager from Docker image

2. **Select Appropriate Manifest**

   ```bash
   if [ "$CI_MODE" = "true" ]; then
       cp /docker/lib/extensions.d/active-extensions.ci.conf \
          /workspace/scripts/extensions.d/active-extensions.conf
   ```

   - CI mode: Uses CI template
   - Production mode: Uses existing manifest or default

3. **Optional Extension Installation** (test-specific)

   Tests that require additional extensions (nodejs, python, rust, etc.) use `extension-manager install-all` to install
   them from the manifest.

#### Why Pre-Install Base System?

**Performance:**

- ✅ **10-12 seconds** startup vs **90-120 seconds** with extension-based installation
- ✅ **75% faster** CI/CD workflows
- ✅ **Immediate availability** of core tools

**Reliability:**

- ✅ No DNS/network failures during startup
- ✅ Consistent versions across all instances
- ✅ Reduced complexity in entrypoint scripts

#### Deployment Flow Diagram

```text
Docker Build
    │
    ├─→ Installs base system (workspace, mise, ssh, claude)
    ├─→ Includes active-extensions.ci.conf (template)
    │
    ▼
Container Startup (entrypoint.sh)
    │
    ├─→ Base system: ✓ Already available (mise, workspace, SSH, Claude)
    │
    ├─→ Check: First boot? (/workspace/scripts/lib missing?)
    │   │
    │   ├─→ YES: Copy lib/ to /workspace/scripts/
    │   │         Copy active-extensions.ci.conf → active-extensions.conf
    │   │
    │   └─→ NO: Skip (volume already has lib/)
    │
    ▼
Container Ready
    │
    ├─→ Base system: ✓ Available (mise, workspace, SSH, Claude)
    └─→ Optional: Tests install additional extensions as needed
```

#### Testing Implications

**Workflow Verification Steps** (integration.yml, extension-tests.yml):

After deployment, workflows verify the base system:

```bash
# Verify base system components
mise --version
ls /workspace/projects
which ssh
claude --version

# Verify extension library copied to volume
ls /workspace/scripts/lib/extension-manager.sh
```

**Key Differences:**

- **Base System**: Always available immediately (pre-installed in Docker image)
- **Extensions**: Installed on-demand via `extension-manager install-all`
- **CI**: Fresh volume every test
- **Production**: Persistent volume

#### Debugging Base System Issues

**Verify base system is available:**

```bash
which mise
# Expected: /usr/local/bin/mise

ls -la /workspace
# Expected: projects/ scripts/ config/ developer/ docs/

which ssh
# Expected: /usr/local/bin/ssh (wrapper script)

which claude
# Expected: /usr/local/bin/claude
```

**If components missing:**

1. Docker image may not be built correctly
2. Check Dockerfile for base system installation steps
3. Rebuild Docker image: `fly deploy` or CI build workflow

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

#### Tested Extensions (21 Total)

**Note**: The base system (workspace-structure, mise, ssh-environment, claude) is pre-installed in the
Docker image and not tested as extensions.

| Extension                    | Key Tools          | Dependencies        | Test Focus               |
| ---------------------------- | ------------------ | ------------------- | ------------------------ |
| **Languages (mise-powered)** |                    |                     |                          |
| nodejs                       | node, npm          | mise (pre-installed) | Runtime, package manager |
| python                       | python3, pip3      | mise (pre-installed) | Execution, packages      |
| rust                         | rustc, cargo       | mise (pre-installed) | Compilation, cargo       |
| golang                       | go                 | mise (pre-installed) | Compilation, modules     |
| nodejs-devtools              | tsc, eslint        | mise (pre-installed), nodejs | TypeScript, linting      |
| ruby                         | ruby, gem, bundle  | mise (pre-installed) | Ruby execution, Rails    |
| **Languages (Traditional)**  |                    |                     |                          |
| php                          | php, composer      | -                   | PHP, Symfony             |
| jvm                          | java, sdk          | -                   | SDKMAN, Java             |
| dotnet                       | dotnet             | -                   | .NET SDK, ASP.NET        |
| **Claude AI**                |                    |                     |                          |
| claude-marketplace           | marketplace config | git                 | Plugin installation      |
| openskills                   | openskills, skills | nodejs, git         | Skills management        |
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

#### Test Steps

For each extension using `extension-manager`:

1. **Dependency Installation**: Auto-install dependencies based on `depends_on` field
2. **Manifest Addition**: Add extension to `active-extensions.conf`
3. **Installation**: Run `extension-manager install-all`
4. **Command Availability**: Verify all expected commands in PATH
5. **mise Verification**: For mise-powered extensions, verify managed by mise
6. **Key Functionality**: Test core capability
7. **Status Check**: Verify `extension-manager status <name>` output
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

Representative sample of 9 extensions tested for full API compliance:

- nodejs (mise-powered language)
- python (mise-powered language)
- rust (mise-powered language)
- golang (mise-powered language)
- tmux-workspace (native apt-based utility)
- monitoring (apt packages with multi-dependency)
- docker (mixed: apt + binary downloads, complex multi-step)
- openskills (npm global install pattern)
- agent-manager (git/GitHub release binary pattern)

**When It Runs**: On every push/PR affecting extension files

### 5. Base System Verification Tests

Tests that the pre-installed base system is available and functional.

For details on the base system, see [EXTENSIONS.md - Pre-Installed Base System](EXTENSIONS.md#pre-installed-base-system-architecture).

#### Verification Tests

- **mise Availability**: Verifies `mise --version` works
- **Workspace Structure**: Verifies `/workspace` directory tree exists
- **SSH Environment**: Verifies SSH wrapper scripts are in place
- **Claude CLI**: Verifies `claude --version` works

**When It Runs**: On every push/PR affecting extension files or Docker image

### 6. Manifest Operations Tests

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
  - Tests multi-level dependency chain (nodejs-devtools → nodejs)
  - Adds only top-level extension to manifest
  - Verifies all dependencies auto-install
  - Uses test fixture with single extension
- **Missing Dependency Errors**:
  - Simulates mise unavailability to break prerequisites
  - Attempts to install nodejs (which requires mise)
  - Verifies installation fails with clear error message
  - Confirms error mentions "prerequisite" or "mise required"

**Test Fixtures Used**: `.github/workflows/test-fixtures/manifest-only-top-level.conf`

**When It Runs**: On every push/PR affecting extension files

### 9. Extension Combinations

Tests common extension combinations for conflicts using manifest-based activation:

#### Test Combinations

Each combination activates multiple extensions in `active-extensions.conf`:

**Note**: Base system (workspace, mise, ssh, claude) is pre-installed and not included in manifest.

- **mise-stack**: nodejs, python, rust, golang (mise-Powered Languages)
- **full-node**: nodejs, nodejs-devtools (Complete Node.js Development Stack)
- **fullstack**: nodejs, python, docker, cloud-tools (Python + Docker + Cloud)
- **systems**: rust, golang, docker (Rust + Go + Docker)
- **enterprise**: nodejs, jvm, docker, infra-tools (JVM + Docker + Infrastructure)
- **ai-dev**: nodejs, python, ai-tools, monitoring (Python + AI Tools + Monitoring)

#### Validation

- All extensions activate successfully via `extension-manager install-all`
- Base system (mise, workspace, SSH, Claude) is already available
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

#### Overall API Coverage: 100% (7/7 functions including v2.0 and v2.1)

### Feature Coverage

| Feature                       | Tested | Test Job                  | Coverage |
| ----------------------------- | ------ | ------------------------- | -------- |
| Base System Verification      | ✅     | base-system-tests         | 100%     |
| Cleanup Extensions Ordering   | ✅     | cleanup-extensions-tests  | 100%     |
| Dependency Resolution         | ✅     | dependency-chain-tests    | 100%     |
| Manifest Comment Preservation | ✅     | manifest-operations-tests | 100%     |
| Extension Reordering          | ✅     | manifest-operations-tests | 100%     |
| Error Handling                | ✅     | dependency-chain-tests    | 75%      |
| Idempotency                   | ✅     | per-extension-tests       | 100%     |

#### Overall Feature Coverage: ~96%

### Extension Coverage

- **Total Extensions**: 21 (base system components not counted as extensions)
- **Extensions Tested**: 21
- **Coverage**: 100%
- **Untested**: None (template intentionally excluded, used as development reference)

---

## Resource Requirements

### VM Specifications

Different test jobs use different VM sizes:

| Test Type           | Memory | CPUs | Disk | Timeout |
| ------------------- | ------ | ---- | ---- | ------- |
| Per-Extension       | 8GB    | 4    | 20GB | 60 min  |
| Extension API Tests | 4GB    | 2    | 20GB | 45 min  |
| Base System Tests   | 2GB    | 1    | 10GB | 40 min  |
| Cleanup Extensions  | 2GB    | 1    | 10GB | 35 min  |
| Manifest Operations | 2GB    | 1    | 10GB | 35 min  |
| Dependency Chain    | 4GB    | 2    | 15GB | 50 min  |
| Combinations        | 16GB   | 4    | 20GB | 90 min  |

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

| Failure Type          | Likely Cause               | Resolution                                       |
| --------------------- | -------------------------- | ------------------------------------------------ |
| Configuration timeout | Extension takes too long   | Increase timeout in matrix                       |
| Command not found     | Installation incomplete    | Check installation steps in extension            |
| Idempotency failure   | No existence check         | Add `command_exists` checks                      |
| Conflict detected     | Duplicate installations    | Review extension interactions                    |
| Prerequisites failed  | Missing dependency         | Add dependency to `depends_on` field             |
| mise not found        | Base system issue          | Check Docker image build, mise should be pre-installed |
| Dependency chain broken | Required extension missing | Ensure dependencies installed before extension |

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
    - { name: "r", commands: "R,Rscript", key_tool: "R", timeout: "20m", uses_mise: "true" }
```

**Note**: `mise` is pre-installed, so no need to specify it as a dependency.

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

#### Job 1: Extension Manager Validation

- [ ] Extension shows in `extension-manager list`
- [ ] Name extraction works correctly

#### Job 2: Extension Syntax Validation

- [ ] Shellcheck validation passes
- [ ] All required API functions defined
- [ ] Proper shebang and sourcing

#### Job 3: Per-Extension Tests

- [ ] Installation completes within timeout
- [ ] All commands available after installation
- [ ] Key functionality test passes
- [ ] Idempotent (safe to run multiple times)

#### Job 4: Extension API Tests (if in sample)

- [ ] validate() returns 0
- [ ] status() outputs correct format
- [ ] uninstall() calls remove() correctly
- [ ] deactivate() removes from manifest
- [ ] upgrade() works (if API v2.0)

#### Job 5-8: Base System/Cleanup/Manifest/Dependencies

- [ ] Base system (mise, workspace, SSH, Claude) remains functional
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
8. **Declare Required Domains** (API v2.1+): Use `EXT_REQUIRED_DOMAINS` for domains needed during installation

#### DNS Check Best Practices (API v2.1+)

Declare domains needed for installation:

```bash
# Extension metadata
EXT_REQUIRED_DOMAINS="example.com github.com registry.npmjs.org"

# In prerequisites()
prerequisites() {
  print_status "Checking prerequisites for ${EXT_NAME}..."
  check_disk_space 1000
  check_required_domains || return 1
  print_success "All prerequisites met"
  return 0
}
```

**Benefits**: Automatic DNS checks, pre-flight aggregation, clear error messages, faster failure detection

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
- [x] **Base System Verification** - Pre-installed components (mise, workspace, SSH, Claude) verified
- [x] **Cleanup Extensions Testing** - Auto-ordering logic verified
- [x] **Manifest Operations Testing** - Reorder and comment preservation tested
- [x] **Dependency Chain Testing** - Transitive dependency resolution validated
- [x] **Test Fixtures** - Clean, maintainable test data approach
- [x] **Expanded Matrix** - 21 extensions tested (100% coverage)
- [x] **Error Handling** - Prerequisites failure testing added
- [x] **API v2.0 Testing** - Upgrade functionality tested
- [x] **Pre-Installed Base System** - Moved core components to Docker image for faster startup
- [x] **API v2.1 DNS Checks** - DNS pre-flight checks and domain validation

### Planned Enhancements

- [ ] Performance benchmarking for extensions
- [ ] Cross-platform testing (different VM sizes)
- [ ] Circular dependency detection testing
- [ ] Extension marketplace scoring
- [ ] Installation time optimization tracking
- [ ] Automated conflict detection across all combinations
- [ ] Network reliability testing for DNS checks

### Test Job Workflow

#### Execution Flow

```text
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
│  3. Per-Extension Tests (20 extensions × install/validate)  │
│  4. Extension API Tests (9 extensions × all API functions)  │
│  5. Base System Tests (verification tests)                  │
│  6. Cleanup Extensions (ordering tests)                     │
│  7. Manifest Operations (reorder, comments)                 │
│  8. Dependency Chain (transitive deps, errors)              │
│  9. Extension Combinations (6 common stacks)                │
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
- Job 5: Base System Tests
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
- **Pre-Installed Base System**: [EXTENSIONS.md - Pre-Installed Base System Architecture](EXTENSIONS.md#pre-installed-base-system-architecture)
- **Extension Manager Script**: `docker/lib/extension-manager.sh`
- **Integration Testing Workflow**: `.github/workflows/integration.yml`
- **Validation Testing Workflow**: `.github/workflows/validate.yml`
- **Extension Tests Workflow**: `.github/workflows/extension-tests.yml`
