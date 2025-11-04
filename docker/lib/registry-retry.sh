#!/bin/bash
# Registry operation retry helpers
# Provides resilient wrappers for package manager operations

# Retry apt-get update with exponential backoff
apt_update_retry() {
  local max_attempts=${1:-3}
  local attempt=1

  # Use sudo only if not root
  local SUDO=""
  [ "$EUID" -ne 0 ] && SUDO="sudo"

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  APT update attempt $attempt of $max_attempts..."

    if $SUDO apt-get update -qq; then
      echo "✅ APT update successful"
      return 0
    else
      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((5 * attempt))
        echo "⚠️  APT update failed, retrying in ${wait_time}s..."
        sleep $wait_time
        attempt=$((attempt + 1))
      else
        echo "❌ APT update failed after $max_attempts attempts"
        return 1
      fi
    fi
  done
}

# Retry apt-get install with exponential backoff
apt_install_retry() {
  local max_attempts=${1:-3}
  shift
  local packages="$*"
  local attempt=1

  # Use sudo only if not root
  local SUDO=""
  [ "$EUID" -ne 0 ] && SUDO="sudo"

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  APT install attempt $attempt of $max_attempts: $packages"

    if DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq $packages; then
      echo "✅ APT install successful"
      return 0
    else
      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((10 * attempt))
        echo "⚠️  APT install failed, retrying in ${wait_time}s..."

        # Try to fix broken packages before retry
        $SUDO dpkg --configure -a 2>/dev/null || true
        $SUDO apt-get -f install -y -qq 2>/dev/null || true

        sleep $wait_time
        attempt=$((attempt + 1))
      else
        echo "❌ APT install failed after $max_attempts attempts"
        return 1
      fi
    fi
  done
}

# Retry npm install with exponential backoff
npm_install_retry() {
  local max_attempts=${1:-3}
  shift
  local packages="$*"
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  NPM install attempt $attempt of $max_attempts: $packages"

    if npm install $packages; then
      echo "✅ NPM install successful"
      return 0
    else
      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((5 * attempt))
        echo "⚠️  NPM install failed, retrying in ${wait_time}s..."

        # Clear npm cache on retry
        npm cache clean --force 2>/dev/null || true

        sleep $wait_time
        attempt=$((attempt + 1))
      else
        echo "❌ NPM install failed after $max_attempts attempts"
        return 1
      fi
    fi
  done
}

# Retry pip install with exponential backoff
pip_install_retry() {
  local max_attempts=${1:-3}
  shift
  local packages="$*"
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  PIP install attempt $attempt of $max_attempts: $packages"

    if pip3 install --quiet $packages; then
      echo "✅ PIP install successful"
      return 0
    else
      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((5 * attempt))
        echo "⚠️  PIP install failed, retrying in ${wait_time}s..."

        # Clear pip cache on retry
        pip3 cache purge 2>/dev/null || true

        sleep $wait_time
        attempt=$((attempt + 1))
      else
        echo "❌ PIP install failed after $max_attempts attempts"
        return 1
      fi
    fi
  done
}

# Retry wget download with exponential backoff
wget_retry() {
  local max_attempts=${1:-3}
  shift
  local url="$1"
  shift
  local output_args="$*"
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  WGET download attempt $attempt of $max_attempts: $url"

    if wget --quiet --timeout=30 --tries=1 $output_args "$url"; then
      echo "✅ Download successful"
      return 0
    else
      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((5 * attempt))
        echo "⚠️  Download failed, retrying in ${wait_time}s..."
        sleep $wait_time
        attempt=$((attempt + 1))
      else
        echo "❌ Download failed after $max_attempts attempts"
        return 1
      fi
    fi
  done
}

# Retry curl download with exponential backoff
curl_retry() {
  local max_attempts=${1:-3}
  shift
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    echo "▶️  CURL request attempt $attempt of $max_attempts"

    if curl --fail --silent --show-error --max-time 30 "$@"; then
      echo "✅ Request successful"
      return 0
    else
      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((5 * attempt))
        echo "⚠️  Request failed, retrying in ${wait_time}s..."
        sleep $wait_time
        attempt=$((attempt + 1))
      else
        echo "❌ Request failed after $max_attempts attempts"
        return 1
      fi
    fi
  done
}

# Export all functions
export -f apt_update_retry
export -f apt_install_retry
export -f npm_install_retry
export -f pip_install_retry
export -f wget_retry
export -f curl_retry
