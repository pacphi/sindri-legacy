# CI Test Scripts

This directory contains extracted test scripts for GitHub Actions workflows, eliminating complex heredoc escaping and improving maintainability.

## Directory Structure

```
.github/scripts/
├── common/                    # Shared utilities across all workflows
├── integration/               # Integration test scripts
├── extension-tests/           # Extension system test scripts
└── README.md                  # This file
```

## Common Utilities (`common/`)

### retry-utils.sh

Comprehensive retry logic with exponential backoff for CI operations.

**Functions**:

- `retry_with_backoff(max_attempts, initial_delay, max_delay, command...)` - Generic retry with backoff
- `flyctl_deploy_retry(app_name)` - Flyctl deployment with retry (4 attempts)
- `ssh_command_retry(app_name, command)` - SSH command execution with retry (5 attempts)
- `wait_for_machine_ready(app_name)` - Machine readiness check (90 attempts / 180s)

**Usage**:

```bash
source .github/scripts/common/retry-utils.sh
retry_with_backoff 3 5 30 some-flaky-command
```

## Integration Test Scripts (`integration/`)

### verify-manifest.sh

Verifies CI extension manifest was created and contains all protected extensions.

**Checks**:

- Manifest file exists at `/workspace/scripts/extensions.d/active-extensions.conf`
- All protected extensions present: workspace-structure, mise-config, ssh-environment
- Displays active extensions for debugging

**Usage**:

```bash
# Copy to VM and execute
flyctl ssh sftp shell --app $app <<'EOF'
  put .github/scripts/integration/verify-manifest.sh /tmp/verify-manifest.sh
  bye
EOF
flyctl ssh console --app $app --user developer -C "/bin/bash -lc 'bash /tmp/verify-manifest.sh'"
```

### setup-manifest.sh

Sets up extension manifest from CI template for testing.

**Actions**:

- Copies `active-extensions.ci.conf` to `active-extensions.conf` if not exists
- Displays protected extensions in manifest

### verify-protected.sh

Verifies protected extensions are installed and functional.

**Checks**:

- mise command available and working
- /workspace directory exists with correct structure

### test-basic-workflow.sh

Tests basic extension manager workflow (list, install, status).

**Tests**:

- Extension listing functionality
- Extension installation with auto-activation
- Manifest updates
- Status command

### test-extension-system.sh

Comprehensive extension system test including mise-managed extension installation.

**Tests**:

- Extension manager availability
- nodejs extension installation (mise-powered)
- Extension validation via mise
- mise diagnostics

## Extension Test Scripts (`extension-tests/`)

### verify-manifest.sh

Similar to integration/verify-manifest.sh but with fallback logic for test environments.

**Additional Features**:

- Creates manifest from CI template if missing
- Auto-repairs missing protected extensions

### add-extension.sh

Handles adding an extension to manifest with dependency resolution.

**Usage**: `add-extension.sh <extension-name> [dependencies...]`

**Features**:

- Processes dependency list
- Skips protected extensions (already in CI conf)
- Adds extension to manifest

### test-protected.sh

Tests protected extension enforcement (cannot deactivate/uninstall).

**Tests**:

- Deactivation prevention with correct error messages
- Uninstall prevention with correct error messages
- Uses PIPESTATUS to capture exit codes correctly

### test-dependency.sh

Tests dependency chain resolution and error handling.

**Tests**:

- Missing dependency detection (temporarily disables mise)
- Appropriate error messages
- Prerequisite checking functionality

## Design Principles

### Why External Scripts?

1. **No Escaping Hell**: Eliminates complex quote/dollar escaping in heredocs
2. **Testable**: Scripts can be run locally for debugging
3. **Reusable**: Shared across multiple workflows
4. **Maintainable**: Easier to read and modify
5. **Versioned**: Scripts evolve with codebase

### Shell Types

All scripts should be executed with **login shells** (`/bin/bash -lc`) when:

- Running as developer user
- Needing access to mise-managed tools
- Requiring .bashrc sourcing

**Example**:

```bash
# CORRECT - uses login shell
flyctl ssh console --app $app --user developer -C "/bin/bash -lc 'bash /tmp/script.sh'"

# WRONG - non-login shell, mise not in PATH
flyctl ssh console --app $app --user developer -C "/bin/bash -c 'bash /tmp/script.sh'"
```

### Exit Code Handling

When piping to `tee`, use `$PIPESTATUS[0]` to capture the command's exit code:

```bash
# CORRECT
bash command 2>&1 | tee /tmp/log
exit_code=${PIPESTATUS[0]}
if [ $exit_code -eq 0 ]; then
  echo "Success"
fi

# WRONG - gets tee's exit code, not command's
if bash command | tee /tmp/log; then
  echo "Success"  # Always runs even if command failed
fi
```

## Workflow Integration Pattern

```yaml
- name: Test Step
  run: |
    app_name="${{ steps.app-name.outputs.app_name }}"

    # 1. Copy script to VM
    flyctl ssh sftp shell --app $app_name <<'SFTP_EOF'
      put .github/scripts/category/script.sh /tmp/script.sh
      bye
    SFTP_EOF

    # 2. Execute with proper shell type
    flyctl ssh console --app $app_name --user developer -C "/bin/bash -lc 'bash /tmp/script.sh'"
```

## Testing Scripts Locally

```bash
# Make all scripts executable
chmod +x .github/scripts/**/*.sh

# Test retry utilities
bash .github/scripts/common/retry-utils.sh

# Validate with shellcheck
shellcheck .github/scripts/**/*.sh
```

## Maintenance

- All scripts should include shebang: `#!/bin/bash`
- Use `set -e` for fail-fast behavior
- Add comments explaining complex logic
- Keep scripts focused on single responsibility
- Update this README when adding new scripts
