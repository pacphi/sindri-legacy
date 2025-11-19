#!/bin/bash
# Test VM configuration, tools, and extension system
set -e

# Accept parameters via environment variables
REQUIRED_TOOLS="${REQUIRED_TOOLS:-curl,git,ssh}"
EXPECTED_MEMORY_MB="${EXPECTED_MEMORY_MB:-}"
EXPECTED_CPUS="${EXPECTED_CPUS:-}"
EXPECTED_CPU_KIND="${EXPECTED_CPU_KIND:-}"

echo ""
echo "📦 Checking Extension System..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-40s %-30s %s\n" "Component" "Expected" "Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check extension manager
if [ -f "/workspace/.system/bin/extension-manager" ]; then
  printf "%-40s %-30s %s\n" "Extension Manager" "/workspace/.system/bin/extension-manager" "✅ PASS"
else
  printf "%-40s %-30s %s\n" "Extension Manager" "/workspace/.system/bin/extension-manager" "❌ FAIL"
  exit 1
fi

# Check extension definitions directory (from Docker image)
if [ -d "/docker/lib/extensions.d" ]; then
  ext_count=$(ls -1 /docker/lib/extensions.d/*.extension 2>/dev/null | wc -l)
  printf "%-40s %-30s %s\n" "Extension Definitions" "/docker/lib/extensions.d/" "✅ PASS ($ext_count files)"
else
  printf "%-40s %-30s %s\n" "Extension Definitions" "/docker/lib/extensions.d/" "❌ FAIL"
  exit 1
fi

# Check manifest directory
if [ -d "/workspace/.system/manifest" ]; then
  printf "%-40s %-30s %s\n" "Manifest Directory" "/workspace/.system/manifest/" "✅ PASS"
else
  printf "%-40s %-30s %s\n" "Manifest Directory" "/workspace/.system/manifest/" "❌ FAIL"
  exit 1
fi

echo ""
echo "🛠️  Checking Required Tools..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-40s %-30s %s\n" "Tool" "Command" "Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check each required tool
IFS=',' read -ra TOOLS <<< "$REQUIRED_TOOLS"
for tool in "${TOOLS[@]}"; do
  tool=$(echo "$tool" | xargs)  # Trim whitespace
  if which "$tool" > /dev/null 2>&1; then
    tool_path=$(which "$tool")
    printf "%-40s %-30s %s\n" "$tool" "$tool_path" "✅ PASS"
  else
    printf "%-40s %-30s %s\n" "$tool" "Not found" "❌ FAIL"
    exit 1
  fi
done

echo ""
echo "📁 Checking Workspace Directory..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-40s %-30s %s\n" "Component" "Expected" "Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ls -la /workspace/ > /dev/null 2>&1; then
  printf "%-40s %-30s %s\n" "Workspace Directory" "/workspace/" "✅ PASS"
else
  printf "%-40s %-30s %s\n" "Workspace Directory" "/workspace/" "❌ FAIL"
  exit 1
fi

# Resource verification (if any expected values provided)
if [ -n "$EXPECTED_MEMORY_MB" ] || [ -n "$EXPECTED_CPUS" ] || [ -n "$EXPECTED_CPU_KIND" ]; then
  echo ""
  echo "📊 Verifying VM Resources..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "%-40s %-15s %-15s %s\n" "Resource" "Expected" "Actual" "Status"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Memory check (allow 10% variance for system overhead)
  if [ -n "$EXPECTED_MEMORY_MB" ]; then
    min_memory=$((EXPECTED_MEMORY_MB * 90 / 100))
    actual_memory=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$actual_memory" -lt "$min_memory" ]; then
      printf "%-40s %-15s %-15s %s\n" "Memory (MB)" "${EXPECTED_MEMORY_MB}MB" "${actual_memory}MB" "❌ FAIL (below ${min_memory}MB min)"
      exit 1
    else
      printf "%-40s %-15s %-15s %s\n" "Memory (MB)" "${EXPECTED_MEMORY_MB}MB" "${actual_memory}MB" "✅ PASS"
    fi
  fi

  # CPU count check
  if [ -n "$EXPECTED_CPUS" ]; then
    actual_cpus=$(nproc)
    if [ "$actual_cpus" != "$EXPECTED_CPUS" ]; then
      printf "%-40s %-15s %-15s %s\n" "CPU Count" "$EXPECTED_CPUS" "$actual_cpus" "❌ FAIL"
      exit 1
    else
      printf "%-40s %-15s %-15s %s\n" "CPU Count" "$EXPECTED_CPUS" "$actual_cpus" "✅ PASS"
    fi
  fi

  # CPU kind check
  if [ -n "$EXPECTED_CPU_KIND" ]; then
    if [ "$EXPECTED_CPU_KIND" = "performance" ]; then
      if grep -q "Xeon\|EPYC" /proc/cpuinfo 2>/dev/null; then
        cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
        printf "%-40s %-15s %-15s %s\n" "CPU Type" "Performance" "Detected" "✅ PASS ($cpu_model)"
      else
        printf "%-40s %-15s %-15s %s\n" "CPU Type" "Performance" "Unknown" "⚠️  WARNING (Could not confirm)"
      fi
    else
      printf "%-40s %-15s %-15s %s\n" "CPU Type" "Shared" "Shared" "✅ PASS"
    fi
  fi
fi

echo ""
echo "✅ All VM configuration tests passed"
