#!/bin/bash
# Verify CI extension manifest configuration
set -e

echo "=== Extension Manifest Verification ==="

# Check manifest exists
if [ ! -f "/workspace/scripts/lib/extensions.d/active-extensions.conf" ]; then
  echo "❌ Extension manifest not found at /workspace/scripts/lib/extensions.d/active-extensions.conf"
  exit 1
fi

echo "✅ Extension manifest found"
echo ""

manifest="/workspace/scripts/lib/extensions.d/active-extensions.conf"

echo "=== Active Extensions ==="
grep -v "^#" "$manifest" | grep -v "^$" || echo "(no active extensions)"
