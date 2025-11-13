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
        [ "$wait_time" -gt "$max_delay" ] && wait_time=$max_delay

        echo "⚠️  Command failed (exit: $exit_code), retrying in ${wait_time}s..."
        sleep "$wait_time"
        attempt=$((attempt + 1))
      else
        echo "❌ Command failed after $max_attempts attempts (exit: $exit_code)"
        return "$exit_code"
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
# Usage: ssh_command_retry <app_name> [timeout_seconds] <command>
# Example: ssh_command_retry my-app "/bin/bash -lc 'echo test'"
# Example: ssh_command_retry my-app 120 "/bin/bash -lc 'long-running-command'"
# Note: Automatically sets PATH for Sindri binaries unless command already handles it
ssh_command_retry() {
  local app_name=$1
  shift

  # Check if second parameter is a timeout (numeric)
  local timeout_seconds=45  # Default timeout
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    timeout_seconds=$1
    shift
  fi

  local command="$*"
  local max_attempts=5
  local attempt=1

  # Smart PATH handling: Only add PATH export if not already present
  # This ensures extension-manager and other Sindri tools are available in Hallpass SSH context
  if [[ ! "$command" =~ export[[:space:]]+PATH ]]; then
    # Check if command is already wrapped in bash -c
    if [[ "$command" =~ ^/bin/bash[[:space:]]+-[lc]?c[[:space:]]+[\'\"] ]]; then
      # Command is wrapped but missing PATH export, inject it after the opening quote
      # This handles cases like: /bin/bash -lc 'commands...'
      command=$(echo "$command" | sed "s|^\(/bin/bash.*-[lc]*c[[:space:]]*['\"]\)|\1export PATH=/workspace/.system/bin:/workspace/bin:\\\$PATH; |")
      echo "📍 Injecting PATH into existing bash command"
    else
      # Command is not wrapped, wrap it with PATH export
      command="/bin/bash -c 'export PATH=/workspace/.system/bin:/workspace/bin:\$PATH; $command'"
      echo "📍 Wrapping command with PATH for Sindri tools"
    fi
  fi

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  SSH attempt $attempt of $max_attempts (timeout: ${timeout_seconds}s)..."

    # Execute command and capture output for error detection
    local output
    output=$(timeout "${timeout_seconds}s" flyctl ssh console -a "$app_name" --user developer -C "$command" 2>&1)
    local exit_code=$?

    # Check for bash function import errors (fail fast - no retry)
    if echo "$output" | grep -q "error importing function definition"; then
      echo "❌ Bash environment error detected - failing fast (no retry)"
      echo ""
      echo "Error details:"
      echo "$output" | grep "bash:.*error" || echo "$output"
      return 1
    fi

    # Check for other known fatal errors that should not be retried
    if echo "$output" | grep -q "syntax error near unexpected token"; then
      echo "❌ Bash syntax error detected - failing fast (no retry)"
      echo ""
      echo "Error details:"
      echo "$output" | grep "bash:.*syntax error" || echo "$output"
      return 1
    fi

    # If command succeeded, output and return
    if [ $exit_code -eq 0 ]; then
      echo "$output"
      echo "✅ SSH command succeeded"
      return 0
    else
      # Output the result
      echo "$output"

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

# SFTP file upload with retry
# Usage: sftp_put_retry <app_name> <local_file> <remote_path>
# Example: sftp_put_retry my-app ./script.sh /tmp/script.sh
sftp_put_retry() {
  local app_name=$1
  local local_file=$2
  local remote_path=$3
  local max_attempts=5
  local attempt=1

  if [ ! -f "$local_file" ]; then
    echo "❌ Local file not found: $local_file"
    return 1
  fi

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  SFTP upload attempt $attempt of $max_attempts: $local_file -> $remote_path"

    if timeout 30s flyctl ssh sftp put "$local_file" "$remote_path" --app "$app_name" 2>&1; then
      echo "✅ SFTP upload succeeded"
      return 0
    else
      local exit_code=$?

      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((3 * attempt))
        echo "⚠️  SFTP upload failed (exit: $exit_code), retrying in ${wait_time}s..."
        sleep $wait_time
        attempt=$((attempt + 1))
      else
        echo "❌ SFTP upload failed after $max_attempts attempts"
        return $exit_code
      fi
    fi
  done
}

# SFTP shell session with retry (for heredoc uploads)
# Usage: sftp_shell_retry <app_name> <sftp_commands>
# Example: sftp_shell_retry my-app "put local.txt /tmp/remote.txt"
sftp_shell_retry() {
  local app_name=$1
  local sftp_commands=$2
  local max_attempts=5
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  SFTP shell attempt $attempt of $max_attempts..."

    if timeout 30s flyctl ssh sftp shell --app "$app_name" <<< "$sftp_commands" 2>&1; then
      echo "✅ SFTP shell session succeeded"
      return 0
    else
      local exit_code=$?

      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((3 * attempt))
        echo "⚠️  SFTP shell failed (exit: $exit_code), retrying in ${wait_time}s..."
        sleep $wait_time
        attempt=$((attempt + 1))
      else
        echo "❌ SFTP shell failed after $max_attempts attempts"
        return $exit_code
      fi
    fi
  done
}

# SSH chmod with retry (common pattern after uploads)
# Usage: ssh_chmod_retry <app_name> <permissions> <file1> [file2] [file3]...
# Example: ssh_chmod_retry my-app 666 /tmp/script.sh /tmp/helper.sh
ssh_chmod_retry() {
  local app_name=$1
  local permissions=$2
  shift 2
  local files="$*"
  local max_attempts=5
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  SSH chmod attempt $attempt of $max_attempts..."

    if timeout 30s flyctl ssh console --app "$app_name" --command "chmod $permissions $files" 2>&1; then
      echo "✅ SSH chmod succeeded"
      return 0
    else
      local exit_code=$?

      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((2 * attempt))
        echo "⚠️  SSH chmod failed (exit: $exit_code), retrying in ${wait_time}s..."
        sleep $wait_time
        attempt=$((attempt + 1))
      else
        echo "❌ SSH chmod failed after $max_attempts attempts"
        return $exit_code
      fi
    fi
  done
}

# SSH mkdir with retry (common pattern before uploads)
# Usage: ssh_mkdir_retry <app_name> <directory>
# Example: ssh_mkdir_retry my-app "/tmp/lib"
ssh_mkdir_retry() {
  local app_name=$1
  local directory=$2
  local max_attempts=5
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  SSH mkdir attempt $attempt of $max_attempts..."

    if timeout 30s flyctl ssh console --app "$app_name" --user developer --command "mkdir -p $directory" 2>&1; then
      echo "✅ SSH mkdir succeeded"
      return 0
    else
      local exit_code=$?

      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((2 * attempt))
        echo "⚠️  SSH mkdir failed (exit: $exit_code), retrying in ${wait_time}s..."
        sleep $wait_time
        attempt=$((attempt + 1))
      else
        echo "❌ SSH mkdir failed after $max_attempts attempts"
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
export -f sftp_put_retry
export -f sftp_shell_retry
export -f ssh_chmod_retry
export -f ssh_mkdir_retry
export -f wait_for_machine_ready
