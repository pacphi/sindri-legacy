#!/bin/bash
# Test core system features and basic extension workflow
set -e

cd /workspace/scripts/lib

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
bash extension-manager.sh list

# Test installing an actual optional extension
echo ""
echo "Installing github-cli extension as test..."
echo "github-cli" > extensions.d/active-extensions.conf
if bash extension-manager.sh install-all; then
  echo "✅ Extension installed"

  # Verify installation
  if bash extension-manager.sh status github-cli; then
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
