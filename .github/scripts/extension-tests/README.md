# Extension Test Scripts

Reusable test scripts for extension validation in CI/CD pipelines.

## Directory Structure

```
extension-tests/
├── lib/
│   ├── test-helpers.sh    # Shared utility functions
│   └── assertions.sh      # Test assertion library
├── verify-manifest.sh     # Verify manifest structure
├── add-extension.sh   # Install extension with dependencies
├── verify-commands.sh     # Verify commands are available
├── test-key-functionality.sh  # Test primary tool functionality
├── test-api-compliance.sh # Test Extension API
└── test-idempotency.sh    # Test idempotent installation
```

## Library Scripts

### lib/test-helpers.sh

Shared utility functions for test scripts.

**Functions:**

- **Output**: `print_success()`, `print_error()`, `print_warning()`, `print_info()`, `print_section()`
- **Environment**: `source_environment()` - Load shell environment for non-interactive sessions
- **Commands**: `command_exists()`, `check_command_with_version()`
- **Utilities**: `wait_for_condition()`, `retry_command()`
- **Extension Manager**: `get_extension_manager_path()`, `get_manifest_path()`, `run_extension_manager()`
- **Validation**: `is_extension_in_manifest()`, `is_protected_extension()`, `verify_extension_installed()`
- **Debugging**: `dump_environment()`, `dump_manifest()`

**Usage:**

```bash
#!/bin/bash
source "$(dirname "$0")/lib/test-helpers.sh"

print_section "Testing Node.js"
if command_exists node; then
    print_success "Node.js is installed"
else
    print_error "Node.js not found"
    exit 1
fi
```

---

### lib/assertions.sh

Test assertion library with automatic test counting.

**Assertions:**

- `assert_command_exists <cmd> [message]`
- `assert_file_exists <file> [message]`
- `assert_directory_exists <dir> [message]`
- `assert_contains <haystack> <needle> [message]`
- `assert_equals <expected> <actual> [message]`
- `assert_success <command>`
- `assert_failure <command>`
- `assert_exit_code <expected_code> <command>`
- `assert_not_empty <value> [message]`
- `assert_output_contains <command> <pattern> [message]`

**Test Management:**

- `print_test_summary()` - Show pass/fail counts
- `reset_test_counters()` - Reset for new test suite

**Usage:**

```bash
#!/bin/bash
source "$(dirname "$0")/lib/test-helpers.sh"
source "$(dirname "$0")/lib/assertions.sh"

assert_command_exists node "Node.js should be installed"
assert_success "node --version"
assert_output_contains "node --version" "v[0-9]" "Version should be shown"

print_test_summary  # Shows: Tests run: 3, Passed: 3, Failed: 0
```

---

## Test Scripts

### verify-manifest.sh

Verifies CI extension manifest structure.

**What it does:**

1. Checks manifest file exists
2. Verifies protected extensions are present
3. Adds missing protected extensions if needed

**Usage (on VM):**

```bash
bash /tmp/verify-manifest.sh
```

**From GitHub Actions:**

```yaml
- name: Verify CI extension manifest
  run: |
    flyctl ssh sftp shell --app $app_name <<'SFTP_EOF'
      put .github/scripts/extension-tests/verify-manifest.sh /tmp/verify-manifest.sh
      quit
    SFTP_EOF

    flyctl ssh console --app $app_name --user developer \
      -C "/bin/bash -lc 'bash /tmp/verify-manifest.sh'"
```

---

### add-extension.sh

Installs extension with its dependencies.

**Arguments:**

- `$1`: Extension name (required)
- `$2-$n`: Dependencies (optional, space or comma separated)

**What it does:**

1. Creates/updates manifest
2. Adds dependencies to manifest
3. Adds main extension to manifest
4. Runs `extension-manager install-all`

**Usage:**

```bash
# Install rust with mise-config dependency
bash add-extension.sh rust mise-config

# Install monitoring with multiple dependencies
bash add-extension.sh monitoring mise-config,nodejs,python
```

**From GitHub Actions:**

```yaml
- name: Add extension to manifest
  run: |
    flyctl ssh sftp shell --app $app_name <<'SFTP_EOF'
      put .github/scripts/extension-tests/add-extension.sh /tmp/add-extension.sh
      quit
    SFTP_EOF

    flyctl ssh console --app $app_name --user developer \
      --command "/bin/bash -lc 'bash /tmp/add-extension.sh nodejs mise-config'"
```

---

### verify-commands.sh

Verifies that extension commands are available in PATH.

**Arguments:**

- `$1`: Comma-separated list of commands (required)

**What it does:**

1. Sources environment
2. Checks each command with `command -v`
3. Falls back to checking common paths
4. Shows version info if available

**Usage:**

```bash
bash verify-commands.sh "node,npm,npx"
```

**Output:**

```
=== Command Verification ===
Commands to verify: node,npm,npx
Current PATH: /home/developer/.local/bin:...

Checking command: node
✅ node available at: /home/developer/.local/bin/node
v20.11.0

Checking command: npm
✅ npm available at: /home/developer/.local/bin/npm
10.2.4

✅ All commands verified successfully
```

---

### test-key-functionality.sh

Tests primary tool functionality for an extension.

**Arguments:**

- `$1`: Key tool name (required)

**Supported Tools:**

- **Languages**: node, python3, rustc, go, java, php, ruby, dotnet
- **Tools**: mise, claude, tsc, tmux, docker, terraform, aws, gh
- **AI Tools**: ollama, codex, playwright, claude-monitor, agent-manager
- **Utilities**: mkdir, ssh, echo

**What it does:**
Runs tool-specific functional tests:

- **Node**: Version check + hello world execution
- **Rust**: Compile and run simple program
- **Go**: Compile and run simple program
- **Python**: Execute script, check pip/uv
- **Docker**: Check Docker + Compose versions
- etc.

**Usage:**

```bash
bash test-key-functionality.sh node
```

**Output:**

```
=== Testing key functionality for: node ===
ℹ️  Testing Node.js...
v20.11.0
10.2.4
Hello from Node.js
✅ Node.js functionality verified
✅ Key functionality test passed for node
```

---

### test-api-compliance.sh

Tests Extension API compliance (validate, status functions).

**Arguments:**

- `$1`: Extension name (required)

**What it tests:**

1. `validate()` function returns success
2. `status()` function shows required fields:
   - Extension name
   - Status field
3. Extension is present in manifest

**Usage:**

```bash
bash test-api-compliance.sh nodejs
```

**Output:**

```
=== Testing Extension API Compliance: nodejs ===

=== Test 1: validate() function ===
Running: extension-manager validate nodejs
✅ validate() returned success for installed extension

=== Test 2: status() function ===
Extension: nodejs
Status: installed
...
✅ status() shows extension name
✅ status() shows status field

✅ All API compliance tests passed for nodejs
```

---

### test-idempotency.sh

Tests that running `extension-manager install-all` twice doesn't cause errors.

**What it does:**

1. Runs `extension-manager install-all` again
2. Checks for errors in output
3. Reports warnings but doesn't fail on them

**Usage:**

```bash
bash test-idempotency.sh
```

**Output:**

```
=== Testing Idempotency ===
ℹ️  Running extension-manager install-all a second time...
Running configuration a second time...
✅ Second run completed without errors
✅ Idempotency test passed
```

---

## Complete Testing Example

```bash
#!/bin/bash
# Complete extension test script

set -e

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"
source "$SCRIPT_DIR/lib/assertions.sh"

# Configuration
EXTENSION="nodejs"
DEPENDS_ON="mise-config"
COMMANDS="node,npm"
KEY_TOOL="node"

# Install extension
print_section "Adding $EXTENSION"
bash "$SCRIPT_DIR/add-extension.sh" "$EXTENSION" "$DEPENDS_ON"

# Verify commands
print_section "Verifying Commands"
bash "$SCRIPT_DIR/verify-commands.sh" "$COMMANDS"

# Test functionality
print_section "Testing Functionality"
bash "$SCRIPT_DIR/test-key-functionality.sh" "$KEY_TOOL"

# Test API compliance
print_section "Testing API Compliance"
bash "$SCRIPT_DIR/test-api-compliance.sh" "$EXTENSION"

# Test idempotency
print_section "Testing Idempotency"
bash "$SCRIPT_DIR/test-idempotency.sh"

print_success "All tests passed for $EXTENSION!"
```

## GitHub Actions Integration

### Upload Scripts to VM

```yaml
- name: Upload test scripts
  env:
    FLY_API_TOKEN: ${{ secrets.FLYIO_AUTH_TOKEN }}
  run: |
    app_name="${{ steps.setup.outputs.app-name }}"

    flyctl ssh sftp shell --app $app_name <<'SFTP_EOF'
      put .github/scripts/extension-tests/lib/test-helpers.sh /tmp/lib/test-helpers.sh
      put .github/scripts/extension-tests/lib/assertions.sh /tmp/lib/assertions.sh
      put .github/scripts/extension-tests/verify-commands.sh /tmp/verify-commands.sh
      put .github/scripts/extension-tests/test-key-functionality.sh /tmp/test-key-functionality.sh
      quit
    SFTP_EOF
```

### Run Tests on VM

```yaml
- name: Run tests
  env:
    FLY_API_TOKEN: ${{ secrets.FLYIO_AUTH_TOKEN }}
  run: |
    app_name="${{ steps.setup.outputs.app-name }}"

    flyctl ssh console --app $app_name --user developer --command "/bin/bash -lc '
      bash /tmp/verify-commands.sh \"node,npm\"
      bash /tmp/test-key-functionality.sh node
    '"
```

## Development

### Adding New Test Scripts

1. **Create script**: `my-new-test.sh`
2. **Add shebang**: `#!/bin/bash`
3. **Source libraries**:
   ```bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/lib/test-helpers.sh"
   source "$SCRIPT_DIR/lib/assertions.sh"
   ```
4. **Make executable**: `chmod +x my-new-test.sh`
5. **Update this README**

### Testing Locally

```bash
# On Fly.io VM (via SSH)
cd /workspace/scripts/lib
bash /tmp/test-key-functionality.sh node

# Or copy to VM and test
scp test-script.sh developer@app.fly.dev:/tmp/
ssh developer@app.fly.dev "bash /tmp/test-script.sh"
```

### Best Practices

- **Error handling**: Use `set -e` to exit on errors
- **Clear output**: Use helper functions for consistent formatting
- **Documentation**: Add usage comments at top of script
- **Assertions**: Use assertion library for testable checks
- **Exit codes**: Return 0 on success, 1 on failure
- **Debugging**: Include `dump_environment()` for troubleshooting

## Troubleshooting

### Scripts not found

**Error**: `bash: /tmp/script.sh: No such file or directory`

**Solution**: Upload script via SFTP before running:

```yaml
flyctl ssh sftp shell --app $app_name <<'SFTP_EOF'
put .github/scripts/extension-tests/script.sh /tmp/script.sh
quit
SFTP_EOF
```

### Permission denied

**Error**: `bash: /tmp/script.sh: Permission denied`

**Solution**: Scripts should be readable, not necessarily executable (bash reads them):

```bash
bash /tmp/script.sh  # Works even without +x
```

### Command not found in PATH

**Error**: Command fails with "command not found"

**Solution**: Source environment first:

```bash
flyctl ssh console --app $app_name --user developer --command "/bin/bash -lc '
  # -l flag loads login shell which sources environment
  command-to-test
'"
```

### Lib scripts not found

**Error**: `lib/test-helpers.sh: No such file or directory`

**Solution**: Create lib directory and upload helpers:

```bash
mkdir -p /tmp/lib
mv /tmp/test-helpers.sh /tmp/lib/
mv /tmp/assertions.sh /tmp/lib/
```

## See Also

- [Composite Actions](../../actions/README.md) - Reusable GitHub Actions
- [Workflow Refactoring](../../WORKFLOW_REFACTORING.md) - Complete documentation
- [Extension Manager](../../../../docker/lib/extension-manager.sh) - Extension management system
