# Ollama

Run large language models locally without API keys or internet connectivity.

## Overview

Ollama is a platform for running LLMs locally on your machine. It provides a Docker-like experience for AI models with
simple commands for pulling, running, and managing models.

**Key Features:**

- **No API Keys Required**: Completely local execution
- **Privacy**: Your code never leaves your machine
- **Offline Capability**: Works without internet (after model download)
- **Multiple Models**: Support for Llama, Mistral, Phi, CodeLlama, and more
- **REST API**: HTTP API on localhost:11434
- **Simple CLI**: Familiar Docker-like command interface
- **Model Customization**: Create custom models with Modelfiles

## Installation

Ollama is installed automatically as part of the ai-tools extension:

```bash
# Installation script
curl -fsSL https://ollama.com/install.sh | sh
```

## Starting Ollama

### Background Service

```bash
# Start server in background
nohup ollama serve > ~/ollama.log 2>&1 &

# Check if running
ps aux | grep ollama

# View logs
tail -f ~/ollama.log
```

### Systemd Service (Linux)

```bash
# Ollama installer usually sets this up automatically
systemctl status ollama

# Start/stop/restart
sudo systemctl start ollama
sudo systemctl stop ollama
sudo systemctl restart ollama
```

## Essential Commands

### Pull Models

Download models from the registry:

```bash
# Pull specific model
ollama pull llama3.2

# Pull with version tag
ollama pull llama3.2:7b
ollama pull mistral:latest

# Pull code-specialized models
ollama pull codellama
ollama pull deepseek-coder
```

### Run Models

#### Interactive Mode

```bash
# Start interactive session
ollama run llama3.2

# With specific version
ollama run llama3.2:13b

# Exit interactive mode: /bye or Ctrl+D
```

#### Single Prompt

```bash
# One-off question
ollama run llama3.2 "Explain async/await in JavaScript"

# With code input
ollama run codellama "Review this code for bugs" < UserController.ts

# Save output
ollama run llama3.2 "Summarize this" < document.txt > summary.txt
```

### List Models

```bash
# List downloaded models
ollama list

# Output shows:
# NAME              ID          SIZE    MODIFIED
# llama3.2:latest   abc123...   4.7 GB  2 hours ago
# codellama:7b      def456...   3.8 GB  1 day ago
```

### Show Model Info

```bash
# Display model details
ollama show llama3.2

# Shows:
# - Architecture
# - Parameters
# - Quantization
# - License
# - Modelfile
```

### Running Models

```bash
# List currently running models
ollama ps

# Output shows:
# NAME         ID       SIZE  PROCESSOR  UNTIL
# llama3.2     abc...   4.7GB  CPU       4 minutes
```

### Stop Models

```bash
# Stop specific model
ollama stop llama3.2

# Frees memory used by model
```

### Remove Models

```bash
# Delete downloaded model
ollama rm llama3.2

# Remove with version
ollama rm llama3.2:13b

# Free disk space
```

### Copy Models

```bash
# Create model copy
ollama cp llama3.2 my-llama

# Useful for creating custom variants
```

## Popular Models

### General Purpose

| Model | Size | Description |
|-------|------|-------------|
| `llama3.2:latest` | 4.7GB | Meta's Llama 3.2 (default) |
| `llama3.2:13b` | 7.4GB | Larger Llama 3.2 variant |
| `llama3.2:70b` | 40GB | Highest quality Llama 3.2 |
| `mistral:latest` | 4.1GB | Mistral AI model |
| `phi:latest` | 1.6GB | Microsoft Phi (smallest) |

### Code-Specialized

| Model | Size | Description |
|-------|------|-------------|
| `codellama:latest` | 3.8GB | Code-specialized Llama |
| `deepseek-coder:latest` | 3.7GB | DeepSeek Coder |
| `deepseek-r1:8b` | 4.9GB | DeepSeek R1 with reasoning |
| `starcoder2:latest` | 1.7GB | StarCoder 2 |

### Model Registry

Browse all models: https://ollama.com/library

## Custom Models

### Create Custom Model

Create a `Modelfile`:

```dockerfile
# Modelfile
FROM llama3.2

# Set custom parameters
PARAMETER temperature 0.7
PARAMETER top_p 0.9

# Set system message
SYSTEM """
You are a senior software engineer specializing in Python.
Always provide type hints and docstrings.
Follow PEP 8 guidelines strictly.
"""
```

Build the model:

```bash
# Create custom model
ollama create python-expert -f Modelfile

# Run custom model
ollama run python-expert
```

### Template System Messages

```dockerfile
FROM codellama

SYSTEM """
You are a code reviewer focusing on:
1. Security vulnerabilities
2. Performance issues
3. Best practices
4. Code maintainability

Provide specific line numbers and examples.
"""
```

```bash
ollama create code-reviewer -f Reviewerfile
ollama run code-reviewer < PR-diff.txt
```

## REST API

Ollama provides an HTTP API on `localhost:11434`:

### Generate Completion

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Explain closures in JavaScript",
  "stream": false
}'
```

### Chat Completion

```bash
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.2",
  "messages": [
    {"role": "user", "content": "What is recursion?"}
  ],
  "stream": false
}'
```

### List Models via API

```bash
curl http://localhost:11434/api/tags
```

## Common Workflows

### Code Review

```bash
# Review file for issues
ollama run codellama "Review for bugs and security issues" < app.js

# Compare before/after
git diff | ollama run codellama "Review these changes"
```

### Code Generation

```bash
# Generate function
ollama run codellama "Create a function to validate email addresses in Python"

# Generate tests
ollama run codellama "Write unit tests for this function" < calculate.js
```

### Documentation

```bash
# Generate docs
ollama run llama3.2 "Create README for this project" < analysis.txt

# Add docstrings
ollama run codellama "Add comprehensive docstrings" < utils.py
```

### Learning

```bash
# Explain concepts
ollama run llama3.2 "Explain how async/await works with examples"

# Learn syntax
ollama run llama3.2 "How do I implement generics in TypeScript?"
```

### Batch Processing

```bash
# Process multiple files
for file in src/*.ts; do
  echo "Processing $file"
  ollama run codellama "Add type annotations" < "$file" > "$file.new"
done
```

## Performance Tips

### Model Selection

- **Small tasks**: Use `phi` (1.6GB, fastest)
- **General use**: Use `llama3.2` (4.7GB, balanced)
- **Complex reasoning**: Use `llama3.2:70b` (40GB, best quality)
- **Code tasks**: Use `codellama` or `deepseek-coder`

### Memory Management

```bash
# Stop unused models to free memory
ollama ps           # See what's running
ollama stop llama3.2

# Remove unused models
ollama list         # See what's downloaded
ollama rm old-model
```

### GPU Acceleration

Ollama automatically uses GPU if available:

- NVIDIA GPUs (CUDA)
- Apple Silicon (Metal)
- AMD GPUs (ROCm)

## Automation

### Bash Script Example

```bash
#!/bin/bash
# code-review.sh - Automated code review

for file in src/**/*.js; do
  echo "=== Reviewing $file ==="
  ollama run codellama "Review for issues:\n1. Security\n2. Performance\n3. Best practices" < "$file"
  echo ""
done
```

### Python Integration

```python
import subprocess
import json

def ask_ollama(prompt, model="llama3.2"):
    result = subprocess.run(
        ["ollama", "run", model, prompt],
        capture_output=True,
        text=True
    )
    return result.stdout

# Usage
response = ask_ollama("Explain list comprehensions in Python")
print(response)
```

## Troubleshooting

### Server Not Starting

```bash
# Check if already running
ps aux | grep ollama

# Kill existing process
killall ollama

# Restart
nohup ollama serve > ~/ollama.log 2>&1 &
```

### Model Download Fails

```bash
# Check disk space
df -h

# Check internet connectivity
ping ollama.com

# Retry download
ollama pull llama3.2
```

### Out of Memory

```bash
# Use smaller model
ollama run phi  # Only 1.6GB

# Stop running models
ollama stop llama3.2

# Check system memory
free -h
```

### Slow Responses

```bash
# Use smaller/faster model
ollama run phi

# Use quantized version
ollama pull llama3.2:7b  # Smaller than :13b

# Enable GPU if available
# Ollama automatically uses GPU
```

## Configuration

### Model Storage

Models stored in:

- **Linux**: `~/.ollama/models`
- **macOS**: `~/.ollama/models`
- **Docker**: `/usr/share/ollama/.ollama/models`

### Environment Variables

```bash
# Custom model directory
export OLLAMA_MODELS=/path/to/models

# API host
export OLLAMA_HOST=0.0.0.0:11434

# Number of parallel model loads
export OLLAMA_NUM_PARALLEL=4

# GPU layers (NVIDIA)
export OLLAMA_GPU_LAYERS=35
```

## Additional Resources

### Official Links

- **Website**: https://ollama.com
- **Model Library**: https://ollama.com/library
- **GitHub**: https://github.com/ollama/ollama
- **Documentation**: https://docs.ollama.com

### CLI Reference

- **CLI Commands**: https://docs.ollama.com/cli
- **Modelfile Reference**: https://docs.ollama.com/modelfile
- **API Reference**: https://docs.ollama.com/api

### Community

- Discord: https://discord.gg/ollama
- GitHub Discussions
- Reddit: r/LocalLLaMA

## Version History

- Latest version includes GPU acceleration, model quantization, and improved performance
- Regular updates with new model support

## License

MIT License - Free and open source
