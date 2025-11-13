# Architecture

## System Overview

Sindri provides a complete AI-powered cloud development forge running on Fly.io infrastructure with persistent
storage, auto-scaling, and integrated AI development tools.

## Infrastructure Components

### Fly.io VM

- **Base Image**: Ubuntu 24.04 container
- **Auto-scaling**: Scale-to-zero when idle, auto-start on connection
- **Network**: Private networking with SSH access on port 10022
- **Resource Options**: Shared or performance CPU, configurable memory

### Persistent Volume

- **Mount Point**: `/workspace` (30GB default, auto-extends to 100GB)
- **Retention**: Survives VM restarts and rebuilds
- **Auto-extension**: Grows by 5GB when 80% full
- **Snapshots**: Daily backups retained for 7 days

### SSH Access

- **External Port**: 10022 (non-standard for security)
- **Internal Port**: 2222 (SSH daemon, avoids Fly.io hallpass conflicts)
- **Hallpass Service**: Port 22 (Fly.io's built-in SSH via `flyctl ssh console`)
- **Authentication**: Key-based only (passwords disabled)
- **Root Login**: Disabled for security
- **User**: `developer` with sudo access

## Repository Structure

### Build-time (Repository Files)

Files in this repository used to build and deploy the VM:

```text
├── CLAUDE.md                          # Project instructions for Claude
├── LICENSE                            # MIT license
├── README.md                          # Main documentation
├── Dockerfile                         # Development environment container
├── fly.toml                           # Fly.io configuration with auto-scaling
├── docker/                            # Docker-related configurations
│   ├── config/                        # Configuration files copied to VM
│   ├── context/                       # Context files for AI assistants
│   ├── lib/                           # Shared utility libraries
│   └── scripts/                       # Docker setup scripts
├── scripts/                           # VM management scripts (local)
├── templates/                         # Configuration templates
└── docs/                              # Documentation files
```

### Runtime (VM File System)

File locations after deployment to the VM:

```text
/workspace/                            # Persistent volume mount point
├── developer/                         # User home directory (persistent)
├── projects/                          # Development projects
│   ├── active/                        # Current projects
│   └── archive/                       # Archived projects
├── scripts/                           # VM management scripts
│   ├── lib/                           # Shared utility libraries
│   │   ├── common.sh                  # Common utility functions
│   │   ├── extension-manager.sh       # Extension management CLI
│   │   └── *.sh                       # Other libraries
│   ├── extensions.d/                  # Extension scripts
│   │   ├── active-extensions.conf     # Activation manifest
│   │   └── *.sh.example               # Available extensions
│   └── vm-configure.sh                # Main configuration script
├── config/                            # Configuration files
├── backups/                           # Local backup storage
├── docs/                              # Workspace-wide documentation
│   ├── getting-started.md             # Onboarding guide
│   └── extensions-guide.md            # Extension system reference
└── .config/                           # Application configurations
```

## Storage Architecture

### Persistent Storage (`/workspace`)

- **Size**: 30GB default, auto-extends up to 100GB
- **Contents**: All user data, projects, configurations, caches
- **Persistence**: Survives VM restarts, rebuilds, and suspensions
- **Backup**: Daily snapshots, manual backup scripts available

### Ephemeral Storage

- **Size**: ~8GB system files
- **Contents**: OS, system packages, temporary files
- **Lifecycle**: Rebuilt on container updates

### Memory Management

- **Swap**: 2GB swap space for memory-intensive builds
- **Caches**: npm, pip, and other tool caches stored persistently
- **Memory**: Configurable from 256MB to 8GB+

## Network Architecture

### External Access

- **SSH**: Port 10022 for secure remote access (maps to internal port 2222)
- **Flyctl SSH**: Built-in `flyctl ssh console` via hallpass service (port 22)
- **Domains**: `<app-name>.fly.dev` automatically assigned
- **SSL**: Automatic HTTPS certificates
- **Regions**: Deploy in any [Fly.io region](https://fly.io/docs/reference/regions/)

### Internal Networking

- **Private Network**: Isolated Fly.io private network
- **Service Discovery**: Built-in DNS for service communication
- **Database Connectivity**: Easy attachment of Fly.io databases

## File System Mapping

| Repository Location                                      | VM Runtime Location                                      | Purpose                   |
| -------------------------------------------------------- | -------------------------------------------------------- | ------------------------- |
| `docker/scripts/vm-configure.sh`                         | `/workspace/scripts/vm-configure.sh`                     | Main configuration script |
| `docker/lib/*.sh`                                        | `/workspace/.system/lib/*.sh`                            | Shared utility libraries  |
| `docker/lib/extension-manager.sh`                        | `/workspace/.system/bin/extension-manager`            | Extension management CLI  |
| `docker/lib/extensions.d/*.sh.example`                   | `/workspace/scripts/extensions.d/*.sh.example`           | Available extensions      |
| `docker/lib/.system/manifest/active-extensions.conf.example` | `/workspace/scripts/.system/manifest/active-extensions.conf` | Activation manifest       |
| `docker/config/*`                                        | Various VM locations                                     | Configuration files       |

## Development Workflow Architecture

### Initial Deployment

1. **Build**: Docker image built from repository
2. **Deploy**: VM created on Fly.io with persistent volume
3. **Configure**: SSH keys, networking, and basic setup
4. **Provision**: One-time environment setup script

### Daily Development

1. **Connect**: SSH or IDE remote development connection
2. **Auto-resume**: VM starts automatically on connection
3. **Develop**: Full development environment with AI tools
4. **Auto-suspend**: VM suspends when idle to save costs

### Data Flow

```text
Local IDE ←→ SSH (port 10022) ←→ Fly.io VM (SSH daemon on 2222) ←→ Persistent Volume
    ↑              ↓                    ↓ (hallpass on 22)                    ↓
Claude Code/Flow   flyctl ssh console   API Keys (Fly secrets) ←→ Project Files
```

## Auto-scaling Configuration

### Scale-to-Zero

- **Idle Detection**: VM suspends after configurable timeout
- **Wake-up**: Automatic resume on SSH connection or HTTP request
- **State Preservation**: All data preserved during suspension

### Resource Scaling

- **CPU**: Shared or performance CPUs
- **Memory**: Dynamic allocation based on workload
- **Storage**: Auto-extending volumes based on usage

## Extension System Architecture

Sindri uses **Extension API v1.0** with manifest-based activation for managing development tools and environments.

### Extension Lifecycle

1. **Discovery**: Extension scripts stored as `.sh.example` files in `/workspace/scripts/extensions.d/`
2. **Installation**: Users install extensions via `extension-manager install <name>` which auto-activates and installs
3. **Manifest Processing**: The `active-extensions.conf` file controls which extensions install and their execution order
4. **API Execution**: `install` command runs the extension's API functions in sequence:
   - `prerequisites()` - Check system requirements
   - `install()` - Install packages and tools
   - `configure()` - Post-installation configuration
5. **Validation**: `extension-manager validate <name>` runs smoke tests via the `validate()` function
6. **Status Tracking**: Each extension implements `status()` and `remove()` for lifecycle management

### Extension Categories

Extensions are organized by capability:

- **Language Tools**: nodejs, python, rust, golang, ruby, php, dotnet, jvm
- **Infrastructure**: docker, infra-tools (Terraform, Ansible, kubectl)
- **Cloud Platforms**: cloud-tools (AWS, Azure, GCP CLIs)
- **AI Development**: ai-tools, claude, agent-manager
- **Development Tools**: nodejs-devtools, playwright, monitoring
- **Workspace Tools**: workspace-structure, ssh-environment, tmux-workspace

## Security Architecture

### Network Security

- **Firewall**: Only SSH port 10022 exposed externally
- **Dual SSH Access**: Custom SSH daemon (port 2222) + Fly.io hallpass (port 22)
- **Network Isolation**: Fly.io private networking
- **DDoS Protection**: Built-in Fly.io protection
- **Regional Isolation**: Deploy in specific regions

### Authentication

- **SSH Keys**: Required for access
- **API Keys**: Stored as Fly.io secrets
- **No Passwords**: Password authentication disabled
- **Sudo Access**: Limited to `developer` user

### Data Security

- **Encrypted Transit**: All connections over SSH/TLS
- **Volume Encryption**: Available for sensitive data
- **Backup Encryption**: Snapshot encryption options
- **Secret Management**: Fly.io secrets for API keys

## Cost Optimization Architecture

### Billing Model

- **Compute**: Per-second billing when running
- **Storage**: Monthly charge for persistent volumes
- **Network**: Egress charges for data transfer
- **Scale-to-zero**: No compute charges when suspended

### Optimization Strategies

- **Auto-suspend**: Minimize active time
- **Right-sizing**: Match resources to workload
- **Regional Choice**: Select cost-effective regions
- **Volume Management**: Monitor and optimize storage usage

This architecture provides a secure, scalable, and cost-effective remote development environment optimized for
AI-assisted development workflows.
