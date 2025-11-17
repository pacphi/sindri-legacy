# Claude Code API Key Authentication Extension

Provides automatic, transparent API key authentication for Claude Code CLI using encrypted secrets.

## Overview

Claude Code CLI is pre-installed in the Sindri base Docker image. This extension installs a **wrapper script**
that automatically loads your API key from encrypted secrets whenever you run Claude Code.

**For users who authenticate with an ANTHROPIC_API_KEY** (not Pro/Max subscriptions).

### How It Works

1. Your API key is stored encrypted in `~/.secrets/secrets.enc.yaml`
2. When you run `claude`, a wrapper script automatically:
   - Loads the API key from encrypted secrets
   - Exports it as `ANTHROPIC_API_KEY` environment variable
   - Passes control to the real Claude CLI
3. **You just run `claude`** - authentication happens transparently!

No need to manually load secrets or run authentication commands.

## Prerequisites

- Claude Code CLI (pre-installed in base image)
- Anthropic API key

## Installation

```bash
extension-manager install claude-auth-with-api-key
```

## Configuration

### Add API Key

```bash
# On host machine - set your API key as a Fly.io secret
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... -a <app-name>

# VM restarts automatically
# Next time you SSH in and run 'claude', authentication happens automatically!
```

That's it! The wrapper script handles everything automatically.

### How Authentication Works

When you run `claude`:

1. Wrapper script (`/workspace/bin/claude`) executes first
2. It loads your API key from encrypted secrets
3. Sets `ANTHROPIC_API_KEY` environment variable
4. Calls real Claude CLI (`/usr/local/bin/claude`)
5. Claude Code uses the API key automatically

**No manual authentication needed!**

## Validation

```bash
# Check installation and authentication status
extension-manager validate claude-auth-with-api-key

# Check Claude authentication
claude whoami
```

## Status

```bash
extension-manager status claude-auth-with-api-key
```

## Secrets

- **Required**: `anthropic_api_key` - Anthropic API key for Claude Code authentication

## Usage

Just run Claude Code normally - authentication is automatic:

```bash
# Start Claude Code (authentication happens automatically!)
claude

# Check authentication status
claude whoami

# All commands work transparently
claude /help
```

The wrapper ensures your API key is always available when needed, without you having to think about it.

## Troubleshooting

**Claude not authenticated:**

```bash
# Check if API key is in secrets
view-secrets

# Check if wrapper is installed
which claude  # Should show: /workspace/bin/claude

# Check if wrapper can load secrets
cat /workspace/bin/claude  # Verify wrapper script exists
```

**If authentication still fails:**

```bash
# Verify API key in Fly.io secrets
flyctl secrets list -a <app-name>

# If missing, add it
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... -a <app-name>

# Restart VM to sync secrets
flyctl machine restart <machine-id> -a <app-name>

# Reinstall extension if wrapper is missing
extension-manager install claude-auth-with-api-key
```

**Wrapper not in PATH:**

```bash
# Verify /workspace/bin is first in PATH
echo $PATH

# Should start with: /workspace/bin:...
# If not, restart your shell or run:
source ~/.bashrc
```

## Notes

- **Claude Code CLI** is pre-installed in the base Docker image at `/usr/local/bin/claude`
- **Wrapper script** is installed at `/workspace/bin/claude` (takes precedence via PATH)
- **API key security**: Stored encrypted in `~/.secrets/secrets.enc.yaml`, only loaded when needed
- **No persistent environment variables**: API key is loaded on-demand by wrapper, not stored in shell environment
- **Transparent operation**: You just run `claude` - everything else is automatic
- **Not for Pro/Max users**: If you authenticate via Pro or Max subscription (not API key), you don't need this extension

## How the Wrapper Works

```bash
#!/bin/bash
# Simplified view of /workspace/bin/claude

# Load secrets library
source ~/.secrets/lib.sh

# Export API key if available
if has_secret "anthropic_api_key"; then
    export ANTHROPIC_API_KEY=$(get_secret "anthropic_api_key")
fi

# Execute real Claude CLI
exec /usr/local/bin/claude "$@"
```

The wrapper is transparent - all arguments are passed through to the real Claude CLI.
