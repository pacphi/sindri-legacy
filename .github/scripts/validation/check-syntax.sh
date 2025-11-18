#!/bin/bash
# Check extension file syntax and structure
# Usage: check-syntax.sh [extension-file]

set -e

extension_file="$1"

if [ -z "$extension_file" ]; then
    echo "Usage: $0 <extension-file>"
    exit 1
fi

if [ ! -f "$extension_file" ]; then
    echo "❌ Extension file not found: $extension_file"
    exit 1
fi

echo "=== Extension Syntax Validation ==="
echo "File: $extension_file"
echo ""

# Check for required functions
required_functions=("prerequisites" "install" "configure" "validate" "status" "remove")
missing_functions=()

for func in "${required_functions[@]}"; do
    if grep -q "^${func}()" "$extension_file"; then
        echo "✅ Function exists: ${func}()"
    else
        echo "⚠️  Function missing: ${func}()"
        missing_functions+=("$func")
    fi
done

# Check for optional functions (API v2.0+)
if grep -q "^upgrade()" "$extension_file"; then
    echo "✅ Function exists: upgrade() (API v2.0+)"
fi

# Check for required metadata
required_metadata=("EXT_NAME" "EXT_DESCRIPTION")
for meta in "${required_metadata[@]}"; do
    if grep -q "^${meta}=" "$extension_file"; then
        echo "✅ Metadata exists: ${meta}"
    else
        echo "⚠️  Metadata missing: ${meta}"
    fi
done

# Run shellcheck if available
if command -v shellcheck >/dev/null 2>&1; then
    echo ""
    echo "=== Shellcheck Validation ==="
    if shellcheck -x "$extension_file"; then
        echo "✅ Shellcheck passed"
    else
        echo "⚠️  Shellcheck found issues (non-fatal)"
    fi
fi

# Final summary
echo ""
if [ ${#missing_functions[@]} -eq 0 ]; then
    echo "✅ All required functions present"
else
    echo "⚠️  Missing functions: ${missing_functions[*]}"
    echo "   (May be expected for some extensions)"
fi

echo "✅ Syntax validation completed"
