#!/bin/bash
# Test extension system with nodejs installation
set -e

echo "=== Testing Extension System ==="

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

# Test extension-manager availability
echo ""
echo "Testing extension-manager list..."
$EXTENSION_MANAGER list

echo ""
echo "✅ Extension manager available"

# Test extension installation (mise already available from base image)
echo ""
echo "Installing nodejs extension..."
if $EXTENSION_MANAGER install nodejs 2>&1; then
  echo "✅ nodejs extension installed"
else
  echo "⚠️  Installation failed, checking mise status..."
  if command -v mise >/dev/null 2>&1; then
    echo "Running mise doctor for diagnostics:"
    mise doctor || true
  else
    echo "mise not available (this is expected for non-mise extensions)"
  fi
  exit 1
fi

# Verify nodejs installation via mise
echo ""
echo "Verifying nodejs via mise..."
if mise_activation=$(timeout 3 mise activate bash 2>/dev/null); then
  eval "$mise_activation"
fi
if command -v node >/dev/null 2>&1; then
  echo "✅ nodejs available via mise"
  node --version
else
  echo "❌ nodejs not found after installation"
  exit 1
fi

# Verify mise is managing nodejs
echo ""
echo "Checking mise management of nodejs..."
if command -v mise >/dev/null 2>&1; then
  echo "✅ mise is available, running diagnostics..."
  mise doctor || echo "⚠️  mise doctor check completed with warnings"
else
  echo "ℹ️  mise not available (this is expected for current extension set)"
fi

echo ""
echo "✅ Extension system test passed"
