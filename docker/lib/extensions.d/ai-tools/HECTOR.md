# Hector

Pure A2A-Native Declarative AI Agent Platform - build, deploy, and orchestrate AI agents at scale using YAML configuration.

## Overview

Hector is a production-ready framework built in Go for building AI agent systems without writing code. Define everything
in YAML - prompts, reasoning strategies, and tools - like infrastructure as code but for AI agents.

**Key Features:**

- **Declarative YAML Configuration**: No Python, no SDKs, no complex setup
- **A2A Protocol Native**: Agent-to-Agent communication standard
- **Distributed Architecture**: Scale across multiple nodes
- **Single Binary Deployment**: Easy deployment and operation
- **Multi-Agent Systems**: Define sophisticated agent interactions
- **Built in Go**: High performance and operational simplicity

## Installation

Hector is installed automatically as part of the ai-tools extension (requires Go):

```bash
go install github.com/kadirpekel/hector/cmd/hector@latest
```

## Basic Configuration

Create `agents.yaml`:

```yaml
agents:
  analyst:
    llm: gpt-4o
    tools: [search, write_file, search_replace]
    reasoning:
      engine: chain-of-thought
      max_iterations: 100
    prompt: |
      You are a system analyst specializing in architecture reviews.
      Analyze codebases for design patterns, potential issues,
      and improvement opportunities.

  coder:
    llm: gpt-4o-mini
    tools: [read_file, write_file, bash]
    reasoning:
      engine: react
      max_iterations: 50
    prompt: |
      You are a senior software engineer.
      Write clean, tested, well-documented code.
      Follow best practices and design patterns.
```

## CLI Commands

### Serve

Start the Hector server:

```bash
# Start with config
hector serve --config agents.yaml

# Custom port
hector serve --config agents.yaml --port 8081

# Custom host
hector serve --config agents.yaml --host 0.0.0.0
```

**Default**: Server runs on `http://localhost:8081`

### Call

Send single task to an agent:

```bash
# Execute task
hector call "Analyze system architecture and suggest improvements" \
  --agent analyst \
  --server http://localhost:8081

# Different agent
hector call "Implement user authentication" \
  --agent coder \
  --server http://localhost:8081
```

### Chat

Interactive conversation with agent:

```bash
# Start chat session
hector chat --agent analyst --server http://localhost:8081

# Now converse naturally
> Analyze the database schema
> What are the main bottlenecks?
> Suggest optimization strategies
```

### List

Show available agents:

```bash
hector list --server http://localhost:8081

# Output:
# Available agents:
# - analyst (gpt-4o, chain-of-thought)
# - coder (gpt-4o-mini, react)
```

## Configuration

### API Key Setup

```bash
# OpenAI (required)
export OPENAI_API_KEY=sk-...

# Or in ~/.bashrc
echo 'export OPENAI_API_KEY=sk-...' >> ~/.bashrc
```

### Agent Configuration

```yaml
agents:
  agent-name:
    llm: gpt-4o                    # Model to use
    tools: [tool1, tool2]          # Available tools
    reasoning:
      engine: chain-of-thought     # Or: react, tree-of-thought
      max_iterations: 100          # Max reasoning steps
    prompt: |                      # System prompt
      Agent instructions here
    temperature: 0.7               # Creativity (0.0-1.0)
    max_tokens: 4096              # Max response length
```

### Available Reasoning Engines

- **chain-of-thought**: Sequential reasoning, good for analysis
- **react**: Reason + Act loop, good for tasks requiring actions
- **tree-of-thought**: Explore multiple reasoning paths

### Available Tools

- `search` - Web search capability
- `read_file` - Read files from filesystem
- `write_file` - Write/modify files
- `search_replace` - Find and replace in files
- `bash` - Execute shell commands
- `python` - Run Python code
- Custom MCP tools

## Multi-Agent Workflows

### Sequential Workflow

```yaml
agents:
  planner:
    llm: gpt-4o
    tools: [search, read_file]
    prompt: |
      You are a technical architect.
      Create detailed implementation plans.

  implementer:
    llm: gpt-4o
    tools: [read_file, write_file, bash]
    prompt: |
      You are a senior developer.
      Implement features based on plans.
      Depends on: planner

  tester:
    llm: gpt-4o-mini
    tools: [read_file, write_file, bash]
    prompt: |
      You are a QA engineer.
      Write comprehensive tests.
      Depends on: implementer
```

**Usage**:

```bash
# Plan feature
hector call "Plan user authentication feature" --agent planner

# Implement
hector call "Implement the authentication plan" --agent implementer

# Test
hector call "Write tests for authentication" --agent tester
```

### Collaborative Agents

```yaml
agents:
  researcher:
    llm: gpt-4o
    tools: [search, write_file]
    prompt: "Research technical solutions"

  reviewer:
    llm: gpt-4o
    tools: [read_file]
    prompt: "Review and critique solutions"

  synthesizer:
    llm: gpt-4o
    tools: [read_file, write_file]
    prompt: "Synthesize best solution from research and review"
```

## Common Use Cases

### Architecture Review

```bash
hector chat --agent analyst
> Review the current microservices architecture
> Identify coupling issues
> Suggest improvements for scalability
```

### Feature Development

```bash
hector call "Implement OAuth2 authentication with JWT tokens" --agent coder
```

### Code Review

```yaml
agents:
  security-reviewer:
    llm: gpt-4o
    tools: [read_file]
    prompt: |
      Review code for security vulnerabilities:
      - SQL injection
      - XSS
      - Authentication issues
      - Authorization flaws
```

```bash
hector call "Review all API endpoints for security" --agent security-reviewer
```

### Documentation Generation

```yaml
agents:
  documenter:
    llm: gpt-4o
    tools: [read_file, write_file]
    prompt: |
      Generate comprehensive documentation:
      - API references
      - Code comments
      - Architecture diagrams
      - User guides
```

## Best Practices

### 1. Agent Specialization

Create focused agents for specific tasks:

```yaml
# ✓ Good: Specialized agents
agents:
  backend-dev:
    prompt: "Expert in Node.js, Express, PostgreSQL"

  frontend-dev:
    prompt: "Expert in React, TypeScript, Tailwind"

# ✗ Bad: Generic agent
agents:
  developer:
    prompt: "You can write any code"
```

### 2. Tool Access Control

Grant minimum necessary tools:

```yaml
# ✓ Good: Minimal tools
agents:
  reviewer:
    tools: [read_file]  # Read-only

# ✗ Bad: Excessive tools
agents:
  reviewer:
    tools: [read_file, write_file, bash]  # Too much access
```

### 3. Reasoning Engine Selection

| Task Type | Engine | Rationale |
|-----------|--------|-----------|
| Analysis | chain-of-thought | Sequential reasoning |
| Implementation | react | Action-oriented tasks |
| Complex problems | tree-of-thought | Multiple solution paths |

### 4. Iteration Limits

Set appropriate max_iterations:

```yaml
agents:
  quick-task:
    max_iterations: 10  # Simple tasks

  complex-feature:
    max_iterations: 100  # Complex implementations
```

## Troubleshooting

### Server Won't Start

```bash
# Check if port in use
lsof -i :8081

# Use different port
hector serve --config agents.yaml --port 8082
```

### Agent Not Found

```bash
# List available agents
hector list --server http://localhost:8081

# Check config file
cat agents.yaml
```

### API Key Issues

```bash
# Verify key is set
echo $OPENAI_API_KEY

# Test connection
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"
```

### Command Not Found

```bash
# Check installation
which hector

# Verify Go bin in PATH
echo $PATH | grep go/bin

# Reinstall
go install github.com/kadirpekel/hector/cmd/hector@latest
```

## Advanced Topics

### Distributed Deployment

Run multiple Hector instances:

```bash
# Node 1
hector serve --config agents.yaml --host 0.0.0.0 --port 8081

# Node 2
hector serve --config agents.yaml --host 0.0.0.0 --port 8082

# Load balance across nodes
```

### Docker Deployment

```dockerfile
FROM golang:1.24-alpine

RUN go install github.com/kadirpekel/hector/cmd/hector@latest

COPY agents.yaml /app/
WORKDIR /app

CMD ["hector", "serve", "--config", "agents.yaml", "--host", "0.0.0.0"]
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hector
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: hector
        image: hector:latest
        command: ["hector", "serve", "--config", "/config/agents.yaml"]
        env:
        - name: OPENAI_API_KEY
          valueFrom:
            secretKeyRef:
              name: ai-secrets
              key: openai-api-key
```

## Additional Resources

### Official Links

- **Website**: https://gohector.dev/
- **GitHub**: https://github.com/kadirpekel/hector
- **Documentation**: https://gohector.dev/docs

### Community

- GitHub Issues
- DEV Community: https://dev.to/kadir_pekel_3277e6819e5b9/meet-hector-a-declarative-ai-agent-platform-in-go-40j2

## Version History

- Latest version with A2A protocol support
- Production-ready framework
- Built in Go for performance

## License

See GitHub repository for license details
