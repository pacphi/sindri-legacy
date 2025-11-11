# Apache Guacamole Extension

Complete guide for installing and using Apache Guacamole, a clientless remote desktop gateway that provides
browser-based access to SSH, RDP, and VNC protocols.

## Overview

The `guacamole` extension installs:

- **guacd** - Guacamole proxy daemon
- **Tomcat 9** - Java web application server
- **Guacamole Web Application** - Browser-based interface
- **Protocol Support** - RDP, SSH, VNC via FreeRDP and libVNC
- **User Authentication** - XML-based user management (basic setup)

## Table of Contents

- [Quick Start](#quick-start)
- [System Requirements](#system-requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Accessing Guacamole](#accessing-guacamole)
- [User Management](#user-management)
- [Connection Configuration](#connection-configuration)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)
- [Security](#security)
- [Upgrade](#upgrade)
- [Uninstallation](#uninstallation)

---

## Quick Start

```bash
# 1. Install the extension (takes 10-15 minutes)
extension-manager install guacamole

# 2. Add HTTP service to fly.toml
cat >> fly.toml << 'EOF'

[[services]]
  internal_port = 8080
  protocol = "tcp"

  [[services.ports]]
    port = 80
    handlers = ["http"]

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]
EOF

# 3. Redeploy
flyctl deploy -a your-app-name

# 4. Access Guacamole in browser
# https://your-app.fly.dev/guacamole
# Username: guacadmin
# Password: guacadmin

# 5. IMMEDIATELY change the default password!
```

---

## System Requirements

### Minimum Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **RAM** | 768MB | 1GB+ |
| **Disk** | 1.5GB free | 2GB+ free |
| **CPU** | 1 core | 2+ cores |
| **VM Size** | shared-cpu-1x | shared-cpu-2x |
| **Cost** | $3-5/month | $15-30/month |

### Software Requirements

- Ubuntu/Debian Linux
- Java Runtime (installed automatically)
- Build tools (installed automatically)
- Network access to download Apache Guacamole packages

### Network Requirements

- Inbound HTTP/HTTPS (ports 80/443)
- Outbound HTTPS for downloads
- Access to protocols you want to proxy (SSH, RDP, VNC)

---

## Installation

### Prerequisites Check

The extension automatically verifies:

- Ubuntu/Debian system
- Not running in CI mode
- Sufficient disk space (1GB+)
- Required build tools available
- DNS resolution to Apache download servers

### Installation Process

```bash
# Install the extension
extension-manager install guacamole
```

**Installation Time:** 10-15 minutes

**What Gets Installed:**

1. **Build Dependencies** (~200MB):
   - Compiler toolchain (gcc, make)
   - Graphics libraries (cairo, JPEG, PNG)
   - Protocol libraries (FreeRDP, libVNC, libSSH)

2. **guacamole-server** (built from source):
   - guacd proxy daemon
   - Protocol plugins (RDP, SSH, VNC)

3. **Tomcat 9** (~50MB):
   - Java application server
   - Admin tools

4. **guacamole-client** (WAR file):
   - Web application (~20MB)
   - JavaScript remote desktop client

### Post-Installation

The extension automatically:

- Creates `/etc/guacamole/` configuration directory
- Generates default `guacamole.properties`
- Creates `user-mapping.xml` with default admin user
- Configures systemd service for guacd
- Deploys web application to Tomcat
- Starts all services

### Verify Installation

```bash
# Check installation status
extension-manager status guacamole

# Verify guacd daemon
sudo systemctl status guacd

# Verify Tomcat
sudo systemctl status tomcat9

# Check services are listening
ss -tln | grep -E '4822|8080'
```

---

## Configuration

### Automatic Configuration

Default setup includes:

**guacd Configuration** (`/etc/guacamole/guacamole.properties`):

```properties
guacd-hostname: localhost
guacd-port: 4822
auth-provider: net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider
basic-user-mapping: /etc/guacamole/user-mapping.xml
```

**Default User** (`/etc/guacamole/user-mapping.xml`):

- Username: `guacadmin`
- Password: `guacadmin`
- Access: SSH to localhost

### fly.toml Configuration

Add HTTP/HTTPS service:

```toml
# Add to your fly.toml

[[services]]
  internal_port = 8080
  protocol = "tcp"
  auto_stop_machines = false
  auto_start_machines = true
  min_machines_running = 1

  [[services.ports]]
    port = 80
    handlers = ["http"]
    force_https = true  # Redirect HTTP to HTTPS

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

  # Health check (optional)
  [[services.tcp_checks]]
    interval = "15s"
    timeout = "2s"
    grace_period = "30s"
```

**Deploy after configuration:**

```bash
flyctl deploy -a your-app-name
```

### TLS/HTTPS Configuration

Fly.io automatically provides TLS certificates for your app domain:

```bash
# Check TLS certificate status
flyctl certs show -a your-app-name

# Certificate is auto-provisioned for your-app.fly.dev
```

**Note:** HTTPS is critical for Guacamole security - passwords are transmitted during login.

---

## Accessing Guacamole

### Web Interface

After deployment, access Guacamole at:

```url
https://your-app.fly.dev/guacamole/
```

**Important Notes:**

- Note the trailing slash `/` - it's required
- First access may take 30-60 seconds (Tomcat warm-up)
- Use HTTPS, not HTTP (Fly.io redirects automatically)

### Default Login

```text
Username: guacadmin
Password: guacadmin
```

**CRITICAL:** Change this password immediately after first login (see [User Management](#user-management)).

### Login Process

1. Navigate to `https://your-app.fly.dev/guacamole/`
2. Enter username and password
3. Click "Login"
4. You'll see the connection list (initially one SSH connection)

### Testing Connection

Default configuration includes SSH to localhost:

1. Login to Guacamole
2. Click the "localhost SSH" connection
3. A browser-based terminal will open
4. Enter your Sindri VM user credentials when prompted

---

## User Management

Guacamole uses XML-based authentication in the basic setup. User accounts are defined in `/etc/guacamole/user-mapping.xml`.

### Changing the Default Password

#### Option 1: Edit XML File

```bash
# SSH into your VM
ssh developer@your-app.fly.dev -p 10022

# Edit user-mapping.xml
sudo nano /etc/guacamole/user-mapping.xml

# Find the guacadmin entry and change the password:
<authorize username="guacadmin" password="NEW_SECURE_PASSWORD">

# Save and restart Tomcat
sudo systemctl restart tomcat9
```

### Adding New Users

Edit `/etc/guacamole/user-mapping.xml`:

```xml
<user-mapping>
    <!-- Admin user -->
    <authorize username="guacadmin" password="SECURE_PASSWORD">
        <protocol>ssh</protocol>
        <param name="hostname">localhost</param>
        <param name="port">22</param>
        <param name="username">developer</param>
    </authorize>

    <!-- New user with RDP access -->
    <authorize username="john" password="JOHN_PASSWORD">
        <protocol>rdp</protocol>
        <param name="hostname">localhost</param>
        <param name="port">3389</param>
        <param name="username">developer</param>
        <param name="ignore-cert">true</param>
    </authorize>

    <!-- Read-only SSH user -->
    <authorize username="viewer" password="VIEWER_PASSWORD">
        <protocol>ssh</protocol>
        <param name="hostname">localhost</param>
        <param name="port">22</param>
        <param name="username">developer</param>
        <param name="readonly">true</param>
    </authorize>
</user-mapping>
```

**Restart Tomcat after changes:**

```bash
sudo systemctl restart tomcat9
```

### Database Authentication (Advanced)

For production with many users, consider migrating to database authentication:

1. Install MySQL/PostgreSQL extension
2. Download Guacamole JDBC authentication extension
3. Configure database schema
4. Update `guacamole.properties`

**See:** [Guacamole Database Authentication](https://guacamole.apache.org/doc/gug/jdbc-auth.html)

---

## Connection Configuration

Define connections in `/etc/guacamole/user-mapping.xml` within each `<authorize>` block.

### SSH Connections

**Basic SSH:**

```xml
<authorize username="user" password="PASSWORD">
    <protocol>ssh</protocol>
    <param name="hostname">localhost</param>
    <param name="port">22</param>
    <param name="username">developer</param>
</authorize>
```

**SSH with Specific Colors:**

```xml
<authorize username="user" password="PASSWORD">
    <protocol>ssh</protocol>
    <param name="hostname">localhost</param>
    <param name="port">22</param>
    <param name="username">developer</param>
    <param name="color-scheme">green-black</param>
    <param name="font-size">16</param>
</authorize>
```

### RDP Connections

**Basic RDP** (requires xfce-ubuntu extension):

```xml
<authorize username="user" password="PASSWORD">
    <protocol>rdp</protocol>
    <param name="hostname">localhost</param>
    <param name="port">3389</param>
    <param name="username">developer</param>
    <param name="password">USER_PASSWORD</param>
    <param name="ignore-cert">true</param>
</authorize>
```

**RDP with Performance Tuning:**

```xml
<authorize username="user" password="PASSWORD">
    <protocol>rdp</protocol>
    <param name="hostname">localhost</param>
    <param name="port">3389</param>
    <param name="username">developer</param>
    <param name="password">USER_PASSWORD</param>
    <param name="ignore-cert">true</param>
    <param name="color-depth">16</param>
    <param name="disable-audio">true</param>
    <param name="enable-wallpaper">false</param>
    <param name="enable-theming">false</param>
</authorize>
```

### VNC Connections

```xml
<authorize username="user" password="PASSWORD">
    <protocol>vnc</protocol>
    <param name="hostname">localhost</param>
    <param name="port">5901</param>
    <param name="password">VNC_PASSWORD</param>
</authorize>
```

### Multiple Connections Per User

Users can have access to multiple connections:

```xml
<authorize username="admin" password="ADMIN_PASSWORD">
    <!-- SSH Connection -->
    <connection name="SSH Terminal">
        <protocol>ssh</protocol>
        <param name="hostname">localhost</param>
        <param name="port">22</param>
    </connection>

    <!-- RDP Connection -->
    <connection name="Desktop">
        <protocol>rdp</protocol>
        <param name="hostname">localhost</param>
        <param name="port">3389</param>
        <param name="ignore-cert">true</param>
    </connection>
</authorize>
```

---

## Usage Examples

### Browser-Based SSH Access

1. Login to Guacamole at `https://your-app.fly.dev/guacamole/`
2. Click the SSH connection
3. Terminal opens in browser
4. Work normally - all standard terminal features work

**Benefits:**

- Access from any device with browser (Chromebook, tablet, etc.)
- No SSH client installation needed
- Copy/paste works in browser
- Shareable session (with caution)

### Accessing Desktop Environment

**Prerequisites:** Install `xfce-ubuntu` extension first

1. Configure RDP connection in `user-mapping.xml`
2. Login to Guacamole
3. Click the RDP connection
4. Full desktop loads in browser

### Multi-Protocol Workflow

Configure both SSH and RDP for the same user:

```xml
<authorize username="developer" password="SECURE_PASSWORD">
    <connection name="Terminal">
        <protocol>ssh</protocol>
        <param name="hostname">localhost</param>
        <param name="port">22</param>
        <param name="username">developer</param>
    </connection>

    <connection name="Desktop">
        <protocol>rdp</protocol>
        <param name="hostname">localhost</param>
        <param name="port">3389</param>
        <param name="username">developer</param>
        <param name="ignore-cert">true</param>
    </connection>
</authorize>
```

Switch between terminal and desktop as needed.

### File Transfer

**Upload Files via RDP:**

1. Configure RDP with file sharing:

    ```xml
    <param name="enable-drive">true</param>
    <param name="drive-path">/tmp/guacamole-uploads</param>
    ```

2. Connect via RDP
3. Use Guacamole menu (Ctrl+Alt+Shift) → Devices → Shared Drive

**SFTP via SSH:**
Enable SFTP in SSH connection:

```xml
<param name="enable-sftp">true</param>
<param name="sftp-root-directory">/workspace</param>
```

---

## Troubleshooting

### Cannot Access Web Interface

**Check Tomcat Status:**

```bash
sudo systemctl status tomcat9

# View logs
sudo tail -f /var/lib/tomcat9/logs/catalina.out
```

**Check guacd Daemon:**

```bash
sudo systemctl status guacd

# View logs
sudo journalctl -u guacd -f
```

**Verify Ports:**

```bash
# Tomcat (8080)
ss -tln | grep 8080

# guacd (4822)
ss -tln | grep 4822
```

**Test Local Access:**

```bash
# From within VM
curl http://localhost:8080/guacamole/

# Should return HTML
```

### Login Fails

**Check User Configuration:**

```bash
# Verify user-mapping.xml syntax
sudo cat /etc/guacamole/user-mapping.xml

# Common issues:
# - Missing closing tags
# - Incorrect password (case-sensitive)
# - XML syntax errors
```

**Restart Tomcat:**

```bash
sudo systemctl restart tomcat9

# Wait 30 seconds for deployment
sleep 30

# Try login again
```

### Connection Fails

**SSH Connection Fails:**

```bash
# Test SSH locally
ssh localhost

# Check SSH service
sudo systemctl status ssh

# Check user credentials
```

**RDP Connection Fails:**

```bash
# Verify xRDP is installed and running
sudo systemctl status xrdp

# Check RDP port
ss -tln | grep 3389

# Test RDP locally
xfreerdp /v:localhost /u:developer
```

### Performance Issues

**Slow Web Interface:**

```bash
# Check Java heap size
sudo grep -r "Xmx" /etc/default/tomcat9

# Increase if needed (requires restart)
sudo sed -i 's/-Xmx128m/-Xmx512m/' /etc/default/tomcat9
sudo systemctl restart tomcat9
```

**Slow RDP/VNC:**

```xml
<!-- Reduce quality for better performance -->
<param name="color-depth">16</param>
<param name="disable-audio">true</param>
<param name="enable-wallpaper">false</param>
```

### Deployment Issues

**WAR File Not Deploying:**

```bash
# Check WAR file exists
ls -lh /var/lib/tomcat9/webapps/guacamole.war

# Check ownership
sudo chown tomcat:tomcat /var/lib/tomcat9/webapps/guacamole.war

# Force redeployment
sudo rm -rf /var/lib/tomcat9/webapps/guacamole
sudo systemctl restart tomcat9
```

---

## Advanced Configuration

### Recording Sessions

Enable session recording:

```xml
<authorize username="user" password="PASSWORD">
    <protocol>ssh</protocol>
    <param name="hostname">localhost</param>
    <param name="port">22</param>
    <param name="username">developer</param>

    <!-- Recording configuration -->
    <param name="recording-path">/var/recordings</param>
    <param name="create-recording-path">true</param>
    <param name="recording-name">session-${GUAC_USERNAME}-${GUAC_DATE}-${GUAC_TIME}</param>
</authorize>
```

**Create recording directory:**

```bash
sudo mkdir -p /var/recordings
sudo chown tomcat:tomcat /var/recordings
```

### Custom Branding

Customize the login page:

```bash
# Create branding directory
sudo mkdir -p /etc/guacamole/extensions

# Add custom CSS
sudo nano /etc/guacamole/branding.jar
# (Requires creating a JAR with custom resources)

# Restart Tomcat
sudo systemctl restart tomcat9
```

### LDAP Authentication

For enterprise integration:

1. Download guacamole-auth-ldap extension
2. Configure LDAP server details in `guacamole.properties`
3. Remove basic authentication

**Example:**

```properties
ldap-hostname: ldap.example.com
ldap-port: 389
ldap-user-base-dn: ou=users,dc=example,dc=com
```

### Reverse Proxy (Fly.io)

Guacamole works behind Fly.io's reverse proxy by default. For custom configuration:

```toml
[[services]]
  internal_port = 8080
  protocol = "tcp"

  # Custom headers
  [[services.http_checks]]
    path = "/guacamole/"
    headers = { "X-Forwarded-Proto" = "https" }
```

---

## Security

### HTTPS Only

Always use HTTPS for Guacamole access:

```toml
# Force HTTPS in fly.toml
[[services.ports]]
  port = 80
  handlers = ["http"]
  force_https = true  # Redirects HTTP → HTTPS
```

### Strong Passwords

**Password Requirements:**

- Minimum 12 characters
- Mix of upper/lowercase, numbers, symbols
- Unique per user
- Not the default `guacadmin`

### Network Security

**Restrict Access by IP:**

Guacamole doesn't have built-in IP filtering. Use Fly.io private networking:

```bash
# Create private network
flyctl wireguard create

# Connect only via private network
```

Or use SSH tunneling:

```bash
# On local machine
ssh -L 8080:localhost:8080 developer@your-app.fly.dev -p 10022

# Access via http://localhost:8080/guacamole/
```

### Audit Logging

Monitor Guacamole access:

```bash
# View Tomcat access logs
sudo tail -f /var/lib/tomcat9/logs/localhost_access_log.*.txt

# View guacd logs
sudo journalctl -u guacd -f

# View authentication logs
sudo tail -f /var/log/auth.log
```

### Disable Root Login

In SSH connections, ensure regular users are used:

```xml
<!-- Good: regular user -->
<param name="username">developer</param>

<!-- Bad: root user -->
<param name="username">root</param>
```

### File Sharing Security

If enabling file transfers:

```xml
<!-- Restrict upload directory -->
<param name="enable-drive">true</param>
<param name="drive-path">/tmp/uploads</param>

<!-- Make it read-only -->
<param name="disable-download">false</param>
<param name="disable-upload">true</param>
```

---

## Upgrade

### Upgrading Guacamole

The extension supports upgrading:

```bash
# Check current version
guacd -v

# Upgrade to latest version
extension-manager upgrade guacamole
```

**Upgrade Process:**

1. Stops guacd and Tomcat
2. Downloads and compiles new guacamole-server
3. Downloads new guacamole-client WAR
4. Restarts services

**Important:** Configuration is preserved during upgrade.

### Upgrade Notes

- Backup `/etc/guacamole/` before upgrading
- Review [Guacamole Release Notes](https://guacamole.apache.org/releases/)
- Test in non-production environment first

### Manual Upgrade

If automatic upgrade fails:

```bash
# Backup configuration
sudo cp -r /etc/guacamole /etc/guacamole.backup

# Remove old version
extension-manager remove guacamole

# Reinstall latest
extension-manager install guacamole

# Restore configuration
sudo cp /etc/guacamole.backup/user-mapping.xml /etc/guacamole/
sudo systemctl restart tomcat9
```

---

## Uninstallation

### Remove Extension

```bash
# Uninstall Guacamole
extension-manager remove guacamole
```

**This removes:**

- guacamole-server (guacd daemon)
- guacamole-client (web application)
- Tomcat 9
- Configuration files (with confirmation)
- Build dependencies (optional)

### Remove fly.toml Configuration

```bash
# Edit fly.toml and remove HTTP service
# Then redeploy
flyctl deploy -a your-app-name
```

### Clean Up Data

```bash
# Remove recordings (if configured)
sudo rm -rf /var/recordings

# Remove Tomcat work directory
sudo rm -rf /var/lib/tomcat9/work

# Remove logs
sudo rm -rf /var/lib/tomcat9/logs
```

---

## Comparison with Other Options

### vs. XFCE + xRDP

| Aspect | Guacamole | XFCE + xRDP |
|--------|-----------|-------------|
| Client | Browser only | RDP app |
| Protocols | SSH/RDP/VNC | RDP only |
| Setup | Complex | Medium |
| Resource Usage | Medium (~512MB) | High (~800MB) |
| Management | Web-based | Direct RDP |

**Choose Guacamole when:**

- Client installation not allowed
- Need multiple protocol support
- Browser-only access required

**Choose XFCE + xRDP when:**

- Traditional RDP workflow preferred
- Better desktop performance needed
- Simpler setup desired

### vs. X11 Forwarding

| Aspect | Guacamole | X11 Forwarding |
|--------|-----------|----------------|
| Client | Browser | X Server |
| Setup | Complex | Simple |
| Resource Usage | Medium | Low |
| Access Method | Web UI | SSH with -X |
| Use Case | Browser access | Individual apps |

**Choose Guacamole when:**

- Browser-only environment
- Multiple users need access
- Web-based management needed

**Choose X11 Forwarding when:**

- Minimal resource usage critical
- SSH access already available
- Running specific GUI apps

---

## Additional Resources

- [Apache Guacamole Documentation](https://guacamole.apache.org/doc/gug/)
- [User Authentication](https://guacamole.apache.org/doc/gug/users.html)
- [Configuring Guacamole](https://guacamole.apache.org/doc/gug/configuring-guacamole.html)
- [Protocol Reference](https://guacamole.apache.org/doc/gug/protocols.html)
- [GUI Access Options Overview](GUI_ACCESS_OPTIONS.md)

---

## Support

For issues with the Guacamole extension:

1. Check [Troubleshooting](#troubleshooting) section
2. Review Tomcat logs: `sudo tail -f /var/lib/tomcat9/logs/catalina.out`
3. Review guacd logs: `sudo journalctl -u guacd -f`
4. Check extension status: `extension-manager status guacamole`

---

**Last Updated:** 2025-01-11
**Extension Version:** 1.0.0
**Guacamole Version:** 1.5.4
**Compatible with:** Sindri Extension API v2.0
