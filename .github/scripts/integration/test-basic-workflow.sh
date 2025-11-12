#!/bin/bash
# Test core system features and basic extension workflow
set -e

echo "=== Testing Core System Features ==="

# Verify core directories exist (from baked workspace-structure)
echo ""
echo "Verifying workspace structure..."
for dir in "/workspace" "/workspace/developer" "/workspace/projects/active" "/workspace/scripts" "/workspace/docs"; do
  if [[ -d "$dir" ]]; then
    echo "✅ Directory exists: $dir"
  else
    echo "❌ Missing directory: $dir"
    exit 1
  fi
done

# Verify core commands (from baked mise-config and claude)
echo ""
echo "Verifying core commands..."
if command -v mise &> /dev/null; then
  echo "✅ Command available: mise ($(mise --version 2>&1 | head -1))"
else
  echo "❌ Missing command: mise"
  exit 1
fi

if command -v claude &> /dev/null; then
  echo "✅ Command available: claude"
else
  echo "❌ Missing command: claude"
  exit 1
fi

echo ""
echo "=== Testing Extension Manager Workflow ==="

# Test listing extensions (should NOT include workspace-structure, mise-config, etc.)
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

echo "Available installable extensions:"
$EXTENSION_MANAGER list

# Test installing an actual optional extension that installs new tools
echo ""
echo "Installing nodejs extension as test..."

# Verify node is NOT available before extension installation
if command -v node &> /dev/null; then
  echo "⚠️  Warning: node command already available before extension installation"
  echo "   This means nodejs may already be installed, making this test less meaningful"
fi

echo "nodejs" > /workspace/.system/manifest/active-extensions.conf
if $EXTENSION_MANAGER install-all; then
  echo "✅ Extension installation completed"

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

echo ""
echo "✅ All core features and extension workflow tests passed"
