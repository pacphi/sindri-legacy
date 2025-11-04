# OpenSkills Extension

OpenSkills is a CLI tool that implements
[Anthropic's Agent Skills specification](https://github.com/anthropics/anthropic-skills-marketplace),
bringing Claude Code's skills system to all AI coding agents.

## Overview

This extension installs and configures OpenSkills CLI for managing Claude Code skills from Anthropic's official marketplace.

It provides:

- **Skill Installation**: Install skills from GitHub repositories, particularly Anthropic's marketplace
- **Progressive Disclosure**: Load skill instructions only when needed to keep agent context clean
- **Multi-Agent Support**: Works universally across different coding agents (Claude Code, Cursor, Windsurf, Aider)
- **Skill Management**: Commands to install, list, sync, and remove skills
- **SKILL.md Format**: Uses YAML frontmatter with markdown instructions, matching Claude Code's exact specification
- **Bundled Resources**: Supports organizing skills with references, scripts, and assets

## Prerequisites

- **Node.js** 20.6 or newer (installed via `nodejs` extension)
- **npm** (included with Node.js)
- **git** (for cloning skill repositories)

## Installation

### Via Extension Manager

```bash
# Install openskills (auto-activates if needed)
extension-manager install openskills

# Or use interactive mode
extension-manager --interactive

# Or manually activate then install
# Edit: docker/lib/extensions.d/active-extensions.conf
# Add line: openskills
extension-manager install-all
```

### Verification

```bash
# Check installation status
extension-manager status openskills

# Validate installation
extension-manager validate openskills

# Check version
openskills --version
```

## Usage

### Installing Skills from Anthropic's Marketplace

```bash
# Install from Anthropic's official marketplace (interactive selection)
openskills install anthropics/anthropic-skills-marketplace

# Or use the shell alias
skill-marketplace
```

### Managing Skills

```bash
# List all installed skills
openskills list
# Or: skill-list

# Sync skills to AGENTS.md
openskills sync
# Or: skill-sync

# Read skill content (for agents)
openskills read <skill-name>
# Or: skill-read <skill-name>

# Remove skills interactively
openskills manage
# Or: skill-manage
```

### Using Skills with Claude Code

Once skills are installed and synced:

1. **AGENTS.md** file is created/updated in your project
2. Claude Code automatically loads relevant skills when needed
3. Skills provide context-specific instructions without cluttering prompts

## Shell Aliases

The extension provides convenient aliases:

| Alias               | Command                                                      | Description                           |
| ------------------- | ------------------------------------------------------------ | ------------------------------------- |
| `skills`            | `openskills`                                                 | Short alias for openskills            |
| `skill-install`     | `openskills install`                                         | Install skills                        |
| `skill-list`        | `openskills list`                                            | List installed skills                 |
| `skill-sync`        | `openskills sync`                                            | Sync skills to AGENTS.md              |
| `skill-read`        | `openskills read`                                            | Read skill content                    |
| `skill-manage`      | `openskills manage`                                          | Manage/remove skills                  |
| `skill-marketplace` | `openskills install anthropics/anthropic-skills-marketplace` | Quick access to Anthropic marketplace |
| `skills-help`       | `openskills --help`                                          | Show help                             |
| `skills-version`    | `openskills --version`                                       | Show version                          |

## Configuration

### Installation Location

- **Binary**: Installed via npm global packages (managed by Node.js)
- **Config Directory**: `~/.openskills/`
- **Skills Storage**: `~/.openskills/skills/`
- **Project File**: `AGENTS.md` (created in project root on sync)

### SSH Support

The extension creates SSH wrappers for non-interactive sessions, enabling:

- Remote command execution via `ssh developer@<app>.fly.dev openskills list`
- CI/CD integration
- Automated skill management

## Extension API Compliance

This extension implements **Extension API v2.0** with the following features:

### Metadata

- **Name**: openskills
- **Version**: 1.0.0
- **API Version**: 2.0
- **Category**: dev-tools
- **Install Method**: npm
- **Upgrade Strategy**: automatic

### Functions

- ✅ `prerequisites()` - Check Node.js 20.6+, npm, git
- ✅ `install()` - Install openskills via npm globally
- ✅ `configure()` - Setup config directory, SSH wrappers, aliases
- ✅ `validate()` - Test command availability and functionality
- ✅ `status()` - Display version and installed skills
- ✅ `upgrade()` - Upgrade via npm (Extension API v2.0)
- ✅ `remove()` - Uninstall and cleanup

### Dependencies

The extension has explicit dependencies checked in `prerequisites()`:

- `nodejs` extension (provides Node.js 20.6+ and npm)
- `git` command (for cloning repositories)

## Troubleshooting

### Command Not Found

**Symptom**: `openskills: command not found`

**Solution**:

```bash
# Reload shell environment
exec bash -l

# Or verify npm global packages
npm list -g --depth=0

# Reinstall if needed
extension-manager uninstall openskills
extension-manager install openskills
```

### Node.js Version Too Old

**Symptom**: `Node.js 20.6+ required`

**Solution**:

```bash
# Upgrade Node.js via mise
mise use node@lts

# Verify version
node --version

# Reinstall openskills
extension-manager install openskills
```

### Git Not Available

**Symptom**: `git is required but not installed`

**Solution**:

Git is pre-installed in Sindri. If missing:

```bash
# Check git availability
which git

# Verify it's in PATH
echo $PATH

# Git should be at /usr/bin/git
```

### Skills Not Loading

**Symptom**: Skills installed but not appearing in Claude Code

**Solution**:

```bash
# Sync skills to AGENTS.md
openskills sync

# Verify AGENTS.md exists in project root
ls -la AGENTS.md

# Check skills are listed
cat AGENTS.md
```

## Upgrading

### Manual Upgrade

```bash
# Check current version
openskills --version

# Upgrade via extension-manager
extension-manager upgrade openskills

# Verify new version
openskills --version
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
# Uninstall openskills
extension-manager uninstall openskills

# You'll be prompted to optionally remove:
# - Config directory (~/.openskills)
# - Installed skills
# - Aliases from .bashrc
```

## Examples

### Basic Workflow

```bash
# 1. Install skills from marketplace
skill-marketplace
# Select skills interactively

# 2. List installed skills
skill-list

# 3. Sync to project
cd /workspace/projects/active/my-project
skill-sync

# 4. Skills are now available to Claude Code
# AGENTS.md file created with skill references
```

### Custom Skill Repository

```bash
# Install skills from custom GitHub repository
openskills install username/my-skills-repo

# List all skills (including custom)
openskills list
```

### Remove Specific Skills

```bash
# Interactive management
openskills manage
# Select skills to remove
```

## Resources

- **OpenSkills GitHub**: https://github.com/numman-ali/openskills
- **Anthropic Skills Marketplace**: https://github.com/anthropics/anthropic-skills-marketplace
- **Agent Skills Specification**: https://github.com/anthropics/anthropic-skills-marketplace/blob/main/SPEC.md
- **Claude Code Documentation**: https://docs.claude.com/en/docs/claude-code

## Related Extensions

- **claude** - Claude Code CLI (works alongside openskills)
- **nodejs** - Node.js runtime (required dependency)
- **nodejs-devtools** - Additional Node.js development tools

## Support

For issues specific to:

- **OpenSkills tool**: https://github.com/numman-ali/openskills/issues
- **Sindri integration**: https://github.com/cphillipson/sindri/issues
- **Skills marketplace**: https://github.com/anthropics/anthropic-skills-marketplace/issues

## License

OpenSkills is an open-source project. See the [OpenSkills repository](https://github.com/numman-ali/openskills)
for license information.
