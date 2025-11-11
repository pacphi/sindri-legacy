FROM ubuntu:24.04

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

# Configure SSH daemon
RUN mkdir -p /var/run/sshd && \
    cp /docker/config/sshd_config /etc/ssh/sshd_config && \
    cp /docker/config/developer-sudoers /etc/sudoers.d/developer

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