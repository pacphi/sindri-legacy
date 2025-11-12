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
echo "Available installable extensions:"
/workspace/.system/bin/extension-manager list

# Test installing an actual optional extension that installs new tools
echo ""
echo "Installing nodejs extension as test..."

# Verify node is NOT available before extension installation
if command -v node &> /dev/null; then
  echo "⚠️  Warning: node command already available before extension installation"
  echo "   This means nodejs may already be installed, making this test less meaningful"
fi

echo "nodejs" > /workspace/.system/manifest/active-extensions.conf
if extension-manager install-all; then
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
  if extension-manager status nodejs; then
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
