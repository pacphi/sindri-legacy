# Sindri Workspace Structure

This document describes the runtime directory structure of a Sindri VM workspace at `/workspace`.

## Directory Tree

```text
/workspace/                                   # Persistent volume root (mixed ownership)
│
├── developer/                                # Developer home directory (developer:developer, 755)
│   ├── .bashrc                               # Shell configuration
│   ├── .bash_profile                         # Login shell configuration
│   ├── .ssh/                                 # SSH keys (700)
│   │   └── authorized_keys                   # Authorized SSH keys (600)
│   ├── .claude/                              # Claude Code configuration (644)
│   │   ├── CLAUDE.md                         # Global preferences for Claude
│   │   └── settings.json                     # Claude settings (marketplaces, plugins)
│   ├── .config/                              # User application configs
│   │   ├── mise/                             # mise tool version manager config
│   │   └── gh/                               # GitHub CLI configuration
│   │       └── hosts.yml                     # GitHub authentication (600)
│   ├── .openskills/                          # OpenSkills CLI storage
│   │   └── *.md                              # Installed skill definitions
│   └── extensions/                           # Extension-specific artifacts
│
├── config/                                   # User configuration files (developer:developer, 775)
│   ├── marketplaces.yml                      # Claude marketplace configuration
│   ├── marketplaces.yml.example              # Template for marketplaces
│   ├── agents-config.yaml                    # Agent manager configuration
│   └── templates/                            # Configuration templates
│
├── scripts/                                  # User and extension-generated scripts (developer:developer, 775)
│   ├── context-loader.sh                     # Context loading utilities
│   ├── cf-with-context.sh                    # Claude Flow with context wrapper
│   └── *.sh                                  # Other utility scripts
│
├── projects/                                 # Development projects (developer:developer, 775)
│   └── active/                               # Active projects directory
│       ├── my-app/                           # Example project
│       │   ├── CLAUDE.md                     # Project-specific context
│       │   ├── mise.toml                     # Project tool versions
│       │   └── src/                          # Source code
│       └── another-project/
│
├── agents/                                   # AI agent configurations (developer:developer, 775)
│   └── *.yaml                                # Agent definition files
│
├── context/                                  # Context management for AI tools (developer:developer, 775)
│   ├── global/                               # Global context files
│   │   └── *.md                              # Global context documents
│   └── templates/                            # Context templates
│       └── *.md                              # Template files
│
├── bin/                                      # User binaries and scripts (developer:developer, 775)
│   ├── extension-manager -> ../.system/bin/extension-manager  # Symlink to system binary
│   ├── backup -> /docker/scripts/backup.sh   # Symlink to backup script
│   ├── clone-project -> /docker/scripts/clone-project.sh
│   ├── new-project -> /docker/scripts/new-project.sh
│   ├── restore -> /docker/scripts/restore.sh
│   └── system-status -> /docker/scripts/system-status.sh
│
├── docs/                                     # Workspace-wide documentation (developer:developer, 775)
│   └── *.md                                  # Documentation files
│
├── backups/                                  # Backup files (developer:developer, 775)
│   └── *.tar.gz                              # Compressed backups
│
├── .system/                                  # System runtime files (root:root, 755)
│   ├── bin/                                  # System binaries (root:root, 755)
│   │   └── extension-manager -> /docker/lib/extension-manager.sh  # Symlink to Docker image
│   ├── lib/                                  # System libraries (root:root, 755)
│   │   ├── common.sh -> /docker/lib/common.sh                     # Symlink
│   │   ├── extensions-common.sh -> /docker/lib/extensions-common.sh  # Symlink
│   │   └── extensions.d -> /docker/lib/extensions.d/              # Symlink to extensions
│   └── manifest/                             # Extension system config (developer:developer, 775)
│       └── active-extensions.conf            # Active extensions list (644)
│
└── README.md                                 # Workspace documentation (root:root, 644)
```

## Directory Purposes

### User Workspace (Developer-Owned, Writable)

#### `/workspace/developer/`

- **Purpose**: Developer's home directory on persistent volume
- **Owner**: `developer:developer` (755)
- **Persistence**: Yes - survives VM restarts
- **Contents**:
  - Shell configurations (`.bashrc`, `.bash_profile`)
  - SSH keys and authentication
  - Tool configurations (Claude, mise, GitHub CLI)
  - User-installed packages and tools
- **Notes**: This is `$HOME` for the developer user at runtime

#### `/workspace/config/`

- **Purpose**: User-editable configuration files
- **Owner**: `developer:developer` (775)
- **Persistence**: Yes
- **Contents**:
  - Extension configuration files (e.g., `marketplaces.yml`)
  - Agent configurations
  - Templates for configuration
- **Usage**: Extensions that need user-editable config files place them here

#### `/workspace/scripts/`

- **Purpose**: User scripts and extension-generated helper scripts
- **Owner**: `developer:developer` (775)
- **Persistence**: Yes
- **Contents**:
  - Context loader utilities
  - Wrapper scripts for AI tools
  - Custom user scripts
- **Usage**: Extensions can generate helper scripts here during installation

#### `/workspace/projects/`

- **Purpose**: Active development projects
- **Owner**: `developer:developer` (775)
- **Persistence**: Yes
- **Structure**:
  - `active/` - Current projects
  - Each project has its own subdirectory
- **Usage**: Primary location for git repositories and development work

#### `/workspace/agents/`

- **Purpose**: AI agent configurations
- **Owner**: `developer:developer` (775)
- **Persistence**: Yes
- **Contents**: YAML configuration files for Claude Flow agents
- **Usage**: Defines agent behaviors and capabilities

#### `/workspace/context/`

- **Purpose**: Context management for AI tools
- **Owner**: `developer:developer` (775)
- **Persistence**: Yes
- **Structure**:
  - `global/` - Context available to all projects
  - `templates/` - Reusable context templates
- **Usage**: Store context files for AI coding assistants

#### `/workspace/bin/`

- **Purpose**: User-accessible binaries and scripts
- **Owner**: `developer:developer` (775)
- **Persistence**: Yes
- **Contents**: Symlinks to system scripts and user tools
- **Usage**: Added to `$PATH` for easy command access

#### `/workspace/docs/`

- **Purpose**: Workspace-wide documentation
- **Owner**: `developer:developer` (775)
- **Persistence**: Yes
- **Contents**: Markdown documentation files
- **Usage**: Knowledge base and reference material

#### `/workspace/backups/`

- **Purpose**: Backup storage
- **Owner**: `developer:developer` (775)
- **Persistence**: Yes
- **Contents**: Compressed backup archives
- **Usage**: Automated backups of workspace data

### System Directories (Root-Owned, Read-Only)

#### `/workspace/.system/`

- **Purpose**: System runtime files managed by Sindri
- **Owner**: `root:root` (755)
- **Persistence**: Structure persists, contents are symlinks
- **Contents**: Symlinks to Docker image files
- **Usage**: Provides access to system binaries and libraries

#### `/workspace/.system/bin/`

- **Purpose**: System binaries
- **Owner**: `root:root` (755)
- **Persistence**: Symlinks recreated on startup
- **Contents**: `extension-manager` symlink
- **Usage**: System commands accessible via symlinks

#### `/workspace/.system/lib/`

- **Purpose**: System libraries
- **Owner**: `root:root` (755)
- **Persistence**: Symlinks recreated on startup
- **Contents**:
  - `common.sh` - Shared utility functions
  - `extensions-common.sh` - Extension API helpers
  - `extensions.d/` - Extension definitions
- **Usage**: Shared code for extensions and scripts

#### `/workspace/.system/manifest/`

- **Purpose**: Extension system configuration
- **Owner**: `developer:developer` (775)
- **Persistence**: Yes - user-modifiable
- **Contents**: `active-extensions.conf` - List of enabled extensions
- **Usage**: Controls which extensions are installed/activated
- **Note**: Exception to `.system/` being root-owned - this is developer-owned

## Ownership Summary

| Directory | Owner | Permissions | Writable by Developer |
|-----------|-------|-------------|----------------------|
| `/workspace/developer/` | developer:developer | 755 | ✓ Yes |
| `/workspace/config/` | developer:developer | 775 | ✓ Yes |
| `/workspace/scripts/` | developer:developer | 775 | ✓ Yes |
| `/workspace/projects/` | developer:developer | 775 | ✓ Yes |
| `/workspace/agents/` | developer:developer | 775 | ✓ Yes |
| `/workspace/context/` | developer:developer | 775 | ✓ Yes |
| `/workspace/bin/` | developer:developer | 775 | ✓ Yes |
| `/workspace/docs/` | developer:developer | 775 | ✓ Yes |
| `/workspace/backups/` | developer:developer | 775 | ✓ Yes |
| `/workspace/.system/` | root:root | 755 | ✗ No |
| `/workspace/.system/bin/` | root:root | 755 | ✗ No |
| `/workspace/.system/lib/` | root:root | 755 | ✗ No |
| `/workspace/.system/manifest/` | developer:developer | 775 | ✓ Yes |

## Key Design Principles

1. **Separation of Concerns**:
   - User files in writable directories
   - System files in read-only directories (via symlinks)
   - Extension management in dedicated location

2. **Persistence**:
   - All user data in `/workspace` survives VM restarts
   - System files in `/docker` are immutable (from Docker image)
   - `.system/` uses symlinks for efficiency

3. **Security**:
   - System binaries are root-owned (read-only to users)
   - User workspace is developer-owned (writable)
   - Sensitive files have restricted permissions (600 for SSH keys)

4. **Extension Guidelines**:
   - **Never write to** `/workspace/` root (not developer-owned)
   - **User configs go to** `/workspace/config/`
   - **Helper scripts go to** `/workspace/scripts/`
   - **User home files go to** `/workspace/developer/`
   - **System manifests go to** `/workspace/.system/manifest/`

## Common Pitfalls

### ❌ Don't Do This

```bash
# Writing to /workspace root (permission denied)
cp file.yml /workspace/
echo "data" > /workspace/config.txt
```

### ✓ Do This Instead

```bash
# Write to appropriate subdirectory
cp file.yml /workspace/config/
echo "data" > /workspace/developer/.myconfig
```

## Extension File Placement Reference

| Extension Type | Configuration Files | Helper Scripts | User Data |
|---------------|-------------------|----------------|-----------|
| **claude-marketplace** | `/workspace/config/marketplaces.yml` | N/A | `/workspace/developer/.claude/settings.json` |
| **openskills** | N/A | N/A | `/workspace/developer/.openskills/` |
| **context-loader** | N/A | `/workspace/scripts/context-loader.sh` | `/workspace/context/` |
| **agent-manager** | `/workspace/config/agents-config.yaml` | N/A | `/workspace/agents/` |
| **tmux-workspace** | `/workspace/config/tmux-*.conf` | `/workspace/scripts/tmux-*.sh` | `/workspace/developer/.tmux/` |

## Verification Commands

```bash
# Check workspace structure
ls -la /workspace/

# Check directory ownership
ls -ld /workspace/*/

# Check manifest location
cat /workspace/.system/manifest/active-extensions.conf

# Check config directory contents
ls -la /workspace/config/

# Verify permissions on key directories
stat /workspace/config /workspace/.system/manifest
```
