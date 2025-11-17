# Claude Code Extension

Handles authentication for Claude Code CLI using encrypted secrets.

## Overview

Claude Code CLI is pre-installed in the Sindri base Docker image. This extension only manages
authentication configuration using the transparent secrets management system.

## Prerequisites

- Claude Code CLI (pre-installed in base image)
- Anthropic API key

## Installation

```bash
extension-manager install claude
```

## Configuration

The extension automatically authenticates Claude Code when an API key is available in encrypted secrets.

### Add API Key

```bash
# On host machine
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... -a <app-name>

# VM restarts automatically
# Claude is authenticated on next boot
```

### Manual Configuration

```bash
# Re-run authentication after adding/updating API key
extension-manager configure claude
```

## Validation

```bash
# Check installation and authentication status
extension-manager validate claude

# Check Claude authentication
claude whoami
```

## Status

```bash
extension-manager status claude
```

## Secrets

- **Required**: `anthropic_api_key` - Anthropic API key for Claude Code authentication

## Usage

Once authenticated, Claude Code is ready to use:

```bash
# Start Claude Code
claude

# Check authentication
claude whoami
```

## Troubleshooting

**Claude not authenticated:**
```bash
# Check if API key is in secrets
view-secrets

# If missing, add it
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... -a <app-name>

# Manually re-configure
extension-manager configure claude
```

**Authentication fails:**
```bash
# Try manual authentication
claude

# Or check API key validity
claude whoami
```

## Notes

- Claude Code CLI is baked into the Docker image and doesn't require installation
- This extension only handles authentication configuration
- API keys are stored encrypted and never exposed in environment variables
- Authentication happens automatically during container startup when secrets are available
