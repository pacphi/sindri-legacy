# Getting Started with Sindri

Welcome to your Sindri workspace! This guide will help you get up and running with your AI-powered cloud development environment.

## First Connection

Connect to your workspace via SSH:

```bash
ssh developer@<app-name>.fly.dev -p 10022
```

Or use Fly.io's hallpass service:

```bash
flyctl ssh console -a <app-name>
```

## Quick Start

### 1. Install Essential Extensions

Run the interactive extension manager to select and install your development tools:

```bash
extension-manager --interactive
```

Or install specific extensions:

```bash
# Install Node.js with mise
extension-manager install nodejs

# Install Python with mise
extension-manager install python

# Install Claude Code CLI
extension-manager install claude
```

### 2. Create Your First Project

Use the `new-project` command to create a new development project:

```bash
# Create a Node.js project
new-project my-app --type node

# Create a Python project
new-project my-api --type python

# Create a Rust project
new-project my-tool --type rust
```

Or clone an existing repository:

```bash
# Clone and enhance a repository
clone-project https://github.com/user/repo

# Clone with branch name
clone-project https://github.com/user/repo --branch feature-branch
```

### 3. Navigate to Your Project

```bash
cd /workspace/projects/active/my-app
```

### 4. Start Coding

Launch Claude Code to begin development:

```bash
claude
```

## Workspace Structure

Your workspace is organized as follows:

- `/workspace/projects/active/` - Your development projects
- `/workspace/scripts/` - Utility and management scripts
- `/workspace/config/` - Configuration files
- `/workspace/docs/` - Workspace documentation
- `/workspace/bin/` - Executable binaries
- `/workspace/backups/` - Backup files

Each project in `projects/active/` has its own structure with `src/`, `tests/`, `docs/`, etc.

## Common Commands

### Extension Management

```bash
# List available extensions
extension-manager list

# Check extension status
extension-manager status nodejs

# Validate installation
extension-manager validate nodejs

# Upgrade extension
extension-manager upgrade nodejs
```

### Project Management

```bash
# Create new project
new-project <name> --type <type>

# Clone repository
clone-project <url> [options]
```

### Claude Code

```bash
# Launch Claude Code
claude

# View installed plugins
claude /plugin list
```

## Next Steps

- Explore available extensions: `extension-manager list`
- Read the extension guide: `/workspace/docs/extensions-guide.md`
- Configure your environment: Edit `/workspace/config/`
- Set up project-specific settings in your project's directory

## Cost Management

Your workspace auto-suspends when idle to save costs:

```bash
# Manual suspend
flyctl machine stop <machine-id> -a <app-name>

# Resume (automatic on SSH connection)
ssh developer@<app-name>.fly.dev -p 10022
```

## Support

- Documentation: `/workspace/docs/`
- Extension help: `extension-manager status <name>`
- Main project: https://github.com/pacphi/sindri

Happy coding!
