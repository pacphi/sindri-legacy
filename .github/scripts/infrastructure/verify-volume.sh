#!/bin/bash
# Verify volume mount and persistence
set -e

echo "=== Volume Mount Verification ==="
echo "Checking /workspace mount:"
df -h /workspace || echo "WARNING: df command failed"
echo ""

echo "Checking permissions:"
ls -la /workspace/ | head -10
echo ""

echo "Checking ownership:"
stat -c "Owner: %U:%G Mode: %a" /workspace 2>/dev/null || \
  stat -f "Owner: %Su:%Sg Mode: %Lp" /workspace 2>/dev/null || \
  echo "stat command not available"

echo ""
echo "✅ Volume mount verification complete"
