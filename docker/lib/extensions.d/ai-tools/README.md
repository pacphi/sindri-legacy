# AI CLI Tools and Coding Assistants

Complete collection of AI-powered development tools and coding assistants for Sindri environments.

## Quick Navigation

- [Installed Tools Overview](#installed-tools-overview)
- [Detailed CLI Documentation](#detailed-cli-documentation)
- [API Key Requirements](#api-key-requirements)
- [Getting Started](#getting-started)
- [Best Practices](#best-practices)

---

## Installed Tools Overview

### Autonomous Coding Agents

| Tool | Command | Description | Documentation |
|------|---------|-------------|---------------|
| **Factory AI Droid** | `droid` | AI-powered development agent with complete development cycles | [DROID.md](DROID.md) |
| **Codex CLI** | `codex` | Multi-mode AI assistant (suggest/edit/run) | [CODEX.md](CODEX.md) |
| **Hector** | `hector` | Pure A2A-Native declarative AI agent platform | [HECTOR.md](HECTOR.md) |

### Major Platform CLIs

| Tool | Command | Requirements | Documentation |
|------|---------|--------------|---------------|
| **Gemini CLI** | `gemini` | GOOGLE_GEMINI_API_KEY | [GEMINI.md](GEMINI.md) |
| **GitHub Copilot** | `gh copilot` | GitHub CLI + subscription | [GITHUB_COPILOT.md](GITHUB_COPILOT.md) |
| **AWS Q Developer** | `aws q` | AWS CLI | [AWS_Q.md](AWS_Q.md) |

### Local AI & Model Management

| Tool | Command | Description | Documentation |
|------|---------|-------------|---------------|
| **Ollama** | `ollama` | Run LLMs locally (no API key) | [OLLAMA.md](OLLAMA.md) |
| **Grok CLI** | `grok` | Conversational AI CLI powered by Grok | [GROK.md](GROK.md) |
| **Fabric** | `fabric` | AI pattern framework | [FABRIC.md](FABRIC.md) |

---

## Detailed CLI Documentation

### Factory AI Droid

**Full Documentation**: [DROID.md](DROID.md)

Factory AI's Droid CLI is an AI-powered development agent providing:

- Complete development cycles from planning through QA
- Contextual code awareness from repositories and documentation
- Custom droids for specialized tasks
- Skills system for workflow automation
- AGENTS.md integration for project context

**Quick Start**:

```bash
# Navigate to project
cd /workspace/projects/my-project

# Launch interactive session
droid

# First time: authenticate via browser
# Then use natural language for tasks
```

**Key Features**:

- Browser-based authentication
- Custom droids (`.factory/droids/`)
- Skills system (`.factory/skills/`)
- Jira/Notion/Slack integration
- SOC-2 compliant

### Codex CLI

**Command**: `codex`

Multi-mode AI assistant with suggest, edit, and run capabilities.

**Usage**:

```bash
# Suggest solutions
codex suggest "how to optimize this function"

# Edit files directly
codex edit file.js

# Run commands
codex run "create a REST API"
```

**Requirements**: API key (configuration during installation)

### Hector

**Command**: `hector`
**Prerequisites**: Go (via golang extension)

Pure A2A-Native declarative AI agent platform using YAML configuration.

**Usage**:

```bash
# Start agent server
hector serve --config agent.yaml

# Interactive chat
hector chat assistant

# Execute single task
hector call assistant "implement feature X"

# List available agents
hector list
```

### Gemini CLI

**Full Documentation**: [GEMINI.md](GEMINI.md)

**Command**: `gemini`
**API Key**: `GOOGLE_GEMINI_API_KEY`
**Get Key**: https://makersuite.google.com/app/apikey

**Usage**:

```bash
# Chat interface
gemini chat "explain this code"

# Code generation
gemini generate "write unit tests for UserService"

# Code analysis
gemini analyze "review for security issues"
```

**Set API Key**:

```bash
# Via Fly.io secrets (recommended)
flyctl secrets set GOOGLE_GEMINI_API_KEY=key -a <app-name>

# Or environment variable
export GOOGLE_GEMINI_API_KEY=your_key
```

### GitHub Copilot CLI

**Command**: `gh copilot`
**Prerequisites**: GitHub CLI (`gh`) + GitHub Copilot subscription

**Usage**:

```bash
# Suggest commands
gh copilot suggest "git command to undo last commit"

# Explain commands
gh copilot explain "docker-compose up -d"

# Interactive mode
gh copilot
```

**Authentication**: Requires GitHub account with active Copilot subscription

### AWS Q Developer

**Command**: `aws q`
**Prerequisites**: AWS CLI (via cloud-tools extension)

**Usage**:

```bash
# Interactive chat
aws q chat

# Code explanations
aws q explain "lambda function code"

# Generate code
aws q generate "S3 bucket policy"
```

**Authentication**: Requires AWS credentials (`aws configure`)

### Ollama

**Command**: `ollama`

Run large language models locally without API keys.

**Start Service**:

```bash
# Start in background
nohup ollama serve > ~/ollama.log 2>&1 &
```

**Usage**:

```bash
# Pull a model
ollama pull llama3.2

# Run interactively
ollama run llama3.2

# List installed models
ollama list

# Remove a model
ollama rm llama3.2
```

**Popular Models**:

- `llama3.2` - Meta's Llama 3.2
- `codellama` - Code-specialized Llama
- `mistral` - Mistral AI models
- `phi` - Microsoft Phi models

**Model Storage**: `~/ai-tools/ollama-models/`

### Grok CLI

**Full Documentation**: [GROK.md](GROK.md)

**Command**: `grok`
**Prerequisites**: Node.js/npm (via nodejs extension)
**API Key**: `GROK_API_KEY`

**Interactive Mode**:

```bash
# Start conversational AI
grok

# Specify working directory
grok -d /path/to/project
```

**Headless Mode**:

```bash
# Process single prompt
grok --prompt "explain this error"
grok -p "show me the package.json file"
```

**Configuration**:

```bash
# Global settings
~/.grok/user-settings.json

# Project settings
.grok/settings.json

# Custom instructions
.grok/GROK.md
```

**Set API Key**:

```bash
# Via Fly.io secrets (recommended)
flyctl secrets set GROK_API_KEY=key -a <app-name>

# Or environment variable
export GROK_API_KEY=your_key

# Or user settings file
cat > ~/.grok/user-settings.json << 'EOF'
{
  "apiKey": "your_key",
  "model": "grok-code-fast-1"
}
EOF
```

### Fabric

**Command**: `fabric`

AI framework for prompt patterns and workflows.

**First-Time Setup**:

```bash
fabric --setup
```

**Usage**:

```bash
# Use a pattern
echo "complex code" | fabric --pattern explain

# List available patterns
fabric --list

# Create custom pattern
fabric --pattern mypattern --create
```

**Custom Patterns**: `~/ai-tools/fabric-patterns/`

---

## API Key Requirements

| Tool | Requirement | How to Get |
|------|-------------|------------|
| **Factory AI Droid** | Browser authentication | https://app.factory.ai |
| **Ollama** | None (local) | - |
| **Fabric** | Optional | Configure during setup |
| **Codex** | API key | During installation |
| **Gemini** | GOOGLE_GEMINI_API_KEY | https://makersuite.google.com/app/apikey |
| **Grok CLI** | GROK_API_KEY | https://x.ai (X.AI account) |
| **GitHub Copilot** | GitHub subscription | https://github.com/features/copilot |
| **AWS Q** | AWS credentials | `aws configure` |

### Setting API Keys

#### Method 1: Fly.io Secrets (Recommended)

```bash
flyctl secrets set GOOGLE_GEMINI_API_KEY=your_key -a <app-name>
flyctl secrets set GROK_API_KEY=your_key -a <app-name>

# VM restarts automatically with encrypted secrets
```

#### Method 2: Environment Variables

```bash
# Add to ~/.bashrc
export GOOGLE_GEMINI_API_KEY=your_key
export GROK_API_KEY=your_key

# Reload shell
source ~/.bashrc
```

**Security**: Secrets are encrypted at rest via SOPS + age. See `/workspace/docs/SECRETS.md` for details.

---

## Directory Structure

```text
/workspace/ai-tools/
├── ollama-models/      # Ollama model storage
├── fabric-patterns/    # Custom Fabric patterns
└── projects/           # AI-assisted projects
```

---

## Getting Started

### Local AI (No API Keys)

Perfect for development and testing:

```bash
# Start Ollama
nohup ollama serve > ~/ollama.log 2>&1 &

# Pull a model
ollama pull llama3.2

# Use interactively
ollama run llama3.2

# Or via API
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Explain async programming"
}'
```

### Cloud AI (Requires API Keys)

For production and advanced features:

```bash
# Set up Gemini
export GOOGLE_GEMINI_API_KEY=your_key
gemini chat "help me debug this TypeScript error"

# Use Factory AI Droid
droid
> Implement JWT authentication for my API
```

### Development Workflows

**Code Generation**:

```bash
# Via Codex
codex run "add error handling to UserController"

# Via Gemini
gemini generate "unit tests for calculateDiscount function"

# Via Factory AI Droid
droid
> Write comprehensive tests for the authentication module
```

**Code Review**:

```bash
# Via Hector
hector chat assistant
> Review this pull request for security issues

# Via Factory AI Droid
droid
> Analyze these changes for potential bugs and security vulnerabilities
```

**Debugging**:

```bash
# Via AWS Q
aws q chat
> Why is my Lambda function timing out?

# Via Ollama (local, private)
ollama run codellama
> Explain why this recursive function causes stack overflow
```

---

## Best Practices

### 1. Cost Management

**Use local models for development**:

```bash
# Free, private, unlimited
ollama run llama3.2
```

**Reserve cloud APIs for production**:

- Gemini: Complex reasoning
- GitHub Copilot: IDE integration
- Factory AI Droid: Complete features
- AWS Q: Cloud-specific tasks

### 2. Security

**Never commit API keys**:

```bash
# Use Fly.io secrets
flyctl secrets set GOOGLE_GEMINI_API_KEY=key -a <app>
```

**Use local models for sensitive code**:

```bash
# Keep proprietary code local
ollama run codellama < sensitive_code.js
```

**Review AI-generated code**:

- Always validate AI suggestions
- Test thoroughly before deployment
- Use as assistant, not replacement

### 3. Prompt Engineering

**Be specific**:

```bash
# ✗ Vague
droid
> Fix the bug

# ✓ Specific
droid
> Fix the authentication bug in UserController where expired tokens aren't being rejected
```

**Provide context**:

```bash
# Include relevant information
gemini chat "Given this TypeScript interface [paste code], generate a mock factory function"
```

**Iterate**:

```bash
# Refine prompts based on results
codex suggest "optimize this function for memory usage instead of speed"
```

### 4. Tool Selection

| Use Case | Recommended Tool |
|----------|------------------|
| Complete features | Factory AI Droid |
| Quick code snippets | Codex, Gemini, Grok CLI |
| Local/private code | Ollama |
| Git operations | GitHub Copilot |
| AWS infrastructure | AWS Q |
| Workflow automation | Hector |
| Pattern-based tasks | Fabric |
| Interactive debugging | Grok CLI |

### 5. Privacy Considerations

**Public Cloud AI**:

- Sent to external APIs
- May be used for training
- Review provider terms

**Local AI (Ollama)**:

- Stays on your machine
- No data sent externally
- Ideal for proprietary code

**Hybrid Approach**:

```bash
# Sensitive analysis: local
ollama run codellama < proprietary_algorithm.py

# General assistance: cloud
gemini chat "how to implement OAuth2 in Go"
```

---

## Troubleshooting

### Factory AI Droid Issues

See [DROID.md - Troubleshooting](DROID.md#troubleshooting) for:

- Command not found
- Authentication problems
- Browser authentication on headless systems

### Ollama Not Starting

```bash
# Check if already running
ps aux | grep ollama

# View logs
tail -f ~/ollama.log

# Restart
killall ollama
nohup ollama serve > ~/ollama.log 2>&1 &
```

### API Key Not Working

```bash
# Verify secret is set
flyctl secrets list -a <app-name>

# Check if loaded
view-secrets

# Restart VM to reload
flyctl machine restart <machine-id> -a <app-name>
```

### Command Not Found

```bash
# Reload shell
exec bash

# Or manually source
source ~/.bashrc

# Check PATH
echo $PATH | grep -E "\.factory|\.local"
```

---

## Extension Management

### Status Check

```bash
extension-manager status ai-tools
```

### Upgrade

```bash
extension-manager upgrade ai-tools
```

### Uninstall

```bash
extension-manager remove ai-tools
```

---

## Additional Resources

### Official Documentation

- **Factory AI**: [DROID.md](DROID.md) - Complete Droid CLI documentation
- **Codex CLI**: [CODEX.md](CODEX.md) - Complete Codex CLI guide
- **Gemini CLI**: [GEMINI.md](GEMINI.md) - Complete Gemini CLI guide
- **Grok CLI**: [GROK.md](GROK.md) - Complete Grok CLI guide
- **Ollama**: [OLLAMA.md](OLLAMA.md) - Complete Ollama guide
- **Hector**: [HECTOR.md](HECTOR.md) - Complete Hector guide
- **Fabric**: [FABRIC.md](FABRIC.md) - Complete Fabric guide
- **GitHub Copilot**: [GITHUB_COPILOT.md](GITHUB_COPILOT.md) - Complete GitHub Copilot CLI guide
- **AWS Q**: [AWS_Q.md](AWS_Q.md) - Complete AWS Q Developer guide

### Community Resources

- Factory AI Community Forums
- Ollama Discord
- GitHub Discussions
- Stack Overflow tags: `ai-coding`, `llm`

### Support

For issues specific to this extension:

```bash
extension-manager validate ai-tools
```

For individual tool issues, consult their respective documentation links above.

---

## Version History

- **2.0.0** - Added Factory AI Droid and Grok CLI, replaced xAI Grok SDK with Grok CLI, comprehensive documentation
- **1.0.0** - Initial release with Ollama, Codex, Gemini, Hector, Fabric

---

## License

This extension follows Sindri's licensing. Individual tools are subject to their respective licenses.
