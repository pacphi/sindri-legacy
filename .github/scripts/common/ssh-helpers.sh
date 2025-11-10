#!/bin/bash
# SSH helper functions for workflows
# Wrapper script to source retry-utils.sh and provide convenient aliases

# Source retry utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.github/scripts/common/retry-utils.sh
source "$SCRIPT_DIR/retry-utils.sh"

# Convenience function: Upload and chmod in one call
# Usage: sftp_upload_and_chmod <app_name> <local_file> <remote_path> <permissions>
# Example: sftp_upload_and_chmod my-app ./script.sh /tmp/script.sh 666
sftp_upload_and_chmod() {
  local app_name=$1
  local local_file=$2
  local remote_path=$3
  local permissions=$4

  echo "📤 Uploading $local_file to $remote_path and setting permissions to $permissions"

  if ! sftp_put_retry "$app_name" "$local_file" "$remote_path"; then
    echo "❌ Upload failed"
    return 1
  fi

  if ! ssh_chmod_retry "$app_name" "$permissions" "$remote_path"; then
    echo "❌ chmod failed"
    return 1
  fi

  echo "✅ Upload and chmod completed"
  return 0
}

# Convenience function: Upload multiple files and chmod
# Usage: sftp_upload_multiple <app_name> <permissions> <local1>:<remote1> [local2:remote2] ...
# Example: sftp_upload_multiple my-app 666 ./a.sh:/tmp/a.sh ./b.sh:/tmp/b.sh
sftp_upload_multiple() {
  local app_name=$1
  local permissions=$2
  shift 2

  local uploaded_files=()
  local failed=false

  # Upload all files
  for pair in "$@"; do
    local local_file="${pair%%:*}"
    local remote_path="${pair##*:}"

    echo "📤 Uploading $local_file to $remote_path"

    if sftp_put_retry "$app_name" "$local_file" "$remote_path"; then
      uploaded_files+=("$remote_path")
    else
      echo "❌ Failed to upload $local_file"
      failed=true
      break
    fi
  done

  if [ "$failed" = true ]; then
    echo "❌ Upload failed, skipping chmod"
    return 1
  fi

  # chmod all uploaded files
  if [ ${#uploaded_files[@]} -gt 0 ]; then
    echo "🔧 Setting permissions to $permissions for ${#uploaded_files[@]} files"
    if ssh_chmod_retry "$app_name" "$permissions" "${uploaded_files[@]}"; then
      echo "✅ All uploads and chmod completed"
      return 0
    else
      echo "❌ chmod failed"
      return 1
    fi
  fi
}

# Export convenience functions
export -f sftp_upload_and_chmod
export -f sftp_upload_multiple
