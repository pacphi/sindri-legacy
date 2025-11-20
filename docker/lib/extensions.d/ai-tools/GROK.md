# Grok CLI

Conversational AI CLI tool powered by Grok with intelligent text editor capabilities and tool usage.

## Overview

Grok CLI provides a terminal-based AI assistant powered by X.AI's Grok models. It offers:

- **Interactive Mode**: Conversational AI in your terminal
- **Headless Mode**: Single-prompt execution for automation
- **Tool Integration**: Automatic file operations and bash command execution
- **Text Editor Capabilities**: Intelligent code editing
- **MCP Support**: Extend capabilities with Model Context Protocol servers
- **Project Context**: `.grok/GROK.md` for custom instructions

## Installation

Grok CLI is installed automatically as part of the ai-tools extension via npm:

```bash
npm install -g @vibe-kit/grok-cli
```

## API Key Setup

### Method 1: User Settings File (Recommended)

Create `~/.grok/user-settings.json`:

```json
{
  "apiKey": "your_grok_api_key",
  "model": "grok-code-fast-1",
  "baseUrl": "https://api.x.ai/v1"
}
```

### Method 2: Environment Variable

```bash
# Add to ~/.bashrc
export GROK_API_KEY=your_api_key_here

# Or set temporarily
export GROK_API_KEY=your_key
grok
```

### Method 3: Fly.io Secrets (Sindri)

```bash
# On host machine
flyctl secrets set GROK_API_KEY=your_key -a <app-name>

# VM restarts with encrypted secret
# Extension automatically configures ~/.grok/user-settings.json
```

### Method 4: Command Line Flag

```bash
grok --api-key your_api_key_here
```

### Getting an API Key

1. Visit https://x.ai
2. Sign in or create an account
3. Navigate to API settings
4. Generate a new API key
5. Copy and configure using one of the methods above

## Usage

### Interactive Mode

Start a conversational session:

```bash
# Basic interactive mode
grok

# Specify working directory
grok -d /path/to/project

# Use specific model
grok --model grok-4-latest
```

**Interactive Commands**:

- Type your questions or requests naturally
- Press Ctrl+C to exit
- Grok automatically selects appropriate tools

### Headless Mode

Process single prompts (ideal for automation):

```bash
# Single prompt
grok --prompt "explain this error message"

# Short form
grok -p "show me the package.json file"

# With specific directory
grok -d /workspace/projects/myapp -p "analyze the codebase structure"
```

### Advanced Options

| Flag | Purpose | Example |
|------|---------|---------|
| `-m, --model` | Specify AI model | `grok -m grok-4-latest` |
| `-d, --directory` | Set working directory | `grok -d /path/to/project` |
| `-p, --prompt` | Headless prompt | `grok -p "your question"` |
| `-u, --base-url` | Custom API endpoint | `grok -u https://custom.api` |
| `--max-tool-rounds` | Limit tool executions | `grok --max-tool-rounds 100` |
| `-V, --version` | Show version | `grok --version` |

## Available Models

Grok CLI supports multiple Grok models:

| Model | Description | Use Case |
|-------|-------------|----------|
| `grok-code-fast-1` | Fast coding model (default) | Quick code tasks |
| `grok-4-latest` | Latest Grok 4 | Complex reasoning |
| `grok-3-latest` | Latest Grok 3 | General purpose |
| `grok-3-fast` | Fast Grok 3 | Speed-optimized |

**Set Default Model**:

```json
// ~/.grok/user-settings.json
{
  "model": "grok-4-latest"
}
```

Or via environment:

```bash
export GROK_MODEL=grok-4-latest
```

## Configuration Files

### Global Configuration

**File**: `~/.grok/user-settings.json`

```json
{
  "apiKey": "your_api_key",
  "model": "grok-code-fast-1",
  "baseUrl": "https://api.x.ai/v1",
  "maxToolRounds": 400
}
```

### Project Configuration

**File**: `.grok/settings.json` (in project root)

```json
{
  "model": "grok-4-latest",
  "mcpServers": {
    "linear": {
      "transport": "sse",
      "url": "https://mcp.linear.app/sse"
    }
  }
}
```

### Custom Instructions

**File**: `.grok/GROK.md` (in project root)

Similar to CLAUDE.md or AGENTS.md, provide project-specific context:

```markdown
# MyProject

## Build Commands
\`\`\`bash
npm install
npm run dev
npm test
\`\`\`

## Architecture
- Next.js 14 with App Router
- PostgreSQL database
- Tailwind CSS

## Coding Standards
- Use TypeScript strict mode
- Functional components only
- Test coverage > 80%
```

## MCP Integration

Extend Grok CLI with Model Context Protocol servers:

### Add MCP Server

```bash
# Add Linear integration
grok mcp add linear --transport sse --url "https://mcp.linear.app/sse"

# Add GitHub integration (example)
grok mcp add github --transport stdio --command "npx @github/mcp-server"
```

### List MCP Servers

```bash
grok mcp list
```

### Remove MCP Server

```bash
grok mcp remove linear
```

## Morph Fast Apply (Optional)

For high-speed code editing at "4,500+ tokens/sec with 98% accuracy":

```bash
# Set Morph API key
export MORPH_API_KEY=your_morph_key

# Or in ~/.grok/user-settings.json
{
  "morphApiKey": "your_morph_key"
}
```

## Common Workflows

### Code Analysis

```bash
# Interactive analysis
grok
> Analyze this codebase for security vulnerabilities

# Headless analysis
grok -p "Review UserController.ts for SQL injection risks"
```

### Code Generation

```bash
# Generate new code
grok -p "Create a React component for user authentication"

# Generate tests
grok -p "Write unit tests for the calculateDiscount function"
```

### Debugging

```bash
# Debug errors
grok
> I'm getting a TypeError in line 42 of api.ts. Here's the code: [paste]

# Explain errors
grok -p "Explain this error: Cannot read property 'map' of undefined"
```

### Refactoring

```bash
# Suggest refactoring
grok
> Refactor this function to use async/await instead of callbacks

# Optimize code
grok -p "Optimize this database query for better performance"
```

## CI/CD Integration

Use headless mode in automated workflows:

```bash
# GitHub Actions example
- name: AI Code Review
  run: |
    export GROK_API_KEY=${{ secrets.GROK_API_KEY }}
    grok -p "Review these changes for issues: $(git diff)"
```

## Best Practices

### 1. Use Project Context

Create `.grok/GROK.md` in each project:

```markdown
# Project Name

## Tech Stack
- Framework: Next.js 14
- Database: PostgreSQL
- Testing: Jest + Playwright

## Conventions
- Use functional components
- Props interfaces in same file
- Tests in __tests__ directory
```

### 2. Leverage MCP Servers

Integrate with external tools:

```bash
# Add project management
grok mcp add linear --transport sse --url "https://mcp.linear.app/sse"

# Now Grok can query Linear issues
grok
> Show me open issues assigned to me in Linear
```

### 3. Optimize for Speed

```bash
# Use fast models for simple tasks
export GROK_MODEL=grok-code-fast-1

# Use advanced models for complex reasoning
grok --model grok-4-latest -p "Design authentication architecture"
```

### 4. Secure Your API Key

```bash
# Never commit API keys
echo ".grok/" >> .gitignore

# Use encrypted secrets in production
flyctl secrets set GROK_API_KEY=key -a <app>

# Restrict file permissions
chmod 600 ~/.grok/user-settings.json
```

## Troubleshooting

### Command Not Found

```bash
# Verify installation
npm list -g @vibe-kit/grok-cli

# Reinstall if needed
npm install -g @vibe-kit/grok-cli

# Check PATH
which grok
```

### API Key Not Working

```bash
# Verify key is set
echo $GROK_API_KEY

# Check user settings
cat ~/.grok/user-settings.json

# Test with explicit key
grok --api-key your_key -p "test"
```

### Connection Issues

```bash
# Test API connectivity
curl https://api.x.ai/v1/models

# Use custom base URL if needed
grok --base-url https://custom.endpoint
```

### Tool Execution Limits

If hitting max tool rounds:

```bash
# Increase limit
grok --max-tool-rounds 1000

# Or in user settings
{
  "maxToolRounds": 1000
}
```

## Additional Resources

### Official Links

- **Website**: https://grokcli.io
- **GitHub**: https://github.com/superagent-ai/grok-cli
- **npm Package**: https://www.npmjs.com/package/@vibe-kit/grok-cli
- **X.AI Platform**: https://x.ai

### Support

- GitHub Issues: https://github.com/superagent-ai/grok-cli/issues
- X.AI Documentation
- Community forums

## Version History

- **1.0.0** - Initial release with conversational AI and tool integration

## License

MIT License - See package documentation for details
