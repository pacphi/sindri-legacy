#!/bin/bash
# Verify CI extension manifest configuration
# Consolidated script used by both integration and extension tests
set -e

cd /workspace/scripts/lib
manifest_file="extensions.d/active-extensions.conf"

echo "=== Extension Manifest Verification ==="
echo ""

# Manifest should exist (created by entrypoint.sh in CI mode)
if [ ! -f "$manifest_file" ]; then
  echo "❌ Manifest not found - entrypoint.sh may not have run correctly"
  echo "Creating from CI template as fallback..."
  cp extensions.d/active-extensions.ci.conf "$manifest_file" || {
    echo "❌ Failed to create manifest from CI template"
    exit 1
  }
fi

echo "✅ Manifest exists: $manifest_file"
echo ""

echo "=== Active Extensions ==="
grep -v "^#" "$manifest_file" | grep -v "^$" || echo "(no active extensions)"
