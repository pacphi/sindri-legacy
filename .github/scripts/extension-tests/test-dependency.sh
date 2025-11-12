#!/bin/bash
# Test dependency chain resolution and error handling
set -e

manifest="/workspace/.system/manifest/active-extensions.conf"

# Source the common setup for extension-manager
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/setup-extension-manager.sh"

echo "=== Testing Dependency Chain Error Handling ==="

echo "Creating manifest with nodejs only..."
echo "nodejs" > $manifest

echo ""
echo "Temporarily disabling mise to test prerequisite check..."
if command -v mise >/dev/null 2>&1; then
  mise_path=$(command -v mise)
  sudo mv $mise_path ${mise_path}.disabled 2>/dev/null || mv $mise_path ${mise_path}.disabled
fi

echo ""
echo "Running: extension-manager install nodejs (should fail - mise missing)"
# Capture exit code before piping to tee
$EXTENSION_MANAGER install nodejs 2>&1 | tee /tmp/prereq_fail.log
install_exit=${PIPESTATUS[0]}

if [ $install_exit -eq 0 ]; then
  echo "❌ Installation succeeded when mise dependency missing"
  sudo mv ${mise_path}.disabled $mise_path 2>/dev/null || mv ${mise_path}.disabled $mise_path
  cat /tmp/prereq_fail.log
  exit 1
else
  echo ""
  echo "✅ Installation correctly failed due to missing mise dependency"

  if grep -qi "prerequisite\|mise.*required\|mise.*not found" /tmp/prereq_fail.log; then
    echo "✅ Appropriate error message shown (dependency check working)"
  else
    echo "⚠️  Error message could be clearer"
    cat /tmp/prereq_fail.log
  fi

  # Restore mise for subsequent tests
  sudo mv ${mise_path}.disabled $mise_path 2>/dev/null || mv ${mise_path}.disabled $mise_path
fi

echo ""
echo "✅ Dependency error handling test passed"
