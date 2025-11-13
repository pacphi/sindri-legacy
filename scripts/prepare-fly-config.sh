#!/bin/bash

# prepare-fly-config.sh
# Script to prepare fly.toml for deployment by substituting template variables
# Usage: ./scripts/prepare-fly-config.sh [--ci-mode]

set -euo pipefail

# Detect OS for sed compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS requires empty string after -i
  SED_SUFFIX=""
else
  # Linux (GitHub Actions) doesn't use empty string
  SED_SUFFIX=""
fi

# Function to handle sed in-place edits correctly across platforms
sed_inplace() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i "" "$@"
  else
    sed -i "$@"
  fi
}

# Default values
APP_NAME="${APP_NAME:-}"
REGION="${REGION:-sjc}"
VOLUME_NAME="${VOLUME_NAME:-sindri_data}"
VOLUME_SIZE="${VOLUME_SIZE:-30}"
VM_MEMORY="${VM_MEMORY:-8192}"
CPU_KIND="${CPU_KIND:-shared}"
CPU_COUNT="${CPU_COUNT:-4}"
SSH_EXTERNAL_PORT="${SSH_EXTERNAL_PORT:-10022}"
CI_MODE="false"

# Normalize VM_MEMORY format to include units (mb or gb)
# Accepts: "4096", "4096mb", "4gb" → Outputs: "4096mb" or "4gb"
normalize_memory_format() {
  local memory="$1"
  # If already has units (mb, gb, MB, GB), use as-is
  if [[ "$memory" =~ (mb|MB|gb|GB)$ ]]; then
    echo "$memory"
  else
    # No units specified, assume MB
    echo "${memory}mb"
  fi
}

VM_MEMORY=$(normalize_memory_format "$VM_MEMORY")

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --ci-mode)
      CI_MODE="true"
      shift
      ;;
    --app-name)
      APP_NAME="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --ci-mode          Configure for CI testing (disables services and health checks)"
      echo "  --app-name NAME    Set app name"
      echo "  --region REGION    Set region (default: sjc)"
      echo "  --help             Show this help message"
      echo ""
      echo "Environment variables can be used to set other values:"
      echo "  VOLUME_NAME, VOLUME_SIZE, VM_MEMORY, CPU_KIND, CPU_COUNT, SSH_EXTERNAL_PORT"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$APP_NAME" ]]; then
  echo "Error: APP_NAME must be set either via environment variable or --app-name option"
  exit 1
fi

echo "Preparing fly.toml configuration..."
echo "  App name: $APP_NAME"
echo "  Region: $REGION"
echo "  VM Memory: $VM_MEMORY"
echo "  CPU: $CPU_COUNT x $CPU_KIND"
echo "  CI Mode: $CI_MODE"

# Create backup of original fly.toml if not already backed up
if [[ ! -f fly.toml.backup ]]; then
  echo "  Creating backup: fly.toml.backup"
  cp fly.toml fly.toml.backup
fi

# Create working copy
cp fly.toml fly.toml.tmp

# Replace template variables
sed_inplace "s/{{APP_NAME}}/$APP_NAME/g" fly.toml.tmp
sed_inplace "s/{{REGION}}/$REGION/g" fly.toml.tmp
sed_inplace "s/{{VOLUME_NAME}}/$VOLUME_NAME/g" fly.toml.tmp
sed_inplace "s/{{VOLUME_SIZE}}/$VOLUME_SIZE/g" fly.toml.tmp
sed_inplace "s/{{VM_MEMORY}}/$VM_MEMORY/g" fly.toml.tmp
sed_inplace "s/{{CPU_KIND}}/$CPU_KIND/g" fly.toml.tmp
sed_inplace "s/{{CPU_COUNT}}/$CPU_COUNT/g" fly.toml.tmp
sed_inplace "s/{{SSH_EXTERNAL_PORT}}/$SSH_EXTERNAL_PORT/g" fly.toml.tmp

# Handle CI mode - use empty services to prevent conflicts with hallpass
if [[ "$CI_MODE" == "true" ]]; then
  echo "  CI Mode: Configuring empty services to prevent hallpass conflicts"

  # Replace services section with empty array to disable all health checks
  # This prevents port 22 conflicts between SSH daemon and Fly.io's hallpass service
  cat > services_replacement.tmp << 'EOF'
# Services configuration - empty for CI mode to prevent hallpass conflicts
services = []

# Monitoring and health checks - disabled for CI
# [checks]
# No health checks in CI mode - rely on deployment success only
EOF

  # Remove existing services and checks sections, then add empty services
  sed_inplace '/# SSH service configuration/,/restart_limit = 0/d' fly.toml.tmp
  sed_inplace '/# Monitoring and health checks/,/path = "\/metrics"/d' fly.toml.tmp
  sed_inplace '/\[checks\]/,/timeout = "2s"/d' fly.toml.tmp

  # Remove release_command in CI mode to prevent deployment timeouts
  sed_inplace '/release_command/d' fly.toml.tmp

  # Insert empty services configuration before [machine] section
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed syntax
    sed -i '' '/\[machine\]/i\
\
# Services configuration - empty for CI mode to prevent hallpass conflicts\
services = []\
\
# Monitoring and health checks - disabled for CI\
# [checks]\
# No health checks in CI mode - rely on deployment success only\
' fly.toml.tmp
  else
    # Linux sed syntax - requires different quoting
    sed -i '/\[machine\]/i\
\
# Services configuration - empty for CI mode to prevent hallpass conflicts\
services = []\
\
# Monitoring and health checks - disabled for CI\
# [checks]\
# No health checks in CI mode - rely on deployment success only\
' fly.toml.tmp
  fi

  rm -f services_replacement.tmp
fi

# Replace the original file
mv fly.toml.tmp fly.toml

echo "✅ fly.toml configuration prepared successfully"

# Validate the configuration
if command -v flyctl &> /dev/null; then
  echo "Validating fly.toml..."
  if flyctl config validate --config fly.toml; then
    echo "✅ fly.toml validation passed"
  else
    echo "❌ fly.toml validation failed"
    exit 1
  fi
else
  echo "⚠️  flyctl not found - skipping validation"
fi