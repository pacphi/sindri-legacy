# GitHub Copilot CLI

AI-powered assistance right in your terminal - part of GitHub Copilot subscription.

## Overview

GitHub Copilot CLI brings GitHub Copilot's coding agent directly to the command line, providing AI assistance for shell
commands, code explanations, and development tasks.

**Key Features:**

- **Command Suggestions**: Natural language to shell commands
- **Command Explanations**: Understand complex commands
- **Coding Agent**: Complete coding tasks in terminal
- **Multiple AI Models**: GPT-5.1, Gemini 3 Pro, and more (Nov 2025)
- **Enhanced Code Search**: Bundled ripgrep with grep/glob tools
- **Image Support**: Paste and drag-and-drop images
- **Session Management**: Save chats as Markdown or gists
- **Custom Agents**: Create specialized agents

## Prerequisites

- **GitHub CLI**: `gh` command must be installed
- **Subscription**: GitHub Copilot Pro, Pro+, Business, or Enterprise plan
- **Authentication**: Logged into GitHub via `gh auth login`

## Installation

GitHub Copilot CLI is installed as a `gh` extension:

```bash
# Install extension
gh extension install github/gh-copilot

# Update to latest
gh extension upgrade github/gh-copilot

# Or via npm (standalone)
npm install -g @github/copilot
```

## Basic Commands

### Start Copilot CLI

```bash
# Interactive mode
copilot

# Or via gh extension
gh copilot
```

### Suggest Commands

```bash
# Get command suggestions
gh copilot suggest "list all Docker containers"
gh copilot suggest "find files modified in last 7 days"
gh copilot suggest "git command to undo last commit"

# Short form (in copilot session)
> suggest "find large files"
```

### Explain Commands

```bash
# Explain complex command
gh copilot explain "docker-compose up -d"
gh copilot explain "kubectl get pods -A"
gh copilot explain "awk '{print $1}' file.txt"

# Explain from history
history | tail -1 | gh copilot explain
```

## Slash Commands (2025 Updates)

### /model

Switch between AI models:

```bash
copilot
> /model

# Available models (Nov 2025):
# - GPT-5.1
# - GPT-5.1-Codex
# - GPT-5.1-Codex-Mini
# - Gemini 3 Pro
# - Claude 3.7 Sonnet
```

### /share

Save conversation:

```bash
copilot
> /share

# Options:
# - Save as Markdown file
# - Create GitHub gist (public/private)
```

### /usage

View session statistics:

```bash
copilot
> /usage

# Shows:
# - Premium requests used
# - Session duration
# - Lines of code edited
```

### /delegate

Hand off to coding agent:

```bash
copilot
> /delegate

# Commits unstaged changes to new branch
# Launches Copilot coding agent for implementation
```

## Common Use Cases

### Command Discovery

```bash
# Find the right command
gh copilot suggest "compress a directory with tar"
gh copilot suggest "create a systemd service"
gh copilot suggest "setup SSH key authentication"
```

### Git Operations

```bash
# Git helpers
gh copilot suggest "undo last commit but keep changes"
gh copilot suggest "rebase last 3 commits"
gh copilot suggest "find commits by author in date range"
```

### DevOps Tasks

```bash
# Docker
gh copilot suggest "clean up all stopped containers"
gh copilot suggest "view logs of running container"

# Kubernetes
gh copilot suggest "deploy app to kubernetes cluster"
gh copilot suggest "scale deployment to 5 replicas"
```

### File Operations

```bash
# File management
gh copilot suggest "find and delete all node_modules directories"
gh copilot suggest "rename files to lowercase"
gh copilot suggest "find duplicate files by content"
```

### System Administration

```bash
# System tasks
gh copilot suggest "check which process is using port 3000"
gh copilot suggest "monitor CPU usage in real-time"
gh copilot suggest "create a cron job for daily backups"
```

## Enhanced Features (2025)

### Code Search

Copilot CLI now includes bundled ripgrep:

```bash
copilot
> search for "authenticate" in TypeScript files
> find all TODO comments
> grep for SQL queries in the codebase
```

### Image Support

```bash
copilot
# Paste or drag-and-drop images
> explain this architecture diagram [paste image]
> what's wrong with this error screenshot [drag image]
```

### Custom Agents

Create specialized agents:

```bash
copilot
> /agent new security-reviewer

# Configure agent for specific tasks
# Agent persists across sessions
```

## Agentic Coding (March 2025)

Amazon Q Developer's CLI agent (powered by Claude 3.7 Sonnet) enables:

- **Dynamic Conversations**: More context-aware interactions
- **File Operations**: Read and write files locally
- **AWS Resource Queries**: Query AWS resources directly
- **Code Generation**: Create, test, and debug code
- **Iterative Refinement**: Make adjustments based on feedback

```bash
# Example agentic session
copilot
> Create a new REST API endpoint for user registration
> Add input validation using Joi
> Write unit tests for the endpoint
> Now add rate limiting
```

## Configuration

### Authentication

```bash
# Login to GitHub
gh auth login

# Verify Copilot access
gh copilot --version
```

### Aliases

```bash
# Create shell aliases
gh copilot alias -- zsh      # For zsh
gh copilot alias -- bash     # For bash

# Now use:
# ?? - suggest command
# ?! - explain command
```

## Best Practices

### 1. Be Specific

```bash
# ✗ Vague
gh copilot suggest "do something with files"

# ✓ Specific
gh copilot suggest "find all .log files larger than 100MB and delete them"
```

### 2. Use for Learning

```bash
# Explain unfamiliar commands
gh copilot explain "find . -type f -mtime -7"

# Understand syntax
gh copilot explain 'awk '\''{print $2}'\'' data.txt'
```

### 3. Verify Before Executing

```bash
# Get suggestion
gh copilot suggest "delete all temporary files"

# Review the suggested command
# Understand what it does
# Then execute manually
```

## CI/CD Integration

```yaml
# GitHub Actions
- name: Get deployment command
  run: |
    DEPLOY_CMD=$(gh copilot suggest "deploy to production" --headless)
    echo "Command: $DEPLOY_CMD"
    # Review before executing
```

## Troubleshooting

### Extension Not Found

```bash
# List extensions
gh extension list

# Install if missing
gh extension install github/gh-copilot

# Update
gh extension upgrade github/gh-copilot
```

### Authentication Issues

```bash
# Re-authenticate
gh auth logout
gh auth login

# Check status
gh auth status
```

### Subscription Issues

- Verify active Copilot subscription
- Check: https://github.com/settings/copilot
- Ensure CLI access is enabled

## Additional Resources

### Official Links

- **GitHub**: https://github.com/github/gh-copilot
- **Documentation**: https://docs.github.com/copilot/how-tos/use-copilot-in-the-cli
- **CLI Page**: https://github.com/features/copilot/cli
- **Changelog**: https://github.blog/changelog

### Learning Resources

- **Getting Started**: https://dev.to/github/stop-struggling-with-terminal-commands-github-copilot-in-the-cli-is-here-to-help-4pnb
- **Guide**: https://medium.com/@sanzgiri/a-guide-to-enabling-github-copilot-from-the-cli-ecafe2a900f9

### Community

- GitHub Community Forum
- GitHub Discussions
- Stack Overflow: `github-copilot-cli`

## Version History

- **November 2025**: GPT-5.1 models, enhanced code search, improved image support
- **October 2025**: Custom agents, model selection UI, streamlined interface
- **September 2025**: Public preview launch
- **March 2025**: CLI agent with Claude 3.7 Sonnet

## License

Requires GitHub Copilot subscription - See GitHub terms of service
