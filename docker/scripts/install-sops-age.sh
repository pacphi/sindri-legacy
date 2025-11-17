#!/bin/bash
#
# Install SOPS and age for secrets management
#
# This script installs SOPS (Secrets OPerationS) and age encryption tools
# into the base Docker image. These tools enable transparent secrets
# management with automatic encryption of Fly.io secrets.
#
# SOPS: https://github.com/getsops/sops
# age: https://github.com/FiloSottile/age
#

set -euo pipefail

# Configuration
SOPS_VERSION="v3.8.1"
SOPS_URL="https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64"
SOPS_INSTALL_PATH="/usr/local/bin/sops"

echo "Installing secrets management tools (SOPS + age)..."

# Install age via apt
apt-get update
apt-get install -y age
apt-get clean
rm -rf /var/lib/apt/lists/*

# Download and install SOPS binary
echo "Downloading SOPS ${SOPS_VERSION}..."
wget -qO "${SOPS_INSTALL_PATH}" "${SOPS_URL}"
chmod 755 "${SOPS_INSTALL_PATH}"

# Verify installations
echo "Verifying installations..."
if ! command -v age &>/dev/null; then
    echo "ERROR: age installation failed"
    exit 1
fi

if ! command -v sops &>/dev/null; then
    echo "ERROR: sops installation failed"
    exit 1
fi

# Display versions
echo "✓ age version: $(age --version 2>&1 | head -1)"
echo "✓ sops version: $(sops --version 2>&1 | head -1)"

echo "Secrets management tools installed successfully"
