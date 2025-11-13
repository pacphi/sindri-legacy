#!/bin/bash
# Install extension with dependencies
# Usage: add-extension.sh <extension-name> [dependencies]
set -e

# Source environment for non-interactive sessions
if [ -f /etc/profile.d/00-ssh-environment.sh ]; then
    source /etc/profile.d/00-ssh-environment.sh
fi
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

# Activate mise if available
if command -v mise >/dev/null 2>&1; then
    # SECURITY: Set PROMPT_COMMAND to avoid unbound variable error with set -u
    # mise activate bash generates code that references PROMPT_COMMAND before using :-
    export PROMPT_COMMAND="${PROMPT_COMMAND:-}"
    if mise_activation=$(timeout 3 mise activate bash 2>/dev/null); then
        eval "$mise_activation"
    fi
fi

extension_name="$1"
shift
# Support both space-separated and comma-separated dependencies
depends_on="$*"
depends_on="${depends_on//,/ }"  # Replace commas with spaces

manifest_file="/workspace/.system/manifest/active-extensions.conf"

# Create manifest from CI template if it doesn't exist
if [ ! -f "$manifest_file" ]; then
  cp /docker/lib/extensions.d/active-extensions.ci.conf "$manifest_file" 2>/dev/null || touch "$manifest_file"
fi

# Add dependencies first if specified
if [ -n "$depends_on" ]; then
  echo "Adding dependencies to manifest: $depends_on"
  for dep in $depends_on; do
    dep=$(echo "$dep" | xargs)  # Trim whitespace

    if ! grep -q "^$dep$" "$manifest_file" 2>/dev/null; then
      echo "$dep" >> "$manifest_file"
      echo "✅ Dependency $dep added to manifest"
    else
      echo "✅ Dependency $dep already in manifest"
    fi
  done
fi

# Add the main extension to manifest
if ! grep -q "^$extension_name$" "$manifest_file" 2>/dev/null; then
  echo "$extension_name" >> "$manifest_file"
  echo "✅ $extension_name added to manifest"
else
  echo "✅ $extension_name already in manifest"
fi

echo ""
echo "=== Active Extensions in Manifest ==="
grep -v "^[[:space:]]*#" "$manifest_file" | grep -v "^[[:space:]]*$" || echo "(empty)"

echo ""
