# Fabric

Open-source framework for augmenting humans using AI through a modular system of crowdsourced AI prompts (patterns).

## Overview

Fabric provides a curated collection of AI prompt patterns for specific tasks. Instead of writing prompts from scratch,
use battle-tested patterns for common workflows.

**Key Features:**

- **Crowdsourced Patterns**: Community-curated AI prompts
- **Modular System**: Solve specific problems with specific patterns
- **Universal Compatibility**: Use patterns in any AI app (ChatGPT, Claude, etc.)
- **CLI Interface**: Terminal-based workflow
- **Custom Patterns**: Create and share your own
- **Multiple Categories**: Code, writing, analysis, security, wellness, etc.

## Installation

Fabric is installed as part of the ai-tools extension (requires Go):

```bash
git clone --depth 1 https://github.com/danielmiessler/fabric.git ~/.local/share/fabric
cd ~/.local/share/fabric
go build -o fabric
ln -s ~/.local/share/fabric/fabric ~/.local/bin/fabric
```

## First-Time Setup

```bash
fabric --setup

# Configure:
# - API provider (OpenAI, Anthropic, etc.)
# - API key
# - Default model
# - Pattern directory
```

## Basic Usage

### List Patterns

```bash
# Show all available patterns
fabric --list

# Categories:
# - Code: code_review, improve_code, explain_code
# - Analysis: analyze_claims, extract_wisdom, summarize
# - Writing: write_essay, improve_writing
# - Security: analyze_threat_report, find_vulns
# - Wellness: emotional_analysis, improve_mental_health
```

### Use a Pattern

```bash
# Pipe content to pattern
echo "complex code" | fabric --pattern explain

# From file
cat UserController.ts | fabric --pattern code_review

# From command output
git diff | fabric --pattern analyze_changes
```

### Stream Results

```bash
# Stream output as it's generated
cat article.txt | fabric --pattern summarize --stream
```

### Save Output

```bash
# Save to file
cat code.js | fabric --pattern improve_code --output improved.js

# Or with redirection
echo "text" | fabric --pattern summarize > summary.txt
```

## Popular Patterns

### Code Patterns

```bash
# Review code for issues
cat src/api.ts | fabric --pattern code_review

# Improve code quality
cat messy.js | fabric --pattern improve_code

# Explain code
cat complex.py | fabric --pattern explain_code

# Find security vulnerabilities
cat UserAuth.ts | fabric --pattern find_vulns
```

### Analysis Patterns

```bash
# Summarize content
cat long-article.txt | fabric --pattern summarize

# Extract key insights
cat research-paper.pdf | fabric --pattern extract_wisdom

# Analyze claims
cat opinion.txt | fabric --pattern analyze_claims

# Create visual concept map (v1.4.322+)
cat architecture.md | fabric --pattern create_conceptmap
```

### Writing Patterns

```bash
# Improve writing quality
cat draft.txt | fabric --pattern improve_writing

# Write essay
echo "Topic: AI in healthcare" | fabric --pattern write_essay

# Create outline
echo "Subject: Microservices" | fabric --pattern create_outline
```

### Security Patterns

```bash
# Analyze threat reports
cat incident.txt | fabric --pattern analyze_threat_report

# Security audit
cat api-code.js | fabric --pattern find_vulns

# Risk assessment
cat architecture.md | fabric --pattern assess_risk
```

### Wellness Patterns (NEW 2025)

```bash
# Emotional analysis
cat journal-entry.txt | fabric --pattern emotional_analysis

# Mental health support
echo "I'm feeling stressed" | fabric --pattern improve_mental_health
```

## Advanced Features

### Model Selection

```bash
# Use specific model
fabric --pattern summarize --model gpt-4-turbo

# Use different provider
fabric --pattern explain --model claude-sonnet-4-5
```

### Custom Patterns

Create your own patterns in `~/.config/fabric/patterns/`:

```bash
# Create pattern directory
mkdir -p ~/.config/fabric/patterns/my-pattern

# Create system.md (instructions)
cat > ~/.config/fabric/patterns/my-pattern/system.md << 'EOF'
# My Custom Pattern

You are a specialized code reviewer for TypeScript React applications.

## Review Checklist
1. Type safety - check for `any` usage
2. React hooks - verify rules of hooks
3. Performance - identify re-render issues
4. Accessibility - check ARIA labels

Provide specific examples and fixes.
EOF

# Use your pattern
cat Component.tsx | fabric --pattern my-pattern
```

### Suggest Pattern

Let Fabric suggest which pattern to use:

```bash
echo "I want to analyze customer feedback" | fabric --pattern suggest_pattern
# Fabric will recommend appropriate patterns
```

## Configuration

### Config Location

`~/.config/fabric/config.yaml`

### Example Config

```yaml
apikey: sk-...
model: gpt-4-turbo
provider: openai
stream: true
patterns_dir: ~/.config/fabric/patterns
```

### Supported Providers

- OpenAI (GPT models)
- Anthropic (Claude models)
- Google (Gemini models)
- Ollama (local models)
- Azure OpenAI
- Custom endpoints

## Common Workflows

### Development Workflow

```bash
# 1. Review PR
git diff main | fabric --pattern code_review > review.md

# 2. Improve code
cat src/utils.ts | fabric --pattern improve_code > src/utils.improved.ts

# 3. Generate tests
cat src/UserService.ts | fabric --pattern create_tests > tests/UserService.test.ts

# 4. Update docs
cat src/ | fabric --pattern create_docs > DOCS.md
```

### Learning Workflow

```bash
# Explain unfamiliar code
cat complex-algorithm.rs | fabric --pattern explain_code

# Extract key concepts
cat tutorial.md | fabric --pattern extract_wisdom

# Create study notes
cat documentation.md | fabric --pattern summarize
```

### Security Workflow

```bash
# Audit codebase
cat src/**/*.ts | fabric --pattern find_vulns > security-audit.md

# Analyze incident
cat incident-report.txt | fabric --pattern analyze_threat_report

# Review dependencies
npm audit | fabric --pattern assess_risk
```

## Best Practices

### 1. Choose Right Pattern

| Task | Pattern |
|------|---------|
| Understand code | `explain_code` |
| Fix code | `improve_code` |
| Review security | `code_review`, `find_vulns` |
| Summarize text | `summarize` |
| Extract insights | `extract_wisdom` |
| Analyze claims | `analyze_claims` |

### 2. Combine with Unix Tools

```bash
# Process multiple files
find src/ -name "*.ts" -exec cat {} \; | fabric --pattern code_review

# Filter results
git log --oneline | fabric --pattern summarize | grep "feature"

# Chain patterns
cat code.js | fabric --pattern explain_code | fabric --pattern summarize
```

### 3. Save Outputs

```bash
# Create analysis reports
cat codebase/ | fabric --pattern analyze_architecture > architecture-review.md

# Generate documentation
for file in src/*.ts; do
  cat "$file" | fabric --pattern create_docs >> DOCS.md
done
```

## Troubleshooting

### Setup Issues

```bash
# Reconfigure
fabric --setup

# Check config
cat ~/.config/fabric/config.yaml
```

### Pattern Not Found

```bash
# Update patterns
cd ~/.local/share/fabric
git pull

# Rebuild
go build -o fabric

# List available patterns
fabric --list
```

### API Key Issues

```bash
# Check configuration
fabric --setup

# Test with specific key
OPENAI_API_KEY=sk-... fabric --pattern summarize < test.txt
```

## Additional Resources

### Official Links

- **GitHub**: https://github.com/danielmiessler/fabric
- **Documentation**: Available in repository
- **Pattern Library**: https://github.com/danielmiessler/fabric/tree/main/patterns

### Community

- GitHub Discussions
- Daniel Miessler's Blog: https://danielmiessler.com
- Community patterns repository

## Version History

- **v1.4.322** (Nov 2025) - Added create_conceptmap, WELLNESS category, Claude Sonnet 4.5
- **v1.4** (July 2025) - Custom patterns, OAuth, image generation, web search, code_review

## License

MIT License - Open source and free to use
