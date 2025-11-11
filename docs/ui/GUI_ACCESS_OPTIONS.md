# GUI Access Options for Sindri

This guide provides a comprehensive overview of all methods for accessing graphical user interfaces (GUI) on
Sindri development VMs. Each approach has distinct trade-offs in terms of setup complexity, resource usage,
performance, and use cases.

## Quick Comparison

| Method | Client Required | Resource Impact | Setup Complexity | Best For |
|--------|----------------|-----------------|------------------|----------|
| **X11 Forwarding** | X Server | Minimal (per-app) | Low | Running individual GUI apps |
| **XFCE + xRDP** | RDP client | High (full desktop) | Medium | Full desktop environment |
| **Guacamole** | Web browser only | Medium | High | Browser-based access |

## Overview of Methods

### 1. X11 Forwarding over SSH (Lightest)

**What it is:** Forward individual GUI application windows over SSH to your local machine.

**Pros:**

- Minimal resource usage (only runs what you need)
- No desktop environment required
- Native window integration on your local desktop
- Works with standard SSH connection
- Zero additional cost

**Cons:**

- Requires X server on client machine
- Latency-sensitive (network dependent)
- Setup varies by OS (complex on Windows)
- Each app runs separately

**Resource Requirements:**

- Server: +50-200MB RAM per GUI application
- Client: X server (built-in on Linux/macOS, requires installation on Windows)
- Network: Low bandwidth, sensitive to latency

**Best for:**

- Running specific GUI tools (browser automation, visual debugging)
- Development workflows that need occasional GUI access
- Users already familiar with SSH
- Playwright/Puppeteer visual testing
- FireCrawl scraping with visual feedback

**See:** [X11_FORWARDING_GUIDE.md](X11_FORWARDING_GUIDE.md) for detailed setup

---

### 2. XFCE Desktop + xRDP (Traditional Remote Desktop)

**What it is:** Full lightweight desktop environment accessible via Remote Desktop Protocol (RDP).

**Pros:**

- Complete desktop experience
- Works with standard RDP clients (Windows built-in, Microsoft Remote Desktop on macOS)
- Familiar interface for desktop users
- All GUI apps available in one session
- Persistent sessions (disconnect/reconnect without losing state)

**Cons:**

- High resource usage (~800MB+ RAM baseline)
- Slower VM startup (+30-60s)
- Requires larger VM size (higher cost)
- Requires fly.toml modification and redeployment
- Full desktop overhead even when using one app

**Resource Requirements:**

- Server RAM: +800MB baseline, 2GB+ recommended
- Server Disk: +2GB for packages
- Server CPU: 2+ cores recommended
- VM Size: shared-cpu-2x minimum ($15-30/month vs $3-5 for basic)

**Best for:**

- Users who need persistent desktop sessions
- Multiple GUI applications simultaneously
- Development workflows requiring full desktop features
- Teams already using RDP infrastructure
- Long-running GUI sessions

**See:** [XFCE_UBUNTU.md](XFCE_UBUNTU.md) for detailed setup

---

### 3. Apache Guacamole (Web-Based Gateway)

**What it is:** Clientless remote desktop gateway - access SSH, RDP, VNC through your web browser.

**Pros:**

- No client software required (browser only)
- Access from anywhere (Chromebook, tablet, etc.)
- Supports multiple protocols (SSH, RDP, VNC)
- Centralized access management
- Works through corporate firewalls (HTTPS)
- Can connect to multiple machines

**Cons:**

- Complex installation (Java/Tomcat stack)
- Medium resource usage (~512MB for services)
- Manual user management via XML config
- Requires HTTPS setup for production security
- Upgrade complexity (version coordination)

**Resource Requirements:**

- Server RAM: +512MB for Java/Tomcat
- Server Disk: +300MB for packages
- Server CPU: 1+ core minimum
- Network: Inbound HTTPS access required

**Best for:**

- Browser-only environments (Chromebooks, tablets)
- Multiple protocol access (SSH + RDP + VNC)
- Centralized access management
- Teams that need web-based access
- Environments where client installation is restricted

**See:** [GUACAMOLE.md](GUACAMOLE.md) for detailed setup

---

## Decision Matrix

### Choose **X11 Forwarding** if

- ✓ You only need GUI access occasionally
- ✓ You're running specific tools (browser automation, visual debugging)
- ✓ You want minimal resource impact
- ✓ You're comfortable with command-line setup
- ✓ Cost optimization is a priority
- ✓ Your local machine can run an X server

### Choose **XFCE + xRDP** if

- ✓ You need a full desktop environment
- ✓ You're using multiple GUI applications regularly
- ✓ You prefer traditional remote desktop experience
- ✓ You have budget for larger VM sizes
- ✓ You need persistent desktop sessions
- ✓ Your local machine has an RDP client

### Choose **Guacamole** if

- ✓ You need browser-only access
- ✓ You want to support multiple protocols (SSH/RDP/VNC)
- ✓ You're accessing from diverse devices (Chromebook, tablet, etc.)
- ✓ Client software installation is not allowed
- ✓ You need centralized connection management
- ✓ You can handle complex setup and maintenance

---

## Combining Methods

You can install multiple methods simultaneously:

```bash
# Lightweight browser automation via X11
# See X11_FORWARDING_GUIDE.md

# Add full desktop for occasional heavy GUI work
extension-manager install xfce-ubuntu

# Or add Guacamole for browser-based access
extension-manager install guacamole
```

**Note:** Installing XFCE or Guacamole will increase your resource requirements and costs. X11 forwarding is always
available via SSH without additional extensions.

---

## Cost Impact Summary

| Configuration | VM Size | Monthly Cost | Use Case |
|--------------|---------|--------------|----------|
| SSH + X11 only | shared-cpu-1x | $3-5 | Occasional GUI apps |
| SSH + X11 + Guacamole | shared-cpu-1x | $3-5 | Browser-based access |
| XFCE + xRDP | shared-cpu-2x | $15-30 | Full desktop |
| XFCE + Guacamole | shared-cpu-2x | $15-30 | Desktop + web access |

---

## Network Configuration

### X11 Forwarding

No fly.toml changes required - uses existing SSH port (10022).

### XFCE + xRDP

Add to `fly.toml`:

```toml
[[services]]
  internal_port = 3389
  protocol = "tcp"

  [[services.ports]]
    port = 3389
```

### Guacamole

Add to `fly.toml`:

```toml
[[services]]
  internal_port = 8080
  protocol = "tcp"

  [[services.ports]]
    port = 80
    handlers = ["http"]

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]
```

---

## Security Considerations

### X11 Forwarding

- **Security:** Encrypted via SSH tunnel
- **Authentication:** SSH keys/passwords
- **Network:** Uses existing SSH connection
- **Recommendation:** Enable `X11UseLocalhost` in sshd_config

### XFCE + xRDP

- **Security:** TLS encryption (built into xRDP)
- **Authentication:** Username/password
- **Network:** Exposes port 3389 publicly
- **Recommendation:** Use strong passwords, consider VPN or Fly.io private networking

### Guacamole

- **Security:** HTTPS required for production
- **Authentication:** User-mapping.xml (basic) or database/LDAP
- **Network:** Exposes HTTP(S) ports publicly
- **Recommendation:** Configure TLS certificates, use database authentication for teams

---

## Performance Optimization

### X11 Forwarding

- Use compression: `ssh -X -C user@host`
- Enable trusted forwarding for local networks: `ssh -Y`
- Configure `ForwardX11Trusted yes` for better performance (trusted networks only)

### XFCE + xRDP

- Disable compositing (included in extension config)
- Use lower color depth in RDP client (16-bit)
- Reduce screen resolution for better performance
- Close unused applications

### Guacamole

- Configure connection compression
- Limit screen resolution and color depth
- Use Guacamole's recording feature selectively
- Monitor Tomcat heap size (increase if needed)

---

## Troubleshooting

### X11 Forwarding Issues

```bash
# Test X11 forwarding
ssh -X user@host xeyes

# Check DISPLAY variable
echo $DISPLAY

# Verify X11UseLocalhost setting
grep X11UseLocalhost /etc/ssh/sshd_config
```

### XFCE + xRDP Issues

```bash
# Check xRDP service
sudo systemctl status xrdp

# Check xRDP logs
sudo tail -f /var/log/xrdp.log
sudo tail -f /var/log/xrdp-sesman.log

# Test port binding
ss -tln | grep 3389
```

### Guacamole Issues

```bash
# Check guacd daemon
sudo systemctl status guacd

# Check Tomcat
sudo systemctl status tomcat9

# Check Tomcat logs
sudo tail -f /var/lib/tomcat9/logs/catalina.out

# Test web access locally
curl http://localhost:8080/guacamole/
```

---

## Use Case Examples

### Browser Automation Testing (Playwright/Puppeteer)

**Recommended:** X11 Forwarding

```bash
# Local machine: Connect with X11 forwarding
ssh -X developer@your-app.fly.dev -p 10022

# Server: Run Playwright with headed browser (visible on local display)
npx playwright test --headed

# Or run specific browser for debugging
chromium --no-sandbox
```

### Web Scraping with Visual Feedback (FireCrawl)

**Recommended:** X11 Forwarding + Chromium

```bash
# Install Chromium on server
sudo apt-get install chromium-browser

# Connect with X11 forwarding
ssh -X developer@your-app.fly.dev -p 10022

# Run FireCrawl with visible browser
firecrawl scrape --browser-visible https://example.com
```

### Full-Time Development with IDE

**Recommended:** XFCE + xRDP

Install VS Code or JetBrains IDEs in the desktop environment for full IDE experience with GUI debugging, visual testing,
and desktop integration.

### Team Access from Diverse Devices

**Recommended:** Guacamole

Configure Guacamole with multiple user accounts and connection profiles for SSH, RDP access to various servers -
accessible from any device with a browser.

---

## Next Steps

1. **For lightweight GUI needs:** Start with [X11_FORWARDING_GUIDE.md](X11_FORWARDING_GUIDE.md)
2. **For full desktop environment:** See [XFCE_UBUNTU.md](XFCE_UBUNTU.md)
3. **For browser-based access:** See [GUACAMOLE.md](GUACAMOLE.md)

## Additional Resources

- [Playwright Extension Documentation](../CLAUDE.md#playwright)
- [Extension System Overview](../CLAUDE.md#extension-system-v10)
- [Fly.io Network Configuration](https://fly.io/docs/reference/configuration/#the-services-sections)
- [SSH Configuration](../CLAUDE.md#ssh-architecture-notes)
