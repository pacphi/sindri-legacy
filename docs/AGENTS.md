# Agent System Guide

Agents extend Claude's capabilities for specialized tasks. The environment includes comprehensive agent management
through shell aliases.

> **Note**: This guide covers Claude Flow's agent system for task coordination. For cost-optimized multi-model AI,
> see [agent-flow integration](COST_MANAGEMENT.md#ai-model-cost-optimization-with-agent-flow) in the Cost
> Management guide.

## Quick Start

```bash
# See all available agent commands
agent-help

# Install agents
agent-install

# Search for agents
agent-find "test"
agent-search "python"
```

## Available Commands

All agent commands are defined in `/workspace/.agent-aliases`. Key commands include:

### Core Management

- `agent-install` - Install agents from configured sources
- `agent-update` - Update to latest versions
- `agent-list` - List installed agents
- `agent-validate` - Validate configuration

### Search & Discovery

- `agent-find <term>` - Search by name
- `agent-search <term>` - Search by content
- `agent-by-category` - Browse by category
- `agent-by-tag <tag>` - Find by tag
- `agent-with-keyword <keyword>` - Find by filename keyword
- `agent-sample [count]` - See random examples
- `agent-stats` - Comprehensive statistics
- `agent-info <file>` - Show agent metadata
- `agent-index` - Create search index for speed
- `agent-search-fast <term>` - Use indexed search (faster)
- `agent-duplicates` - Find duplicate agents

### Using with Claude Flow

Context-aware agent usage is defined in `/workspace/.context-aliases`:

```bash
# Run with project context
cf-l <agent-name> "task"

# Example
cf-l code-reviewer "review the API module"
```

## Configuration

Agent sources and settings: `/workspace/config/agents-config.yaml`

**Note**: GitHub token required for agent installation:

```bash
flyctl secrets set GITHUB_TOKEN=ghp_... -a <app-name>
```

### Custom Agent Sources

You can customize agent sources in two ways:

**Before deployment** (recommended):

```bash
# Edit configuration files in repository before VM setup
nano docker/config/agents-config.yaml    # Configure agent sources
nano docker/config/agent-aliases         # Customize agent aliases
nano docker/lib/agent-discovery.sh       # Add discovery functions
```

**After deployment on the VM**:

```bash
# Edit deployed configurations
nano /workspace/config/agents-config.yaml          # Agent sources
nano /workspace/.agent-aliases                     # Agent aliases
nano /workspace/scripts/lib/agent-discovery.sh     # Discovery functions

# Reload the configurations
source /workspace/.agent-aliases                   # Reload agent aliases
source /workspace/scripts/lib/agent-discovery.sh   # Reload discovery functions
agent-install                                      # Reinstall agents if config changed
```

**Example custom source in agents-config.yaml:**

```yaml
sources:
  - name: my-custom-agents
    enabled: true
    type: github
    repository: my-org/my-agents
    branch: main
    paths:
      source: agents
      target: ${settings.base_dir}
    filters:
      include_patterns:
        - "*.md"
```

This configuration downloads agent files from a custom GitHub repository and makes them available for use with Claude Code.

## Finding Commands

View all available commands and their usage:

```bash
# Show all agent commands with descriptions
agent-help

# Check alias definitions directly
cat /workspace/.agent-aliases
cat /workspace/.context-aliases
```

## Common Workflows

```bash
# Initial setup
agent-install
agent-count

# Find specific agent
agent-find "test"
agent-info <agent-file>

# Update periodically
agent-update
```

For complete command reference, run `agent-help` or examine the alias files directly.

## Custom Agent Development

Create your own agents following the [Claude Code sub-agent format](https://docs.anthropic.com/en/docs/claude-code/sub-agents#file-format):

```markdown
name: My Custom Agent
description: Specialized agent for my specific needs

## Instructions

You are a specialized agent that helps with...

## Capabilities

- Specific capability 1
- Specific capability 2

## Usage Examples

Use this agent when you need to...
```

**Steps to deploy custom agents:**

1. Create agent files (`.md` format) following the specification above
2. Place them in your configured source directory
3. Run `agent-install` to make them available
4. Use them with `cf-l <agent-name> "task"` for context-aware execution

Custom agents integrate seamlessly with the existing agent system and can be discovered through standard agent search commands.
