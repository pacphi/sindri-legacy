# Contributing

We welcome contributions to improve this remote AI-assisted development environment! Whether you're fixing bugs,
adding features, improving documentation, or sharing extensions, your contributions help the entire community.

## Ways to Contribute

### Code Contributions

- **Bug Fixes**: Fix issues with VM setup, configuration, or scripts
- **Feature Additions**: Add new capabilities to the development environment
- **Performance Improvements**: Optimize resource usage or startup times
- **Security Enhancements**: Strengthen security measures or fix vulnerabilities

### Documentation

- **Setup Guides**: Improve installation and configuration documentation
- **Tutorials**: Create walkthroughs for specific use cases
- **API Documentation**: Document script functions and configuration options
- **Troubleshooting**: Add solutions for common issues

### Extensions

- **Language Support**: Add support for new programming languages
- **Tool Integrations**: Integrate popular development tools
- **Cloud Services**: Add integrations with cloud platforms
- **Workflow Automation**: Create productivity-enhancing automation

### Testing and Feedback

- **Environment Testing**: Test on different platforms and configurations
- **Bug Reports**: Report issues with detailed reproduction steps
- **Feature Requests**: Suggest improvements and new capabilities
- **User Experience**: Provide feedback on setup and usage workflows

## Getting Started

### Development Environment Setup

1. **Fork the Repository**

   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR-USERNAME/sindri.git
   cd sindri
   ```

2. **Local Development Setup (Optional)**

   For working on Sindri's documentation, linting, and formatting:

   ```bash
   # Install pnpm (if not already installed)
   npm install -g pnpm

   # Install dependencies
   pnpm install

   # Run linting and formatting
   pnpm run lint:md          # Lint markdown files
   pnpm run lint:md:fix      # Fix markdown issues
   pnpm run format           # Format all files
   pnpm run format:check     # Check formatting
   ```

   > **Note**: Sindri uses pnpm for package management. The `package.json` file contains scripts for linting and
   > formatting documentation.

3. **Set Up Development VM**

   ```bash
   # Deploy development environment
   ./scripts/vm-setup.sh --app-name contrib-dev --region sjc

   # Connect and configure
   ssh developer@contrib-dev.fly.dev -p 10022
   /workspace/scripts/vm-configure.sh
   ```

4. **Install Development Tools with mise**

   Sindri uses [mise](https://mise.jdx.dev) for polyglot tool version management:

   ```bash
   # Check mise installation
   mise --version

   # List all available tools
   mise ls

   # Install all tools from .mise.toml
   mise install

   # Activate mise environment
   eval "$(mise activate bash)"

   # Verify tool versions
   mise doctor
   ```

5. **Create Feature Branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

### mise Tool Management Workflow

Sindri uses mise for polyglot tool version management. Understanding mise basics will help you work effectively with
Sindri extensions.

**Common mise Commands:**

```bash
# List all installed tools and their versions
mise ls

# List only currently active tools
mise ls --current

# Install all tools from a TOML file
mise install -C /path/to/config.toml

# Install a specific tool
mise use nodejs@22
mise use python@3.13
mise use npm:typescript@latest

# Upgrade tools to latest versions
mise upgrade nodejs
mise upgrade --all

# Check mise installation health
mise doctor

# View mise configuration
mise config

# Uninstall a tool
mise uninstall nodejs@20

# Activate mise in current shell
eval "$(mise activate bash)"

# Show tool installation paths
mise where nodejs
```

**Working with mise Extensions:**

```bash
# Check which extensions use mise
grep -l "mise install" /workspace/scripts/extensions.d/*.extension

# View extension's TOML config
cat /workspace/config/mise/nodejs.toml

# Manually install from extension's TOML
mise install -C /workspace/config/mise/nodejs.toml

# Test tool availability after activation
eval "$(mise activate bash)"
node --version
npm --version
```

**mise Environment Variables:**

```bash
# Enable experimental features
export MISE_EXPERIMENTAL=1

# Set custom data directory
export MISE_DATA_DIR=/workspace/mise

# Disable mise activation
export MISE_DISABLED=1

# Verbose logging
export MISE_LOG_LEVEL=debug
```

**Troubleshooting mise:**

```bash
# Tool not found after installation
eval "$(mise activate bash)"  # Re-activate mise

# Check tool installation status
mise ls --current | grep tool-name

# Verify tool path
mise where tool-name

# Run health check
mise doctor

# Clear cache and reinstall
mise cache clear
mise install tool-name
```

### Project Structure

Understanding the codebase organization:

```text
sindri/
├── docker/                     # Container configuration
│   ├── config/                 # Configuration files
│   ├── context/                # AI context files
│   ├── lib/                    # Shared libraries and extensions
│   └── scripts/                # Container setup scripts
├── scripts/                    # VM management (local)
│   ├── lib/                    # Management libraries
│   └── vm-*.sh                 # VM lifecycle scripts
├── templates/                  # Configuration templates
├── docs/                       # Documentation
└── README.md                   # Main documentation
```

## Development Guidelines

### Code Standards

**Shell Scripting:**

```bash
#!/bin/bash
# Always use strict error handling
set -euo pipefail

# Source common utilities
source /workspace/scripts/lib/common.sh

# Use descriptive function names
function install_development_tool() {
    print_status "Installing development tool..."

    # Check prerequisites
    if ! command_exists curl; then
        print_error "curl is required"
        return 1
    fi

    # Installation logic here

    print_success "Development tool installed"
}
```

**Documentation:**

- Use clear, concise language
- Include code examples for all features
- Document prerequisites and assumptions
- Add troubleshooting sections

**Configuration:**

- Use environment variables for customization
- Provide sensible defaults
- Document all configuration options
- Validate configuration inputs

### Testing Requirements

**Local Testing:**

```bash
# Test script locally before submitting
./scripts/vm-setup.sh --app-name test-dev --region sjc

# Validate configuration
ssh developer@test-dev.fly.dev -p 10022 "/workspace/scripts/validate-setup.sh"

# Clean up test environment
./scripts/vm-teardown.sh --app-name test-dev
```

**Extension Testing:**

```bash
# Test new extensions
cp docker/lib/extensions.d/your-extension.extension \
   docker/lib/extensions.d/your-extension.sh

# Deploy and test
flyctl deploy -a test-dev
ssh developer@test-dev.fly.dev -p 10022 "/workspace/scripts/vm-configure.sh --extensions-only"
```

**mise Extension Testing:**

```bash
# Test mise-powered extension
extension-manager install your-extension

# Verify TOML configuration
cat /workspace/config/mise/your-extension.toml

# Check tools are registered with mise
mise ls --current

# Activate mise and test tools
eval "$(mise activate bash)"
your-tool --version

# Test tool version management
mise use tool@specific-version
mise ls --current | grep tool

# Run extension validation
extension-manager validate your-extension

# Test idempotency (should not fail on re-run)
extension-manager install your-extension
```

**Security Testing:**

```bash
# Run security scans
shellcheck scripts/*.sh docker/scripts/*.sh
bandit -r docker/lib/ -f json

# Test with minimal permissions

ssh -o PasswordAuthentication=no -o PreferredAuthentications=publickey \
    developer@test-dev.fly.dev -p 10022
```

## Contribution Workflow

### Pull Request Process

1. **Create Feature Branch**

   ```bash
   git checkout -b feature/descriptive-name
   # or
   git checkout -b fix/bug-description
   ```

2. **Make Changes**
   - Write code following project standards
   - Add or update documentation
   - Include tests where applicable
   - Update CHANGELOG.md if significant

3. **Test Thoroughly**

   ```bash
   # Local testing
   ./scripts/validate-changes.sh

   # Deploy test environment
   ./scripts/vm-setup.sh --app-name pr-test --region sjc

   # Verify changes work
   ssh developer@pr-test.fly.dev -p 10022 "your-test-commands"
   ```

4. **Commit Changes**

   ```bash
   # Use conventional commit format
   git add .
   git commit -m "feat: add support for Python data science stack"
   # or
   git commit -m "fix: resolve SSH key permission issues"
   # or
   git commit -m "docs: update setup guide with troubleshooting steps"
   ```

5. **Push and Create PR**

   ```bash
   git push origin feature/descriptive-name
   ```

   Then create a pull request on GitHub with:
   - Clear description of changes
   - Screenshots or examples if UI-related
   - Testing steps performed
   - Breaking changes noted

### Conventional Commits

Use these prefixes for commit messages:

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation updates
- `style:` - Code formatting (no functional changes)
- `refactor:` - Code restructuring (no functional changes)
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

## Extension Development

### Creating New Extensions

**Extension Template:**

Extensions are organized in directories under `docker/lib/extensions.d/`. Each extension has its own directory containing
the extension file and any related configuration files.

**Directory Structure:**

```bash
docker/lib/extensions.d/
└── extension-name/
    ├── extension-name.extension      # Main extension script (required)
    ├── extension-name.aliases        # Shell aliases (optional)
    ├── extension-name.toml           # mise configuration (optional)
    └── extension-name-ci.toml        # CI-specific mise config (optional)
```

**Extension Script Template:**

```bash
#!/bin/bash
# docker/lib/extensions.d/extension-name/extension-name.extension
# Description: Brief description of what this extension does
# Prerequisites: List any requirements
# Usage: How to enable and use this extension

# Load common utilities
source /workspace/scripts/lib/common.sh

print_status "Installing [Extension Name]..."

# Check prerequisites
if ! command_exists prerequisite-command; then
    print_error "Prerequisite not found: prerequisite-command"
    exit 1
fi

# Installation logic
install_packages package1 package2

# Configuration
cat > /workspace/config/extension-config << 'EOF'
# Extension configuration
SETTING1=value1
SETTING2=value2
EOF

# Post-installation setup
setup_extension_environment

print_success "[Extension Name] installed successfully"

# Usage instructions
cat << 'USAGE'
Extension installed! Usage:
  command1 --option     # Description
  command2              # Description

Configuration file: /workspace/config/extension-config
USAGE
```

**Extension Guidelines:**

- Use descriptive numbering (10-90 by category)
- Include comprehensive error checking
- Provide clear success/failure feedback
- Document prerequisites and usage
- Make extensions idempotent (safe to run multiple times)

### Creating mise-Powered Extensions

Sindri uses **mise** for modern tool version management. When creating extensions that install development tools,
consider using mise for simplified tool management.

**Benefits of mise-powered extensions:**

- **Version management**: Easy switching between tool versions
- **Declarative configuration**: Tools defined in `.mise.toml` files
- **Cross-platform**: Works consistently across different environments
- **Plugin ecosystem**: Access to 800+ tools via mise registry
- **Automatic activation**: Tools available in shell automatically

**When to use mise:**

- ✅ Language runtimes (Node.js, Python, Go, Rust, Ruby)
- ✅ CLI tools from npm, cargo, pipx, go install
- ✅ GitHub/GitLab release binaries
- ✅ Development tools with version dependencies
- ❌ System services (Docker, databases)
- ❌ Tools requiring complex system-level setup
- ❌ Extensions with no tool installation

**Extension Structure with mise:**

```bash
#!/bin/bash
# docker/lib/extensions.d/##-tool-name.extension
# Description: Install tool-name via mise
# Prerequisites: mise-config extension
# Uses: mise for version management

source /workspace/scripts/lib/common.sh

# Prerequisites check
function prerequisites() {
    command_exists mise || {
        echo "mise not found - install mise-config extension first"
        return 1
    }
}

# Install function
function install() {
    print_status "Installing tool-name via mise..."

    # Create mise TOML configuration
    cat > /workspace/config/mise/tool-name.toml << 'EOF'
[tools]
# Language runtime
"tool-name" = "1.2.3"

# Tools from package ecosystems
"npm:package-name" = "latest"
"cargo:binary-name" = "latest"
"pipx:cli-tool" = "latest"

# GitHub release binaries
"ubi:owner/repo" = "latest"
EOF

    # Install tools from TOML
    mise install -C /workspace/config/mise/tool-name.toml

    print_success "tool-name installed via mise"
}

# Configure function
function configure() {
    print_status "Configuring tool-name..."

    # Add mise activation to shell profiles
    append_to_profile 'eval "$(mise activate bash)"'

    # Tool-specific configuration
    cat > /workspace/config/tool-config << 'EOF'
# Tool configuration here
EOF
}

# Validate function
function validate() {
    print_status "Validating tool-name installation..."

    # Activate mise environment
    eval "$(mise activate bash)"

    # Check tool availability
    command_exists tool-name || return 1

    # Verify version
    tool-name --version

    print_success "tool-name validation passed"
}

# Status function
function status() {
    if command_exists mise; then
        mise ls --current 2>/dev/null | grep tool-name || echo "tool-name: not installed"
    else
        echo "tool-name: mise not available"
    fi
}

# Remove function
function remove() {
    print_status "Removing tool-name..."

    # Remove tools managed by mise
    mise uninstall tool-name 2>/dev/null || true

    # Remove configuration
    rm -f /workspace/config/mise/tool-name.toml
    rm -f /workspace/config/tool-config

    print_success "tool-name removed"
}
```

**mise TOML Configuration Best Practices:**

1. **Organize tools by category:**

   ```toml
   [tools]
   # Language runtime
   "nodejs" = "22"

   # Package ecosystem tools
   "npm:typescript" = "latest"
   "npm:prettier" = "latest"

   # Binary tools
   "ubi:sharkdp/fd" = "latest"
   ```

2. **Use version constraints:**

   ```toml
   [tools]
   "python" = "3.13"          # Specific version
   "go" = "latest"            # Latest stable
   "rust" = "1.80"            # Major.minor
   ```

3. **Document tool purposes:**

   ```toml
   [tools]
   # Code formatting and linting
   "npm:prettier" = "latest"
   "npm:eslint" = "latest"

   # Type checking
   "npm:typescript" = "latest"
   ```

4. **Group related tools:**

   ```toml
   # Create separate TOML files for each extension
   # /workspace/config/mise/nodejs.toml
   # /workspace/config/mise/python.toml
   # /workspace/config/mise/rust.toml
   ```

**Adding Tools to Existing mise Extensions:**

To add a new tool to an existing mise-managed extension:

1. **Locate the TOML file:**

   ```bash
   ls /workspace/config/mise/*.toml
   ```

2. **Edit the appropriate TOML:**

   ```bash
   # For Node.js tools
   nano /workspace/config/mise/nodejs.toml
   ```

3. **Add tool entry:**

   ```toml
   [tools]
   # Existing tools...
   "nodejs" = "22"

   # Add new tool
   "npm:new-tool-name" = "latest"
   ```

4. **Install the new tool:**

   ```bash
   mise install -C /workspace/config/mise/nodejs.toml
   ```

5. **Verify installation:**

   ```bash
   mise ls --current | grep new-tool-name
   new-tool-name --version
   ```

**Example: Adding a Python tool:**

```bash
# Edit Python mise config
cat >> /workspace/config/mise/python.toml << 'EOF'

# Add new CLI tool
"pipx:ruff" = "latest"
EOF

# Install the tool
mise install -C /workspace/config/mise/python.toml

# Verify
ruff --version
```

**Available mise Backends:**

- `npm:package` - Node.js packages
- `cargo:crate` - Rust packages
- `pipx:package` - Python CLI tools
- `go:package` - Go packages
- `gem:package` - Ruby gems
- `ubi:owner/repo` - GitHub/GitLab releases
- `core` - Native mise support (node, python, go, rust, ruby, etc.)

**Testing mise Extensions:**

```bash
# Test extension installation
extension-manager install tool-name

# Verify mise TOML exists
ls -la /workspace/config/mise/tool-name.toml

# Check tools are installed
mise ls --current

# Validate tool commands work
eval "$(mise activate bash)"
tool-name --version

# Test idempotency
extension-manager install tool-name  # Should succeed without errors
```

**Common Patterns:**

1. **Language + ecosystem tools:**

   ```toml
   [tools]
   "python" = "3.13"
   "pipx:black" = "latest"
   "pipx:flake8" = "latest"
   "pipx:mypy" = "latest"
   ```

2. **Binary tools from GitHub:**

   ```toml
   [tools]
   "ubi:sharkdp/bat" = "latest"
   "ubi:sharkdp/fd" = "latest"
   "ubi:BurntSushi/ripgrep" = "latest"
   ```

3. **Multiple versions:**

   ```toml
   [tools]
   "nodejs" = ["18", "20", "22"]  # Install multiple versions
   ```

For complete mise documentation, see:

- [mise official docs](https://mise.jdx.dev)
- [mise registry](https://mise.jdx.dev/registry.html)
- [Sindri mise standardization](MISE_STANDARDIZATION.md)

### Documentation Standards

**File Headers:**

```bash
#!/bin/bash
# Script Name: descriptive-name.sh
# Description: What this script does
# Author: Your Name <email@example.com>
# Version: 1.0.0
# Last Modified: YYYY-MM-DD
#
# Usage: ./script-name.sh [options]
# Example: ./script-name.sh --option value
#
# Prerequisites:
# - Prerequisite 1
# - Prerequisite 2
```

**Function Documentation:**

```bash
# Description: Brief description of function purpose
# Parameters:
#   $1: Parameter description
#   $2: Parameter description (optional)
# Returns: Description of return value/behavior
# Example: example_usage param1 param2
function example_function() {
    local param1="$1"
    local param2="${2:-default_value}"

    # Function implementation
}
```

## Review Process

### Code Review Checklist

**Functionality:**

- [ ] Code works as intended
- [ ] Edge cases handled appropriately
- [ ] Error conditions managed gracefully
- [ ] Performance impact considered

**Security:**

- [ ] No secrets or credentials exposed
- [ ] Input validation implemented
- [ ] Proper file permissions set
- [ ] Security best practices followed

**Documentation:**

- [ ] Code is well-commented
- [ ] Usage examples provided
- [ ] Prerequisites documented
- [ ] Breaking changes noted

**Testing:**

- [ ] Changes tested in clean environment
- [ ] Extension compatibility verified
- [ ] Security implications assessed
- [ ] Performance impact measured

**mise Integration (if applicable):**

- [ ] TOML configuration follows best practices
- [ ] Tools are available in mise registry or via appropriate backend
- [ ] Extension includes mise prerequisites check
- [ ] mise activation added to shell profiles
- [ ] Tool versions are pinned or use appropriate constraints
- [ ] validate() function tests mise-managed tools
- [ ] remove() function properly uninstalls mise tools

### Continuous Integration

**Automated Checks:**

- Shellcheck for script validation
- Security scanning for vulnerabilities
- Documentation link validation
- Example code testing

**Manual Review:**

- Code quality and maintainability
- User experience impact
- Security implications
- Documentation completeness

## Release Process

### Versioning

We use semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes to APIs or workflows
- **MINOR**: New features, backward-compatible
- **PATCH**: Bug fixes, security updates

### Release Checklist

**Pre-release:**

- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version numbers bumped
- [ ] Security scan clean

**Release:**

- [ ] Tagged release created
- [ ] Release notes published
- [ ] Documentation deployed
- [ ] Community notified

## Community Guidelines

### Communication

- **Be Respectful**: Treat all contributors with respect
- **Be Constructive**: Provide helpful feedback and suggestions
- **Be Collaborative**: Work together to improve the project
- **Be Patient**: Remember everyone has different experience levels

### Getting Help

- **GitHub Issues**: Report bugs and request features
- **Discussions**: Ask questions and share ideas
- **Documentation**: Check existing docs first
- **Community**: Connect with other contributors

### Recognition

Contributors are recognized through:

- Git commit attribution
- Release notes mentions
- Documentation acknowledgments
- Community highlighting

## Roadmap

### Short-term Goals

- Improved extension system
- Enhanced security features
- Better cost optimization tools
- Expanded language support

### Medium-term Goals

- Multi-region deployment templates
- Advanced monitoring and alerting
- CI/CD integration templates
- Team collaboration features

### Long-term Vision

- Full infrastructure-as-code support
- Enterprise-grade security and compliance
- AI-powered development optimization
- Global developer community platform

## Questions?

- Check existing [Issues](https://github.com/pacphi/sindri/issues)
- Start a [Discussion](https://github.com/pacphi/sindri/discussions)
- Review [Documentation](docs/)
- Contact maintainers

Thank you for contributing to the future of AI-assisted remote development! 🚀
