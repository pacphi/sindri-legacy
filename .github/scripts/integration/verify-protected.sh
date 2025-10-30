#!/bin/bash
# Verify protected extensions are installed and functional
set -e

echo "Checking mise availability..."
if command -v mise >/dev/null 2>&1; then
  echo "✅ mise available"
  mise --version
else
  echo "❌ mise not found - mise-config installation may have failed"
  exit 1
fi

echo ""
echo "Checking workspace structure..."
if [ -d /workspace ]; then
  echo "✅ /workspace directory exists"
  ls -la /workspace | head -10
else
  echo "❌ /workspace directory missing"
  exit 1
fi
