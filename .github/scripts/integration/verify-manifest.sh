#!/bin/bash
# Verify CI extension manifest configuration
set -e

echo "=== Extension Manifest Verification ==="

# Check manifest exists
if [ ! -f "/workspace/scripts/extensions.d/active-extensions.conf" ]; then
  echo "❌ Extension manifest not found at /workspace/scripts/extensions.d/active-extensions.conf"
  exit 1
fi

echo "✅ Extension manifest found"
echo ""

# Verify protected extensions are present
echo "Checking for protected extensions..."
manifest="/workspace/scripts/extensions.d/active-extensions.conf"

missing_protected=()
for ext in workspace-structure mise-config ssh-environment; do
  if ! grep -q "^${ext}$" "$manifest"; then
    missing_protected+=("$ext")
  else
    echo "  ✓ $ext"
  fi
done

if [ ${#missing_protected[@]} -gt 0 ]; then
  echo ""
  echo "❌ Missing protected extensions:"
  printf "  - %s\n" "${missing_protected[@]}"
  exit 1
fi

echo ""
echo "✅ All protected extensions present in manifest"
echo ""
echo "=== Active Extensions ==="
grep -v "^#" "$manifest" | grep -v "^$" || echo "(no active extensions)"
