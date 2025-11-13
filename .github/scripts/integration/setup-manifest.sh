#!/bin/bash
# Setup extension manifest for testing
set -e

manifest_file="/workspace/.system/manifest/active-extensions.conf"

# Create manifest from CI template if it doesn't exist
if [ ! -f "$manifest_file" ]; then
  cp /docker/lib/extensions.d/active-extensions.ci.conf "$manifest_file" 2>/dev/null || touch "$manifest_file"
fi

echo ""
echo "=== Extension Manifest Contents ==="
grep -v "^[[:space:]]*#" "$manifest_file" | grep -v "^[[:space]]*$" || echo "(empty)"
