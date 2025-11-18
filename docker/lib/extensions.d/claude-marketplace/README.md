# Claude Marketplace Extension

This extension automatically configures Claude Code plugin marketplaces via YAML configuration and `settings.json` integration.

## Overview

This extension provides automated configuration of plugin marketplaces through a YAML-based workflow that integrates
directly withClaude Code's `settings.json`. Marketplaces and plugins are configured once and automatically installed
when Claude Code is invoked.

It provides:

- **YAML Configuration**: Human-readable marketplace and plugin configuration
- **Direct settings.json Integration**: Merges configuration into Claude Code's settings
- **Automatic Installation**: Claude Code handles marketplace and plugin installation
- **Curated Collection**: Pre-selected high-quality marketplaces for various use cases
- **Idempotent**: Safe to re-run installation without duplicating configuration
- **Team Consistency**: Share YAML configuration across teams for consistent tooling

## Prerequisites

- **Claude CLI** (pre-installed in base Docker image) - **Required**
- **Claude Authentication** (via `claude-auth-with-api-key` extension or manual auth) - **Required**
- **yq** (YAML processor) - **Required** (pre-installed in base image)
- **jq** (JSON processor) - **Required** (pre-installed in base image)

## Installation

### Via Extension Manager

```bash
# Install claude-marketplace (auto-activates if needed)
extension-manager install claude-marketplace

# Or use interactive mode
extension-manager --interactive
```

### Verification

```bash
# Check installation status
extension-manager status claude-marketplace

# Validate installation
extension-manager validate claude-marketplace

# View configured marketplaces and plugins
cat ~/.claude/settings.json | jq '.extraKnownMarketplaces, .enabledPlugins'
```

## Usage

### Automated Configuration Workflow

The extension automatically configures marketplaces and plugins:

1. **Create YAML configuration** (or use the template):

   ```bash
   # Copy template
   cp /workspace/marketplaces.yml.example /workspace/marketplaces.yml

   # Edit to customize
   vim /workspace/marketplaces.yml
   ```

2. **Install extension** (processes YAML → JSON → settings.json):

   ```bash
   extension-manager install claude-marketplace
   ```

3. **Invoke Claude Code** (automatic marketplace and plugin installation):

   ```bash
   claude
   ```

Claude Code automatically:

- Registers all marketplaces from `extraKnownMarketplaces`
- Installs all plugins from `enabledPlugins` array
- Handles authentication and dependencies

### Manual Plugin Management

After configuration, you can still manage plugins manually:

```bash
# Browse and install plugins interactively
claude /plugin

# List all registered marketplaces
claude /plugin marketplace list

# List installed plugins
claude /plugin list

# Install additional plugin
claude /plugin install plugin-name@marketplace-name

# Uninstall plugin
claude /plugin uninstall plugin-name
```

## Configuration

### YAML Configuration Format

The `marketplaces.yml` file uses Claude Code's official configuration format:

```yaml
extraKnownMarketplaces:
  marketplace-name:
    source:
      source: github
      repo: owner/repository

enabledPlugins:
  plugin-name@marketplace-name: true
```

### Example Configuration

```yaml
# Claude Code Plugin Marketplaces Configuration
# See: https://docs.claude.com/en/docs/claude-code/settings

extraKnownMarketplaces:
  beads-marketplace:
    source:
      source: github
      repo: steveyegge/beads

  cc-blueprint-toolkit:
    source:
      source: github
      repo: croffasia/cc-blueprint-toolkit

enabledPlugins:
  beads@beads-marketplace: true
  bp@cc-blueprint-toolkit: true
```

### Curated Marketplaces

The `marketplaces.yml.example` includes these pre-selected marketplaces:

| Marketplace                        | Description                                         | Repository                                |
| ---------------------------------- | --------------------------------------------------- | ----------------------------------------- |
| **beads-marketplace**              | Natural language programming with Claude            | steveyegge/beads                          |
| **cc-blueprint-toolkit**           | Project scaffolding and architecture templates      | croffasia/cc-blueprint-toolkit            |
| **claude-equity-research-marketplace** | Financial analysis and equity research tools | quant-sentiment-ai/claude-equity-research |
| **n8n-mcp-skills**                 | Workflow automation integration                     | czlonkowski/n8n-skills                    |
| **life-sciences**                  | Anthropic's official life sciences research plugins | anthropics/life-sciences                  |
| **awesome-claude-skills**          | Community-curated collection of useful skills       | ComposioHQ/awesome-claude-skills          |

### File Locations

- **Claude Settings**: `~/.claude/settings.json` (merged configuration)
- **YAML Template**: `/workspace/marketplaces.yml.example` (full list, 6 marketplaces)
- **CI YAML Template**: `/workspace/marketplaces.ci.yml.example` (CI testing, 3 marketplaces)
- **YAML Config**: `/workspace/marketplaces.yml` (user-created working file)
- **Default Settings**: Extension includes `default-settings.json` as merge base

### CI Mode

When `CI_MODE=true`, the extension automatically uses `marketplaces.ci.yml.example`:

**CI Test Marketplaces (3 selected for reliability)**:

```yaml
extraKnownMarketplaces:
  beads-marketplace:
    source:
      source: github
      repo: steveyegge/beads

  claude-equity-research-marketplace:
    source:
      source: github
      repo: quant-sentiment-ai/claude-equity-research

  awesome-claude-skills:
    source:
      source: github
      repo: ComposioHQ/awesome-claude-skills

enabledPlugins:
  beads@beads-marketplace: true
  trading-ideas@claude-equity-research-marketplace: true
  brand-guidelines@awesome-claude-skills: true
```

## How It Works

### Workflow Overview

1. **YAML → JSON Conversion**:
   - Extension uses `yq` to convert `marketplaces.yml` to JSON
   - Validates YAML syntax before conversion

2. **settings.json Merging**:
   - Reads existing `~/.claude/settings.json` (or uses `default-settings.json`)
   - Merges marketplace configuration using `jq`
   - Preserves other Claude Code settings (model, thinking mode, etc.)
   - Creates timestamped backup before modification

3. **Automatic Installation**:
   - Claude Code reads `extraKnownMarketplaces` and `enabledPlugins`
   - Automatically clones marketplace repositories
   - Installs specified plugins on next invocation
   - No manual CLI commands required

### Backup System

The extension automatically backs up `settings.json` before any modification:

- **Location**: `~/.claude/backups/settings-YYYYMMDD-HHMMSS.json`
- **Retention**: Keeps last 5 backups
- **Restore**: Manually copy from backup directory if needed

## Extension API Compliance

This extension implements **Extension API v2.0**:

### Metadata

- **Name**: claude-marketplace
- **Version**: 2.0.0
- **API Version**: 2.0
- **Category**: dev-tools
- **Install Method**: native
- **Upgrade Strategy**: manual

### Functions

- ✅ `prerequisites()` - Check Claude CLI, yq, jq availability
- ✅ `install()` - Convert YAML → JSON, merge into settings.json
- ✅ `configure()` - Display configuration summary and next steps
- ✅ `validate()` - Verify settings.json structure, YAML syntax, plugin references
- ✅ `status()` - Display marketplaces, plugins, YAML config, and management commands
- ✅ `upgrade()` - Reprocess YAML and update settings.json
- ✅ `remove()` - Clean marketplace config from settings.json with backup

### Dependencies

- `claude` extension (provides Claude CLI)
- `yq` (pre-installed in base image)
- `jq` (pre-installed in base image)

## Troubleshooting

### YAML Syntax Errors

**Symptom**: `Failed to convert YAML to JSON`

**Solution**:

```bash
# Validate YAML syntax
yq eval '.' /workspace/marketplaces.yml

# Check for common issues:
# - Indentation (use spaces, not tabs)
# - Missing colons
# - Unquoted special characters

# Fix syntax errors, then reinstall
extension-manager install claude-marketplace
```

### settings.json Validation Fails

**Symptom**: `settings.json has invalid JSON syntax`

**Solution**:

```bash
# Validate JSON syntax
jq empty ~/.claude/settings.json

# If corrupt, restore from backup
ls -lt ~/.claude/backups/settings-*.json | head -5
cp ~/.claude/backups/settings-YYYYMMDD-HHMMSS.json ~/.claude/settings.json

# Or start fresh
echo '{}' > ~/.claude/settings.json
extension-manager install claude-marketplace
```

### Plugin References Invalid

**Symptom**: `Plugin 'foo@unknown-marketplace' references unknown marketplace`

**Solution**:

```bash
# Check marketplace names in YAML
yq eval '.extraKnownMarketplaces | keys' /workspace/marketplaces.yml

# Ensure enabledPlugins reference those marketplace names
yq eval '.enabledPlugins' /workspace/marketplaces.yml

# Fix references:
# enabledPlugins:
#   plugin-name@marketplace-name: true  # marketplace-name must exist in extraKnownMarketplaces
```

### yq Not Found

**Symptom**: `yq command not found`

**Solution**:

yq is pre-installed in the base Docker image. If it's missing, the base image may need to be rebuilt:

```bash
# Verify yq is installed
yq --version

# If missing, this indicates a problem with the base image
# Contact your system administrator or rebuild the Docker image
```

### Marketplace Configuration Not Appearing

**Symptom**: settings.json exists but has no marketplace configuration

**Solution**:

```bash
# Check if YAML file exists
ls -l /workspace/marketplaces.yml

# If missing, copy from template
cp /workspace/marketplaces.yml.example /workspace/marketplaces.yml

# Reinstall to process YAML
extension-manager install claude-marketplace

# Verify merge
jq '.extraKnownMarketplaces, .enabledPlugins' ~/.claude/settings.json
```

## Upgrading

### Manual Upgrade

```bash
# Reprocess YAML configuration
extension-manager upgrade claude-marketplace

# Verify updated configuration
extension-manager status claude-marketplace
```

### Automatic Upgrade

```bash
# Upgrade all extensions
extension-manager upgrade-all

# Preview upgrades first (dry-run)
extension-manager upgrade-all --dry-run
```

## Removal

```bash
# Uninstall claude-marketplace
extension-manager uninstall claude-marketplace

# You'll be prompted to optionally remove:
# - Marketplace configuration from settings.json
# - YAML configuration files
# - Settings.json backups are preserved
```

## Examples

### Basic Workflow

```bash
# 1. Create YAML configuration
cp /workspace/marketplaces.yml.example /workspace/marketplaces.yml

# 2. Customize marketplaces (optional)
vim /workspace/marketplaces.yml

# 3. Install extension (processes YAML → settings.json)
extension-manager install claude-marketplace

# 4. Invoke Claude (automatic marketplace/plugin installation)
claude

# 5. Verify installation
claude /plugin list
```

### Custom Marketplace Configuration

Create `/workspace/marketplaces.yml` with your selection:

```yaml
extraKnownMarketplaces:
  beads-marketplace:
    source:
      source: github
      repo: steveyegge/beads

  cc-blueprint-toolkit:
    source:
      source: github
      repo: croffasia/cc-blueprint-toolkit

enabledPlugins:
  beads@beads-marketplace: true
  bp@cc-blueprint-toolkit: true
```

Then install:

```bash
extension-manager install claude-marketplace
```

### Adding New Marketplaces

To add a new marketplace:

1. **Edit YAML configuration**:

   ```yaml
   extraKnownMarketplaces:
     my-custom-marketplace:
       source:
         source: github
         repo: myorg/my-marketplace

   enabledPlugins:
     my-plugin@my-custom-marketplace: true
   ```

2. **Reinstall to apply changes**:

   ```bash
   extension-manager install claude-marketplace
   ```

3. **Invoke Claude to install**:

   ```bash
   claude
   ```

### Viewing Current Configuration

```bash
# View settings.json
cat ~/.claude/settings.json | jq .

# View just marketplaces
jq '.extraKnownMarketplaces' ~/.claude/settings.json

# View just enabled plugins
jq '.enabledPlugins' ~/.claude/settings.json

# Use extension status command
extension-manager status claude-marketplace
```

## Advanced Usage

### Multiple Source Types

The YAML configuration supports different source types:

```yaml
extraKnownMarketplaces:
  # GitHub repository
  github-marketplace:
    source:
      source: github
      repo: owner/repository

  # Git URL
  git-marketplace:
    source:
      source: git
      url: https://gitlab.com/company/plugins.git

  # Local directory (for development)
  local-marketplace:
    source:
      source: directory
      path: /path/to/marketplace
```

### Project-Specific Configuration

Different projects can have different marketplace configurations:

```bash
# In project A
cd /workspace/projects/active/project-a
cp /workspace/marketplaces.yml.example ./marketplaces.yml
# Edit marketplaces.yml for project A
extension-manager install claude-marketplace

# In project B
cd /workspace/projects/active/project-b
cp /workspace/marketplaces.yml.example ./marketplaces.yml
# Edit marketplaces.yml for project B
extension-manager install claude-marketplace
```

### Marketplace Discovery

Browse the official Claude Code Plugin Marketplace directory:

**[https://claudecodemarketplace.com/](https://claudecodemarketplace.com/)**

The directory provides:

- Curated list of available plugin marketplaces
- Marketplace descriptions and categories
- Installation instructions (YAML format)
- Community ratings and reviews

## Resources

- **Claude Code Plugin Marketplace**: https://claudecodemarketplace.com/
- **Plugin Marketplace Docs**: https://docs.claude.com/en/docs/claude-code/plugin-marketplaces
- **Settings Configuration**: https://docs.claude.com/en/docs/claude-code/settings
- **Claude Code Documentation**: https://docs.claude.com/en/docs/claude-code
- **yq Documentation**: https://mikefarah.gitbook.io/yq/

## Related Extensions

- **claude** - Claude Code CLI (required dependency)
- **openskills** - OpenSkills CLI for Agent Skills management
- **nodejs** - Node.js runtime (recommended for many plugins)

## Support

For issues specific to:

- **Claude CLI**: https://docs.claude.com/en/docs/claude-code
- **Sindri integration**: https://github.com/pacphi/sindri/issues
- **Specific plugins**: Check individual plugin repositories

## License

This extension is part of the Sindri project. See the [Sindri repository](https://github.com/pacphi/sindri) for license information.

Individual plugins have their own licenses - check each plugin's repository for details.
