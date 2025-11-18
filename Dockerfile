# ==============================================================================
# Dockerfile - Application Layer
# ==============================================================================
# This layer contains frequently-changing application files: extension
# definitions, helper scripts, and runtime configuration.
# Rebuild trigger: Extension script changes, helper script updates
# Build time: ~10-15 seconds
# Size: ~751MB total (1MB + tooling layer)
# Stability: Updated daily (most common changes)
# ==============================================================================

ARG TOOLING_IMAGE=registry.fly.io/sindri-registry:tooling-stable
FROM ${TOOLING_IMAGE}

# Copy all Docker scripts, extensions, and configurations
# This includes:
# - Extension definitions (docker/lib/extensions.d/)
# - Helper scripts (docker/lib/*.sh)
# - All setup scripts (docker/scripts/)
# - Configuration files (docker/config/)
COPY docker/ /docker/

# Make all scripts executable
RUN chmod +x /docker/scripts/*.sh /docker/lib/*.sh

# ==============================================================================
# APPLICATION LAYER SETUP
# ==============================================================================

# Setup bash environment for developer user
# Configures .bashrc with aliases, PATH, and environment variables
RUN /docker/scripts/setup-bashrc.sh

# Setup MOTD banner (shown on every SSH login)
# Displays system information and available resources
RUN /docker/scripts/setup-motd.sh

# Create welcome script for developer user (shown once on first login)
# One-time tutorial message for new users
RUN /docker/scripts/create-welcome.sh

# Expose SSH port
EXPOSE 22

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /docker/scripts/health-check.sh

# Use startup script as entry point
CMD ["/docker/scripts/entrypoint.sh"]