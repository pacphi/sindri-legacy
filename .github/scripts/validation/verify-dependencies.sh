#!/bin/bash
# Verify extension dependency chain
# Usage: verify-dependencies.sh <extension-name>

set -e

extension="$1"

if [ -z "$extension" ]; then
    echo "Usage: $0 <extension-name>"
    exit 1
fi

extension_file="/docker/lib/extensions.d/${extension}.extension"

if [ ! -f "$extension_file" ]; then
    echo "❌ Extension file not found: $extension_file"
    exit 1
fi

echo "=== Dependency Chain Verification ==="
echo "Extension: $extension"
echo ""

# Extract dependencies from metadata
depends_on=$(grep "^EXT_DEPENDS_ON=" "$extension_file" | cut -d'=' -f2- | tr -d '"' || echo "")

if [ -z "$depends_on" ]; then
    echo "✅ No dependencies declared"
    exit 0
fi

echo "Dependencies: $depends_on"
echo ""

# Verify each dependency exists
missing_deps=()
for dep in $depends_on; do
    dep_file="/docker/lib/extensions.d/${dep}.extension"
    if [ -f "$dep_file" ]; then
        echo "✅ Dependency exists: $dep"
    else
        echo "❌ Dependency missing: $dep"
        missing_deps+=("$dep")
    fi
done

echo ""
if [ ${#missing_deps[@]} -eq 0 ]; then
    echo "✅ All dependencies satisfied"
else
    echo "❌ Missing dependencies: ${missing_deps[*]}"
    exit 1
fi
