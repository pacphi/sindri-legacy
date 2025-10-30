#!/bin/bash
# Test basic extension workflow
set -e

cd /workspace/scripts/lib

echo "=== Testing Extension Manager Workflow ==="

# Test listing extensions
echo ""
echo "Available extensions:"
bash extension-manager.sh list

# Test installing workspace-structure extension (auto-activates)
echo ""
echo "Installing workspace-structure extension (with auto-activation)..."
if bash extension-manager.sh install workspace-structure; then
  echo "✅ Extension installed and activated"
else
  echo "❌ Extension installation failed"
  exit 1
fi

# Verify extension is in manifest (already installed by entrypoint)
echo ""
echo "Checking extension in manifest..."
if grep -q "^workspace-structure$" extensions.d/active-extensions.conf; then
  echo "✅ Extension in manifest (already installed by entrypoint)"
else
  echo "❌ Extension not found in manifest"
  exit 1
fi

# Check extension status
echo ""
echo "Checking extension status..."
bash extension-manager.sh status workspace-structure

echo ""
echo "✅ Basic extension workflow test passed"
