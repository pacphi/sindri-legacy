#!/bin/bash
set -e

# Source retry helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/lib/registry-retry.sh"

# Suppress systemd tmpfiles warnings by pre-creating system users/groups
# This prevents "Failed to resolve user" warnings during package installation
groupadd -f -g 999 systemd-journal 2>/dev/null || true
groupadd -f -g 998 systemd-network 2>/dev/null || true
useradd -r -g systemd-network -u 998 -s /usr/sbin/nologin systemd-network 2>/dev/null || true

# Update package lists with retry
apt_update_retry 3

# Install system dependencies with retry
# Note: libssl-dev, zlib1g-dev, libyaml-dev, libreadline-dev are required for compiling language runtimes and their native extensions
# Using --no-install-recommends to avoid pulling in unnecessary packages
apt_install_retry 3 \
    --no-install-recommends \
    software-properties-common \
    openssh-server \
    sudo \
    curl \
    wget \
    git \
    vim \
    nano \
    screen \
    tree \
    jq \
    unzip \
    build-essential \
    pkg-config \
    libssl-dev \
    zlib1g-dev \
    libyaml-dev \
    libreadline-dev \
    pipx \
    sqlite3 \
    postgresql-client \
    redis-tools \
    net-tools \
    iputils-ping \
    telnet \
    netcat-openbsd \
    rsync \
    zip \
    gnupg \
    ca-certificates \
    gettext-base

# Install yq from GitHub releases (mikefarah/yq)
echo "Installing yq from GitHub releases..."
wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
chmod +x /usr/local/bin/yq

# Install GitHub CLI
echo "Installing GitHub CLI..."
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt_update_retry 3
apt_install_retry 3 --no-install-recommends gh

# Clean up to reduce image size
apt-get clean
