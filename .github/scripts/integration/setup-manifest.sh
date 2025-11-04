#!/bin/bash
# Setup extension manifest with protected extensions for testing
set -e

cd /workspace/scripts/lib
manifest_file="extensions.d/active-extensions.conf"

# Create manifest from CI template (has protected extensions: workspace-structure, mise-config, ssh-environment)
if [ ! -f "$manifest_file" ]; then
  cp extensions.d/active-extensions.ci.conf "$manifest_file" 2>/dev/null || touch "$manifest_file"
fi

echo ""
echo "=== Protected Extensions in Manifest (from CI config) ==="
grep -v "^[[:space:]]*#" "$manifest_file" | grep -v "^[[:space]]*$" || echo "(empty)"
