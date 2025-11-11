---
description: Create a new extension with proper directory structure, manifest entry, and API v2.0 compliance
---

Create a new extension named "{{args}}" following Sindri's Extension API v2.0 standards:

1. **Gather Requirements**:
   - Extension name and description
   - Tool/package to be installed
   - Dependencies on other extensions (especially mise-config if using mise)
   - Whether this is a mise-powered extension
   - Installation method (apt, mise, curl, etc.)
   - Key commands to validate
   - Environment variables needed

2. **Create Directory Structure**:
   - Create `docker/lib/extensions.d/{{args}}/` directory
   - Generate `install.sh` with proper API v2.0 functions:
     - `prerequisites()` - Check system requirements and dependencies
     - `install()` - Install packages and tools
     - `configure()` - Post-install configuration
     - `validate()` - Run smoke tests
     - `status()` - Check installation state
     - `remove()` - Uninstall and cleanup
     - `upgrade()` - Upgrade functionality (API v2.0)
   - Create extension metadata section at top of file
   - Add proper error handling and logging
   - Ensure idempotent operations

3. **Best Practices Implementation**:
   - Use mise if applicable (check for mise-config dependency)
   - Set DEBIAN_FRONTEND=noninteractive for apt operations
   - Run apt-get update before install, apt-get clean after
   - Create directories with proper permissions
   - Use $HOME instead of hardcoded /workspace/developer
   - Add validation checks for all installed commands
   - Include version pinning where appropriate
   - Add comprehensive error messages

4. **Manifest Integration**:
   - Add entry to `docker/lib/extensions.d/active-extensions.conf` in proper dependency order
   - Dependencies must be ordered correctly (dependents after dependencies)
   - Base system (workspace, mise, ssh, claude) is already available from Docker image
   - Add clear comments explaining the extension's purpose

5. **Documentation**:
   - Add inline comments explaining each section
   - Include usage examples in comments
   - Document any environment variables
   - Add troubleshooting notes if applicable

6. **Template Structure**:

```bash
#!/bin/bash
# Extension: {{args}}
# Description: [Brief description]
# Dependencies: [List required extensions]
# API Version: 2.0

set -e

# Extension metadata
EXTENSION_NAME="{{args}}"
EXTENSION_VERSION="1.0.0"
EXTENSION_DESCRIPTION="[Description]"

prerequisites() {
    log_info "Checking prerequisites for $EXTENSION_NAME..."
    # Check dependencies and system requirements
    return 0
}

install() {
    log_info "Installing $EXTENSION_NAME..."
    # Install packages and tools
    return 0
}

configure() {
    log_info "Configuring $EXTENSION_NAME..."
    # Post-install configuration
    return 0
}

validate() {
    log_info "Validating $EXTENSION_NAME installation..."
    # Run smoke tests
    return 0
}

status() {
    log_info "Checking $EXTENSION_NAME status..."
    # Report installation status
    return 0
}

remove() {
    log_info "Removing $EXTENSION_NAME..."
    # Cleanup and uninstall
    return 0
}

upgrade() {
    log_info "Upgrading $EXTENSION_NAME..."
    # Upgrade to latest version
    return 0
}

# Run main function if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    extension_init
fi
```

1. **Validation**:
   - Test all API functions work correctly
   - Verify idempotent behavior
   - Check dependency ordering
   - Validate against API compliance tests

If no extension name is provided, prompt for the required information interactively.
