# X11 Forwarding Guide for Browser Automation

Comprehensive guide for using X11 forwarding to run GUI applications from Sindri on your local display, with a focus on
browser automation tools (Playwright, Puppeteer) and web scraping (FireCrawl).

## Overview

X11 forwarding allows GUI applications running on the remote Sindri VM to display on your local machine through an
SSH tunnel. This is ideal for:

- **Browser Automation** - Visual debugging with Playwright/Puppeteer
- **Web Scraping** - Visual feedback with FireCrawl
- **Spot Checks** - Occasional GUI tool usage without desktop overhead
- **Development** - Testing GUI applications before deployment

## Table of Contents

- [Quick Start](#quick-start)
- [Client Setup](#client-setup)
- [Basic X11 Forwarding](#basic-x11-forwarding)
- [Browser Automation](#browser-automation)
- [Web Scraping](#web-scraping)
- [Advanced Usage](#advanced-usage)
- [Performance Optimization](#performance-optimization)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

---

## Quick Start

### For Browser Automation (Playwright)

```bash
# 1. Connect with X11 forwarding
ssh -X developer@your-app.fly.dev -p 10022

# 2. Test X11 is working (if xeyes installed)
xeyes  # Should show eyes on your local display

# 3. Run Playwright with headed browser
npx playwright test --headed

# 4. Browser window appears on your local machine
```

### For Web Scraping (FireCrawl)

```bash
# 1. Connect with X11 forwarding
ssh -X developer@your-app.fly.dev -p 10022

# 2. Install Chromium (if not already installed)
sudo apt-get install -y chromium-browser

# 3. Run FireCrawl with visible browser
chromium --no-sandbox https://example.com
```

---

## Client Setup

### Linux

X11 is built-in on most Linux distributions.

**Verify X Server:**

```bash
# Check DISPLAY variable
echo $DISPLAY
# Should show something like :0 or :1

# Test X server
xeyes  # Should open a window with eyes
```

**Install X11 Apps (if needed):**

```bash
# Debian/Ubuntu
sudo apt-get install x11-apps

# Fedora/RHEL
sudo dnf install xorg-x11-apps
```

### macOS

Requires XQuartz (X11 server for macOS).

**Installation:**

```bash
# Option 1: Homebrew
brew install --cask xquartz

# Option 2: Direct download
# Visit https://www.xquartz.org/
```

**Configuration:**

1. Install XQuartz
2. Logout and login (or restart)
3. Launch XQuartz from Applications → Utilities → XQuartz
4. XQuartz → Preferences → Security:
   - ✓ Check "Allow connections from network clients"
5. Restart XQuartz

**Testing:**

```bash
# DISPLAY should be set automatically
echo $DISPLAY

# Test X11
xeyes
```

### Windows

Requires an X Server. Multiple options available.

#### Option 1: VcXsrv (Free, Recommended)

**Installation:**

```powershell
# Download from: https://sourceforge.net/projects/vcxsrv/

# Or via Chocolatey
choco install vcxsrv
```

**Configuration:**

1. Launch XLaunch
2. Display settings: Multiple windows
3. Start no client
4. ✓ Check "Disable access control"
5. Save configuration

**Set DISPLAY in SSH:**

```bash
# Find your Windows IP on WSL network
# Usually: 192.168.x.x or use hostname.local

export DISPLAY=YOUR_WINDOWS_IP:0.0
```

#### Option 2: Xming (Free)

```powershell
# Download from: https://sourceforge.net/projects/xming/
# Install and run Xming
```

#### Option 3: MobaXterm (Commercial, All-in-One)

Includes X server and SSH client:

```text
# Download from: https://mobaxterm.mobatek.net/
# X11 forwarding is automatic
```

#### Option 4: Windows Subsystem for Linux (WSL2)

**With WSLg (Windows 11):**

```bash
# WSLg includes automatic X11 support
# Just use SSH from WSL2 terminal
ssh -X user@host
```

**Without WSLg (Windows 10):**

```bash
# Install VcXsrv on Windows
# In WSL2, set DISPLAY
export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0.0
```

---

## Basic X11 Forwarding

### Connecting with X11 Forwarding

**Basic Connection:**

```bash
# Enable X11 forwarding
ssh -X developer@your-app.fly.dev -p 10022
```

**Trusted X11 Forwarding (Better Performance):**

```bash
# Use on trusted networks only
ssh -Y developer@your-app.fly.dev -p 10022
```

**With Compression (Slower Networks):**

```bash
# Compress X11 traffic
ssh -X -C developer@your-app.fly.dev -p 10022
```

### Verify X11 Forwarding

Once connected:

```bash
# Check DISPLAY variable (should be set by SSH)
echo $DISPLAY
# Output: localhost:10.0 (or similar)

# Test X11 forwarding
xeyes &
# Eyes should appear on your local display
```

### Install Basic X11 Applications

```bash
# Install test applications
sudo apt-get update
sudo apt-get install -y x11-apps

# Test applications
xclock &    # Clock
xeyes &     # Eyes that follow mouse
xlogo &     # X.org logo
```

---

## Browser Automation

### Playwright

Playwright is a powerful browser automation framework that supports Chromium, Firefox, and WebKit.

#### Setup

**Install Playwright** (if not already installed):

```bash
# Via playwright extension
extension-manager install playwright

# Or manually in your project
npm install -D playwright @playwright/test
npx playwright install chromium
npx playwright install-deps chromium
```

#### Running with X11 Forwarding

**Headed Mode (Browser Visible):**

```bash
# Connect with X11 forwarding
ssh -X developer@your-app.fly.dev -p 10022

# Navigate to your project
cd /workspace/projects/active/my-project

# Run tests in headed mode
npx playwright test --headed

# Browser opens on your local display!
```

**Debug Mode (Interactive):**

```bash
# Open Playwright Inspector
npx playwright test --debug

# Playwright Inspector UI appears locally
# Step through tests, inspect selectors
```

**Specific Browser:**

```bash
# Run specific browser
npx playwright test --project=chromium --headed
npx playwright test --project=firefox --headed
npx playwright test --project=webkit --headed
```

#### Example: Visual Debugging

**test.spec.ts:**

```typescript
import { test, expect } from '@playwright/test';

test('visual debugging example', async ({ page }) => {
  // Browser opens on local display
  await page.goto('https://example.com');

  // See the page as test runs
  await page.screenshot({ path: 'screenshot.png' });

  // Interact with elements visually
  await page.click('text=More information');

  // Wait to observe behavior
  await page.waitForTimeout(5000);
});
```

**Run with X11:**

```bash
ssh -X developer@your-app.fly.dev -p 10022
cd /workspace/projects/active/my-project
npx playwright test test.spec.ts --headed
```

#### Code Generator (Playwright Codegen)

**Generate test code by interacting with browser:**

```bash
# Connect with X11
ssh -X developer@your-app.fly.dev -p 10022

# Start codegen
npx playwright codegen https://example.com

# Two windows open locally:
# 1. Browser - interact normally
# 2. Inspector - generated code appears

# Copy generated code to your test files
```

**Advanced codegen:**

```bash
# With authentication
npx playwright codegen --save-storage=auth.json https://example.com

# With specific device
npx playwright codegen --device="iPhone 12" https://example.com

# With custom viewport
npx playwright codegen --viewport-size=1280,720 https://example.com
```

---

### Puppeteer

Puppeteer is a Node.js library for controlling Chrome/Chromium.

#### Setup

**Install Puppeteer:**

```bash
npm install puppeteer

# Or with skipDownload (use system Chrome)
PUPPETEER_SKIP_DOWNLOAD=true npm install puppeteer
```

**Install Chromium:**

```bash
sudo apt-get install -y chromium-browser
```

#### Running with X11 Forwarding

**Basic Script:**

**scraper.js:**

```javascript
const puppeteer = require('puppeteer');

(async () => {
  // Launch browser in headed mode
  const browser = await puppeteer.launch({
    headless: false,  // Show browser
    executablePath: '/usr/bin/chromium',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage'
    ]
  });

  const page = await browser.newPage();
  await page.goto('https://example.com');

  // Browser visible on local display
  await page.screenshot({ path: 'screenshot.png' });

  // Keep browser open to inspect
  console.log('Browser open - inspect on your display');
  await new Promise(resolve => setTimeout(resolve, 30000));

  await browser.close();
})();
```

**Run with X11:**

```bash
ssh -X developer@your-app.fly.dev -p 10022
cd /workspace/projects/active/scraper
node scraper.js
```

#### Visual Debugging Puppeteer

**Slow down execution to observe:**

```javascript
const browser = await puppeteer.launch({
  headless: false,
  slowMo: 250,  // Slow down by 250ms per operation
  executablePath: '/usr/bin/chromium',
  args: ['--no-sandbox']
});
```

**Open DevTools automatically:**

```javascript
const browser = await puppeteer.launch({
  headless: false,
  devtools: true,  // Auto-open DevTools
  executablePath: '/usr/bin/chromium',
  args: ['--no-sandbox']
});
```

---

## Web Scraping

### FireCrawl

FireCrawl is a tool for scraping websites with JavaScript rendering support.

#### Setup

**Install FireCrawl:**

```bash
# Via npm
npm install -g firecrawl-cli

# Or via pip
pip install firecrawl
```

**Install Browser:**

```bash
# Chromium is recommended
sudo apt-get install -y chromium-browser

# Or Firefox
sudo apt-get install -y firefox
```

#### Running with X11 Forwarding

**Basic Scraping (Visual):**

```bash
# Connect with X11
ssh -X developer@your-app.fly.dev -p 10022

# Scrape with browser visible
firecrawl scrape https://example.com --browser-visible

# Browser opens on local display
# Watch scraping in real-time
```

**Advanced Options:**

```bash
# Scrape with custom wait time
firecrawl scrape https://example.com \
  --browser-visible \
  --wait 5000 \
  --output result.json

# Scrape multiple pages
firecrawl crawl https://example.com \
  --browser-visible \
  --max-depth 3 \
  --output results/
```

### Chromium Manual Control

Sometimes you just need to manually browse to develop scraping logic.

**Launch Chromium with X11:**

```bash
# Connect with X11
ssh -X developer@your-app.fly.dev -p 10022

# Launch Chromium
chromium-browser --no-sandbox &

# Or with specific profile
chromium-browser --no-sandbox --user-data-dir=/workspace/chrome-profile &
```

**Useful Chromium Flags:**

```bash
# Disable GPU (if issues occur)
chromium-browser --no-sandbox --disable-gpu

# Start with DevTools open
chromium-browser --no-sandbox --auto-open-devtools-for-tabs

# Mobile emulation
chromium-browser --no-sandbox --user-agent="Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)"

# Disable web security (testing only!)
chromium-browser --no-sandbox --disable-web-security --user-data-dir=/tmp/chrome-test
```

### Firefox with X11

**Install Firefox:**

```bash
sudo apt-get install -y firefox
```

**Launch with X11:**

```bash
ssh -X developer@your-app.fly.dev -p 10022
firefox &
```

**Selenium with Firefox:**

```python
from selenium import webdriver
from selenium.webdriver.firefox.options import Options

# Configure Firefox for X11
options = Options()
# Don't set headless - we want to see it!

driver = webdriver.Firefox(options=options)
driver.get('https://example.com')

# Browser opens on local display
input('Press Enter to close browser...')
driver.quit()
```

---

## Advanced Usage

### Running Multiple GUI Apps

**Background Jobs:**

```bash
# Connect with X11
ssh -X developer@your-app.fly.dev -p 10022

# Start multiple apps in background
chromium-browser --no-sandbox &
firefox &
code &  # VS Code, if installed

# List jobs
jobs

# Bring to foreground
fg %1

# Kill job
kill %1
```

### Persistent X11 Sessions with tmux

**Setup:**

```bash
# Install tmux
sudo apt-get install -y tmux

# Start tmux session with X11
ssh -X developer@your-app.fly.dev -p 10022
tmux new -s gui-session

# Launch GUI app
chromium-browser --no-sandbox &

# Detach: Ctrl+b, then d
# Browser keeps running!

# Reconnect later
ssh -X developer@your-app.fly.dev -p 10022
tmux attach -t gui-session
```

### X11 Forwarding with Jump Hosts

**Through Bastion:**

```bash
# Forward X11 through jump host
ssh -X -J jump-host developer@your-app.fly.dev -p 10022
```

**SSH Config:**

```bash
# ~/.ssh/config
Host sindri-gui
  HostName your-app.fly.dev
  Port 10022
  User developer
  ForwardX11 yes
  ForwardX11Trusted yes
  Compression yes

# Connect
ssh sindri-gui
```

### Clipboard Integration

**Clipboard Sharing:**

```bash
# Install xclip on server
sudo apt-get install -y xclip

# Copy from server to local clipboard
echo "text" | xclip -selection clipboard

# Paste from local clipboard to server
xclip -selection clipboard -o
```

### X11 Forwarding with Docker

**Run GUI app in Docker container:**

```bash
# Connect with X11
ssh -X developer@your-app.fly.dev -p 10022

# Forward DISPLAY to Docker container
docker run -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  my-gui-app
```

---

## Performance Optimization

### Connection Optimization

**Use Compression:**

```bash
# Enable compression for slow networks
ssh -X -C developer@your-app.fly.dev -p 10022
```

**Tune SSH Compression:**

```bash
# ~/.ssh/config
Host sindri-gui
  ForwardX11 yes
  Compression yes
  CompressionLevel 6  # 1-9, higher = more compression
```

### X11 Performance Settings

**Reduce Color Depth:**

```bash
# Use 16-bit color instead of 32-bit
export XAUTHORITY=$HOME/.Xauthority
xdpyinfo | grep "depth of root"

# Launch with reduced depth (app-specific)
chromium-browser --force-color-profile=srgb
```

**Disable Animations:**

```bash
# For Chromium
chromium-browser --no-sandbox --disable-gpu-compositing --disable-smooth-scrolling
```

### Network Optimization

**Use Fly.io WireGuard:**

```bash
# Create WireGuard tunnel (one-time)
flyctl wireguard create

# Connect via private network (lower latency)
ssh -X developer@fdaa:0:xxxx::3 -p 10022
```

**Persistent Connection:**

```bash
# Use ControlMaster for persistent connections
# ~/.ssh/config
Host sindri-gui
  ForwardX11 yes
  ControlMaster auto
  ControlPath ~/.ssh/control-%r@%h:%p
  ControlPersist 1h
```

---

## Troubleshooting

### No DISPLAY Set

**Problem:**

```bash
$ chromium-browser
Error: DISPLAY is not set
```

**Solutions:**

```bash
# Check if X11 forwarding is enabled
ssh -vvv -X user@host 2>&1 | grep -i x11
# Should show: debug1: Requesting X11 forwarding

# Manually set DISPLAY (not recommended, but for testing)
export DISPLAY=localhost:10.0

# Check server sshd config
sudo grep X11 /etc/ssh/sshd_config
# Should have: X11Forwarding yes
```

### Can't Open Display

**Problem:**

```bash
Error: Can't open display: localhost:10.0
```

**Solutions:**

1. **Check X11 authentication:**

  ```bash
  # Verify XAUTHORITY
  echo $XAUTHORITY
  ls -la $XAUTHORITY

  # Check .Xauthority permissions
  chmod 600 ~/.Xauthority
  ```

2. **Check X Server (client-side):**

  ```bash
  # Linux/macOS: Verify X server running
  ps aux | grep X

  # macOS: Restart XQuartz
  killall XQuartz
  open -a XQuartz

  # Windows: Restart VcXsrv
  ```

3. **Firewall issues:**

  ```bash
  # Check if X11 ports are blocked
  # X11 uses display offset from port 6000
  # :10.0 = port 6010
  netstat -an | grep 6010
  ```

### Slow Performance

**Problem:** GUI apps are laggy or slow to respond.

**Solutions:**

1. **Enable compression:**

  ```bash
  ssh -X -C developer@your-app.fly.dev -p 10022
  ```

2. **Use trusted forwarding:**

  ```bash
  ssh -Y developer@your-app.fly.dev -p 10022
  ```

3. **Reduce network usage:**

  ```bash
  # Use lightweight browsers
  chromium-browser --no-sandbox --disable-gpu --disable-software-rasterizer
  ```

4. **Check bandwidth:**

  ```bash
  # Test SSH connection speed
  ssh developer@your-app.fly.dev -p 10022 "dd if=/dev/zero bs=1M count=100" | pv > /dev/null
  ```

### Browser Won't Start

**Problem:** Chromium/Firefox fails to launch.

**Solutions:**

1. **Check dependencies:**

  ```bash
  # For Chromium
  sudo apt-get install -y chromium-browser
  npx playwright install-deps chromium

  # For Firefox
  sudo apt-get install -y firefox
  ```

2. **Use no-sandbox flag:**

  ```bash
  # Chromium requires this in containerized environments
  chromium-browser --no-sandbox
  ```

3. **Check for errors:**

  ```bash
  # Run with verbose output
  chromium-browser --no-sandbox --enable-logging --v=1
  ```

### X11 Forwarding Disabled

**Problem:** X11 forwarding not working.

**Check Server Configuration:**

```bash
# SSH into server
ssh developer@your-app.fly.dev -p 10022

# Check sshd config
sudo grep X11 /etc/ssh/sshd_config

# Should have:
# X11Forwarding yes
# X11DisplayOffset 10
# X11UseLocalhost yes

# If not, add them:
sudo sed -i 's/#X11Forwarding no/X11Forwarding yes/' /etc/ssh/sshd_config

# Restart SSH
sudo systemctl restart ssh
```

---

## Security Considerations

### X11 Security Risks

X11 forwarding can expose security risks:

**Risks:**

- X11 protocol allows keylogging
- Screen capture possible
- Clipboard access
- Input injection

**Mitigations:**

1. **Use untrusted forwarding (-X) by default:**

  ```bash
  ssh -X user@host  # Safer, some restrictions
  ```

2. **Only use trusted forwarding (-Y) on secure networks:**

  ```bash
  ssh -Y user@host  # Full access, trusted networks only
  ```

3. **Limit X11 forwarding timeout:**

  ```bash
  # ~/.ssh/config
  Host sindri
    ForwardX11Timeout 10m  # Timeout after 10 minutes
  ```

### Firewall Configuration

**Restrict X11 ports** (client-side):

```bash
# Only allow X11 from localhost
# (Handled automatically by SSH)
```

### Audit X11 Usage

**Monitor X11 connections:**

```bash
# Server-side: Check auth.log
sudo tail -f /var/log/auth.log | grep X11

# Client-side: Check for unexpected displays
xauth list
```

---

## Best Practices

### Development Workflow

**Recommended workflow:**

1. **Initial development:** Headless on server
2. **Debugging:** X11 forwarding for visual inspection
3. **Production:** Headless with screenshots/videos

```bash
# Development (headless)
npx playwright test

# Debugging (visible)
ssh -X developer@your-app.fly.dev -p 10022
npx playwright test --headed

# Production (headless with artifacts)
npx playwright test --screenshot=on --video=on
```

### Resource Management

**Don't leave GUI apps running:**

```bash
# Kill all Chrome processes
pkill -f chromium

# Kill all Firefox processes
pkill -f firefox

# Check running X11 apps
ps aux | grep -E 'chromium|firefox|X11'
```

### SSH Configuration

**Optimal ~/.ssh/config:**

```bash
Host sindri-gui
  HostName your-app.fly.dev
  Port 10022
  User developer

  # X11 settings
  ForwardX11 yes
  ForwardX11Trusted no  # Safer default
  ForwardX11Timeout 30m

  # Performance
  Compression yes
  CompressionLevel 6

  # Connection persistence
  ControlMaster auto
  ControlPath ~/.ssh/control-%r@%h:%p
  ControlPersist 1h
```

---

## Comparison with Desktop Options

### vs. XFCE + xRDP

| Aspect | X11 Forwarding | XFCE + xRDP |
|--------|----------------|-------------|
| Resource Usage | Low (per-app) | High (desktop) |
| Setup | Simple | Medium |
| Performance | Network-dependent | Better for sustained use |
| Cost | No extra cost | Requires larger VM |
| Use Case | Spot checks, debugging | Full-time GUI work |

**Choose X11 Forwarding for:**

- Browser automation testing
- Visual debugging
- Occasional GUI needs
- Cost optimization

**Choose XFCE + xRDP for:**

- Full desktop environment
- Multiple GUI apps constantly
- Traditional desktop workflow

---

## Additional Resources

- [SSH X11 Forwarding Documentation](https://man.openbsd.org/ssh#X11_FORWARDING)
- [Playwright Documentation](https://playwright.dev)
- [Puppeteer Documentation](https://pptr.dev)
- [XQuartz FAQ](https://www.xquartz.org/FAQs.html)
- [VcXsrv Guide](https://sourceforge.net/projects/vcxsrv/)
- [GUI Access Options Overview](GUI_ACCESS_OPTIONS.md)

---

**Last Updated:** 2025-01-11
**Compatible with:** Sindri v1.0
