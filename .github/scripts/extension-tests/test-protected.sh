#!/bin/bash
# Test protected extension enforcement
set -e

cd /workspace/scripts/lib

echo "=== Testing Protected Extension Enforcement ==="

# Test deactivation prevention
echo ""
echo "Testing deactivation prevention..."
for ext in workspace-structure mise-config ssh-environment; do
  echo ""
  echo "Testing deactivation prevention for $ext..."

  # Capture exit code before piping to tee
  bash extension-manager.sh deactivate $ext 2>&1 | tee /tmp/deactivate_${ext}.log
  deactivate_exit=${PIPESTATUS[0]}

  if [ $deactivate_exit -eq 0 ]; then
    echo "❌ FAIL: $ext was deactivated (should be protected)"
    cat /tmp/deactivate_${ext}.log
    exit 1
  else
    # Check that error message mentions protection
    if grep -qi "protected\|cannot.*deactivate" /tmp/deactivate_${ext}.log; then
      echo "✅ PASS: $ext properly protected from deactivation with correct error message"
    else
      echo "⚠️  $ext blocked but no protection message found"
      cat /tmp/deactivate_${ext}.log
    fi
  fi
done

echo ""
echo "✅ All protected extensions properly blocked from deactivation"

# Test uninstall prevention
echo ""
echo "Testing uninstall prevention..."
for ext in workspace-structure mise-config ssh-environment; do
  echo ""
  echo "Testing uninstall prevention for $ext..."

  # Capture exit code before piping to tee
  bash extension-manager.sh uninstall $ext 2>&1 | tee /tmp/uninstall_${ext}.log
  uninstall_exit=${PIPESTATUS[0]}

  if [ $uninstall_exit -eq 0 ]; then
    echo "❌ FAIL: $ext was uninstalled (should be protected)"
    cat /tmp/uninstall_${ext}.log
    exit 1
  else
    # Check that error message mentions protection
    if grep -qi "protected\|cannot.*uninstall" /tmp/uninstall_${ext}.log; then
      echo "✅ PASS: $ext properly protected from uninstall with correct error message"
    else
      echo "⚠️  $ext blocked but no protection message found"
      cat /tmp/uninstall_${ext}.log
    fi
  fi
done

echo ""
echo "✅ All protected extensions properly blocked from uninstall"
