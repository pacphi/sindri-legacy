# Claude Marketplace Extension

This extension integrates Claude Code with https://claudecodemarketplace.com/ and automatically installs
curated plugins from GitHub repositories.

## Overview

This extension configures Claude Code to access plugins from the Claude Code Plugin Marketplace and provides
automated installation of curated plugins specified in a `.plugins` configuration file.

It provides:

- **Marketplace Integration**: Automatic configuration of https://claudecodemarketplace.com/
- **Automated Installation**: Install plugins from a `.plugins` file (one per line)
- **Curated Collection**: Pre-selected high-quality plugins for various use cases
- **GitHub Support**: Install plugins directly from GitHub repositories
- **Idempotent**: Safe to re-run installation without duplicating plugins
- **Team Consistency**: Share `.plugins` file across team for consistent tooling

## Prerequisites

- **Claude CLI** (installed via `claude` extension)
- **git** (for cloning plugin repositories)
- **Authenticated Claude session** (run `claude` first if needed)

## Installation

### Via Extension Manager

```bash
# Install claude-marketplace (auto-activates if needed)
extension-manager install claude-marketplace

# Or use interactive mode
extension-manager --interactive

# Or manually activate then install
# Edit: docker/lib/extensions.d/active-extensions.conf
# Add line: claude-marketplace
extension-manager install-all
```

### Verification

```bash
# Check installation status
extension-manager status claude-marketplace

# Validate installation
extension-manager validate claude-marketplace

# List registered marketplaces
claude /plugin marketplace list
```

## Usage

### Automated Plugin Installation

The extension automatically installs plugins listed in `/workspace/.plugins`:

1. **Create your plugins file** (or use the template):

   ```bash
   cp /workspace/.plugins.example /workspace/.plugins
   ```

2. **Edit the file** to select desired plugins:

   ```bash
   vim /workspace/.plugins
   ```

3. **Install** (happens automatically during extension install):

   ```bash
   extension-manager install claude-marketplace
   ```

### Manual Plugin Management

```bash
# Browse and install plugins interactively
claude /plugin

# List all registered marketplaces
claude /plugin marketplace list

# Add a new marketplace
claude /plugin marketplace add owner/repo

# List installed plugins
claude /plugin list

# Install specific plugin
claude /plugin install plugin-name@marketplace-name

# Uninstall plugin
claude /plugin uninstall plugin-name

# Update marketplace metadata
claude /plugin marketplace update marketplace-name

# Remove marketplace
claude /plugin marketplace remove marketplace-name
```

## Curated Plugins

The `.plugins.example` file includes these pre-selected plugins:

| Plugin                     | Description                                         | Repository                                |
| -------------------------- | --------------------------------------------------- | ----------------------------------------- |
| **beads**                  | Natural language programming with Claude            | steveyegge/beads                          |
| **cc-blueprint-toolkit**   | Project scaffolding and architecture templates      | croffasia/cc-blueprint-toolkit            |
| **claude-equity-research** | Financial analysis and equity research tools        | quant-sentiment-ai/claude-equity-research |
| **n8n-skills**             | Workflow automation integration                     | czlonkowski/n8n-skills                    |
| **life-sciences**          | Anthropic's official life sciences research plugins | anthropics/life-sciences                  |
| **awesome-claude-skills**  | Community-curated collection of useful skills       | ComposioHQ/awesome-claude-skills          |

## Configuration

### `.plugins` File Format

One plugin per line, GitHub format (`owner/repo`):

```bash
# Claude Code Plugin Marketplace - Curated Plugins
# Lines starting with # are comments

# Development Tools
steveyegge/beads
croffasia/cc-blueprint-toolkit

# Domain-Specific
quant-sentiment-ai/claude-equity-research
anthropics/life-sciences

# Automation & Integration
czlonkowski/n8n-skills
ComposioHQ/awesome-claude-skills
```

### Installation Locations

- **Claude Config**: `~/.claude/settings.json`
- **Plugins Template**: `/workspace/.plugins.example` (full list, 6 plugins)
- **CI Plugins Template**: `/workspace/.plugins.ci.example` (CI testing, 3 plugins)
- **Plugins Config**: `/workspace/.plugins` (user-created)
- **Installed Plugins**: Managed by Claude CLI

### CI Mode

When `CI_MODE=true`, the extension automatically:

1. Uses `.plugins.ci.example` (3 plugins) instead of `.plugins.example` (6 plugins)
2. Creates `/workspace/.plugins` from CI template if it doesn't exist
3. Installs the minimal CI test set for faster, more reliable testing

**CI Test Plugins (3 selected for reliability)**:

- `steveyegge/beads` - Natural language programming
- `anthropics/life-sciences` - Official Anthropic plugin
- `ComposioHQ/awesome-claude-skills` - Community-curated collection

### Marketplace Configuration

The extension adds this to `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "claudecodemarketplace": {
      "source": {
        "url": "https://claudecodemarketplace.com/marketplace.json"
      }
    }
  }
}
```

## Extension API Compliance

This extension implements **Extension API v2.0** with the following features:

### Metadata

- **Name**: claude-marketplace
- **Version**: 2.0.0
- **API Version**: 2.0
- **Category**: dev-tools
- **Install Method**: native
- **Upgrade Strategy**: manual

### Functions

- ✅ `prerequisites()` - Check Claude CLI, git, authentication
- ✅ `install()` - Configure marketplace, install plugins from `.plugins` file
- ✅ `configure()` - Update Claude settings, verify marketplace access
- ✅ `validate()` - Test marketplace access and configuration
- ✅ `status()` - Display marketplace status and installed plugins
- ✅ `upgrade()` - Update marketplace metadata, re-sync plugins
- ✅ `remove()` - Remove marketplace configuration, optionally uninstall plugins

### Dependencies

The extension has explicit dependencies checked in `prerequisites()`:

- `claude` extension (provides Claude CLI)
- `git` command (for cloning repositories)

## Troubleshooting

### Marketplace Not Accessible

**Symptom**: `Could not access plugin marketplace`

**Solution**:

```bash
# Check Claude authentication
claude --version

# Re-authenticate if needed
claude

# Verify settings file
cat ~/.claude/settings.json

# Reinstall extension
extension-manager uninstall claude-marketplace
extension-manager install claude-marketplace
```

### Plugin Installation Fails

**Symptom**: `Failed to install: owner/repo`

**Solution**:

```bash
# Verify git access to repository
git ls-remote https://github.com/owner/repo

# Check Claude plugin system
claude /plugin marketplace list

# Try installing manually
claude /plugin marketplace add owner/repo

# Check for authentication issues
claude /plugin
```

### `.plugins` File Not Found

**Symptom**: `No .plugins file found`

**Solution**:

```bash
# Copy template
cp /workspace/.plugins.example /workspace/.plugins

# Edit to customize
vim /workspace/.plugins

# Reinstall to process plugins
extension-manager install claude-marketplace
```

### Settings File Corruption

**Symptom**: Invalid JSON in `settings.json`

**Solution**:

```bash
# Validate JSON
cat ~/.claude/settings.json | jq .

# If invalid, backup and recreate
mv ~/.claude/settings.json ~/.claude/settings.json.bak
echo '{}' > ~/.claude/settings.json

# Reinstall extension
extension-manager install claude-marketplace
```

## Upgrading

### Manual Upgrade

```bash
# Check current configuration
extension-manager status claude-marketplace

# Upgrade via extension-manager
extension-manager upgrade claude-marketplace

# Verify marketplace updated
claude /plugin marketplace list
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
# - Installed plugins
# - .plugins and .plugins.example files
```

## Examples

### Basic Workflow

```bash
# 1. Create plugins configuration
cp /workspace/.plugins.example /workspace/.plugins

# 2. Customize plugins (optional)
vim /workspace/.plugins

# 3. Install extension (auto-installs plugins)
extension-manager install claude-marketplace

# 4. Verify installation
claude /plugin list

# 5. Browse available plugins
claude /plugin
```

### Custom Plugin List

Create `/workspace/.plugins` with your selection:

```bash
# My Project Plugins
steveyegge/beads
croffasia/cc-blueprint-toolkit
```

Then install:

```bash
extension-manager install claude-marketplace
```

### Project-Specific Plugins

Different projects can have different plugin requirements:

```bash
# In project A
cd /workspace/projects/active/project-a
cp /workspace/.plugins.example ./.plugins
# Edit ./.plugins for project A needs
extension-manager install claude-marketplace

# In project B
cd /workspace/projects/active/project-b
cp /workspace/.plugins.example ./.plugins
# Edit ./.plugins for project B needs
extension-manager install claude-marketplace
```

## Advanced Usage

### Adding Custom Marketplaces

You can add additional marketplaces beyond the default:

```bash
# Add from GitHub repository
claude /plugin marketplace add owner/my-custom-marketplace

# Add from Git URL
claude /plugin marketplace add https://gitlab.com/company/plugins.git

# Add from local directory (for development)
claude /plugin marketplace add ./my-marketplace

# Add from remote URL
claude /plugin marketplace add https://url.of/marketplace.json
```

### Managing Multiple Marketplaces

```bash
# List all registered marketplaces
claude /plugin marketplace list

# Update specific marketplace
claude /plugin marketplace update marketplace-name

# Remove marketplace
claude /plugin marketplace remove marketplace-name
```

### Plugin Development

To develop and test your own plugins:

1. Create a marketplace repository with `.claude-plugin/marketplace.json`
2. Add locally: `claude /plugin marketplace add ./my-marketplace`
3. Test plugin installation: `claude /plugin install my-plugin@my-marketplace`
4. Publish to GitHub when ready
5. Share with team via `.plugins` file

## Resources

- **Claude Code Marketplace**: https://claudecodemarketplace.com/
- **Plugin Marketplace Docs**: https://docs.claude.com/en/docs/claude-code/plugin-marketplaces
- **Claude Code Documentation**: https://docs.claude.com/en/docs/claude-code
- **GitHub Plugin Repositories**: Listed in `.plugins.example`

## Related Extensions

- **claude** - Claude Code CLI (required dependency)
- **openskills** - OpenSkills CLI for Agent Skills management
- **nodejs-devtools** - Additional development tools

## Support

For issues specific to:

- **Claude CLI**: https://docs.claude.com/en/docs/claude-code
- **Sindri integration**: https://github.com/pacphi/sindri/issues
- **Specific plugins**: Check individual plugin repositories

## License

This extension is part of the Sindri project. See the [Sindri repository](https://github.com/pacphi/sindri)
for license information.

Individual plugins have their own licenses - check each plugin's repository for details.
