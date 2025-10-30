#!/bin/bash
set -e

# Suppress systemd tmpfiles warnings by pre-creating system users/groups
# This prevents "Failed to resolve user" warnings during package installation
groupadd -f -g 999 systemd-journal 2>/dev/null || true
groupadd -f -g 998 systemd-network 2>/dev/null || true
useradd -r -g systemd-network -u 998 -s /usr/sbin/nologin systemd-network 2>/dev/null || true

# Update package lists
apt-get update

# Install system dependencies
apt-get install -y \
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
    software-properties-common

# Install GitHub CLI
echo "Installing GitHub CLI..."
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update
apt-get install -y gh

# Clean up to reduce image size
rm -rf /var/lib/apt/lists/*
apt-get clean