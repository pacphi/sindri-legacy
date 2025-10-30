#!/bin/bash
# Install extension with dependencies
# Usage: install-extension.sh <extension-name> [dependencies]
set -e

extension_name="$1"
shift
# Support both space-separated and comma-separated dependencies
depends_on="$*"
depends_on="${depends_on//,/ }"  # Replace commas with spaces

cd /workspace/scripts/lib
manifest_file="extensions.d/active-extensions.conf"

# Create manifest from CI template (already has protected extensions)
if [ ! -f "$manifest_file" ]; then
  cp extensions.d/active-extensions.ci.conf "$manifest_file" 2>/dev/null || touch "$manifest_file"
fi

# Protected extensions - must match PROTECTED_EXTENSIONS in docker/lib/extensions-common.sh
protected="workspace-structure mise-config ssh-environment"

# Add dependencies first if specified
if [ -n "$depends_on" ]; then
  echo "Adding dependencies to manifest: $depends_on"
  for dep in $depends_on; do
    dep=$(echo "$dep" | xargs)  # Trim whitespace

    # Skip if protected (already in CI conf)
    if echo "$protected" | grep -qw "$dep"; then
      echo "⏭️  Skipping $dep (protected, already in CI conf)"
      continue
    fi

    if ! grep -q "^$dep$" "$manifest_file" 2>/dev/null; then
      echo "$dep" >> "$manifest_file"
      echo "✅ Dependency $dep added to manifest"
    else
      echo "✅ Dependency $dep already in manifest"
    fi
  done
fi

# Add the main extension to manifest (skip if protected)
if echo "$protected" | grep -qw "$extension_name"; then
  echo "⏭️  Skipping $extension_name (protected, already in CI conf)"
elif ! grep -q "^$extension_name$" "$manifest_file" 2>/dev/null; then
  echo "$extension_name" >> "$manifest_file"
  echo "✅ $extension_name added to manifest"
else
  echo "✅ $extension_name already in manifest"
fi

echo ""
echo "=== Active Extensions in Manifest ==="
grep -v "^[[:space:]]*#" "$manifest_file" | grep -v "^[[:space:]]*$" || echo "(empty)"

echo ""
echo "Running: extension-manager install-all"
bash extension-manager.sh install-all
