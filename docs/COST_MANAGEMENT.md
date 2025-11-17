# Cost Management

## Cost Structure

Understanding Fly.io's billing model helps optimize Sindri's infrastructure costs.

### Billing Components

#### Compute Resources

- **Per-second billing** when VM is running
- **Scale-to-zero**: No compute charges when suspended
- **CPU Types**: Shared (cheaper) vs Performance (dedicated)
- **Memory**: Billed per GB allocated

#### Storage

- **Persistent Volumes**: Monthly charge regardless of VM state
- **Snapshots**: Additional charge for backup retention
- **Network**: Egress charges for data transfer

## Cost Estimates

### Resource Tier-Based Estimates

Sindri uses a 4-tier resource classification system. Here are cost estimates for each tier:

**Minimal Tier** (1x shared-cpu, 1GB RAM, 10GB storage)

- **Use Case**: Lightweight utilities (tmux, monitoring, agent-manager, context-loader, github-cli)
- VM running 10% time: ~$2.10/month
- VM running 25% time: ~$3.25/month
- VM running 50% time: ~$5.75/month
- VM running 100% time: ~$10.75/month

**Standard Tier** (2x shared-cpu, 4GB RAM, 20GB storage)

- **Use Case**: Standard packages (nodejs, python, golang, php, playwright, claude-marketplace)
- VM running 10% time: ~$5.50/month
- VM running 25% time: ~$10.25/month
- VM running 50% time: ~$19.00/month
- VM running 100% time: ~$36.50/month

**Heavy Tier** (4x performance-cpu, 8GB RAM, 20GB storage)

- **Use Case**: Compilation & containers (rust, ruby, jvm, dotnet, docker, infra-tools, cloud-tools, ai-tools)
- VM running 25% time: ~$38.75/month
- VM running 50% time: ~$76.00/month
- VM running 100% time: ~$150.50/month

**XHeavy Tier** (4x performance-cpu, 16GB RAM, 30GB storage)

- **Use Case**: Desktop environments & multiple extensions (xfce-ubuntu, guacamole, extension-combinations)
- VM running 25% time: ~$60.50/month
- VM running 50% time: ~$119.50/month
- VM running 100% time: ~$237.50/month

### CI/CD Testing Costs

Test workflows use resource tiers dynamically based on extension requirements:

- **Minimal tier tests**: ~$0.05 per test run (15-20 min)
- **Standard tier tests**: ~$0.12 per test run (15-25 min)
- **Heavy tier tests**: ~$0.45 per test run (20-30 min)
- **XHeavy tier tests**: ~$0.90 per test run (60-90 min)

**Monthly CI estimates** (based on typical usage):

- 100 commits/month with per-extension tests: ~$45-60/month
- Weekly comprehensive tests (4 runs/month): ~$8-12/month
- **Total estimated CI costs**: ~$55-75/month

### Cost Optimization Benefits

Using resource tiers provides significant cost savings:

- **Minimal tier** (5 extensions): 87% cheaper than heavy tier
- **Standard tier** (8 extensions): 75% cheaper than heavy tier
- **Heavy tier** (8 extensions): Right-sized for compilation/containers
- **XHeavy tier** (3 extensions): Reserved for desktop environments only

**Estimated monthly CI savings**: ~40-50% compared to using heavy tier for all extensions

_Estimates include compute + storage + egress. Actual costs may vary based on usage patterns and region._

## Automatic Cost Optimization

### Auto-suspend Configuration

The VM automatically suspends when idle to minimize costs:

```toml
# fly.toml configuration
[services.auto_stop_machines]
enabled = true

[services.auto_start_machines]
enabled = true
```

#### Idle Detection

- SSH connection monitoring
- HTTP request detection
- Configurable timeout periods
- Graceful shutdown process

#### Resume Triggers

- SSH connection attempts
- HTTP requests
- Fly.io wake-up calls
- Scheduled tasks

### Scale-to-Zero Benefits

- **Zero compute costs** when not developing
- **Persistent data** remains available
- **Instant resume** on connection
- **No manual intervention** required

## Manual Cost Control

### VM Lifecycle Management

**Suspend VM manually:**

```bash
./scripts/vm-suspend.sh
# Stops the VM immediately to save costs
```

**Resume VM:**

```bash
./scripts/vm-resume.sh
# Starts the VM when you're ready to develop
```

**Check VM status:**

```bash
flyctl status -a my-sindri-dev
flyctl machine list -a my-sindri-dev
```

### Resource Optimization

**Scale down for light work:**

```bash
flyctl scale memory 256 -a my-sindri-dev
flyctl scale count 1 -a my-sindri-dev
```

**Scale up for intensive tasks:**

```bash
flyctl scale memory 8192 -a my-sindri-dev
flyctl scale count 2 -a my-sindri-dev
```

**Monitor resource usage:**

```bash
flyctl metrics -a my-sindri-dev
```

## Cost Monitoring

### Usage Tracking Script

The built-in cost monitoring script provides detailed usage analytics:

```bash
# Check current status and estimated costs (default)
./scripts/cost-monitor.sh

# View historical usage patterns
./scripts/cost-monitor.sh --action history

# Export usage data for analysis
./scripts/cost-monitor.sh --action export --export-format csv --export-file usage.csv
```

**Monitoring Features:**

- Real-time cost estimates
- Usage pattern analysis
- Resource utilization metrics
- Cost trend projections
- Budget alerts and warnings

### Fly.io Dashboard

- **Usage Metrics**: CPU, memory, and network utilization
- **Billing History**: Detailed cost breakdown
- **Resource Allocation**: Current and historical configurations
- **Budget Alerts**: Set spending limits and notifications

## Storage Cost Optimization

### Volume Management

**Monitor storage usage:**

```bash
# On the VM
df -h /workspace
du -sh /workspace/*
```

**Archive old projects:**

```bash
# Move to archive directory
mv /workspace/projects/active/old-project /workspace/projects/archive/

# Or create backup then manually remove
./scripts/volume-backup.sh
# After backup completes, remove old projects manually
rm -rf /workspace/projects/active/old-project
```

### Backup Strategy

**Efficient backup schedule:**

- **Daily**: Critical project files only
- **Weekly**: Full workspace backup
- **Monthly**: Archive and compress old backups

```bash
# Standard backup (creates compressed tar.gz)
./scripts/volume-backup.sh

# Available backup actions:
./scripts/volume-backup.sh --action backup   # Default backup
./scripts/volume-backup.sh --action sync     # Sync workspace data
./scripts/volume-backup.sh --action list     # List existing backups
./scripts/volume-backup.sh --action cleanup --keep 3  # Keep only 3 most recent
```

## Team Cost Management

### Shared VM Strategy

Multiple developers sharing one VM:

**Benefits:**

- Split costs among team members
- Shared development environment
- Centralized tool management

**Considerations:**

- Resource contention during peak usage
- Coordination for major updates
- Security and access management

### Individual VM Strategy

Separate VMs for each developer:

**Benefits:**

- Isolated development environments
- Independent resource scaling
- Personal customization freedom

**Cost Optimization:**

- Standardized VM configurations
- Shared backup storage
- Team-wide monitoring dashboard

## Advanced Cost Strategies

### Multi-region Deployment

Deploy VMs in cost-effective regions:

```bash
# List regions and pricing
flyctl platform regions

# Deploy in cheaper regions
./scripts/vm-setup.sh --region lax  # Los Angeles
./scripts/vm-setup.sh --region ord  # Chicago
```

### Scheduled Scaling

Automatically scale based on development schedules:

```bash
# Scale up during work hours (9 AM)
echo "0 9 * * 1-5 /usr/local/bin/flyctl scale memory 2048 -a my-sindri-dev" | crontab

# Scale down after hours (6 PM)
echo "0 18 * * 1-5 /usr/local/bin/flyctl scale memory 256 -a my-sindri-dev" | crontab
```

### Resource Right-sizing

Monitor and optimize resource allocation:

1. **Baseline Monitoring**: Track usage for 1-2 weeks
2. **Identify Patterns**: Find peak and minimum resource needs
3. **Optimize Configuration**: Right-size CPU and memory
4. **Continuous Monitoring**: Adjust based on workload changes

### AI Model Cost Optimization with agent-flow

agent-flow enables dramatic cost reduction by intelligently routing tasks to optimal models across multiple providers.

#### Cost Comparison

**Traditional approach** (Claude Sonnet 4 only):

- $3.00 per million input tokens
- $15.00 per million output tokens
- Average task: ~$0.50

**agent-flow approach** (intelligent routing):

- Route simple tasks to Llama 3.1 8B: $0.06/$0.06 per million tokens
- Route complex tasks to Claude: $3.00/$15.00 per million tokens
- **Cost savings: 85-99%** depending on task mix

#### Available Providers

1. **OpenRouter** - 100+ models with flexible pricing
   - Ultra-low-cost models (Llama, Mistral): ~$0.06-0.20 per million tokens
   - Mid-tier models: ~$0.50-2.00 per million tokens
   - Premium models: Available when quality matters

2. **Google Gemini** - Free tier available
   - Gemini 1.5 Flash: Free tier with rate limits
   - Gemini 1.5 Pro: Paid tier for production

3. **Anthropic Claude** - Default high-quality option
   - Use for complex reasoning and critical tasks
   - agent-flow automatically selects when quality justifies cost

#### Setup for Cost Optimization

```bash
# Set up OpenRouter for cost savings
flyctl secrets set OPENROUTER_API_KEY=sk-or-... -a <app-name>

# Optional: Gemini free tier
flyctl secrets set GOOGLE_GEMINI_API_KEY=... -a <app-name>

# On VM, use cost-optimized commands
af-cost "Simple task"                    # Use cheapest suitable model
af-openrouter "Build feature"            # Use OpenRouter
af-llama "Generate documentation"        # Specific low-cost model
```

#### Optimization Strategy

**Task-based routing:**

- **Documentation/boilerplate**: Use ultra-low-cost models (~95% savings)
- **Code review/analysis**: Use mid-tier models (~70% savings)
- **Complex refactoring**: Use Claude (quality priority)

**Example workflow:**

```bash
# Generate docs with low-cost model
af-cost "Generate API documentation from code comments"

# Review with mid-tier model
af-reviewer "Check for security issues"

# Complex task with Claude
af-claude "Refactor authentication system with OAuth2"
```

#### Monitoring AI Costs

Track model usage and costs:

```bash
# Check current provider configuration
af-help

# Review available models and pricing
# Visit https://openrouter.ai/models for real-time pricing
```

#### Best Practices

1. **Start cheap**: Use `af-cost` by default, escalate when needed
2. **Batch tasks**: Group similar operations to one model/provider
3. **Mix providers**: Don't lock into single vendor
4. **Monitor quality**: Validate output quality vs. cost savings
5. **Free tier first**: Exhaust Gemini free tier before paid options

#### Cost Example

**Monthly AI usage scenario:**

- 100 documentation tasks: $0.50 (was $50 with Claude only)
- 50 code reviews: $5.00 (was $25)
- 20 complex refactorings: $10.00 (Claude, quality matters)
- **Total: $15.50/month** (was $75/month) = **79% savings**

Combined with VM auto-suspend, total environment cost < $25/month for full AI-assisted development.

## Budget Planning

### Monthly Budget Calculation

**Fixed Costs:**

- Persistent volume: `$volume_size_gb * $0.15`
- Snapshots: `$snapshot_count * $0.02`

**Variable Costs:**

- Compute: `$hourly_rate * $hours_running * $days_per_month`
- Egress: `$gb_transferred * $0.02`

**Cost Monitoring:**

```bash
# Get current costs and optimization recommendations
./scripts/cost-monitor.sh
```

### Manual Cost Tracking

Cost monitoring provides recommendations but no automated alerts:

```bash
# Regular monitoring (run weekly)
./scripts/cost-monitor.sh

# Export data for your own tracking
./scripts/cost-monitor.sh --action export --export-format csv --export-file monthly_costs.csv
```

## Cost Troubleshooting

### Unexpected High Costs

**Common Causes:**

- VM not suspending (check auto-suspend configuration)
- High network egress (large file transfers)
- Resource over-allocation (too much CPU/memory)
- Multiple VMs running simultaneously

**Investigation Steps:**

1. Check VM status: `flyctl machine list -a my-sindri-dev`
2. Review resource usage: `flyctl metrics -a my-sindri-dev`
3. Analyze billing: Fly.io dashboard billing section
4. Monitor traffic: Check egress patterns

**Quick Fixes:**

```bash
# Force suspend all machines
flyctl machine stop --all -a my-sindri-dev

# Reset to minimal configuration
flyctl scale memory 256 -a my-sindri-dev
flyctl scale count 1 -a my-sindri-dev

# Review current costs and get recommendations
./scripts/cost-monitor.sh
```

By following these cost management strategies, you can maintain a powerful AI-assisted development environment
while keeping expenses predictable and optimized.
