#!/bin/bash
# Common retry utilities for CI workflows
# Provides retry logic with exponential backoff for flaky operations

# Generic retry with exponential backoff
# NOTE: This is the CI/automation version optimized for GitHub Actions.
#       A similar function exists in docker/lib/common.sh for VM use
#       with different defaults (1s delay, no cap).
#       These are intentionally separate - CI version has:
#       - Higher initial delay (5s vs 1s) for flaky remote operations
#       - Max delay cap (60s) to prevent workflow timeouts
#       - Different parameter handling ("$@" vs eval) for safety in automation
retry_with_backoff() {
  local max_attempts=${1:-3}
  local initial_delay=${2:-5}
  local max_delay=${3:-60}
  local attempt=1
  local exit_code=0

  shift 3

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  Attempt $attempt of $max_attempts: $*"

    if "$@"; then
      echo "✅ Command succeeded"
      return 0
    else
      exit_code=$?

      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((initial_delay * attempt))
        [ $wait_time -gt $max_delay ] && wait_time=$max_delay

        echo "⚠️  Command failed (exit: $exit_code), retrying in ${wait_time}s..."
        sleep $wait_time
        attempt=$((attempt + 1))
      else
        echo "❌ Command failed after $max_attempts attempts (exit: $exit_code)"
        return $exit_code
      fi
    fi
  done
}

# Flyctl deployment with retry
flyctl_deploy_retry() {
  local app_name=$1
  local max_attempts=4
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  Deployment attempt $attempt of $max_attempts for $app_name..."

    # Add timeout to prevent indefinite hangs (increased for image build)
    if timeout 300s flyctl deploy \
      --app "$app_name" \
      --strategy immediate \
      --wait-timeout 300s \
      --yes; then
      echo "✅ Deployment successful"
      return 0
    else
      local exit_code=$?

      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((15 * attempt))
        echo "⚠️  Deployment failed (exit: $exit_code), retrying in ${wait_time}s..."

        # Check if it's a registry issue
        if flyctl logs -a "$app_name" 2>&1 | grep -i "registry\|pull\|image"; then
          echo "🔍 Detected potential registry issue in logs"
        fi

        sleep $wait_time
        attempt=$((attempt + 1))
      else
        echo "❌ Deployment failed after $max_attempts attempts"
        echo "📋 Final logs:"
        flyctl logs -a "$app_name" || true
        return $exit_code
      fi
    fi
  done
}

# SSH command with retry
ssh_command_retry() {
  local app_name=$1
  shift
  local command="$*"
  local max_attempts=5
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  SSH attempt $attempt of $max_attempts..."

    # Execute command directly - caller provides complete command with shell invocation
    if timeout 45s flyctl ssh console -a "$app_name" --user developer -C "$command"; then
      echo "✅ SSH command succeeded"
      return 0
    else
      local exit_code=$?

      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((3 * attempt))
        echo "⚠️  SSH failed (exit: $exit_code), retrying in ${wait_time}s..."
        sleep $wait_time
        attempt=$((attempt + 1))
      else
        echo "❌ SSH command failed after $max_attempts attempts"
        return $exit_code
      fi
    fi
  done
}

# Machine readiness check with retry
wait_for_machine_ready() {
  local app_name=$1
  local max_attempts=90  # 180 seconds total (increased for CI stability)
  local attempt=1

  echo "⏳ Waiting for machine to be ready..."

  while [ $attempt -le $max_attempts ]; do
    # Capture status for logging
    status_output=$(flyctl status -a "$app_name" 2>&1)

    # Check for "started" (immediate deployment bypasses health checks)
    if echo "$status_output" | grep -q "started"; then
      echo "✅ Machine is started"
      echo "$status_output"

      # Give SSH daemon time to fully initialize (critical for CI)
      sleep 15

      # Additional check: can we execute a simple command?
      if timeout 15s flyctl ssh console -a "$app_name" --user developer -C "/bin/bash -lc 'echo ready'" &>/dev/null; then
        echo "✅ Machine is responsive"
        return 0
      else
        echo "⚠️  Machine started but not responsive yet (attempt $attempt/$max_attempts)..."
      fi
    else
      # Log progress every 10 attempts to avoid spam
      [ $((attempt % 10)) -eq 0 ] && echo "⏳ Still waiting... (attempt $attempt/$max_attempts)"
    fi

    sleep 2
    attempt=$((attempt + 1))
  done

  echo "❌ Machine failed to become ready after $max_attempts attempts"
  echo "Final status:"
  flyctl status -a "$app_name" 2>&1 || true
  return 1
}

# Export functions for use in workflows
export -f retry_with_backoff
export -f flyctl_deploy_retry
export -f ssh_command_retry
export -f wait_for_machine_ready
