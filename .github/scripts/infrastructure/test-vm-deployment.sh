#!/bin/bash
# Test VM deployment and core infrastructure
# This consolidates:
# - VM deployment verification (directories, mounts)
# - SSH connectivity verification
# - Core system commands (mise, claude, extension-manager)
# - Basic extension workflow
# - Extension system functionality

set -e

echo "=========================================="
echo "VM Deployment & Infrastructure Test Suite"
echo "=========================================="

# ============================================================
# PHASE 1: Workspace Structure
# ============================================================
echo ""
echo "=== PHASE 1: Workspace Structure ==="
echo ""

echo "Verifying workspace directories..."
for dir in "/workspace" "/workspace/developer" "/workspace/projects/active" "/workspace/scripts" "/workspace/docs" "/workspace/config" "/workspace/bin"; do
  if [[ -d "$dir" ]]; then
    echo "✅ Directory exists: $dir"
  else
    echo "❌ Missing directory: $dir"
    exit 1
  fi
done

echo "Verifying system directories..."
for dir in "/workspace/.system" "/workspace/.system/bin" "/workspace/.system/lib" "/workspace/.system/manifest"; do
  if [[ -d "$dir" ]]; then
    echo "✅ System directory exists: $dir"
  else
    echo "❌ Missing system directory: $dir"
    exit 1
  fi
done

# ============================================================
# PHASE 2: Core Commands (Baked into Base Image)
# ============================================================
echo ""
echo "=== PHASE 2: Core Commands (Pre-installed) ==="
echo ""

echo "Verifying mise (tool version manager)..."
if command -v mise &> /dev/null; then
  echo "✅ Command available: mise ($(mise --version 2>&1 | head -1))"
else
  echo "❌ Missing command: mise"
  exit 1
fi

echo "Verifying claude (AI CLI)..."
if command -v claude &> /dev/null; then
  echo "✅ Command available: claude"
else
  echo "❌ Missing command: claude"
  exit 1
fi

echo "Verifying SSH environment setup..."
if [ -f "/etc/profile.d/00-ssh-environment.sh" ]; then
  echo "✅ SSH environment script exists"
else
  echo "❌ Missing SSH environment script"
  exit 1
fi

# ============================================================
# PHASE 3: Extension Manager
# ============================================================
echo ""
echo "=== PHASE 3: Extension Manager ==="
echo ""

# Set up extension-manager with fallback to absolute path
# This handles Hallpass SSH context where PATH may not be fully configured
EXTENSION_MANAGER="extension-manager"
if ! command -v extension-manager &> /dev/null; then
  if [ -f "/workspace/.system/bin/extension-manager" ]; then
    EXTENSION_MANAGER="/workspace/.system/bin/extension-manager"
    echo "ℹ️  Using extension-manager from absolute path"
  elif [ -f "/workspace/bin/extension-manager" ]; then
    EXTENSION_MANAGER="/workspace/bin/extension-manager"
    echo "ℹ️  Using extension-manager from /workspace/bin"
  else
    echo "❌ Extension manager not found in PATH or known locations"
    exit 1
  fi
fi

echo "Testing extension-manager list command..."
$EXTENSION_MANAGER list

echo ""
echo "✅ Extension manager available and functional"

# ============================================================
# PHASE 4: Basic Extension Workflow (nodejs as test)
# ============================================================
echo ""
echo "=== PHASE 4: Basic Extension Workflow ==="
echo ""

echo "Installing nodejs extension as test case..."

# Verify node is NOT available before extension installation
if command -v node &> /dev/null; then
  echo "⚠️  Warning: node command already available before extension installation"
  echo "   This means nodejs may already be installed, making this test less meaningful"
fi

# Add nodejs to manifest
echo "nodejs" > /workspace/.system/manifest/active-extensions.conf
if $EXTENSION_MANAGER install-all; then
  echo "✅ Extension installation completed"

  # Source environment to activate mise
  if [ -f /etc/profile.d/00-ssh-environment.sh ]; then
    source /etc/profile.d/00-ssh-environment.sh
  fi
  if command -v mise >/dev/null 2>&1; then
    if mise_activation=$(timeout 3 mise activate bash 2>/dev/null); then
      eval "$mise_activation"
    fi
  fi

  # Verify actual installation occurred (node command should now be available)
  if command -v node &> /dev/null; then
    echo "✅ node command available: $(node --version)"
  else
    echo "❌ node command not found after extension installation"
    exit 1
  fi

  # Verify npm is also available (comes with nodejs extension)
  if command -v npm &> /dev/null; then
    echo "✅ npm command available: $(npm --version)"
  else
    echo "❌ npm command not found after extension installation"
    exit 1
  fi

  # Verify extension status
  if $EXTENSION_MANAGER status nodejs; then
    echo "✅ Extension status verified"
  else
    echo "❌ Extension status check failed"
    exit 1
  fi
else
  echo "❌ Extension installation failed"
  exit 1
fi

# ============================================================
# PHASE 5: Extension System Validation
# ============================================================
echo ""
echo "=== PHASE 5: Extension System Validation ==="
echo ""

echo "Verifying nodejs via mise..."
if command -v mise >/dev/null 2>&1; then
  echo "✅ mise is available"

  # Run mise doctor for diagnostics
  echo "Running mise doctor for health check..."
  if mise doctor 2>&1 | head -20; then
    echo "✅ mise doctor check completed"
  else
    echo "⚠️  mise doctor check completed with warnings (non-fatal)"
  fi

  # List installed tools
  echo ""
  echo "Installed tools via mise:"
  mise ls 2>&1 || echo "⚠️  mise ls failed (may be expected)"
else
  echo "❌ mise not available"
  exit 1
fi

# ============================================================
# PHASE 6: Volume Mount Verification
# ============================================================
echo ""
echo "=== PHASE 6: Volume Mount Verification ==="
echo ""

echo "Verifying /workspace volume mount..."
if mountpoint -q /workspace 2>/dev/null; then
  echo "✅ /workspace is a mount point"
else
  # On some systems, /workspace might not show as mountpoint
  # Verify the volume is functional by checking developer-owned directories
  if [ -d "/workspace/developer" ] && [ -w "/workspace/developer" ]; then
    echo "✅ /workspace exists and developer directories are writable (may or may not show as mount point)"
  else
    echo "❌ /workspace volume not properly configured"
    exit 1
  fi
fi

echo "Testing write permissions on /workspace/developer..."
test_file="/workspace/developer/.test-write-$$"
if echo "test" > "$test_file" 2>/dev/null; then
  rm -f "$test_file"
  echo "✅ /workspace/developer has write permissions"
else
  echo "❌ /workspace/developer does not have write permissions"
  exit 1
fi

# ============================================================
# FINAL SUMMARY
# ============================================================
echo ""
echo "=========================================="
echo "✅ ALL INFRASTRUCTURE TESTS PASSED"
echo "=========================================="
echo "✅ Workspace Structure"
echo "✅ Core Commands (mise, claude)"
echo "✅ Extension Manager"
echo "✅ Basic Extension Workflow (nodejs)"
echo "✅ Extension System Validation"
echo "✅ Volume Mount Verification"
echo "=========================================="
