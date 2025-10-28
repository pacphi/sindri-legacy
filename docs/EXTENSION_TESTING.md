# Extension System Testing

This document describes the comprehensive testing system for VM extensions.

## Overview

The extension testing workflow [extension-tests](../.github/workflows/extension-tests.yml) provides automated validation and functional testing
for all extensions in the `docker/lib/extensions.d/` directory. Extensions follow the **Extension API v1.0**
specification with manifest-based activation via `active-extensions.conf`.

This comprehensive testing ensures that users can confidently activate and use any extension through the
`extension-manager` command without encountering issues. Each extension implements 6 required API functions:
`prerequisites()`, `install()`, `configure()`, `validate()`, `status()`, and `remove()`.

## Test Coverage

### 1. Extension Manager Validation

Tests the core extension management system (**Extension API v1.0**):

- **Script Syntax**: Validates `extension-manager.sh` with shellcheck
- **List Command**: Verifies extension listing functionality via `extension-manager list`
- **Name Extraction**: Tests extraction of extension names from `.sh.example` files
- **Manifest Operations**: Tests reading/writing `active-extensions.conf`
- **Protected Extensions**: Verifies core extensions cannot be deactivated improperly
- **Backup Functionality**: Tests file backup creation during deactivation

**When It Runs**: On every push/PR affecting extension files

### 2. Extension Syntax Validation

Validates all extension scripts for code quality:

- **Shellcheck Analysis**: Static analysis of all `.sh` and `.sh.example` files
- **Common.sh Sourcing**: Verifies proper utility function imports
- **Shebang Verification**: Ensures all scripts have `#!/bin/bash`
- **Error Handling**: Checks for use of print functions and error handling
- **Best Practices**: Validates adherence to extension development guidelines

**When It Runs**: On every push/PR affecting extension files

### 3. Per-Extension Tests (Matrix)

Comprehensive testing for each extension individually using the Extension API v1.0:

#### Tested Extensions

| Extension | Key Tools | Test Focus |
|-----------|-----------|------------|
| rust | rustc, cargo | Compilation, cargo tools |
| golang | go | Compilation, go modules |
| python | python3, pip3 | Execution, package management |
| docker | docker, docker-compose | Docker daemon, compose |
| jvm | java, sdk | SDKMAN, Java toolchain |
| php | php, composer | PHP execution, Symfony |
| ruby | ruby, gem, bundle | Ruby execution, Rails |
| dotnet | dotnet | .NET SDK, ASP.NET |
| infra-tools | terraform, ansible | IaC tools |
| cloud-tools | aws | Cloud provider CLIs |
| ai-tools | ollama, fabric | AI coding assistants |

#### Test Steps

For each extension using `extension-manager`:

1. **Installation**: `extension-manager install <name>` (auto-activates, runs prerequisites, install, configure)
2. **Command Availability**: Verify all expected commands in PATH
3. **Key Functionality**: Test core capability (compilation, execution, etc.)
4. **Validation**: `extension-manager validate <name>` confirms working installation
5. **Idempotency**: Re-run installation to verify safe re-execution
6. **Resource Cleanup**: Destroy test VM and volumes

**When It Runs**:

- On push/PR affecting extension files
- On workflow dispatch (all or specific extension)

### 4. Extension Combinations

Tests common extension combinations for conflicts using manifest-based activation:

#### Test Combinations

Each combination activates multiple extensions in `active-extensions.conf`:

- **fullstack**: Python + Docker + Cloud Tools
- **systems**: Rust + Go + Docker
- **enterprise**: JVM + Docker + Infrastructure Tools
- **ai-dev**: Python + AI Tools + Docker

#### Validation

- All extensions activate successfully via `extension-manager`
- Manifest processes extensions in correct order
- No installation conflicts between extensions
- Cross-extension functionality works
- Tools from different extensions coexist

**When It Runs**:

- Manual workflow dispatch

### 6. Results Reporting

Generates comprehensive test report summary:

- Job status for all test categories
- Success/failure indicators
- Links to detailed logs
- GitHub Actions summary

## Workflow Triggers

### Automatic Triggers

```yaml
# On push to main/develop affecting extensions
push:
  branches: [ main, develop ]
  paths:
     # Deployment configuration
      - 'fly.toml'
      - 'Dockerfile'
      # CI scripts
      - 'scripts/prepare-fly-config.sh'
      - 'scripts/lib/fly-common.sh'
      # Extension system
      - 'docker/lib/extensions.d/**'
      - 'docker/lib/extension-manager.sh'
      - 'docker/lib/common.sh'
      - 'docker/lib/extensions-common.sh'
      # VM configuration
      - 'scripts/vm-configure.sh'
      # Workflow itself
      - '.github/workflows/extension-tests.yml'

# On pull requests
pull_request:
  branches: [ main, develop ]
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

## Resource Requirements

### VM Specifications

Different test jobs use different VM sizes:

| Test Type | Memory | CPUs | Disk | Timeout |
|-----------|--------|------|------|---------|
| Per-Extension | 8GB | 4 | 20GB | 60 min |
| Combinations | 16GB | 4 | 20GB | 90 min |

### Cost Considerations

- Each VM deployment costs according to Fly.io pricing
- Tests run in CI_MODE (SSH daemon disabled) for faster deployment
- Automatic cleanup prevents lingering resources
- Use `skip_cleanup=true` only for debugging

## Test Environments

All tests use:

- **CI_MODE**: Enabled to prevent SSH port conflicts
- **Fly.io Region**: `sjc` (US West)
- **Deployment Strategy**: `immediate` (skip health checks)
- **Volume Encryption**: Disabled for faster setup

## Interpreting Results

### Success Criteria

A test passes when:

- ✅ Extension activates without errors
- ✅ `vm-configure.sh` completes successfully
- ✅ All expected commands are available
- ✅ Key functionality tests pass
- ✅ Idempotency check succeeds

### Common Failures

| Failure Type | Likely Cause | Resolution |
|--------------|--------------|------------|
| Activation failed | Missing .example file | Check file exists and naming |
| Configuration timeout | Extension takes too long | Increase timeout in matrix |
| Command not found | Installation incomplete | Check installation steps in extension |
| Idempotency failure | No existence check | Add `command_exists` checks |
| Conflict detected | Duplicate installations | Review extension interactions |

### Debugging Failed Tests

1. **Check Workflow Logs**: Detailed output for each step
2. **Review VM Logs**: `flyctl logs -a <app-name>`
3. **Run with Skip Cleanup**: Keep VM alive for inspection
4. **Test Locally**: Activate extension on local test VM
5. **Enable Debug Mode**: Set `DEBUG=true` in extension script

## Adding New Extensions

When adding a new extension, ensure it will pass tests:

### 1. Create Extension File

```bash
# Get into extensions directory
cd docker/lib/extensions.d

# Copy template
# in this case we want to create a new extension to support R programming language
cp template.sh.example r.sh.example

# Explore existing extensions to see how to structure and implement this new extension

# Edit new example file
vim docker/lib/extensions.d/r.sh.example

# Don't forget to add extension to end of active-extensions.conf to activate it
```

### 2. Add to Test Matrix

Update `.github/workflows/extension-tests.yml`:

```yaml
matrix:
  extension:
    # ... existing extensions ...
    - { name: 'r', commands: 'R',
        key_tool: 'r', timeout: '20m' }
```

### 3. Add Functionality Test

In the workflow, add test case:

```yaml
case "$key_tool" in
  # ... existing cases ...
  r)
    echo "Testing R..."
    R --version
    ;;
esac
```

### 4. Test Locally First

```bash
# On test VM
cd /workspace/scripts/lib
bash extension-manager.sh install r
```

### 5. Verify Passes All Checks

- [ ] Shellcheck validation passes
- [ ] Common.sh properly sourced
- [ ] Idempotent (safe to run multiple times)
- [ ] Commands available after installation
- [ ] Timeout appropriate for installation time
- [ ] Cleanup doesn't leave artifacts

## Best Practices

### For Extension Developers

1. **Always Check Existence**: Use `command_exists` before installing
2. **Handle Errors Gracefully**: Don't exit on minor failures
3. **Use Print Functions**: `print_status`, `print_success`, `print_error`
4. **Test Idempotency**: Extension should be safe to run multiple times
5. **Document Dependencies**: Note any required extensions
6. **Set Reasonable Timeouts**: Consider installation time

### For Extension Users

1. **Review Test Results**: Check workflow before activating new extensions
2. **Test Individually**: Activate one extension at a time initially
3. **Check Combinations**: Review combination tests for your stack
4. **Monitor Resources**: Extensions increase VM resource usage
5. **Validate Installation**: Run validation scripts after activation

## Continuous Improvement

The extension testing system continuously evolves:

### Metrics Tracked

- Test execution time per extension
- Success/failure rates
- Resource usage patterns
- Common failure modes

### Planned Enhancements

- [ ] Performance benchmarking for extensions
- [ ] Cross-platform testing (different VM sizes)
- [ ] Dependency graph validation
- [ ] Automated conflict detection
- [ ] Extension marketplace scoring
- [ ] Installation time optimization

## Support

For issues with extension testing:

1. **Review Logs**: Check GitHub Actions workflow logs
2. **Test Locally**: Reproduce on your own test VM
3. **Open Issue**: Report problems with test workflow
4. **Contribute**: Submit PRs to improve testing

## Related Documentation

- [Extension Development Guide](CUSTOMIZATION.md#extension-system)
- [Extension System README](../docker/lib/extensions.d/README.md)
- [Extension API v1.0 Specification](../docker/lib/extensions.d/README.md#extension-api-v10)
- [Extension Manager Script](../docker/lib/extension-manager.sh)
- [Integration Testing Workflow](../.github/workflows/integration.yml)
- [Validation Testing Workflow](../.github/workflows/validate.yml)
- [Extension Tests Workflow](../.github/workflows/extension-tests.yml)
