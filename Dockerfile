# syntax=docker/dockerfile:1.4
# SECURITY: Pin base image by digest for reproducibility (H6 fix)
# To update digest: docker pull ubuntu:24.04 && docker inspect ubuntu:24.04 | grep -A1 RepoDigests
FROM ubuntu:24.04@sha256:b359f1067efa76f37863778f7b6d0e8d911e3ee8efa807ad01fbf5dc1ef9006b

# ==============================================================================
# DOCKER BUILDKIT SECRETS (H9 fix)
# ==============================================================================
# SECURITY: Use BuildKit secrets for build-time credentials
#
# BuildKit secrets allow passing sensitive data to build steps without:
# - Storing secrets in image layers
# - Exposing secrets in docker history
# - Leaking secrets via cache
#
# Usage Pattern:
# 1. Create secret file:
#    echo "sk-ant-..." > /tmp/anthropic_key.txt
#
# 2. Build with secret:
#    DOCKER_BUILDKIT=1 docker build \
#      --secret id=anthropic_key,src=/tmp/anthropic_key.txt \
#      -t sindri .
#
# 3. Access in RUN command:
#    RUN --mount=type=secret,id=anthropic_key \
#        ANTHROPIC_API_KEY=$(cat /run/secrets/anthropic_key) && \
#        # Use secret here (not persisted in layer)
#
# Example Use Cases:
# - Download private packages during build
# - Authenticate to private registries
# - Access private Git repositories
# - Verify checksums from authenticated sources
#
# Security Benefits:
# - Secrets never written to image layers
# - Secrets not visible in docker history
# - Secrets automatically cleaned up after RUN
# - No risk of accidental commit via `docker commit`
#
# Important:
# - Secrets are ONLY for build-time operations
# - Runtime secrets should use Fly.io secrets or environment variables
# - Never hardcode secrets in Dockerfile
# - Always use --mount=type=secret with RUN
# ==============================================================================

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set locale to prevent locale warnings
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Copy all Docker scripts and configurations
COPY docker/ /docker/
RUN chmod +x /docker/scripts/*.sh /docker/lib/*.sh

# Install system packages
RUN /docker/scripts/install-packages.sh

# Create developer user and configure system
RUN /docker/scripts/setup-user.sh

# Configure SSH daemon and sudo permissions
RUN mkdir -p /var/run/sshd && \
    cp /docker/config/sshd_config /etc/ssh/sshd_config && \
    cp /docker/config/developer-sudoers /etc/sudoers.d/developer && \
    chmod 0440 /etc/sudoers.d/developer && \
    chown root:root /etc/sudoers.d/developer && \
    visudo -c -f /etc/sudoers.d/developer || \
    (echo "ERROR: Invalid sudoers file" && exit 1)

# Setup bash environment for developer user
RUN /docker/scripts/setup-bashrc.sh

# ===========================================================================
# BASE SYSTEM SETUP
# ===========================================================================

# Install and configure mise (unified tool version manager)
RUN /docker/scripts/install-mise.sh

# Configure SSH environment for non-interactive sessions (CI/CD support)
RUN /docker/scripts/setup-ssh-environment.sh

# Install Claude Code CLI and create developer configuration
RUN /docker/scripts/install-claude.sh

# Setup MOTD banner (shown on every SSH login)
RUN /docker/scripts/setup-motd.sh

# Create welcome script for developer user (shown once on first login)
RUN /docker/scripts/create-welcome.sh

# Expose SSH port
EXPOSE 22

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /docker/scripts/health-check.sh

# Use startup script as entry point
CMD ["/docker/scripts/entrypoint.sh"]