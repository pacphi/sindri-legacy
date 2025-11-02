# Sindri Setup Guide

Advanced setup topics not covered in [Quick Start](QUICKSTART.md).

## Cost Overview

The environment is designed to minimize costs through auto-suspend capabilities. See the
[Cost Management Guide](COST_MANAGEMENT.md) for detailed pricing information, configuration options, and optimization
strategies.

**Key cost-saving features:**

- VMs auto-suspend when idle (no compute charges)
- Persistent volumes maintain data while suspended
- Scale-to-zero configuration available
- Resource monitoring scripts included

## Advanced Configuration

### Custom VM Resources

```bash
# Deploy with custom resources
# Consult https://fly.io/docs/reference/regions/ for available regions
./scripts/vm-setup.sh \
  --app-name my-dev \
  --cpu-kind performance \
  --cpu-count 2 \
  --memory 4096 \
  --volume-size 50 \
  --region sjc
```

### API Keys and Secrets

```bash
# Set during or after deployment
flyctl secrets set ANTHROPIC_API_KEY="sk-ant-..." -a <app-name>
flyctl secrets set GITHUB_TOKEN="ghp_..." -a <app-name>
flyctl secrets set PERPLEXITY_API_KEY="pplx-..." -a <app-name>
```

## Team Setup

### Shared VM Access

```bash
# Add multiple SSH keys
flyctl secrets set AUTHORIZED_KEYS="$(cat key1.pub key2.pub key3.pub)" -a <app-name>

# Team members connect to same VM
ssh developer@team-sindri-dev.fly.dev -p 10022
```

### Individual VMs

Each team member deploys their own VM:

```bash
./scripts/vm-setup.sh --app-name alice-sindri-dev
./scripts/vm-setup.sh --app-name bob-sindri-dev
```

Use volume snapshots to share data between VMs when needed.

## Resource Management

### Monitoring

```bash
# Check resource usage
./scripts/cost-monitor.sh

# VM lifecycle
./scripts/vm-suspend.sh
./scripts/vm-resume.sh
```

### Scaling

```bash
# Increase memory
flyctl scale memory 4096 -a <app-name>

# Change CPU type
flyctl machine update <machine-id> --vm-size performance-2x -a <app-name>

# Extend volume
flyctl volumes extend <volume-id> -s 50 -a <app-name>
```

## Backup and Recovery

### Volume Snapshots

```bash
# Create backup
./scripts/volume-backup.sh

# Restore from backup
./scripts/volume-restore.sh
```

### Data Export

```bash
# On VM - backup critical data
/workspace/scripts/backup.sh

# Creates: /workspace/backups/backup_YYYYMMDD_HHMMSS.tar.gz
```

## SSH Access

Sindri provides two SSH connection methods:

### Primary: Regular SSH (Port 10022)

```bash
ssh developer@<app-name>.fly.dev -p 10022
```

**Use this for:**

- Daily development work
- Running extension-manager commands
- IDE remote development
- All normal operations

**Automatically connects as developer user** - no flags needed.

### Fallback: flyctl ssh console

```bash
# For system troubleshooting (as root)
flyctl ssh console -a <app-name>

# For extension/dev work (as developer)
flyctl ssh console -a <app-name> --user developer
```

**Use this only when:**

- Port 10022 SSH is not working
- Emergency access needed
- System-level debugging required

**Important:** The `--user developer` flag is critical when running extension commands via flyctl, otherwise extensions install to root's home directory.

See [SSH Connection Methods](TROUBLESHOOTING.md#understanding-ssh-connection-methods) for complete details.

## Security

### SSH Configuration

Key-based authentication is enforced by default:

- Password authentication disabled
- Root login disabled
- SSH on non-standard port 10022
- Custom SSH daemon via `ssh-environment` extension

### Network Security

VMs are isolated in Fly.io private networking with no inbound HTTP access except SSH.

## Troubleshooting

### VM Issues

```bash
flyctl status -a <app-name>           # Check VM health
flyctl logs -a <app-name>             # View logs
flyctl machine restart <id>           # Restart VM
```

### Storage Issues

```bash
df -h /workspace                      # Check disk usage
flyctl volumes list -a <app-name>     # Check volume status
```

For comprehensive troubleshooting, see the [Troubleshooting Guide](TROUBLESHOOTING.md).

## Next Steps

- **Quick deployment**: [Quick Start Guide](QUICKSTART.md)
- **Customization**: [Customization Guide](CUSTOMIZATION.md)
- **IDE setup**: [IDE Setup Guide](IDE_SETUP.md), then [VSCode](VSCODE.md) or [IntelliJ](INTELLIJ.md)
- **Cost optimization**: [Cost Management](COST_MANAGEMENT.md)
