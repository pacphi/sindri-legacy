# Claude Marketplace Extension

This extension automatically installs curated plugins from Claude Code plugin marketplaces
hosted in GitHub repositories.

## Overview

This extension provides automated installation of plugins from marketplaces specified in a
`.marketplaces` configuration file. Each marketplace is a GitHub repository containing a
`.claude-plugin/marketplace.json` file that defines available plugins.

It provides:

- **Automated Installation**: Install plugins from marketplaces listed in a `.marketplaces` file
- **Curated Collection**: Pre-selected high-quality marketplaces for various use cases
- **GitHub Support**: Install plugins directly from GitHub repository marketplaces
- **Idempotent**: Safe to re-run installation without duplicating marketplaces
- **Team Consistency**: Share `.marketplaces` file across team for consistent tooling

## Prerequisites

- **Claude CLI** (installed via `claude` extension) - **Required**
- **git** (for cloning plugin repositories) - **Required**
- **Claude Authentication** - **Optional** (but required for plugin installation)

### Authentication Requirements

The extension works in two modes:

1. **With Authentication** (Recommended):
   - Plugin installation fully functional
   - Set `ANTHROPIC_API_KEY` environment variable, OR
   - Run `claude` command to authenticate interactively

2. **Without Authentication** (Limited):
   - Marketplace configuration still works
   - Plugin installation is skipped with clear guidance
   - Suitable for environments where API keys aren't available

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

The extension automatically installs plugins listed in `/workspace/.marketplaces`:

1. **Ensure Claude is authenticated** (for plugin installation):

   ```bash
   # Check if authenticated
   claude /plugin marketplace list

   # If not authenticated, run:
   export ANTHROPIC_API_KEY="your-api-key"
   # OR authenticate interactively:
   claude
   ```

2. **Create your marketplaces file** (or use the template):

   ```bash
   cp /workspace/.marketplaces.example /workspace/.marketplaces
   ```

3. **Edit the file** to select desired marketplaces:

   ```bash
   vim /workspace/.marketplaces
   ```

4. **Install** (happens automatically during extension install):

   ```bash
   extension-manager install claude-marketplace
   ```

**Note**: If not authenticated, the marketplace will be configured but plugin
installation will be skipped. You can install plugins later with `claude /plugin`.

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

## Curated Marketplaces

The `.marketplaces.example` file includes these pre-selected marketplaces:

| Marketplace                     | Description                                         | Repository                                |
| -------------------------- | --------------------------------------------------- | ----------------------------------------- |
| **beads**                  | Natural language programming with Claude            | steveyegge/beads                          |
| **cc-blueprint-toolkit**   | Project scaffolding and architecture templates      | croffasia/cc-blueprint-toolkit            |
| **claude-equity-research** | Financial analysis and equity research tools        | quant-sentiment-ai/claude-equity-research |
| **n8n-skills**             | Workflow automation integration                     | czlonkowski/n8n-skills                    |
| **life-sciences**          | Anthropic's official life sciences research plugins | anthropics/life-sciences                  |
| **awesome-claude-skills**  | Community-curated collection of useful skills       | ComposioHQ/awesome-claude-skills          |

## Configuration

### `.marketplaces` File Format

One marketplaces per line, GitHub format (`owner/repo`):

```bash
# Claude Code Plugin Marketplace - Curated Marketplaces
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
- **Marketplaces Template**: `/workspace/.marketplaces.example` (full list, 6 marketplaces)
- **CI Marketplaces Template**: `/workspace/.marketplaces.ci.example` (CI testing, 3 marketplaces)
- **Marketplaces Config**: `/workspace/.marketplaces` (user-created)
- **Installed Plugins**: Managed by Claude CLI

### CI Mode

When `CI_MODE=true`, the extension automatically:

1. Uses `.marketplaces.ci.example` (3 marketplaces) instead of `.marketplaces.example` (6 marketplaces)
2. Creates `/workspace/.marketplaces` from CI template if it doesn't exist
3. Checks for Claude authentication before attempting plugin installation
4. **With `ANTHROPIC_API_KEY` set**: Installs plugins automatically
5. **Without authentication**: Skips plugin installation with informative message

**CI Test Marketplaces (3 selected for reliability)**:

- `steveyegge/beads` - Natural language programming
- `anthropics/life-sciences` - Official Anthropic plugin
- `ComposioHQ/awesome-claude-skills` - Community-curated collection

#### Enabling Plugin Installation in CI

To enable automatic plugin installation in CI/CD:

```yaml
# In your GitHub Actions workflow:
jobs:
  test:
    steps:
      - name: Run tests
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          extension-manager install claude-marketplace
```

**Without authentication**, you'll see:

```text
⚠️  Claude is not authenticated - skipping plugin installation

Plugin installation requires Claude Code authentication.
To enable plugin installation in CI:
  1. Set ANTHROPIC_API_KEY as a repository secret
  2. Pass it to the workflow:
     env:
       ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

Plugins will need to be installed manually or in an authenticated context.
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

- ✅ `prerequisites()` - Check Claude CLI and git (authentication optional)
- ✅ `install()` - Configure marketplace, install plugins if authenticated
- ✅ `configure()` - Check authentication, install plugins if available, configure marketplace
- ✅ `validate()` - Verify marketplace configuration, check plugins if authenticated
- ✅ `status()` - Display marketplace status, configuration, and plugin information
- ✅ `upgrade()` - Update marketplace metadata, re-sync plugins
- ✅ `remove()` - Remove marketplace configuration, optionally uninstall plugins

### Dependencies

The extension has explicit dependencies checked in `prerequisites()`:

- `claude` extension (provides Claude CLI)
- `git` command (for cloning repositories)

## Troubleshooting

### Authentication Issues

**Symptom**: `Claude is not authenticated - skipping plugin installation`

**Solution**:

```bash
# Option 1: Set API key environment variable
export ANTHROPIC_API_KEY="your-api-key-here"

# Option 2: Authenticate interactively
claude

# Option 3: For CI/CD, set as secret
# In GitHub: Settings → Secrets → New repository secret
# Name: ANTHROPIC_API_KEY
# Value: your-api-key

# Then in workflow:
# env:
#   ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

**Note**: The extension will still configure the marketplace even without
authentication. Plugins can be installed later once authenticated.

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

### `.marketplaces` File Not Found

**Symptom**: `No .marketplaces file found`

**Solution**:

```bash
# Copy template
cp /workspace/.marketplaces.example /workspace/.marketplaces

# Edit to customize
vim /workspace/.marketplaces

# Reinstall to process marketplaces
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
# - .marketplaces and .marketplaces.example files
```

## Examples

### Basic Workflow

```bash
# 1. Create marketplaces configuration
cp /workspace/.marketplaces.example /workspace/.marketplaces

# 2. Customize marketplaces (optional)
vim /workspace/.marketplaces

# 3. Install extension (auto-installs marketplaces and their plugins)
extension-manager install claude-marketplace

# 4. Verify installation
claude /plugin list

# 5. Browse available plugins
claude /plugin
```

### Custom Marketplace List

Create `/workspace/.marketplaces` with your selection:

```bash
# My Project Marketplaces
steveyegge/beads
croffasia/cc-blueprint-toolkit
```

Then install:

```bash
extension-manager install claude-marketplace
```

### Project-Specific Marketplaces

Different projects can have different marketplace requirements:

```bash
# In project A
cd /workspace/projects/active/project-a
cp /workspace/.marketplaces.example ./.marketplaces
# Edit ./.marketplaces for project A needs
extension-manager install claude-marketplace

# In project B
cd /workspace/projects/active/project-b
cp /workspace/.marketplaces.example ./.marketplaces
# Edit ./.marketplaces for project B needs
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
5. Share with team via `.marketplaces` file

## Resources

- **Plugin Marketplace Docs**: https://docs.claude.com/en/docs/claude-code/plugin-marketplaces
- **Claude Code Documentation**: https://docs.claude.com/en/docs/claude-code
- **GitHub Marketplace Repositories**: Listed in `.marketplaces.example`
- **Example Marketplaces**: See `.marketplaces.example` for curated list

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
