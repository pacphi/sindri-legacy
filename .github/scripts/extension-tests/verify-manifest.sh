#!/bin/bash
# Verify CI extension manifest for extension tests
set -e

cd /workspace/scripts/lib
manifest_file="extensions.d/active-extensions.conf"

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

# Verify protected extensions are present
missing=()
for ext in workspace-structure mise-config ssh-environment; do
  if ! grep -q "^${ext}$" "$manifest_file"; then
    missing+=("$ext")
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "❌ Missing protected extensions: ${missing[*]}"
  echo "Adding missing protected extensions..."
  for ext in "${missing[@]}"; do
    echo "$ext" >> "$manifest_file"
  done
else
  echo "✅ All protected extensions present"
fi
