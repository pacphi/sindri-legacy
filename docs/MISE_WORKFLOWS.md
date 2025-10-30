# GitHub Workflows - mise Integration Changes

## Overview

This document outlines all required changes to GitHub Actions workflows to support the mise-powered Extension API refactor.

See [MISE_REFACTOR.md](./MISE_REFACTOR.md) for the overall refactoring plan and implementation phases.

## Current Workflows

| Workflow | File | Purpose | mise Impact |
|----------|------|---------|-------------|
| **Project Validation** | `validate.yml` | Lint shell scripts, validate configs, security scans | ⚠️ Medium - no major changes, validate mise scripts |
| **Extension System Tests** | `extension-tests.yml` | Matrix testing of individual extensions | 🔴 High - significant updates needed |
| **Integration Tests** | `integration.yml` | End-to-end VM deployment and persistence | ⚠️ Medium - add mise testing scenarios |
| **Integration (Resilient)** | `integration-resilient.yml` | Resilient tests with retry logic | ⚠️ Medium - add mise with retry |
| **Release Automation** | `release.yml` | Automated releases and changelog | 🟢 Low - minimal changes |

## Phase 0: Foundation Workflow Changes

### 1. Update `validate.yml`

**No changes required** - shellcheck and validation will work on mise-config extension automatically.

Optional enhancement:
```yaml
# Add to validate.yml after "Validate all extension scripts"
- name: Validate mise-config extension
  if: hashFiles('docker/lib/extensions.d/mise-config.sh.example') != ''
  run: |
    echo "Validating mise-config extension..."
    shellcheck docker/lib/extensions.d/mise-config.sh.example
```

### 2. Update `extension-tests.yml`

#### Change 2.1: Update Extension API Function Validation

**Current** (lines 275-334):
```yaml
- name: Verify Extension API v1.0 functions
  run: |
    echo "Verifying Extension API v1.0 standard functions..."

    failed_extensions=()
    required_functions=("prerequisites" "install" "configure" "validate" "status" "remove")
    # ... validation logic
```

**No changes needed** - Extension API v1.0 remains 6 functions.

#### Change 2.2: Add mise-config to Extension Matrix

**Current** (lines 360-389):
```yaml
strategy:
  fail-fast: false
  max-parallel: 8
  matrix:
    extension:
      # Core extensions (always needed)
      - { name: 'workspace-structure', commands: 'mkdir,ls', key_tool: 'mkdir', timeout: '15m' }
      - { name: 'ssh-environment', commands: 'ssh,sshd', key_tool: 'ssh', timeout: '15m' }
      - { name: 'nodejs', commands: 'node,npm,nvm', key_tool: 'node', timeout: '20m' }
      # ...
```

**Updated** - Add mise-config:
```yaml
strategy:
  fail-fast: false
  max-parallel: 8
  matrix:
    extension:
      # Core extensions (always needed)
      - { name: 'workspace-structure', commands: 'mkdir,ls', key_tool: 'mkdir', timeout: '15m' }
      - { name: 'ssh-environment', commands: 'ssh,sshd', key_tool: 'ssh', timeout: '15m' }
      - { name: 'mise-config', commands: 'mise', key_tool: 'mise', timeout: '15m' }
      - { name: 'nodejs', commands: 'node,npm,nvm', key_tool: 'node', timeout: '20m', depends_on: 'mise-config' }
      # ... (add depends_on: 'mise-config' to mise-powered extensions)
```

#### Change 2.3: Add mise Verification Step

Add new step after "Verify commands available":
```yaml
- name: Verify mise-managed tools
  timeout-minutes: 2
  if: steps.should-test.outputs.should_test == 'true' && matrix.extension.uses_mise == 'true'
  run: |
    app_name="${{ steps.app-name.outputs.app_name }}"
    extension_name="${{ matrix.extension.name }}"

    echo "Verifying mise-managed tools for $extension_name..."

    flyctl ssh console --app $app_name --command "/bin/bash -lc '
      # Source mise environment
      eval \"\$(mise activate bash)\"

      echo \"=== mise Tool Verification ===\"
      echo \"mise version: \$(mise --version)\"
      echo \"\"

      echo \"Checking tools managed by mise for $extension_name:\"
      mise ls

      # Extension-specific verification
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
          mise ls cargo:* && echo \"✅ cargo tools managed by mise\"
          ;;
        golang)
          mise ls go && echo \"✅ Go managed by mise\"
          mise ls go:* && echo \"✅ Go tools managed by mise\"
          ;;
        nodejs-devtools)
          mise ls npm:* && echo \"✅ npm tools managed by mise\"
          ;;
      esac

      echo \"✅ mise verification complete\"
    '"
```

#### Change 2.4: Update Extension Matrix with mise Flags

**Phase 1 Extensions** (add `uses_mise: 'true'`):
```yaml
matrix:
  extension:
    # Phase 1: mise-powered extensions
    - { name: 'mise-config', commands: 'mise', key_tool: 'mise', timeout: '15m', uses_mise: 'true' }
    - { name: 'nodejs', commands: 'node,npm', key_tool: 'node', timeout: '20m', depends_on: 'mise-config', uses_mise: 'true' }
    - { name: 'python', commands: 'python3,pip3,uv', key_tool: 'python3', timeout: '30m', depends_on: 'mise-config', uses_mise: 'true' }
    - { name: 'rust', commands: 'rustc,cargo', key_tool: 'rustc', timeout: '30m', depends_on: 'mise-config', uses_mise: 'true' }
    - { name: 'golang', commands: 'go', key_tool: 'go', timeout: '30m', depends_on: 'mise-config', uses_mise: 'true' }
    - { name: 'nodejs-devtools', commands: 'tsc,eslint,prettier,nodemon', key_tool: 'tsc', timeout: '20m', depends_on: 'mise-config,nodejs', uses_mise: 'true' }

    # Non-mise extensions (keep as-is)
    - { name: 'workspace-structure', commands: 'mkdir,ls', key_tool: 'mkdir', timeout: '15m' }
    - { name: 'ssh-environment', commands: 'ssh,sshd', key_tool: 'ssh', timeout: '15m' }
    - { name: 'ruby', commands: 'ruby,gem,bundle', key_tool: 'ruby', timeout: '30m' }
    - { name: 'php', commands: 'php,composer', key_tool: 'php', timeout: '30m' }
    - { name: 'jvm', commands: 'java,sdk', key_tool: 'java', timeout: '30m' }
    - { name: 'dotnet', commands: 'dotnet', key_tool: 'dotnet', timeout: '30m' }
    # ...
```

#### Change 2.5: Add status() Output Validation

Add new step after "Test key functionality":
```yaml
- name: Test enhanced status() output
  timeout-minutes: 2
  if: steps.should-test.outputs.should_test == 'true'
  run: |
    app_name="${{ steps.app-name.outputs.app_name }}"
    extension_name="${{ matrix.extension.name }}"

    echo "Testing enhanced status() output for $extension_name..."

    status_output=$(flyctl ssh console --app $app_name --command "/bin/bash -c '
      cd /workspace/scripts/lib
      bash extension-manager.sh status $extension_name
    '")

    echo "$status_output"

    # Verify status output contains required elements
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

    echo "✅ Enhanced status() output validated"
```

### 3. Update `integration.yml` and `integration-resilient.yml`

#### Change 3.1: Add mise-Powered Stack Testing

Add new combination to extension-combinations job:
```yaml
matrix:
  combination:
    - { name: 'core-stack', extensions: 'workspace-structure,nodejs,ssh-environment', description: 'Core Infrastructure' }
    # Add new mise-powered combination
    - { name: 'mise-stack', extensions: 'workspace-structure,mise-config,nodejs,python,rust,ssh-environment', description: 'mise-Powered Languages (Phase 1)' }
    - { name: 'full-node', extensions: 'workspace-structure,nodejs,nodejs-devtools,claude-config', description: 'Complete Node.js Development Stack' }
    # ...
```

#### Change 3.2: Add mise Verification in Cross-Extension Tests

Update "Test cross-extension functionality" step:
```yaml
- name: Test cross-extension functionality
  run: |
    # ... existing code ...

    case "$combo" in
      # ... existing cases ...

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

        # Verify version switching works
        echo ""
        echo "Testing mise version switching..."
        current_node=$(mise current node)
        echo "Current Node.js version: $current_node"

        echo "✅ mise-powered language stack verified"
        ;;

      # ... rest of cases ...
    esac
```

### 4. Create New Workflow: `mise-compatibility.yml`

Create `.github/workflows/mise-compatibility.yml` to test mise-specific functionality:

```yaml
name: mise Compatibility Tests

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'docker/lib/extensions.d/mise-config.sh.example'
      - 'docker/lib/extensions.d/nodejs.sh.example'
      - 'docker/lib/extensions.d/python.sh.example'
      - 'docker/lib/extensions.d/rust.sh.example'
      - 'docker/lib/extensions.d/golang.sh.example'
      - 'docker/lib/extensions.d/nodejs-devtools.sh.example'
      - '.github/workflows/mise-compatibility.yml'
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'docker/lib/extensions.d/mise-config.sh.example'
      - 'docker/lib/extensions.d/nodejs.sh.example'
      - 'docker/lib/extensions.d/python.sh.example'
      - 'docker/lib/extensions.d/rust.sh.example'
      - 'docker/lib/extensions.d/golang.sh.example'
      - 'docker/lib/extensions.d/nodejs-devtools.sh.example'
      - '.github/workflows/mise-compatibility.yml'
  workflow_dispatch:
    inputs:
      test_migration:
        description: 'Test migration from traditional to mise'
        required: false
        default: false
        type: boolean

env:
  TEST_APP_PREFIX: "mise-test"
  REGION: "sjc"
  FLY_API_TOKEN: ${{ secrets.FLYIO_AUTH_TOKEN }}

jobs:
  # ============================================================================
  # Job 1: mise Installation Test
  # ============================================================================
  mise-installation:
    name: Test mise Installation
    runs-on: ubuntu-latest
    timeout-minutes: 20
    permissions:
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Install Fly CLI
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Generate test app name
        id: app-name
        run: |
          timestamp=$(date +%s)
          app_name="${TEST_APP_PREFIX}-install-${timestamp}"
          echo "app_name=$app_name" >> $GITHUB_OUTPUT

      - name: Deploy test VM
        run: |
          # Prepare and deploy minimal VM
          export APP_NAME="${{ steps.app-name.outputs.app_name }}"
          export VOLUME_NAME="test_data"
          export VOLUME_SIZE="5"
          export VM_MEMORY="1024"
          export CPU_KIND="shared"
          export CPU_COUNT="1"
          export CI_MODE="true"

          ./scripts/prepare-fly-config.sh --ci-mode

          flyctl apps create $APP_NAME --org personal || true
          flyctl volumes create test_data --app $APP_NAME --region ${REGION} --size 5 --no-encryption --yes
          flyctl secrets set CI_MODE="true" --app $APP_NAME
          flyctl deploy --app $APP_NAME --strategy immediate --wait-timeout 120s --yes

      - name: Wait for deployment
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"
          timeout=180
          elapsed=0
          interval=10

          while [ $elapsed -lt $timeout ]; do
            if flyctl status --app $app_name | grep -q "started"; then
              echo "✅ Deployment successful"
              sleep 30
              break
            fi
            sleep $interval
            elapsed=$((elapsed + interval))
          done

      - name: Install mise-config extension
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"

          echo "Installing mise-config extension..."

          flyctl ssh console --app $app_name --command "/bin/bash -c '
            cd /workspace/scripts/lib

            # Add mise-config to manifest
            echo \"mise-config\" > extensions.d/active-extensions.conf

            # Install mise-config
            if bash extension-manager.sh install-all; then
              echo \"✅ mise-config installed\"
            else
              echo \"❌ mise-config installation failed\"
              exit 1
            fi
          '"

      - name: Verify mise installation
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"

          echo "Verifying mise installation..."

          flyctl ssh console --app $app_name --command "/bin/bash -lc '
            # Verify mise command
            if command -v mise >/dev/null 2>&1; then
              echo \"✅ mise command available\"
              mise --version
            else
              echo \"❌ mise command not found\"
              exit 1
            fi

            # Verify mise activation in bashrc
            if grep -q \"mise activate\" ~/.bashrc; then
              echo \"✅ mise activation configured in bashrc\"
            else
              echo \"❌ mise activation not configured\"
              exit 1
            fi

            # Verify mise config directory
            if [ -d ~/.config/mise ]; then
              echo \"✅ mise config directory exists\"
            else
              echo \"❌ mise config directory missing\"
              exit 1
            fi

            echo \"✅ mise installation verified\"
          '"

      - name: Test mise basic operations
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"

          echo "Testing mise basic operations..."

          flyctl ssh console --app $app_name --command "/bin/bash -lc '
            # Activate mise
            eval \"\$(mise activate bash)\"

            # Test mise ls
            echo \"Testing mise ls...\"
            mise ls

            # Test mise doctor
            echo \"\"
            echo \"Testing mise doctor...\"
            mise doctor

            # Test mise search
            echo \"\"
            echo \"Testing mise search...\"
            mise search node | head -5

            echo \"\"
            echo \"✅ mise basic operations work\"
          '"

      - name: Cleanup
        if: always()
        run: |
          flyctl apps destroy "${{ steps.app-name.outputs.app_name }}" --yes || true

  # ============================================================================
  # Job 2: mise-Powered Extension Test
  # ============================================================================
  mise-powered-extensions:
    name: Test mise-Powered Extensions
    runs-on: ubuntu-latest
    timeout-minutes: 45
    permissions:
      contents: read
    needs: mise-installation

    strategy:
      fail-fast: false
      matrix:
        extension:
          - { name: 'nodejs', language: 'node', version: 'lts', test_cmd: 'node -e "console.log(\"test\")"' }
          - { name: 'python', language: 'python', version: '3.13', test_cmd: 'python3 -c "print(\"test\")"' }
          - { name: 'rust', language: 'rust', version: 'stable', test_cmd: 'rustc --version && cargo --version' }
          - { name: 'golang', language: 'go', version: '1.24', test_cmd: 'go version' }

    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Install Fly CLI
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Generate test app name
        id: app-name
        run: |
          timestamp=$(date +%s)
          app_name="${TEST_APP_PREFIX}-${{ matrix.extension.name }}-${timestamp}"
          echo "app_name=$app_name" >> $GITHUB_OUTPUT

      - name: Deploy test VM
        run: |
          export APP_NAME="${{ steps.app-name.outputs.app_name }}"
          export VOLUME_NAME="test_data"
          export VOLUME_SIZE="10"
          export VM_MEMORY="2048"
          export CPU_KIND="shared"
          export CPU_COUNT="2"
          export CI_MODE="true"

          ./scripts/prepare-fly-config.sh --ci-mode

          flyctl apps create $APP_NAME --org personal || true
          flyctl volumes create test_data --app $APP_NAME --region ${REGION} --size 10 --no-encryption --yes
          flyctl secrets set CI_MODE="true" --app $APP_NAME
          flyctl deploy --app $APP_NAME --strategy immediate --wait-timeout 120s --yes

          # Wait for ready
          sleep 60

      - name: Install mise-config + extension
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"
          extension_name="${{ matrix.extension.name }}"

          echo "Installing mise-config and $extension_name..."

          flyctl ssh console --app $app_name --command "/bin/bash -c '
            cd /workspace/scripts/lib

            # Create manifest with mise-config first, then extension
            cat > extensions.d/active-extensions.conf << EOF
mise-config
$extension_name
EOF

            # Install all
            if bash extension-manager.sh install-all; then
              echo \"✅ Extensions installed\"
            else
              echo \"❌ Extension installation failed\"
              exit 1
            fi
          '"

      - name: Verify mise manages the language
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"
          language="${{ matrix.extension.language }}"
          version="${{ matrix.extension.version }}"

          echo "Verifying mise manages $language@$version..."

          flyctl ssh console --app $app_name --command "/bin/bash -lc '
            eval \"\$(mise activate bash)\"

            # Check mise shows the language
            if mise ls $language | grep -q \"$language\"; then
              echo \"✅ mise manages $language\"
              mise ls $language
            else
              echo \"❌ mise does not manage $language\"
              echo \"All mise tools:\"
              mise ls
              exit 1
            fi
          '"

      - name: Test language functionality
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"
          test_cmd="${{ matrix.extension.test_cmd }}"

          echo "Testing language functionality..."

          flyctl ssh console --app $app_name --command "/bin/bash -lc '
            # Source environment
            eval \"\$(mise activate bash)\"

            # Run test command
            $test_cmd

            echo \"✅ Language functionality verified\"
          '"

      - name: Test version switching
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"
          language="${{ matrix.extension.language }}"

          echo "Testing mise version switching for $language..."

          flyctl ssh console --app $app_name --command "/bin/bash -lc '
            eval \"\$(mise activate bash)\"

            echo \"Current version:\"
            mise current $language

            # Test mise ls-remote (show available versions)
            echo \"\"
            echo \"Available versions (first 5):\"
            mise ls-remote $language | head -5

            echo \"\"
            echo \"✅ Version information available\"
          '"

      - name: Cleanup
        if: always()
        run: |
          flyctl apps destroy "${{ steps.app-name.outputs.app_name }}" --yes || true

  # ============================================================================
  # Job 3: Migration Test (Traditional -> mise)
  # ============================================================================
  migration-test:
    name: Test Migration from Traditional to mise
    runs-on: ubuntu-latest
    timeout-minutes: 60
    permissions:
      contents: read
    if: github.event_name == 'workflow_dispatch' && inputs.test_migration == true

    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Install Fly CLI
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Generate test app name
        id: app-name
        run: |
          timestamp=$(date +%s)
          app_name="${TEST_APP_PREFIX}-migration-${timestamp}"
          echo "app_name=$app_name" >> $GITHUB_OUTPUT

      - name: Deploy with traditional nodejs (v2.x)
        run: |
          export APP_NAME="${{ steps.app-name.outputs.app_name }}"
          export VOLUME_NAME="test_data"
          export VOLUME_SIZE="10"
          export VM_MEMORY="2048"
          export CPU_KIND="shared"
          export CPU_COUNT="2"
          export CI_MODE="true"

          ./scripts/prepare-fly-config.sh --ci-mode

          flyctl apps create $APP_NAME --org personal || true
          flyctl volumes create test_data --app $APP_NAME --region ${REGION} --size 10 --no-encryption --yes
          flyctl secrets set CI_MODE="true" --app $APP_NAME
          flyctl deploy --app $APP_NAME --strategy immediate --wait-timeout 120s --yes

          sleep 60

      - name: Install traditional nodejs extension
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"

          echo "Installing nodejs with NVM (traditional)..."

          flyctl ssh console --app $app_name --command "/bin/bash -c '
            cd /workspace/scripts/lib
            echo \"nodejs\" > extensions.d/active-extensions.conf
            bash extension-manager.sh install-all
          '"

      - name: Verify NVM installation
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"

          flyctl ssh console --app $app_name --command "/bin/bash -lc '
            source ~/.nvm/nvm.sh

            echo \"Traditional installation:\"
            echo \"  NVM: \$(nvm --version)\"
            echo \"  Node.js: \$(node --version)\"
            echo \"  npm: v\$(npm --version)\"
          '"

      - name: Install mise-config alongside NVM
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"

          echo "Installing mise-config (should coexist with NVM)..."

          flyctl ssh console --app $app_name --command "/bin/bash -c '
            cd /workspace/scripts/lib
            echo \"mise-config\" >> extensions.d/active-extensions.conf
            bash extension-manager.sh install mise-config
          '"

      - name: Verify coexistence
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"

          echo "Verifying NVM and mise coexist..."

          flyctl ssh console --app $app_name --command "/bin/bash -lc '
            # Check NVM still works
            source ~/.nvm/nvm.sh
            echo \"NVM version: \$(nvm --version)\"
            echo \"Node.js (via NVM): \$(node --version)\"

            # Check mise is available
            eval \"\$(mise activate bash)\"
            echo \"mise version: \$(mise --version)\"

            echo \"\"
            echo \"✅ Both version managers coexist\"
          '"

      - name: Test mise managing alternative tool
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"

          echo "Testing mise managing Python alongside NVM-managed Node.js..."

          flyctl ssh console --app $app_name --command "/bin/bash -lc '
            eval \"\$(mise activate bash)\"

            # Install Python via mise
            mise use python@3.13

            # Verify both work
            echo \"Node.js (NVM): \$(node --version)\"
            echo \"Python (mise): \$(python3 --version)\"

            mise ls

            echo \"\"
            echo \"✅ Hybrid environment works (NVM + mise)\"
          '"

      - name: Cleanup
        if: always()
        run: |
          flyctl apps destroy "${{ steps.app-name.outputs.app_name }}" --yes || true

  # ============================================================================
  # Job 4: mise Tool Registry Test
  # ============================================================================
  mise-registry-test:
    name: Test mise Tool Registry
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Install Fly CLI
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Generate test app name
        id: app-name
        run: |
          timestamp=$(date +%s)
          app_name="${TEST_APP_PREFIX}-registry-${timestamp}"
          echo "app_name=$app_name" >> $GITHUB_OUTPUT

      - name: Deploy and install mise
        run: |
          export APP_NAME="${{ steps.app-name.outputs.app_name }}"
          export VOLUME_NAME="test_data"
          export VOLUME_SIZE="5"
          export VM_MEMORY="1024"
          export CPU_KIND="shared"
          export CPU_COUNT="1"
          export CI_MODE="true"

          ./scripts/prepare-fly-config.sh --ci-mode

          flyctl apps create $APP_NAME --org personal || true
          flyctl volumes create test_data --app $APP_NAME --region ${REGION} --size 5 --no-encryption --yes
          flyctl secrets set CI_MODE="true" --app $APP_NAME
          flyctl deploy --app $APP_NAME --strategy immediate --wait-timeout 120s --yes

          sleep 60

          # Install mise-config
          flyctl ssh console --app $APP_NAME --command "/bin/bash -c '
            cd /workspace/scripts/lib
            echo \"mise-config\" > extensions.d/active-extensions.conf
            bash extension-manager.sh install-all
          '"

      - name: Test mise backends
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"

          echo "Testing various mise backends..."

          flyctl ssh console --app $app_name --command "/bin/bash -lc '
            eval \"\$(mise activate bash)\"

            echo \"=== Testing mise Backends ===\"

            # Core language backends
            echo \"\"
            echo \"1. Testing core language backend (node)...\"
            mise ls-remote node | head -3
            echo \"✅ Core backend works\"

            # npm backend
            echo \"\"
            echo \"2. Testing npm backend (npm:prettier)...\"
            mise ls-remote npm:prettier | head -3 || echo \"⚠️  npm backend may need configuration\"

            # pipx backend
            echo \"\"
            echo \"3. Testing pipx backend (pipx:black)...\"
            mise ls-remote pipx:black | head -3 || echo \"⚠️  pipx backend may need configuration\"

            # cargo backend
            echo \"\"
            echo \"4. Testing cargo backend (cargo:ripgrep)...\"
            mise ls-remote cargo:ripgrep | head -3 || echo \"⚠️  cargo backend may need configuration\"

            # go backend
            echo \"\"
            echo \"5. Testing go backend...\"
            mise ls-remote go | head -3 || echo \"⚠️  go backend may need configuration\"

            echo \"\"
            echo \"✅ Backend tests complete\"
          '"

      - name: Test mise tool installation via CLI
        run: |
          app_name="${{ steps.app-name.outputs.app_name }}"

          echo "Testing manual tool installation via mise CLI..."

          flyctl ssh console --app $app_name --command "/bin/bash -lc '
            eval \"\$(mise activate bash)\"

            # Install a small tool to test
            echo \"Installing node via mise...\"
            mise use node@lts

            # Verify it works
            if command -v node >/dev/null 2>&1; then
              echo \"✅ Node.js installed: \$(node --version)\"
              mise ls node
            else
              echo \"❌ Node.js not available after mise install\"
              exit 1
            fi
          '"

      - name: Cleanup
        if: always()
        run: |
          flyctl apps destroy "${{ steps.app-name.outputs.app_name }}" --yes || true

  # ============================================================================
  # Job 5: Performance Comparison
  # ============================================================================
  performance-comparison:
    name: Compare Traditional vs mise Performance
    runs-on: ubuntu-latest
    timeout-minutes: 90
    permissions:
      contents: read
    if: github.event_name == 'workflow_dispatch'

    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Install Fly CLI
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Test traditional nodejs installation time
        id: traditional
        run: |
          timestamp=$(date +%s)
          app_name="${TEST_APP_PREFIX}-trad-${timestamp}"

          # Deploy and time traditional installation
          export APP_NAME="$app_name"
          export VOLUME_NAME="test_data"
          export VOLUME_SIZE="5"
          export VM_MEMORY="1024"
          export CPU_KIND="shared"
          export CPU_COUNT="1"
          export CI_MODE="true"

          ./scripts/prepare-fly-config.sh --ci-mode

          flyctl apps create $app_name --org personal || true
          flyctl volumes create test_data --app $app_name --region ${REGION} --size 5 --no-encryption --yes
          flyctl secrets set CI_MODE="true" --app $app_name
          flyctl deploy --app $app_name --strategy immediate --wait-timeout 120s --yes

          sleep 60

          # Time installation
          start_time=$(date +%s)

          flyctl ssh console --app $app_name --command "/bin/bash -c '
            cd /workspace/scripts/lib
            echo \"nodejs\" > extensions.d/active-extensions.conf
            bash extension-manager.sh install-all
          '"

          end_time=$(date +%s)
          duration=$((end_time - start_time))

          echo "traditional_time=$duration" >> $GITHUB_OUTPUT
          echo "Traditional installation time: ${duration}s"

          # Cleanup
          flyctl apps destroy $app_name --yes || true

      - name: Test mise nodejs installation time
        id: mise-powered
        run: |
          timestamp=$(date +%s)
          app_name="${TEST_APP_PREFIX}-mise-${timestamp}"

          # Deploy and time mise installation
          export APP_NAME="$app_name"
          export VOLUME_NAME="test_data"
          export VOLUME_SIZE="5"
          export VM_MEMORY="1024"
          export CPU_KIND="shared"
          export CPU_COUNT="1"
          export CI_MODE="true"

          ./scripts/prepare-fly-config.sh --ci-mode

          flyctl apps create $app_name --org personal || true
          flyctl volumes create test_data --app $app_name --region ${REGION} --size 5 --no-encryption --yes
          flyctl secrets set CI_MODE="true" --app $app_name
          flyctl deploy --app $app_name --strategy immediate --wait-timeout 120s --yes

          sleep 60

          # Time installation
          start_time=$(date +%s)

          flyctl ssh console --app $app_name --command "/bin/bash -c '
            cd /workspace/scripts/lib
            cat > extensions.d/active-extensions.conf << EOF
mise-config
nodejs
EOF
            bash extension-manager.sh install-all
          '"

          end_time=$(date +%s)
          duration=$((end_time - start_time))

          echo "mise_time=$duration" >> $GITHUB_OUTPUT
          echo "mise installation time: ${duration}s"

          # Cleanup
          flyctl apps destroy $app_name --yes || true

      - name: Compare results
        run: |
          traditional_time="${{ steps.traditional.outputs.traditional_time }}"
          mise_time="${{ steps.mise-powered.outputs.mise_time }}"

          echo "=== Performance Comparison ==="
          echo "Traditional (NVM): ${traditional_time}s"
          echo "mise-powered:      ${mise_time}s"

          if [ $mise_time -lt $traditional_time ]; then
            speedup=$((traditional_time - mise_time))
            echo "✅ mise is ${speedup}s faster"
          elif [ $mise_time -gt $traditional_time ]; then
            slowdown=$((mise_time - traditional_time))
            echo "⚠️  mise is ${slowdown}s slower"
          else
            echo "⚠️  Performance is identical"
          fi

          # Add to summary
          echo "## Performance Comparison" >> $GITHUB_STEP_SUMMARY
          echo "| Method | Time |" >> $GITHUB_STEP_SUMMARY
          echo "|--------|------|" >> $GITHUB_STEP_SUMMARY
          echo "| Traditional (NVM) | ${traditional_time}s |" >> $GITHUB_STEP_SUMMARY
          echo "| mise-powered | ${mise_time}s |" >> $GITHUB_STEP_SUMMARY
```

## Phase 1: mise-Powered Extension Workflow Changes

### 1. Update Extension Matrix Dependencies

For Phase 1 mise-powered extensions, update their matrix entries:

```yaml
# extension-tests.yml
matrix:
  extension:
    # All Phase 1 extensions depend on mise-config
    - { name: 'nodejs', commands: 'node,npm', key_tool: 'node', timeout: '20m', depends_on: 'mise-config', version: '3.0.0' }
    - { name: 'python', commands: 'python3,pip3', key_tool: 'python3', timeout: '30m', depends_on: 'mise-config', version: '2.0.0' }
    - { name: 'rust', commands: 'rustc,cargo', key_tool: 'rustc', timeout: '30m', depends_on: 'mise-config', version: '2.0.0' }
    - { name: 'golang', commands: 'go', key_tool: 'go', timeout: '30m', depends_on: 'mise-config', version: '2.0.0' }
    - { name: 'nodejs-devtools', commands: 'tsc,eslint,prettier', key_tool: 'tsc', timeout: '20m', depends_on: 'mise-config,nodejs', version: '2.0.0' }
```

### 2. Update "Test key functionality" Step

Add mise-specific tests:

```yaml
- name: Test key functionality
  run: |
    # ... existing code ...

    case "$key_tool" in
      # ... existing cases ...

      node)
        echo "Testing Node.js..."

        # Check if mise-powered or traditional
        if mise ls node &>/dev/null; then
          echo "🔧 Node.js managed by mise"
          mise ls node
          node --version
          npm --version
        else
          echo "🔧 Node.js managed by NVM"
          source ~/.nvm/nvm.sh
          nvm --version
          node --version
          npm --version
        fi
        ;;

      python3)
        echo "Testing Python..."

        # Check if mise-powered or traditional
        if mise ls python &>/dev/null; then
          echo "🔧 Python managed by mise"
          mise ls python
          mise ls pipx:* || echo "(no pipx tools)"
        else
          echo "🔧 Python traditional installation"
        fi

        python3 --version
        pip3 --version
        ;;

      # ... similar updates for rustc, go ...
    esac
```

### 3. Add mise Doctor Check

Add new validation step to catch mise-specific issues:

```yaml
- name: Run mise doctor (if applicable)
  timeout-minutes: 2
  if: steps.should-test.outputs.should_test == 'true' && matrix.extension.depends_on contains 'mise-config'
  run: |
    app_name="${{ steps.app-name.outputs.app_name }}"

    echo "Running mise doctor to check for issues..."

    flyctl ssh console --app $app_name --command "/bin/bash -lc '
      eval \"\$(mise activate bash)\"

      echo \"=== mise doctor ===\"
      mise doctor

      # Check for common issues
      if mise doctor | grep -i \"error\|warning\"; then
        echo \"⚠️  mise doctor found issues\"
      else
        echo \"✅ mise doctor: no issues\"
      fi
    '"
```

## Phase 2: Hybrid Extension Workflow Changes

### 1. Add Environment Variable Testing

For extensions that support both traditional and mise (like ruby), add conditional testing:

```yaml
# In extension-tests.yml, add to ruby test
- name: Test ruby extension (both modes)
  run: |
    app_name="${{ steps.app-name.outputs.app_name }}"

    # Test 1: Traditional rbenv mode (default)
    echo "Testing Ruby with rbenv (traditional)..."
    flyctl ssh console --app $app_name --command "/bin/bash -c '
      cd /workspace/scripts/lib
      echo \"ruby\" > extensions.d/active-extensions.conf
      bash extension-manager.sh install-all
    '"

    # Verify rbenv
    flyctl ssh console --app $app_name --command "/bin/bash -lc '
      if [ -d ~/.rbenv ]; then
        echo \"✅ rbenv installation detected\"
        rbenv --version
        ruby --version
      fi
    '"

    # Test 2: mise mode (if USE_MISE_FOR_RUBY=true)
    echo ""
    echo "Testing Ruby with mise (experimental)..."
    flyctl ssh console --app $app_name --command "/bin/bash -c '
      # Set environment variable
      export USE_MISE_FOR_RUBY=true

      # Reinstall with mise
      cd /workspace/scripts/lib
      bash extension-manager.sh remove ruby --yes
      bash extension-manager.sh install ruby
    '"

    # Verify mise
    flyctl ssh console --app $app_name --command "/bin/bash -lc '
      eval \"\$(mise activate bash)\"

      if mise ls ruby &>/dev/null; then
        echo \"✅ mise installation detected\"
        mise ls ruby
        ruby --version
      fi
    '"
```

### 2. Update Extension Combinations

Add hybrid combinations:

```yaml
# In extension-tests.yml
matrix:
  combination:
    # ... existing combinations ...

    # New hybrid combinations
    - { name: 'hybrid-ruby', extensions: 'workspace-structure,mise-config,ruby', env: 'USE_MISE_FOR_RUBY=true', description: 'Ruby via mise (experimental)' }
    - { name: 'traditional-ruby', extensions: 'workspace-structure,ruby', description: 'Ruby via rbenv (stable)' }
    - { name: 'mise-polyglot', extensions: 'mise-config,nodejs,python,rust,golang', description: 'All Phase 1 Languages via mise' }
```

## Phase 3: Enhanced Status/BOM Reporting

### 1. Add Status Aggregation Test

Create new job in `extension-tests.yml`:

```yaml
# ============================================================================
# Job 6: Status Reporting and BOM
# ============================================================================
status-reporting-test:
  name: Test Status/BOM Reporting
  runs-on: ubuntu-latest
  timeout-minutes: 30
  permissions:
    contents: read
  needs: per-extension-tests

  steps:
    - name: Checkout code
      uses: actions/checkout@v5

    - name: Install Fly CLI
      uses: superfly/flyctl-actions/setup-flyctl@master

    - name: Generate test app name
      id: app-name
      run: |
        timestamp=$(date +%s)
        app_name="${TEST_APP_PREFIX}-status-${timestamp}"
        echo "app_name=$app_name" >> $GITHUB_OUTPUT

    - name: Deploy VM with multiple extensions
      run: |
        export APP_NAME="${{ steps.app-name.outputs.app_name }}"
        export VOLUME_NAME="test_data"
        export VOLUME_SIZE="10"
        export VM_MEMORY="2048"
        export CPU_KIND="shared"
        export CPU_COUNT="2"
        export CI_MODE="true"

        ./scripts/prepare-fly-config.sh --ci-mode

        flyctl apps create $APP_NAME --org personal || true
        flyctl volumes create test_data --app $APP_NAME --region ${REGION} --size 10 --no-encryption --yes
        flyctl secrets set CI_MODE="true" --app $APP_NAME
        flyctl deploy --app $APP_NAME --strategy immediate --wait-timeout 120s --yes

        sleep 60

    - name: Install multiple extensions
      run: |
        app_name="${{ steps.app-name.outputs.app_name }}"

        flyctl ssh console --app $app_name --command "/bin/bash -c '
          cd /workspace/scripts/lib

          # Create manifest with multiple extensions
          cat > extensions.d/active-extensions.conf << EOF
workspace-structure
mise-config
nodejs
python
ssh-environment
EOF

          # Install all
          bash extension-manager.sh install-all
        '"

    - name: Test status-all command
      run: |
        app_name="${{ steps.app-name.outputs.app_name }}"

        echo "Testing extension-manager status-all command..."

        status_output=$(flyctl ssh console --app $app_name --command "/bin/bash -c '
          cd /workspace/scripts/lib
          bash extension-manager.sh status-all
        '")

        echo "$status_output"

        # Verify output contains all installed extensions
        for ext in workspace-structure mise-config nodejs python ssh-environment; do
          if echo "$status_output" | grep -q "Extension: $ext"; then
            echo "✅ $ext in status-all output"
          else
            echo "❌ $ext missing from status-all output"
            exit 1
          fi
        done

        echo "✅ status-all command works"

    - name: Test status-all JSON export
      run: |
        app_name="${{ steps.app-name.outputs.app_name }}"

        echo "Testing JSON export..."

        json_output=$(flyctl ssh console --app $app_name --command "/bin/bash -c '
          cd /workspace/scripts/lib
          bash extension-manager.sh status-all --json
        '")

        echo "$json_output"

        # Validate JSON
        if echo "$json_output" | jq . >/dev/null 2>&1; then
          echo "✅ JSON output is valid"
        else
          echo "❌ JSON output is invalid"
          exit 1
        fi

        # Verify structure
        if echo "$json_output" | jq -e '.extensions' >/dev/null 2>&1; then
          echo "✅ JSON has extensions array"
        else
          echo "❌ JSON missing extensions array"
          exit 1
        fi

    - name: Test BOM generation script
      run: |
        app_name="${{ steps.app-name.outputs.app_name }}"

        echo "Testing BOM report generation..."

        flyctl ssh console --app $app_name --command "/bin/bash -c '
          if [ -f /workspace/scripts/generate-bom-report.sh ]; then
            bash /workspace/scripts/generate-bom-report.sh > /tmp/bom-report.txt
            echo \"\"
            echo \"=== BOM Report ===\"
            cat /tmp/bom-report.txt
            echo \"✅ BOM report generated\"
          else
            echo \"⚠️  BOM report script not found (may not be implemented yet)\"
          fi
        '"

    - name: Cleanup
      if: always()
      run: |
        flyctl apps destroy "${{ steps.app-name.outputs.app_name }}" --yes || true
```

### 2. Add mise Upgrade Test

Test that `extension-manager upgrade-all` works:

```yaml
- name: Test upgrade-all command
  run: |
    app_name="${{ steps.app-name.outputs.app_name }}"

    echo "Testing extension-manager upgrade-all..."

    flyctl ssh console --app $app_name --command "/bin/bash -lc '
      cd /workspace/scripts/lib

      # Show versions before upgrade
      echo \"Before upgrade:\"
      eval \"\$(mise activate bash)\"
      mise ls

      # Run upgrade-all
      echo \"\"
      echo \"Running upgrade-all...\"
      if bash extension-manager.sh upgrade-all; then
        echo \"✅ upgrade-all completed\"
      else
        echo \"❌ upgrade-all failed\"
        exit 1
      fi

      # Show versions after upgrade
      echo \"\"
      echo \"After upgrade:\"
      mise ls
    '"
```

## CI/CD Environment Variable Changes

### New Environment Variables

Add these to workflow files and Fly.io secrets:

```yaml
env:
  # Existing
  CI_MODE: "true"

  # New for mise
  MISE_EXPERIMENTAL: "true"          # Enable experimental features
  MISE_VERBOSE: "false"              # Reduce output noise in CI
  USE_MISE_FOR_RUBY: "false"         # Default to rbenv for ruby
  MISE_INSTALL_TIMEOUT: "600"        # 10 minute timeout for mise installations
```

In Fly.io deployment:
```bash
flyctl secrets set MISE_EXPERIMENTAL="true" --app $app_name
flyctl secrets set USE_MISE_FOR_RUBY="true" --app $app_name  # If testing mise ruby
```

## Dockerfile Changes

### Add mise Installation to Base Image

**Option A: Install mise in Dockerfile (recommended)**

Add to `Dockerfile` before extension setup:
```dockerfile
# Install mise (if mise-config will be commonly used)
RUN curl https://mise.run | sh && \
    echo 'eval "$(mise activate bash)"' >> /etc/bash.bashrc
```

**Option B: Keep mise in mise-config extension**

No Dockerfile changes - mise-config extension handles installation.
This is the **recommended approach** for flexibility.

### Update Extension Layer

No changes needed - extensions remain in the same location:
```dockerfile
# Copy extension system (includes mise-config.sh.example)
COPY docker/lib/extensions.d/ /workspace/scripts/lib/extensions.d/
COPY docker/lib/extension-manager.sh /workspace/scripts/lib/extension-manager.sh
```

## Testing Strategy Changes

### 1. Test Coverage Requirements

Update test coverage to include:

| Test Type | Current | With mise |
|-----------|---------|-----------|
| **Unit Tests** | Each extension tested individually | Add mise-config tests |
| **Integration Tests** | VM deployment + extension install | Add mise ls verification |
| **Compatibility Tests** | N/A | Traditional vs mise side-by-side |
| **Migration Tests** | N/A | NVM → mise upgrade path |
| **Performance Tests** | N/A | Installation time comparison |

### 2. Matrix Strategy Updates

**Before** (8 extensions tested):
```yaml
matrix:
  extension:
    - { name: 'nodejs', ... }
    - { name: 'python', ... }
    - { name: 'rust', ... }
    # ... 5 more
```

**After Phase 1** (9 extensions + mise variants):
```yaml
matrix:
  extension:
    # New
    - { name: 'mise-config', ... }

    # Phase 1 mise-powered (v3.x)
    - { name: 'nodejs', version: '3.0.0', uses_mise: 'true', ... }
    - { name: 'python', version: '2.0.0', uses_mise: 'true', ... }
    - { name: 'rust', version: '2.0.0', uses_mise: 'true', ... }
    - { name: 'golang', version: '2.0.0', uses_mise: 'true', ... }
    - { name: 'nodejs-devtools', version: '2.0.0', uses_mise: 'true', ... }

    # Traditional (unchanged)
    - { name: 'ruby', version: '1.0.0', ... }
    - { name: 'php', version: '1.0.0', ... }
    # ...
```

### 3. Timeout Adjustments

mise installations may be faster - adjust timeouts:

```yaml
# Current
- { name: 'nodejs', timeout: '20m' }
- { name: 'python', timeout: '30m' }
- { name: 'rust', timeout: '30m' }

# With mise (potentially faster)
- { name: 'nodejs', timeout: '15m', uses_mise: 'true' }
- { name: 'python', timeout: '20m', uses_mise: 'true' }
- { name: 'rust', timeout: '20m', uses_mise: 'true' }
```

**Note**: Monitor actual times and adjust accordingly.

## Failure Scenarios and Handling

### 1. mise Registry Unavailable

Add registry health check:

```yaml
- name: Check mise registry availability
  if: matrix.extension.uses_mise == 'true'
  run: |
    app_name="${{ steps.app-name.outputs.app_name }}"

    flyctl ssh console --app $app_name --command "/bin/bash -lc '
      eval \"\$(mise activate bash)\"

      # Test registry connectivity
      if mise ls-remote node | head -1 >/dev/null 2>&1; then
        echo \"✅ mise registry accessible\"
      else
        echo \"⚠️  mise registry may be unavailable\"
        echo \"Falling back to offline mode if available\"
      fi
    '"
```

### 2. Version Conflicts

Add conflict detection:

```yaml
- name: Check for version conflicts
  if: matrix.extension.uses_mise == 'true'
  run: |
    app_name="${{ steps.app-name.outputs.app_name }}"

    flyctl ssh console --app $app_name --command "/bin/bash -lc '
      eval \"\$(mise activate bash)\"

      # Check for multiple versions of same tool
      for tool in node python rust go; do
        count=$(mise ls $tool 2>/dev/null | wc -l)
        if [ $count -gt 1 ]; then
          echo \"⚠️  Multiple $tool versions installed:\"
          mise ls $tool
        fi
      done
    '"
```

### 3. Fallback to Traditional

Add fallback testing for hybrid extensions:

```yaml
- name: Test fallback to traditional (hybrid extensions)
  if: matrix.extension.supports_hybrid == 'true'
  run: |
    app_name="${{ steps.app-name.outputs.app_name }}"
    extension_name="${{ matrix.extension.name }}"

    echo "Testing fallback behavior when mise not available..."

    flyctl ssh console --app $app_name --command "/bin/bash -c '
      # Temporarily rename mise to simulate unavailability
      if command -v mise >/dev/null 2>&1; then
        sudo mv /usr/local/bin/mise /usr/local/bin/mise.backup
      fi

      # Try to install extension
      cd /workspace/scripts/lib
      if bash extension-manager.sh install $extension_name; then
        echo \"✅ Extension installed using fallback method\"
      else
        echo \"❌ Extension failed without mise\"
        sudo mv /usr/local/bin/mise.backup /usr/local/bin/mise 2>/dev/null
        exit 1
      fi

      # Restore mise
      sudo mv /usr/local/bin/mise.backup /usr/local/bin/mise 2>/dev/null
    '"
```

## Summary of Required Changes

### Immediate (Phase 0)

- [x] No breaking changes to existing workflows
- [ ] Add mise-config to extension matrix in `extension-tests.yml`
- [ ] Create `mise-compatibility.yml` workflow for mise-specific tests
- [ ] Add status-all output validation test

### Phase 1 Implementation

- [ ] Update extension matrix with mise dependencies
- [ ] Add mise verification steps to key functionality tests
- [ ] Create performance comparison workflow
- [ ] Update timeout values based on mise performance

### Phase 2 Implementation

- [ ] Add hybrid extension testing (USE_MISE_FOR_<TOOL> env vars)
- [ ] Add fallback testing for mise-optional extensions
- [ ] Update combination matrices with hybrid scenarios

### Phase 3 Implementation

- [ ] Add comprehensive status/BOM reporting tests
- [ ] Add JSON export validation
- [ ] Add mise doctor automated checks
- [ ] Update release workflow to mention mise in release notes

## New GitHub Actions Needed

### 1. mise Setup Action (Optional)

Could create a reusable action:

```yaml
# .github/actions/setup-mise/action.yml
name: 'Setup mise'
description: 'Install and configure mise tool manager'
inputs:
  version:
    description: 'mise version to install'
    required: false
    default: 'latest'
runs:
  using: 'composite'
  steps:
    - name: Install mise
      shell: bash
      run: |
        curl https://mise.run | sh
        echo 'eval "$(mise activate bash)"' >> ~/.bashrc

    - name: Verify installation
      shell: bash
      run: |
        eval "$(mise activate bash)"
        mise --version
```

Usage in workflows:
```yaml
- uses: ./.github/actions/setup-mise
  with:
    version: 'latest'
```

### 2. Extension Status Report Action

```yaml
# .github/actions/extension-status-report/action.yml
name: 'Extension Status Report'
description: 'Generate extension status report for PR/deployment'
inputs:
  app_name:
    description: 'Fly.io app name'
    required: true
outputs:
  report:
    description: 'Status report markdown'
    value: ${{ steps.generate.outputs.report }}
runs:
  using: 'composite'
  steps:
    - name: Generate report
      id: generate
      shell: bash
      run: |
        report=$(flyctl ssh console --app ${{ inputs.app_name }} --command "/bin/bash -c '
          cd /workspace/scripts/lib
          bash extension-manager.sh status-all
        '")

        {
          echo "report<<EOF"
          echo "$report"
          echo "EOF"
        } >> $GITHUB_OUTPUT
```

Usage:
```yaml
- uses: ./.github/actions/extension-status-report
  id: status
  with:
    app_name: ${{ steps.app-name.outputs.app_name }}

- name: Add to PR comment
  uses: actions/github-script@v8
  with:
    script: |
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: '## Extension Status\n\n```\n${{ steps.status.outputs.report }}\n```'
      });
```

## Workflow Execution Order

### Current Flow
```
validate.yml → extension-tests.yml → integration.yml → integration-resilient.yml
     ↓              (matrix: 14 exts)         ↓                    ↓
  Passes all   →   Passes all tests  →  E2E works    →      Resilient
```

### With mise Flow
```
validate.yml → extension-tests.yml → mise-compatibility.yml → integration.yml → integration-resilient.yml
     ↓          (matrix: 15 exts)           ↓                      ↓                    ↓
  Passes all       + mise-config      Test mise features    E2E works with      Resilient with
                   + mise deps                               mise stack          mise retry
```

## Performance Impact

### Expected CI/CD Times

| Workflow | Current Duration | With mise (Estimated) | Change |
|----------|-----------------|----------------------|--------|
| validate.yml | ~5 min | ~5 min | No change |
| extension-tests.yml | ~40 min (14 exts × ~3 min avg) | ~45 min (15 exts, mise may be faster) | +5 min |
| mise-compatibility.yml | N/A (new) | ~30 min | +30 min |
| integration.yml | ~15 min | ~15 min | No change |
| integration-resilient.yml | ~20 min | ~20 min | No change |

**Total CI Time**:
- Current: ~80 min
- With mise: ~115 min (+35 min for comprehensive mise testing)

**Optimization Strategies**:
1. Run mise-compatibility.yml only on mise-related changes (path filters)
2. Use `max-parallel` to run more extension tests concurrently
3. Cache mise installations between runs
4. Skip mise-compatibility on PR commits (run only on main)

## Rollback Procedures

### If mise-Powered Extension Fails in CI

```yaml
# Add to extension-tests.yml
- name: Rollback to traditional on mise failure
  if: failure() && matrix.extension.uses_mise == 'true'
  run: |
    app_name="${{ steps.app-name.outputs.app_name }}"
    extension_name="${{ matrix.extension.name }}"

    echo "⚠️  mise-powered $extension_name failed, testing traditional fallback..."

    flyctl ssh console --app $app_name --command "/bin/bash -c '
      # Remove failed mise installation
      cd /workspace/scripts/lib
      bash extension-manager.sh remove $extension_name --yes

      # Switch to traditional version (v2.x)
      # This would require version pinning in extension-manager
      bash extension-manager.sh install ${extension_name}@2.0

      # Verify traditional installation works
      bash extension-manager.sh validate $extension_name
    '"
```

## Documentation Updates Required

Update workflow documentation:

1. **README.md** - Add section on mise workflows
2. **docs/CONTRIBUTING.md** - Update CI/CD section with mise testing
3. **docs/REFERENCE.md** - Document new workflow files and actions
4. **.github/workflows/README.md** - Create workflow documentation (if doesn't exist)

## Checklist for Implementation

### Phase 0
- [ ] Create `mise-compatibility.yml` workflow
- [ ] Add mise-config to extension-tests.yml matrix
- [ ] Add status-all validation job
- [ ] Test on feature branch

### Phase 1
- [ ] Update extension matrix with mise dependencies
- [ ] Add mise verification steps
- [ ] Update timeouts based on performance testing
- [ ] Add performance comparison runs

### Phase 2
- [ ] Add hybrid extension testing
- [ ] Add fallback scenario tests
- [ ] Update combination matrices

### Phase 3
- [ ] Add BOM reporting tests
- [ ] Create reusable GitHub Actions
- [ ] Add automated mise upgrade tests
- [ ] Document all workflow changes

## References

- Current workflows: `.github/workflows/`
- mise documentation: https://mise.jdx.dev
- Extension API: Extension API v1.0
- Refactor plan: [MISE_REFACTOR.md](./MISE_REFACTOR.md)
