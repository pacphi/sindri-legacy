# XFCE Ubuntu Desktop Extension

Complete guide for installing and using a full desktop environment on Sindri with remote desktop access via xRDP.

## Overview

The `xfce-ubuntu` extension installs:

- **XFCE 4 Desktop Environment** - Lightweight, fast, and feature-rich
- **xRDP Server** - Remote Desktop Protocol server for remote access
- **Essential Desktop Applications** - Firefox, file manager, text editor
- **Optimized Configuration** - Tuned for remote desktop performance

## Table of Contents

- [Quick Start](#quick-start)
- [System Requirements](#system-requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Connecting](#connecting)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)
- [Performance Tuning](#performance-tuning)
- [Security Considerations](#security-considerations)
- [Uninstallation](#uninstallation)

---

## Quick Start

```bash
# 1. Install the extension
extension-manager install xfce-ubuntu

# 2. Add RDP service to fly.toml
cat >> fly.toml << 'EOF'

[[services]]
  internal_port = 3389
  protocol = "tcp"

  [[services.ports]]
    port = 3389
EOF

# 3. Redeploy
flyctl deploy -a your-app-name

# 4. Connect with RDP client
# Address: your-app.fly.dev:3389
# Username: developer (or your username)
# Password: (your password)
```

---

## System Requirements

### Minimum Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **RAM** | 1GB | 2GB+ |
| **Disk** | 3GB free | 5GB+ free |
| **CPU** | 1 core | 2+ cores |
| **VM Size** | shared-cpu-1x | shared-cpu-2x |
| **Cost** | $3-5/month | $15-30/month |

### Fly.io VM Sizing

```bash
# Check current VM size
flyctl scale show -a your-app-name

# Upgrade to shared-cpu-2x (recommended)
flyctl scale vm shared-cpu-2x -a your-app-name

# For better performance, consider dedicated CPU
flyctl scale vm dedicated-cpu-1x -a your-app-name
```

### Network Requirements

- Inbound TCP port 3389 (RDP)
- Outbound HTTPS (for package downloads during install)

---

## Installation

### Prerequisites Check

The extension automatically checks:

- Ubuntu/Debian system (required)
- Not running in CI mode
- Sufficient disk space (2.5GB+)
- Required tools (curl, wget, systemctl)

### Installation Process

```bash
# Install the extension
extension-manager install xfce-ubuntu
```

**Installation Time:** 5-10 minutes

**What Gets Installed:**

1. XFCE desktop environment (~800MB)
2. xRDP server
3. Desktop applications:
   - Firefox web browser
   - Mousepad text editor
   - Thunar file manager
   - Terminal emulator
4. Supporting libraries and fonts

### Verify Installation

```bash
# Check installation status
extension-manager status xfce-ubuntu

# Verify xRDP service
sudo systemctl status xrdp

# Check port binding
ss -tln | grep 3389
```

---

## Configuration

### Automatic Configuration

The extension automatically:

- Creates `~/.xsession` to start XFCE
- Adds user to `xrdp` group
- Enables and starts xRDP service
- Creates desktop directories (Desktop, Documents, Downloads)
- Disables compositing for better RDP performance

### fly.toml Configuration

Add RDP service to your `fly.toml`:

```toml
# Add this to your existing fly.toml

[[services]]
  internal_port = 3389
  protocol = "tcp"

  [[services.ports]]
    port = 3389
    # No handlers for TCP port
```

**Important:** You must redeploy after modifying `fly.toml`:

```bash
flyctl deploy -a your-app-name
```

### Setting User Password

If you haven't set a password yet:

```bash
# SSH into your VM
ssh developer@your-app.fly.dev -p 10022

# Set password
passwd
```

### Custom XFCE Configuration

XFCE settings are stored in `~/.config/xfce4/`. Customize:

**Panel Settings:**

```bash
# Edit panel configuration
mousepad ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
```

**Window Manager:**

```bash
# Edit window manager settings
mousepad ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
```

**Keyboard Shortcuts:**

```bash
# Edit keyboard shortcuts
mousepad ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
```

---

## Connecting

### Windows

**Built-in Remote Desktop Connection:**

1. Press `Win + R`
2. Type `mstsc` and press Enter
3. Enter computer name: `your-app.fly.dev:3389`
4. Click "Connect"
5. Enter credentials:
   - Username: `developer`
   - Password: (your password)

**Connection Settings for Better Performance:**

- Experience tab: Select "LAN (10 Mbps or higher)"
- Display tab: Reduce color depth to "High Color (16 bit)"
- Display tab: Reduce resolution if needed

### macOS

**Microsoft Remote Desktop (from App Store):**

1. Download "Microsoft Remote Desktop" from App Store
2. Click "Add PC"
3. Configure:
   - PC name: `your-app.fly.dev`
   - Port: `3389`
   - User account: Add with username `developer`
4. Double-click to connect

**Connection Options:**

- Preferences → Display: Adjust resolution
- Preferences → Session: Configure reconnection settings

### Linux

**Remmina (recommended):**

```bash
# Install Remmina
sudo apt-get install remmina remmina-plugin-rdp

# Launch and create new connection
remmina
```

**Connection Settings:**

- Protocol: RDP
- Server: `your-app.fly.dev:3389`
- Username: `developer`
- Color depth: RemoteFX (32 bpp)

**Alternative: rdesktop:**

```bash
# Install rdesktop
sudo apt-get install rdesktop

# Connect
rdesktop -u developer -g 1920x1080 your-app.fly.dev:3389
```

---

## Usage Examples

### Development with GUI Tools

**Running VS Code in Desktop:**

```bash
# In RDP session, open terminal
wget -O code.deb 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64'
sudo dpkg -i code.deb
sudo apt-get install -f  # Fix dependencies

# Launch VS Code
code
```

**Using Firefox for Testing:**

```bash
# Firefox is pre-installed
firefox &

# Or use Chromium
sudo apt-get install chromium-browser
chromium-browser --no-sandbox &
```

### Visual Development Workflows

**Playwright Visual Testing:**

```bash
# In desktop terminal
cd /workspace/projects/active/my-project
npx playwright test --headed --debug
```

**Database GUI Tools:**

```bash
# Install DBeaver
wget -O dbeaver.deb https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb
sudo dpkg -i dbeaver.deb
dbeaver &
```

### File Management

**Transfer Files via RDP:**

- Windows: Enable drive redirection in RDP settings
- macOS: Use Microsoft Remote Desktop's folder sharing
- Linux: Use Remmina's folder sharing feature

**Alternative: Use SFTP:**

```bash
# From local machine
sftp -P 10022 developer@your-app.fly.dev
put localfile.txt /workspace/
```

---

## Troubleshooting

### Cannot Connect via RDP

**Check xRDP Service:**

```bash
# SSH into VM
ssh developer@your-app.fly.dev -p 10022

# Check service status
sudo systemctl status xrdp

# Restart if needed
sudo systemctl restart xrdp

# Check logs
sudo tail -f /var/log/xrdp.log
sudo tail -f /var/log/xrdp-sesman.log
```

**Verify Port Configuration:**

```bash
# Check port is bound
ss -tln | grep 3389

# Check fly.toml has RDP service
cat /app/fly.toml | grep 3389

# Verify with flyctl
flyctl status -a your-app-name
```

**Test Local Connection:**

```bash
# From within the VM (via SSH)
sudo apt-get install xrdp-client
xfreerdp /v:localhost /u:developer
```

### Black Screen on Login

**Cause:** Session configuration issue

**Fix:**

```bash
# Recreate .xsession
echo "startxfce4" > ~/.xsession
chmod +x ~/.xsession

# Restart xRDP
sudo systemctl restart xrdp
```

### Slow Performance

**Optimize RDP Client Settings:**

- Reduce screen resolution (1280x720 instead of 1920x1080)
- Lower color depth (16-bit instead of 32-bit)
- Disable desktop background
- Disable animations

**Check VM Resources:**

```bash
# Check RAM usage
free -h

# Check CPU usage
top

# Consider upgrading VM size
flyctl scale vm shared-cpu-2x -a your-app-name
```

### Authentication Failures

**Reset Password:**

```bash
# SSH into VM
ssh developer@your-app.fly.dev -p 10022

# Change password
passwd

# Verify user is in xrdp group
groups
# Should include "xrdp"

# If not, add manually
sudo usermod -aG xrdp $USER
# Then logout/login or reboot
```

### Connection Drops Frequently

**Increase RDP Timeout:**

```bash
# Edit xRDP configuration
sudo mousepad /etc/xrdp/xrdp.ini

# Find and modify:
MaxLoginRetry=4
MaxDisconnectionTime=0  # Never timeout
IdleTimeout=0           # Never timeout

# Restart xRDP
sudo systemctl restart xrdp
```

---

## Performance Tuning

### XFCE Optimization

**Disable Compositing (already done by extension):**

```bash
# Settings → Window Manager Tweaks → Compositor
# Uncheck "Enable display compositing"
```

**Reduce Visual Effects:**

```bash
# Settings → Appearance → Style
# Select "Kokodi" or other lightweight theme

# Settings → Window Manager → Style
# Select "Default" theme
```

**Disable Desktop Icons:**

```bash
# Right-click desktop → Desktop Settings
# Icons tab → Icon type → None
```

### xRDP Optimization

**Edit `/etc/xrdp/xrdp.ini`:**

```ini
[Globals]
# Increase performance
max_bpp=16
# Use fast compression
crypt_level=low
# Disable encryption for local testing (NOT for production)
security_layer=rdp
```

**Restart after changes:**

```bash
sudo systemctl restart xrdp
```

### Network Optimization

**Use Fly.io Private Networking (if you have multiple VMs):**

```toml
# fly.toml
[[services]]
  internal_port = 3389
  protocol = "tcp"

  [[services.ports]]
    port = 3389
    # Optionally restrict to private network
```

**Use WireGuard VPN for Better Performance:**

```bash
# On your local machine
flyctl wireguard create

# Connect via private IPv6 address
# Provides lower latency and better throughput
```

---

## Security Considerations

### Password Security

**Use Strong Passwords:**

```bash
# Set a strong password (12+ characters, mixed case, numbers, symbols)
passwd

# Or use passphrase
```

**Consider SSH Key-Based Auth:**
While xRDP requires passwords, you can:

- Use SSH tunneling (see below)
- Set up fail2ban for brute-force protection

### Network Security

**Restrict RDP Access by IP (Fly.io doesn't support this directly):**

Use SSH tunneling instead:

```bash
# Local machine: Create SSH tunnel
ssh -L 3389:localhost:3389 developer@your-app.fly.dev -p 10022

# Then connect RDP to localhost:3389
# This encrypts ALL traffic through SSH
```

**Install fail2ban:**

```bash
# In the VM
sudo apt-get install fail2ban

# Configure for xRDP
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo mousepad /etc/fail2ban/jail.local

# Add:
[xrdp]
enabled = true
port = 3389
filter = xrdp
logpath = /var/log/xrdp.log
maxretry = 5

# Restart fail2ban
sudo systemctl restart fail2ban
```

### TLS/SSL Encryption

xRDP includes TLS encryption by default. Verify:

```bash
# Check xRDP configuration
grep "security_layer" /etc/xrdp/xrdp.ini

# Should be:
# security_layer=negotiate  # or tls
```

### Audit Access

**Monitor RDP Logins:**

```bash
# View xRDP connection logs
sudo tail -f /var/log/xrdp-sesman.log

# View authentication attempts
sudo tail -f /var/log/auth.log | grep xrdp
```

---

## Uninstallation

### Remove Extension

```bash
# Uninstall the extension
extension-manager remove xfce-ubuntu
```

This will:

1. Stop and disable xRDP service
2. Remove XFCE desktop packages (~800MB)
3. Remove desktop applications (Firefox, etc.)
4. Optionally remove configuration files
5. Optionally remove desktop directories

### Remove fly.toml Configuration

```bash
# Edit fly.toml and remove RDP service block:
# [[services]]
#   internal_port = 3389
#   ...

# Redeploy
flyctl deploy -a your-app-name
```

### Clean Up User Data

If you want to completely remove all desktop-related data:

```bash
# Remove XFCE configuration
rm -rf ~/.config/xfce4

# Remove desktop directories
rm -rf ~/Desktop ~/Documents ~/Downloads

# Remove .xsession
rm ~/.xsession
```

---

## Comparison with Other Options

### vs. X11 Forwarding

| Aspect | XFCE + xRDP | X11 Forwarding |
|--------|-------------|----------------|
| Setup | Medium complexity | Simple |
| Resource Usage | High (~800MB+) | Low (per-app) |
| Performance | Good (persistent) | Variable (network) |
| Use Case | Full desktop | Individual apps |
| Cost | Higher VM needed | No extra cost |

**Choose XFCE + xRDP when:**

- You need a persistent desktop session
- You use multiple GUI apps regularly
- You prefer traditional desktop workflow

**Choose X11 Forwarding when:**

- You only need GUI occasionally
- You want minimal resource usage
- You're comfortable with SSH

### vs. Guacamole

| Aspect | XFCE + xRDP | Guacamole |
|--------|-------------|-----------|
| Client | RDP app required | Browser only |
| Setup | Medium | Complex |
| Performance | Better | Good |
| Access | Traditional RDP | Web-based |
| Management | Simple | User accounts needed |

**Choose XFCE + xRDP when:**

- You have an RDP client available
- You want better performance
- You prefer simpler setup

**Choose Guacamole when:**

- You need browser-only access
- You access from varied devices
- You manage multiple users/connections

---

## Additional Resources

- [XFCE Documentation](https://docs.xfce.org/)
- [xRDP Documentation](https://github.com/neutrinolabs/xrdp/wiki)
- [Fly.io Network Configuration](https://fly.io/docs/reference/configuration/)
- [GUI Access Options Overview](GUI_ACCESS_OPTIONS.md)
- [X11 Forwarding Alternative](X11_FORWARDING_GUIDE.md)

---

## Feedback and Issues

If you encounter issues with the `xfce-ubuntu` extension:

1. Check the [Troubleshooting](#troubleshooting) section
2. View extension logs: `extension-manager status xfce-ubuntu`
3. Report issues in the Sindri repository

---

**Last Updated:** 2025-01-11
**Extension Version:** 1.0.0
**Compatible with:** Sindri Extension API v2.0
