# Gemini CLI

Open source AI agent providing access to Google's Gemini directly in your terminal using a reason-and-act (ReAct) loop
with built-in tools and MCP servers.

## Overview

Gemini CLI transforms the UNIX command line by enabling natural language interactions. You don't need to memorize obscure
syntax - simply describe your intent and Gemini translates and executes it.

**Key Features:**

- **Natural Language Shell**: Execute commands via plain English
- **Interactive Shell Support**: vim, nvim, nano, git interactive, language REPLs
- **Built-in Tools**: web_search, web_fetch, google_web_search, save_memory
- **File Operations**: Respects .gitignore and .geminiignore
- **Media Support**: Reference images, PDFs, audio, video files
- **Checkpointing**: Automatic snapshots before file modifications
- **MCP Integration**: Extend with Model Context Protocol servers
- **Custom Commands**: TOML-based command definitions

## Installation

Gemini CLI is installed automatically as part of the ai-tools extension via npm:

```bash
npm install -g @google/gemini-cli
```

## API Key Setup

### Method 1: Environment Variable (Recommended)

```bash
# Get API key from Google AI Studio
# Visit: https://makersuite.google.com/app/apikey

# Add to ~/.bashrc for persistence
echo 'export GEMINI_API_KEY=your_api_key_here' >> ~/.bashrc
source ~/.bashrc
```

### Method 2: Fly.io Secrets (Sindri)

```bash
# On host machine
flyctl secrets set GOOGLE_GEMINI_API_KEY=your_key -a <app-name>

# VM restarts with encrypted secret
# Extension automatically configures Gemini
```

### Method 3: Configuration File

Create `~/.config/gemini/config.json`:

```json
{
  "api_key": "your_api_key_here"
}
```

## Basic Usage

### Interactive Mode

```bash
# Start Gemini CLI
gemini

# Now use natural language
> Create a Python script that downloads images from a URL
> Rename all .jpg files to include their creation date
> Review this codebase and generate documentation
```

### Single Prompt (Headless)

```bash
gemini chat "explain this error message"
gemini generate "create unit tests for UserService.ts"
```

## Available Commands

### Chat Commands

```bash
# General conversation
gemini chat "how do I implement OAuth2 in Node.js?"

# Code explanation
gemini chat "explain what this function does" < script.js

# Error debugging
gemini chat "why am I getting TypeError: Cannot read property 'map' of undefined"
```

### Code Generation

```bash
# Generate new code
gemini generate "create a REST API endpoint for user registration"

# Generate tests
gemini generate "write unit tests for calculateDiscount function"

# Generate documentation
gemini generate "create API documentation for this Express app"
```

### Analysis

```bash
# Code review
gemini analyze "review for security issues" < UserController.ts

# Performance analysis
gemini analyze "identify performance bottlenecks" < database-queries.sql
```

## Built-in Tools

Gemini CLI includes powerful built-in tools:

### Web Search

```bash
gemini
> Find the latest news articles about 'AI coding assistants'
> Search for best practices for React 18 Suspense
```

### Web Fetch

```bash
gemini
> Fetch the content from https://example.com/api/docs
> Summarize the article at [URL]
```

### Save Memory

```bash
gemini
> Save this API endpoint URL for later: https://api.example.com
> What API endpoint did we save earlier?
```

### File Operations

```bash
gemini
> Analyze all TypeScript files in src/
> Create a new component based on UserProfile.tsx
> Refactor this file to use async/await
```

## Advanced Features

### Gemini 3 Pro (Latest)

Available for Google AI Ultra and paid API subscribers:

```bash
# Use Gemini 3 Pro for complex reasoning
gemini --model gemini-3-pro
> Design the authentication architecture for a microservices application
> Implement comprehensive error handling across the codebase
```

### Interactive Shell Commands

Execute interactive commands directly:

```bash
gemini
> Edit src/app.ts with vim
> Run git commit interactively
> Start Python REPL and test this function
```

### Checkpointing

Gemini automatically saves project snapshots before modifications:

```bash
gemini
# After making changes
> /restore           # List available checkpoints
> /restore 2         # Restore specific checkpoint
```

### Custom Commands

Create reusable commands via TOML files:

**Global Commands** (`~/.gemini/commands/my-command.toml`):

```toml
[command]
name = "review-security"
description = "Review code for security vulnerabilities"
prompt = """
Review the provided code for common security vulnerabilities:
1. SQL injection risks
2. XSS vulnerabilities
3. Authentication issues
4. Authorization flaws
5. Insecure data handling

Provide specific examples and fixes.
"""
```

**Project Commands** (`<project>/.gemini/commands/test-gen.toml`):

```toml
[command]
name = "gen-tests"
description = "Generate unit tests following project conventions"
prompt = """
Generate unit tests for the provided code following these conventions:
- Use Jest and React Testing Library
- Test happy path and error cases
- Mock external dependencies
- Minimum 80% coverage
"""
```

**Usage**:

```bash
# List commands
gemini /commands

# Use custom command
gemini /review-security < UserController.ts
gemini /gen-tests < UserService.ts
```

### MCP Server Integration

Extend Gemini with Model Context Protocol servers:

```bash
# Add MCP server
gemini mcp add github

# List servers
gemini mcp list

# Remove server
gemini mcp remove github

# Configure in settings.json
cat > .gemini/settings.json << 'EOF'
{
  "mcpServers": {
    "github": {
      "transport": "stdio",
      "command": "npx",
      "args": ["@modelcontextprotocol/server-github"]
    },
    "linear": {
      "transport": "sse",
      "url": "https://mcp.linear.app/sse"
    }
  }
}
EOF
```

## Project Context

### .gemini/GEMINI.md

Create project-specific instructions (similar to CLAUDE.md or AGENTS.md):

```markdown
# MyProject

## Build Commands
\`\`\`bash
npm install
npm run dev      # Start dev server on :3000
npm test         # Run Jest tests
npm run build    # Production build
\`\`\`

## Architecture
- Next.js 14 with App Router
- PostgreSQL with Prisma ORM
- Tailwind CSS for styling
- Jest + React Testing Library

## Code Standards
- TypeScript strict mode
- Functional components only
- Props interfaces in same file
- Tests in __tests__/ directories
- Min 80% test coverage

## Naming Conventions
- Components: PascalCase (UserProfile.tsx)
- Utils: camelCase (formatDate.ts)
- Constants: UPPER_SNAKE_CASE
```

### .geminiignore

Exclude files from context (similar to .gitignore):

```text
node_modules/
dist/
build/
*.log
.env
.env.local
```

## Common Workflows

### Code Review

```bash
gemini
> Review this pull request for security and code quality issues
> Analyze UserController.ts for potential bugs
```

### Documentation Generation

```bash
gemini
> Generate comprehensive README for this project
> Create API documentation from the Express routes
> Document all exported functions in utils/
```

### Refactoring

```bash
gemini
> Refactor this class to use async/await instead of callbacks
> Convert this component from class-based to functional with hooks
> Extract reusable logic into helper functions
```

### Test Generation

```bash
gemini
> Generate unit tests for AuthService with 100% coverage
> Create integration tests for the API endpoints
> Write E2E tests for the login flow
```

### Bug Fixing

```bash
gemini
> Debug why this async function is causing a race condition
> Fix the memory leak in the WebSocket connection
> Resolve TypeScript type errors in UserModel
```

### Feature Implementation

```bash
gemini
> Implement JWT authentication with refresh tokens
> Add rate limiting to all API endpoints
> Create a dark mode toggle for the UI
```

## Practical Examples

### Example 1: Batch File Operations

```bash
gemini
> Rename all .jpg and .png files in this directory to include their creation
> date from EXIF data in 'YYYYMMDD_HHMMSS_original_name.jpg' format.
> If no EXIF date found, use file's last modified date.
```

### Example 2: Web Research

```bash
gemini
> Find the latest news articles about 'React Server Components'.
> For the top 5 relevant articles, summarize each in 2-3 sentences
> and list their URLs.
```

### Example 3: Complex Refactoring

```bash
gemini
> Analyze all components in src/components/ and identify:
> 1. Components with prop drilling issues
> 2. Opportunities for custom hooks
> 3. Performance optimization candidates
> Then refactor the top 3 priority items.
```

## Configuration

### Settings File

**Global**: `~/.gemini/settings.json`
**Project**: `.gemini/settings.json`

```json
{
  "apiKey": "your_key",
  "model": "gemini-3-pro",
  "temperature": 0.7,
  "maxTokens": 8192,
  "mcpServers": {
    "github": {
      "transport": "stdio",
      "command": "npx",
      "args": ["@modelcontextprotocol/server-github"]
    }
  }
}
```

### Available Models

- `gemini-3-pro` - Latest Gemini 3 Pro (best reasoning)
- `gemini-2.0-flash` - Fast responses
- `gemini-2.0-pro` - Gemini 2.0 Pro
- `gemini-1.5-pro` - Gemini 1.5 Pro
- `gemini-1.5-flash` - Fast Gemini 1.5

**Select Model**:

```bash
# Via flag
gemini --model gemini-3-pro

# Via environment
export GEMINI_MODEL=gemini-3-pro

# Via settings.json
{
  "model": "gemini-3-pro"
}
```

## CI/CD Integration

Use Gemini CLI in automated workflows:

```yaml
# GitHub Actions example
- name: AI Code Review
  env:
    GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
  run: |
    gemini chat "Review these changes for issues" < <(git diff)
```

## Best Practices

### 1. Provide Clear Context

```bash
# ✗ Vague
gemini chat "fix the bug"

# ✓ Specific
gemini chat "Fix the race condition in src/api/auth.ts line 42 where multiple
concurrent login attempts cause duplicate session creation"
```

### 2. Use Project Context

Create `.gemini/GEMINI.md` with:

- Build commands
- Testing procedures
- Code standards
- Architecture overview

### 3. Leverage Built-in Tools

```bash
# Let Gemini search for information
gemini
> Search for Node.js best practices for handling authentication tokens
> Fetch the TypeScript documentation on utility types
```

### 4. Review Generated Code

Always review and test AI-generated code:

```bash
# Generate code
gemini generate "create user authentication endpoint"

# Review output
# Test thoroughly
# Modify as needed
```

### 5. Use Checkpoints

Gemini saves snapshots automatically:

```bash
# Make changes
gemini
> Refactor entire authentication system

# If issues occur
> /restore    # List checkpoints
> /restore 1  # Restore before changes
```

## Troubleshooting

### API Key Not Working

```bash
# Check environment variable
echo $GEMINI_API_KEY

# Verify in config
cat ~/.config/gemini/config.json

# Test explicitly
gemini --api-key your_key chat "test"
```

### Command Not Found

```bash
# Verify installation
npm list -g @google/gemini-cli

# Reinstall
npm install -g @google/gemini-cli

# Check PATH
which gemini
```

### Rate Limiting

If you hit rate limits:

- Upgrade to paid API tier
- Use Gemini Flash models (faster, cheaper)
- Add delays between requests

### Interactive Commands Not Working

Gemini CLI now supports interactive commands (vim, git, REPLs):

- Ensure you're using latest version
- Update: `npm update -g @google/gemini-cli`

## Additional Resources

### Official Documentation

- **Google AI Studio**: https://makersuite.google.com/app/apikey
- **Gemini CLI Docs**: https://cloud.google.com/gemini/docs/codeassist/gemini-cli
- **Codelabs**: https://codelabs.developers.google.com/gemini-cli-hands-on
- **Developer Blog**: https://developers.googleblog.com/gemini-cli

### Tutorials

- **Tutorial Series**: https://medium.com/google-cloud/gemini-cli-tutorial-series-77da7d494718
- **Cheatsheet**: https://www.philschmid.de/gemini-cli-cheatsheet
- **5 Things to Try**: https://developers.googleblog.com/5-things-to-try-with-gemini-3-pro-in-gemini-cli/

### Community

- Stack Overflow: Tag `gemini-cli`
- Google Cloud Community
- GitHub Discussions

## Version History

Latest features (November 2025):

- Gemini 3 Pro support
- Interactive shell command support
- Enhanced MCP integration
- Improved reasoning capabilities

## License

Apache License 2.0 - See package documentation
