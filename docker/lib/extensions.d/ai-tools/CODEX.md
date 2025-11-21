# Codex CLI

Lightweight coding agent from OpenAI that runs in your terminal and can read, modify, and run code on your machine.

## Overview

Codex CLI is a terminal-based AI coding assistant that provides three primary modes for different development tasks.
Built in Rust for speed and efficiency, it offers a powerful interface for AI-assisted development.

**Key Features:**

- **Three Operating Modes**: Suggest, Edit, and Run
- **Local Execution**: Runs entirely on your machine
- **File Operations**: Read and modify code safely
- **Command Execution**: Execute code and shell commands
- **AGENTS.md Integration**: Project-specific instructions
- **Approval Controls**: Configure what requires approval
- **Open Source**: Built in Rust, available on GitHub

## Installation

Codex CLI is installed automatically as part of the ai-tools extension:

```bash
# Via npm
npm install -g @openai/codex

# Or via Homebrew (macOS)
brew install --cask codex
```

## API Key Setup

### Environment Variable

```bash
# Set OpenAI API key
export OPENAI_API_KEY=sk-...

# Add to ~/.bashrc for persistence
echo 'export OPENAI_API_KEY=sk-...' >> ~/.bashrc
```

### Fly.io Secrets (Sindri)

```bash
# On host machine
flyctl secrets set OPENAI_API_KEY=sk-... -a <app-name>
```

## Three Operating Modes

### 1. Suggest Mode

Get code suggestions and explanations:

```bash
codex suggest "how to optimize this function for performance"
codex suggest "best practice for error handling in async functions"
codex suggest "explain this TypeScript error message"
```

**Use Cases**:

- Get coding advice
- Explain error messages
- Find solutions to problems
- Learn best practices

### 2. Edit Mode

Modify files directly:

```bash
# Edit specific file
codex edit src/UserController.ts

# Edit with specific instruction
codex edit file.js --prompt "add error handling"

# Edit multiple files
codex edit src/**/*.ts
```

**Use Cases**:

- Refactor code
- Add features
- Fix bugs
- Update dependencies

### 3. Run Mode

Execute complex coding tasks:

```bash
codex run "create a REST API with authentication"
codex run "add comprehensive logging to the application"
codex run "implement rate limiting on all endpoints"
```

**Use Cases**:

- Implement complete features
- Generate boilerplate
- Create new modules
- Multi-file changes

## Built-in Slash Commands

When in Codex CLI, use these commands:

| Command | Purpose |
|---------|---------|
| `/init` | Create AGENTS.md with instructions for Codex |
| `/status` | Show current session configuration |
| `/approvals` | Configure what requires approval |
| `/model` | Choose AI model and reasoning effort |
| `/review` | Review changes and find issues |

## Programmatic Usage

### codex exec

Stream progress and capture final output:

```bash
# Basic execution
codex exec "find all TODOs and create implementation plans"

# Full auto mode (allow file edits)
codex exec --full-auto "refactor authentication module"

# Danger mode (allow edits + networked commands)
codex exec --sandbox danger-full-access "deploy to staging"
```

**Output Behavior**:

- Progress streams to stderr
- Final agent message to stdout
- Easy to pipe into other tools

```bash
# Pipe result to file
codex exec "analyze codebase" > analysis.md

# Chain with other commands
codex exec "list all API endpoints" | grep POST
```

## Sandbox Modes

Codex operates in different sandbox levels for safety:

### Read-Only (Default)

```bash
# No file modifications or network commands
codex suggest "how to fix this bug"
```

### Full-Auto (File Edits)

```bash
# Allow file modifications
codex exec --full-auto "add TypeScript types"
```

### Danger Full Access (Unrestricted)

```bash
# Allow file edits AND networked commands
codex exec --sandbox danger-full-access "deploy application"
```

## Project Configuration

### AGENTS.md

Create project-specific instructions:

```bash
# Initialize AGENTS.md
codex /init
```

Example `AGENTS.md`:

```markdown
# MyProject

## Build & Test
\`\`\`bash
npm install
npm run dev
npm test
\`\`\`

## Code Standards
- TypeScript strict mode
- Functional components
- Test coverage > 80%

## Architecture
- Next.js 14 App Router
- PostgreSQL + Prisma
- Tailwind CSS
```

### Configuration File

**Location**: `~/.codex/config.toml`

```toml
[model]
name = "gpt-5.1-codex-max"
reasoning_effort = "medium"

[approvals]
file_edits = true
command_execution = false
network_requests = false

[sandbox]
mode = "full-auto"
```

## Model Selection

### Available Models (2025)

- `gpt-5.1-codex-max` - Latest Codex model (default for ChatGPT users)
- `gpt-4-turbo` - GPT-4 Turbo
- `gpt-4` - GPT-4
- `gpt-3.5-turbo` - Fast, cost-effective

### Set Model

```bash
# Via command
codex /model
# Then select from menu

# Via config.toml
[model]
name = "gpt-5.1-codex-max"
```

## Common Workflows

### Code Review

```bash
# Review current changes
codex /review

# Suggest improvements
codex suggest "review this code for best practices" < UserService.ts
```

### Refactoring

```bash
# Refactor to modern patterns
codex edit legacy-code.js --prompt "convert to async/await"

# Extract functions
codex run "extract reusable logic from UserController into services"
```

### Feature Implementation

```bash
# Implement complete feature
codex run "add JWT authentication with refresh tokens"

# Generate boilerplate
codex run "create CRUD API for User model"
```

### Bug Fixing

```bash
# Fix specific bug
codex edit src/api.ts --prompt "fix race condition in login handler"

# Debug error
codex suggest "explain why I'm getting 'Cannot read property map of undefined'"
```

### Testing

```bash
# Generate tests
codex run "create unit tests for all functions in utils/"

# Improve coverage
codex run "increase test coverage to 90% for AuthService"
```

## TypeScript SDK

For programmatic usage in Node.js/TypeScript:

```typescript
import { Codex } from "@openai/codex-sdk";

// Initialize
const codex = new Codex();

// Start thread
const thread = codex.startThread();

// Run task
const turn = await thread.run("Diagnose the test failure and propose a fix");

// Get response
console.log(turn.response);
```

**SDK Installation**:

```bash
npm install @openai/codex-sdk
```

**Requirements**: Node.js 18+

## Approval Configuration

Control what Codex can do without asking:

```bash
# Open approval settings
codex /approvals

# Options:
# - Allow file edits automatically
# - Allow command execution automatically
# - Allow network requests automatically
# - Review each action (safest)
```

## CI/CD Integration

### GitHub Actions

```yaml
- name: Codex Code Review
  env:
    OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
  run: |
    codex exec "Review PR changes for security issues" > review.md
    cat review.md >> $GITHUB_STEP_SUMMARY
```

### Automated Tasks

```bash
# Find and fix issues
codex exec --full-auto "find all TypeScript errors and fix them"

# Generate documentation
codex exec "create API documentation from route files" > API.md

# Update dependencies
codex exec "analyze package.json and suggest dependency updates"
```

## Best Practices

### 1. Use Appropriate Mode

| Task | Mode | Command |
|------|------|---------|
| Get advice | Suggest | `codex suggest` |
| Modify files | Edit | `codex edit` or `--full-auto` |
| Complete features | Run | `codex run` or `exec --full-auto` |
| Deployment | Danger | `exec --sandbox danger-full-access` |

### 2. Provide Context

```bash
# Create AGENTS.md with project details
codex /init

# Include context in prompts
codex suggest "Given our Next.js 14 App Router architecture, how should I implement SSR?"
```

### 3. Review Changes

```bash
# Always review before accepting
codex /review

# Check status
codex /status
```

### 4. Start with Read-Only

```bash
# Start safely with suggestions
codex suggest "how to implement this feature"

# Then allow edits when ready
codex exec --full-auto "implement the feature"
```

### 5. Use Version Control

```bash
# Commit before major changes
git commit -m "Checkpoint before AI refactoring"

# Let Codex make changes
codex run "refactor authentication system"

# Review git diff
git diff

# Revert if needed
git checkout .
```

## Troubleshooting

### API Key Issues

```bash
# Verify key is set
echo $OPENAI_API_KEY

# Test connection
codex suggest "test connection"
```

### Command Not Found

```bash
# Check installation
npm list -g @openai/codex

# Reinstall
npm install -g @openai/codex

# Verify PATH
which codex
```

### Permission Errors

```bash
# Check sandbox mode
codex /status

# Adjust approvals
codex /approvals

# Or use explicit mode
codex exec --full-auto "your task"
```

### Model Errors

```bash
# Check selected model
codex /model

# Update model
codex /model
# Select gpt-5.1-codex-max or gpt-4-turbo
```

## Additional Resources

### Official Links

- **GitHub**: https://github.com/openai/codex
- **npm Package**: https://www.npmjs.com/package/@openai/codex
- **SDK**: https://www.npmjs.com/package/@openai/codex-sdk
- **OpenAI Platform**: https://platform.openai.com

### Documentation

- **CLI Reference**: https://developers.openai.com/codex/cli
- **SDK Reference**: https://developers.openai.com/codex/sdk/
- **Quickstart**: https://developers.openai.com/codex/quickstart/
- **Changelog**: https://developers.openai.com/codex/changelog/

### Community

- OpenAI Community Forum
- GitHub Issues
- Stack Overflow: Tag `openai-codex`

## Version History

- **0.60.1** - Latest version (as of 2025)
- **0.58.0** - Added GPT-5.1 model family support
- Built in Rust for performance

## License

See OpenAI terms of service and package license
