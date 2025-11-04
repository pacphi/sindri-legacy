# IntelliJ Remote Development Setup

## Connect JetBrains IDEs to your Sindri development environment on Fly.io

> **📋 Complete the common setup first:** See [IDE Setup Guide](IDE_SETUP.md) for prerequisites, SSH
> configuration, and VM setup before proceeding.

This guide covers JetBrains IDE-specific setup using Gateway and remote development features.

## Table of Contents

1. [Install JetBrains Gateway](#install-jetbrains-gateway)
2. [Connect to Remote VM](#connect-to-remote-vm)
3. [Project Setup](#project-setup)
4. [Plugin Installation](#plugin-installation)
5. [IntelliJ Optimization](#intellij-optimization)
6. [IntelliJ Troubleshooting](#intellij-troubleshooting)
7. [Advanced Configuration](#advanced-configuration)
8. [IDE-Specific Notes](#ide-specific-notes)

## Install JetBrains Gateway

### Option 1: Standalone Gateway (Recommended)

1. Download [JetBrains Gateway](https://www.jetbrains.com/remote-development/gateway/)
2. Install following standard installer process
3. Sign in with your JetBrains account (free or paid)

### Option 2: Existing JetBrains IDE

If you have IntelliJ IDEA, PyCharm, or other JetBrains IDE:

- Go to "File" → "Remote Development" or "Welcome Screen" → "Remote Development"

## Connect to Remote VM

> **📋 Prerequisites:** Complete the [IDE Setup Guide](IDE_SETUP.md) first to configure SSH and run the VM
> configuration script.

### Gateway Connection

1. **Open JetBrains Gateway**
2. **Create New Connection**
   - Click "New Connection" → "SSH Connection"

3. **Connection Settings**
   - **Host**: `your-app-name.fly.dev`
   - **Port**: `10022`
   - **Username**: `developer`
   - **Authentication**: Key pair
   - **Private key**: Path to your SSH private key

4. **Advanced Settings**
   - Connection timeout: 60 seconds
   - Keep alive: Enabled
   - Compression: Enabled

5. **Test Connection**
   - Click "Test Connection" → Should show "Connection successful"
   - Click "Next" if successful

### IDE Selection

**Choose IDE Type:**

- IntelliJ IDEA Ultimate (Java, Kotlin, Scala, web)
- IntelliJ IDEA Community (Java, Kotlin)
- PyCharm Professional (Python, web frameworks)
- WebStorm (JavaScript, TypeScript, Node.js)
- Other JetBrains IDEs as needed

**Project Directory:**

- Browse to `/workspace/projects/active`
- Select existing project or create new one

## Project Setup

### First Connection

1. **IDE Installation**
   - Gateway downloads and installs IDE on remote VM (3-5 minutes)
   - Progress shown in Gateway window
   - Full IDE interface opens when complete

2. **Open Project**
   - File → Open → Navigate to `/workspace/projects/active/your-project`
   - IDE will index project files

### Project Configuration

**Java/Kotlin:**

```bash
cd /workspace/projects/active
mkdir my-java-project && cd my-java-project
mkdir -p src/main/java/com/example src/test/java/com/example
# Create pom.xml or build.gradle
```

**Python:**

```bash
cd /workspace/projects/active
mkdir my-python-project && cd my-python-project
python3 -m venv venv && source venv/bin/activate
mkdir src tests && touch requirements.txt
```

**JavaScript/TypeScript:**

```bash
cd /workspace/projects/active
mkdir my-web-project && cd my-web-project
npm init -y && npm install express
mkdir src public
```

## Plugin Installation

### Essential Plugins

**Core:**

- Docker - Container support
- Database Tools - Database management (Ultimate only)
- Git - Version control (pre-installed)

**Language-Specific:**

**JavaScript/TypeScript:**

- Node.js - Node.js development
- TypeScript - Enhanced TypeScript
- Prettier - Code formatting
- ESLint - Code linting

**Python:**

- Python Community Edition (if using Community)
- Jupyter - Notebook support
- Python Security - Security analysis

**Java:**

- Maven/Gradle - Build system support
- Spring Boot - Spring framework

### Installation

1. File → Settings → Plugins (or Preferences on Mac)
2. Search for plugin → Install → Restart if prompted

**Note:** Plugins install on remote VM, not locally.

## IntelliJ Optimization

### IDE Memory Settings

1. Help → Edit Custom VM Options:

   ```bash
   -Xms2048m
   -Xmx4096m
   -XX:ReservedCodeCacheSize=1024m
   ```

2. Build Settings:
   - File → Settings → Build → Compiler
   - Build process heap size: 2048 MB
   - Enable "Compile independent modules in parallel"

3. **File Exclusions:**
   - Add to compiler exclusions: `node_modules`, `dist`, `build`, `__pycache__`, `.venv`

### Connection Optimization

**Gateway Settings:**

- Connection timeout: 60 seconds
- Keep alive: 30 seconds
- Compression: Enabled
- X11 forwarding: Disabled

**SSH Performance:** See [IDE Setup Guide](IDE_SETUP.md#performance-optimization) for SSH optimizations.

## IntelliJ Troubleshooting

> **📋 General Issues:** See [IDE Setup Guide](IDE_SETUP.md#common-troubleshooting) and
> [Troubleshooting Guide](TROUBLESHOOTING.md) for SSH and VM issues.

### IntelliJ-Specific Issues

#### Gateway Hangs During Setup

**Symptoms:** Gateway hangs during IDE installation

**Solutions:**

1. Check VM status: `flyctl status -a your-app-name`
2. Restart VM if needed
3. Increase timeout in Gateway settings

#### IDE Won't Start

**Symptoms:** IDE installation completes but doesn't launch

**Solutions:**

1. Check VM resources: `ssh claude-dev; htop; df -h`
2. Clear IDE cache: `rm -rf ~/.cache/JetBrains`
3. Upgrade VM size if needed

#### Project Not Loading

**Symptoms:** IDE opens but project files don't appear

**Solutions:**

1. Ensure `/workspace/projects/your-project` exists
2. File → Reload Gradle/Maven Project
3. Check project configuration files exist

#### Slow Performance

**Solutions:**

1. Check network latency: `ping your-app-name.fly.dev`
2. Optimize SSH connection (see IDE Setup Guide)
3. Increase VM resources
4. Exclude large directories from indexing

#### Terminal Not Working

**Solutions:**

1. File → Settings → Tools → Terminal → Set shell to `/bin/bash`
2. Use external SSH session if IDE terminal fails

### Debug Tools

**Gateway Logs:** Help → Show Log in Finder/Explorer
**Remote IDE Logs:** `tail -f ~/.cache/JetBrains/*/log/idea.log`

## IntelliJ Best Practices

### Development Workflow

1. **Use Integrated Terminal**

   ```bash
   # All commands run on remote VM
   cd /workspace/projects/active/my-project
   ./mvnw spring-boot:run    # Java
   python main.py            # Python
   npm run dev              # Node.js
   ```

2. **Port Forwarding**
   - IDE auto-forwards common development ports
   - Manual forwarding: Tools → Deployment → Configuration

3. **File Operations**
   - All files on remote VM, changes are immediate
   - No local synchronization needed

### Git Integration

- **VCS Menu:** All Git operations built-in
- **Merge Conflicts:** Built-in resolution tools
- **SSH Agent Forwarding:** Add `ForwardAgent yes` to SSH config

### Database Development (Ultimate)

- **Database Tools:** Connect to Fly.io databases
- **Connection:** Use `localhost` for same-app databases, `app-name.fly.dev` for separate apps

### Testing and Debugging

- **Run Configurations:** Create for your applications
- **Full Debugging:** Breakpoints, inspection, step-through
- **Framework Integration:** JUnit, pytest, Jest built-in

### Performance Tips

- **Monitor Resources:** Use `htop`, `df -h /workspace`
- **Memory Settings:** Help → Edit Custom VM Options
- **Exclude Directories:** Settings → Build → Compiler exclusions

## Advanced Configuration

### IDE Customization

**Code Style:**

1. File → Settings → Editor → Code Style
2. Configure and export settings to share with team

**Live Templates:**

1. File → Settings → Editor → Live Templates
2. Add templates for common patterns

**External Tools:**

1. File → Settings → Tools → External Tools
2. Add Claude Code, backup scripts, etc.

### Multi-Project Workspace

- **Multiple Projects:** File → Open (separate windows)
- **Related Projects:** Use "Add as Module"
- **Project Switching:** Window → Next Project Window or Cmd/Ctrl + Alt + brackets

### Team Collaboration

- **Shared Settings:** Export and commit `.idea/codeStyles/`
- **Run Configurations:** Store in `.idea/runConfigurations/`
- **Required Plugins:** Document in `.idea/externalDependencies.xml`

## IDE-Specific Notes

### IntelliJ IDEA Ultimate vs Community

**Ultimate Features:**

- Database tools
- Web development
- Spring framework support
- Application servers
- Remote development (built-in)

**Community Features:**

- Java, Kotlin, Scala development
- Maven, Gradle support
- Git integration
- Basic debugging

### Other JetBrains IDEs

**PyCharm Professional**:

- Full Python development
- Web frameworks (Django, Flask)
- Database tools
- Scientific tools (Jupyter, Anaconda)

**WebStorm**:

- JavaScript, TypeScript development
- Node.js support
- React, Vue, Angular frameworks
- Testing frameworks

**DataGrip**:

- Database-focused IDE
- SQL development
- Multiple database support

## Summary

IntelliJ is now connected to your remote Sindri development environment with:

- ✅ Full JetBrains IDE functionality with debugging and testing
- ✅ Remote development on persistent Fly.io infrastructure
- ✅ Integrated access to Claude Code and Claude Flow
- ✅ Professional tools including database support (Ultimate)

## Related Documentation

- **[IDE Setup Guide](IDE_SETUP.md)** - Common setup and utilities
- **[VS Code Setup](VSCODE.md)** - Visual Studio Code alternative
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Problem resolution
