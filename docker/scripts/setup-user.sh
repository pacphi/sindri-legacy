#!/bin/bash
set -e

# ==============================================================================
# Environment Configuration
# ==============================================================================
DEVELOPER_USER="developer"
WORKSPACE_DIR="/workspace"
SUDOERS_FILE="/etc/sudoers.d/$DEVELOPER_USER"

# ==============================================================================
# User Setup
# ==============================================================================

# Create developer user with sudo privileges
# -M flag: don't create home directory (will be created on persistent volume)
useradd -M -s /bin/bash -G sudo "$DEVELOPER_USER"

# Set initial password (will be disabled later for SSH key-only access)
echo "$DEVELOPER_USER:$DEVELOPER_USER" | chpasswd

# Configure sudo access without password
echo "$DEVELOPER_USER ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"

# Create workspace mount point (will be mounted as volume)
# Note: The actual workspace directories and developer home will be created
# in entrypoint.sh after the volume is mounted
mkdir -p "$WORKSPACE_DIR"
chmod 755 "$WORKSPACE_DIR"