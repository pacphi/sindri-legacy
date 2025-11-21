# Factory AI CLI (Droid)

Factory AI's Droid CLI is an AI-powered development agent that provides complete development cycles from planning through
 implementation and quality assurance. Droid is installed as part of the **ai-tools** extension in Sindri environments.

## Overview

Factory AI emphasizes contextual code awareness, drawing from organizational repositories, documentation, and issue tracking
to deliver increasingly intelligent recommendations. The platform integrates natively with Jira, Notion, and Slack for
workflow synchronization and supports both local development and CI/CD environments with enterprise-grade security.

**Key Features:**

- **Complete Development Cycles**: Manages workflows from initial planning through implementation and QA while preserving
user decision-making authority
- **Contextual Code Awareness**: Draws from organizational repositories, documentation, and issue tracking
- **Workflow Synchronization**: Native connectors for Jira, Notion, and Slack
- **Deployment Flexibility**: Functions identically in local and CI/CD environments with SOC-2 compliance
- **On-Premise Options**: Deploy within existing development environments without tool switching

## Installation

Factory AI Droid is installed automatically as part of the **ai-tools** extension:

```bash
# Install ai-tools extension (includes Droid)
extension-manager install ai-tools

# Or use interactive mode
extension-manager --interactive
```

## Configuration

After installation, Factory AI Droid creates:

- `~/.factory/` - Main configuration directory
- `~/.factory/droids/` - Custom droids directory
- `~/.factory/skills/` - Skills directory
- `~/.factory/bin/` - Binary directory (added to PATH)
- `~/.factory/config.json` - Configuration file

## Getting Started

### Initial Setup

1. **Navigate to your project directory:**

   ```bash
   cd /path/to/your/project
   ```

2. **Launch Droid CLI:**

   ```bash
   droid
   ```

3. **Authenticate:**
   - On first run, you'll see a welcome screen
   - Follow the prompt to "sign in via your browser to connect to Factory's development agent"
   - Complete authentication in your browser

### Basic Usage

#### Understanding Your Codebase

Ask Droid to analyze your project:

```bash
droid
> Analyze the overall architecture of this project
> What frameworks are being used here?
```

#### Making Code Changes

Request specific modifications:

```bash
droid
> Add comprehensive logging to the main application startup
```

Droid will:

- Propose changes with a clear plan
- Wait for your approval
- Implement the changes after confirmation

#### Advanced Tasks

Leverage integrations and capabilities:

```bash
droid
> Run a security audit on the authentication module
> Implement the feature described in JIRA-123
```

#### Version Control

Use conversational Git commands:

```bash
droid
> Review my uncommitted changes
> Create a descriptive commit for these changes
```

### Essential Controls

| Action | Method |
|--------|--------|
| Submit tasks | Type and press Enter |
| Multi-line input | Shift+Enter |
| Approve changes | Accept in TUI |
| View shortcuts | Press `?` |
| Bash mode | Press `!` (Esc to return) |
| Exit | Ctrl+C or type `exit` |

### Slash Commands

Factory AI provides quick configuration access:

- `/settings` - Configure Droid settings
- `/model` - Select AI model preferences
- `/mcp` - MCP server configuration
- `/droids` - Manage custom droids
- `/help` - Show available commands

---

## Addenda

### A. Custom Droids Configuration

Custom droids function as reusable subagents that the primary assistant can delegate specialized work to. They enable
teams to encode complex workflows once and reuse them consistently.

#### What Are Custom Droids?

Each custom droid is defined as a Markdown file with:

- Its own system prompt
- Model preference
- Tooling policy (which tools it can access)

#### File Locations

**Project Scope** (shared with teammates):

```bash
.factory/droids/
```

**Personal Scope** (follow you across workspaces):

```bash
~/.factory/droids/
```

**Priority**: Project definitions override personal ones when names match.

#### Configuration Format

Each droid uses Markdown with YAML frontmatter:

```markdown
---
name: code-reviewer
description: Reviews code for security vulnerabilities and best practices
model: inherit
tools: [read, grep, bash]
---

# Code Reviewer Droid

You are a specialized code reviewer focusing on:

1. Security vulnerabilities (OWASP Top 10)
2. Code quality and maintainability
3. Best practices for the detected language/framework

## Review Process

1. Read the provided files
2. Identify security issues
3. Check for code smells
4. Suggest improvements with examples

## Output Format

Provide findings in this structure:
- **Critical**: Security vulnerabilities requiring immediate attention
- **High**: Code quality issues that should be addressed soon
- **Medium**: Improvements to consider
- **Low**: Optional optimizations
```

#### Required Fields

| Field | Description | Values |
|-------|-------------|--------|
| `name` | Unique identifier | Lowercase, digits, hyphens, underscores |
| `description` | UI label (optional) | ≤500 characters |
| `model` | Model selection | `inherit` or specific model ID |
| `tools` | Tool access | `undefined` (all) or array of tool IDs |

#### Creating Custom Droids

1. **Enable custom droids:**

   ```bash
   droid /settings
   # Enable "Custom Droids" option
   ```

2. **Create via wizard:**

   ```bash
   droid /droids
   # Follow prompts:
   # - Choose location (project or personal)
   # - Describe the droid's purpose
   # - Set system prompt
   # - Configure identifier, model, and tools
   ```

3. **Manual creation:**
   Create a `.md` file in `.factory/droids/` or `~/.factory/droids/`:

   ```bash
   # Project-level droid
   cat > .factory/droids/test-generator.md << 'EOF'
   ---
   name: test-generator
   description: Generates comprehensive unit tests
   model: inherit
   tools: [read, write, bash]
   ---

   # Test Generator

   Generate comprehensive unit tests for the provided code...
   EOF
   ```

#### Using Custom Droids

Invoke droids through natural language or the Task tool:

```bash
droid
> Use the code-reviewer subagent on these changes
> Have the test-generator create tests for UserController
```

#### Best Practices

**Encode Team Standards:**

- Architecture patterns
- Testing requirements
- Security guidelines
- Documentation standards

**Restrict Tool Access:**

- Read-only droids for analysis
- Edit-only for code modifications
- Bash access only when needed

**Isolate Context:**

- Keep prompts focused on specific tasks
- Avoid prompt bloat from unrelated context
- Use droids to maintain separation of concerns

**Version Control:**

- Commit project droids to version control
- Share team standards as code
- Document droid purposes in README

---

### B. Skills Configuration

Skills are reusable bundles that standardize how Droids execute work. They represent "capability + context + guardrails"
that Droids can invoke as part of a larger plan.

#### What Are Skills?

Skills encode engineering playbooks that apply consistently across projects. They provide:

1. **Behavioral Consistency**: Droids automatically follow team's architecture, testing, and security norms
2. **Session Persistence**: Same workflow executes reliably regardless of when/how triggered
3. **Safe Scaling**: Enable automation without requiring deep codebase expertise

#### Skills vs. Other Features

| Feature | Purpose |
|---------|---------|
| **Skills** | Encode *how* work happens (workflows, conventions, approval chains) |
| **Custom Droids** | Define agent configurations and system prompts |
| **MCP Servers** | Expose external systems and tools |

#### File Structure

Skills use Markdown with YAML frontmatter. Minimal skill structure:

```markdown
---
name: secure-api-endpoint
description: Create a secure REST API endpoint following team standards
---

# Secure API Endpoint Creation

## Prerequisites
- Authentication middleware configured
- Database models defined
- Input validation library available

## Implementation Steps

1. **Define Route**
   - Use RESTful conventions
   - Apply authentication middleware
   - Add rate limiting

2. **Input Validation**
   - Validate all inputs using Joi/Zod
   - Sanitize string inputs
   - Type check all parameters

3. **Error Handling**
   - Use standard error response format
   - Log errors with context
   - Never expose internal errors to clients

4. **Testing**
   - Write unit tests for business logic
   - Create integration tests for endpoint
   - Test authentication and authorization
   - Verify input validation

## Security Checklist
- [ ] Authentication required
- [ ] Authorization checks implemented
- [ ] Input validation applied
- [ ] SQL injection prevention
- [ ] XSS prevention
- [ ] Rate limiting configured
- [ ] HTTPS only in production

## Example Implementation

\`\`\`javascript
router.post('/api/users',
  authenticate,
  rateLimit({ max: 100 }),
  validateInput(userSchema),
  async (req, res) => {
    // Implementation here
  }
);
\`\`\`
```

#### Directory Structure

**Workspace Skills** (project-specific):

```text
<repo>/.factory/skills/
  secure-api-endpoint/
    SKILL.md
    schema-examples.ts
    checklist.md
```

**Personal Skills** (follow you everywhere):

```text
~/.factory/skills/
  debugging-workflow/
    SKILL.md
    debug-commands.sh
```

#### Discovery and Invocation

**Key Difference from Slash Commands:**

- Skills are **model-invoked** (automatic discovery)
- Slash commands are **user-invoked** (explicit)

Droids automatically detect and apply matching skills based on task description:

```bash
droid
> Create a new API endpoint for user registration

# Droid automatically discovers and applies "secure-api-endpoint" skill
```

#### Creating Skills

1. **Create skill directory:**

   ```bash
   mkdir -p .factory/skills/database-migration
   ```

2. **Create SKILL.md:**

   ```bash
   cat > .factory/skills/database-migration/SKILL.md << 'EOF'
   ---
   name: database-migration
   description: Create and apply database migrations safely
   ---

   # Database Migration Skill

   ## Process
   1. Generate migration file
   2. Review migration for safety
   3. Test on development database
   4. Apply to staging
   5. Verify rollback procedure
   6. Document changes

   ## Safety Checks
   - Backup before migration
   - Use transactions
   - Test rollback
   - No data loss
   EOF
   ```

3. **Add supporting files:**

   ```bash
   # Add schema definitions, type files, checklists, etc.
   ```

#### Best Practices

**Encode Team Conventions:**

```markdown
---
name: commit-message-format
description: Create conventional commit messages following team standards
---

# Commit Message Format

Use this format:
```

type(scope): brief description

Detailed explanation of changes...

Fixes: #123

```text
Types: feat, fix, docs, style, refactor, test, chore
```

**Include Approval Chains:**

```markdown
---
name: production-deployment
description: Deploy to production with proper approvals
---

# Production Deployment

## Pre-Deployment Checklist
- [ ] Code review approved
- [ ] Tests passing
- [ ] Security scan complete
- [ ] Product owner approval

## Deployment Steps
1. Create deployment branch
2. Request approval from tech lead
3. Schedule deployment window
4. Execute deployment
5. Monitor metrics
6. Notify stakeholders
```

**Provide Safety Guardrails:**

```markdown
---
name: database-modification
description: Modify database schema safely
---

# Database Modification Safety

## NEVER Do:
- Drop tables without backup
- Delete columns with data
- Remove constraints without migration path

## ALWAYS Do:
- Create backup first
- Test on development
- Provide rollback script
- Document changes
```

#### Enterprise Use Cases

**Large Codebase Governance:**

- Enforce architectural patterns
- Require security reviews
- Mandate testing standards
- Ensure documentation completeness

**Compliance Requirements:**

- SOC-2 audit trails
- GDPR data handling
- HIPAA security measures
- Financial regulation compliance

**Complex Workflows:**

- Multi-step approval processes
- Cross-team coordination
- Deployment orchestration
- Incident response procedures

---

### C. AGENTS.md Configuration

`AGENTS.md` serves as a specialized briefing document for AI coding agents. Unlike `README.md` (intended for humans),
it provides contextual knowledge that agents need to work effectively.

#### Purpose and Benefits

**Complementary Documentation:**

- Keeps README concise for human readers
- Offloads agent-specific guidance
- Prevents clutter in human-focused docs

**Ecosystem Compatibility:**

- Works across multiple AI platforms:
  - Factory's Droids
  - Cursor
  - Aider
  - Gemini CLI
  - Other AI coding assistants
- Single file instead of proprietary formats per tool

#### When to Create AGENTS.md

**Essential for new projects:**

- After running `new-project` command
- After running `clone-project` command
- When onboarding AI agents to existing projects

**Critical for agent success:**

- Enables independent task execution
- Reduces iteration cycles
- Improves reliability across workflows

#### Format and Structure

AGENTS.md uses plain Markdown with semantic organization:

```markdown
# [PROJECT_NAME]

Brief description of what this project does.

## Build & Test

### Development Commands
\`\`\`bash
npm install              # Install dependencies
npm run dev              # Start development server
npm test                 # Run tests
npm run lint             # Run linter
\`\`\`

### Production Build
\`\`\`bash
npm run build            # Build for production
npm run start            # Start production server
\`\`\`

### Testing Strategy
- Unit tests: Jest + React Testing Library
- E2E tests: Playwright
- Run all tests before commits
- Minimum 80% coverage required

## Architecture Overview

### Project Structure
\`\`\`
src/
  components/          # React components
  services/           # API and business logic
  utils/              # Helper functions
  types/              # TypeScript definitions
\`\`\`

### Key Technologies
- React 18 with TypeScript
- Next.js 14 (App Router)
- Tailwind CSS for styling
- Prisma for database ORM
- PostgreSQL database

### Design Patterns
- Feature-based organization
- Hooks for state management
- API routes in `app/api/`
- Server components by default

## Security

### Authentication
- NextAuth.js for authentication
- JWT tokens in HTTP-only cookies
- OAuth with Google/GitHub

### Authorization
- Role-based access control (RBAC)
- Middleware checks in `middleware.ts`
- API route protection required

### Data Protection
- Environment variables in `.env.local`
- Never commit secrets
- Use Prisma for SQL injection prevention
- Sanitize user inputs

## Git Workflow

### Branch Strategy
- `main` - production ready
- `develop` - integration branch
- `feature/*` - new features
- `fix/*` - bug fixes

### Commit Messages
Follow Conventional Commits:
\`\`\`
feat(auth): add Google OAuth integration
fix(api): resolve rate limiting issue
docs(readme): update installation steps
\`\`\`

### Pull Request Process
1. Create feature branch from `develop`
2. Implement changes with tests
3. Run linter and fix issues
4. Create PR with description
5. Require 1 approval
6. Squash merge to `develop`

## Conventions & Patterns

### Code Style
- Use TypeScript strict mode
- Functional components only
- Prefer composition over inheritance
- Max line length: 100 characters

### Naming Conventions
- Components: PascalCase (`UserProfile.tsx`)
- Utilities: camelCase (`formatDate.ts`)
- Constants: UPPER_SNAKE_CASE (`API_BASE_URL`)
- CSS modules: kebab-case (`user-profile.module.css`)

### Error Handling
\`\`\`typescript
try {
  const result = await apiCall()
  return { success: true, data: result }
} catch (error) {
  logger.error('API call failed', { error })
  return { success: false, error: error.message }
}
\`\`\`

### API Response Format
\`\`\`typescript
{
  success: boolean
  data?: T
  error?: string
  meta?: {
    page: number
    total: number
  }
}
\`\`\`

## Domain Knowledge

### Business Logic
- Users can create projects
- Projects have multiple collaborators
- Free tier: 3 projects max
- Pro tier: unlimited projects

### Data Models
- User (id, email, name, role)
- Project (id, name, ownerId, members)
- Task (id, title, status, projectId)

### External Integrations
- Stripe for payments
- SendGrid for emails
- AWS S3 for file storage

## Important Files

- `.env.local` - Environment variables (never commit)
- `prisma/schema.prisma` - Database schema
- `middleware.ts` - Request middleware
- `next.config.js` - Next.js configuration
- `tailwind.config.ts` - Styling configuration
```

#### Common Sections

1. **Build & Test**
   - Installation commands
   - Development server
   - Testing procedures
   - Build processes

2. **Architecture Overview**
   - Project structure
   - Key technologies
   - Design patterns
   - Architectural decisions

3. **Security**
   - Authentication methods
   - Authorization rules
   - Data protection
   - Security best practices

4. **Git Workflows**
   - Branch strategy
   - Commit message format
   - Pull request process
   - Code review requirements

5. **Conventions & Patterns**
   - Code style guidelines
   - Naming conventions
   - Error handling patterns
   - API response formats

6. **Domain Knowledge**
   - Business rules
   - Data models
   - External integrations
   - Terminology

#### Integration with Factory AI

**Automatic Discovery:**

Factory AI agents locate and ingest AGENTS.md from:

1. Current working directory
2. Parent directories up to repository root
3. Subdirectories relevant to active work
4. Personal override: `~/.factory/AGENTS.md`

**Usage During Development:**

- **Planning Phase**: Understand build/test workflows
- **Tool Selection**: Follow naming conventions
- **Validation**: Apply domain knowledge to reduce errors
- **Code Review**: Check against documented patterns

#### Creating AGENTS.md After Project Creation

**After `new-project` command:**

```bash
# Factory AI creates project structure
droid
> Create a new TypeScript React project called "task-manager"

# Immediately create AGENTS.md
cat > AGENTS.md << 'EOF'
# Task Manager

A modern task management application built with React and TypeScript.

## Build & Test
\`\`\`bash
npm install
npm run dev     # Development server on http://localhost:3000
npm test        # Run test suite
npm run build   # Production build
\`\`\`

## Architecture
- React 18 with TypeScript
- Vite for build tooling
- Tailwind CSS for styling

## Testing
- Vitest for unit tests
- Testing Library for components
- Run tests before committing

EOF
```

**After `clone-project` command:**

```bash
# Clone existing repository
droid
> Clone the repository https://github.com/org/project and create a feature branch

# Analyze and create AGENTS.md
droid
> Analyze this codebase and help me create an AGENTS.md file
> Include: build commands, testing, architecture, and conventions
```

#### Personal AGENTS.md Override

Create `~/.factory/AGENTS.md` for personal preferences that apply across all projects:

```markdown
# Personal Development Preferences

## Code Style
- I prefer functional programming patterns
- Use arrow functions for all functions
- Prefer `const` over `let`, never use `var`

## Testing
- Always write tests for new features
- Use describe/it/expect pattern
- Mock external dependencies

## Git Commit Style
- Use conventional commits
- Reference issue numbers
- Include motivation in commit body

## Documentation
- Add JSDoc comments for public APIs
- Update README when adding features
- Keep AGENTS.md current
```

#### Best Practices

**Keep It Current:**

- Update when build process changes
- Document new conventions
- Add new domain knowledge
- Remove outdated information

**Be Specific:**

```markdown
# ✗ Bad
Run the tests.

# ✓ Good
\`\`\`bash
npm test                    # Run all tests
npm test -- --coverage      # With coverage report
npm test -- --watch         # Watch mode for TDD
\`\`\`
```

**Include Examples:**

```markdown
# ✗ Bad
Follow our error handling pattern.

# ✓ Good
Error handling pattern:
\`\`\`typescript
try {
  const data = await fetchUser(id)
  return { success: true, data }
} catch (error) {
  logger.error('Failed to fetch user', { id, error })
  return { success: false, error: error.message }
}
\`\`\`
```

**Explain Why:**

```markdown
# ✗ Bad
Always use `const` instead of `let`.

# ✓ Good
Prefer `const` over `let` to prevent accidental reassignment
and make code intent clearer. Use `let` only when reassignment
is necessary (loops, counters, etc.).
```

---

### D. Advanced Configuration and Integrations

This section covers advanced Factory AI configurations based on community patterns and best practices.

#### Custom Model Configuration

Factory AI supports custom model configurations via `~/.factory/config.json`:

```json
{
  "models": [
    {
      "model": "claude-3-5-sonnet-20241022",
      "base_url": "http://localhost:8000/v1",
      "api_key": "placeholder",
      "provider": "anthropic"
    },
    {
      "model": "gpt-4-turbo",
      "base_url": "http://localhost:8000/v1",
      "api_key": "placeholder",
      "provider": "openai"
    }
  ],
  "default_model": "claude-3-5-sonnet-20241022",
  "custom_droids_enabled": true,
  "skills_enabled": true
}
```

#### Proxy API Integration

For teams using Claude subscriptions via CLI proxy:

1. **Install and configure CLI Proxy API:**

   ```bash
   npm install -g cli-proxy-api
   cli-proxy-api --claude-login
   ```

2. **Start proxy server:**

   ```bash
   # Systemd service (Linux)
   systemctl start cli-proxy-api

   # Docker (cross-platform)
   docker run -d -p 8000:8000 cli-proxy-api

   # Manual
   cli-proxy-api &
   ```

3. **Configure Factory AI:**
   Add custom model configuration to `~/.factory/config.json` as shown above.

4. **Authentication:**
   - Proxy handles OAuth token refresh automatically
   - Credentials stored in `~/.cli-proxy-api/`
   - Re-authenticate with `cli-proxy-api --claude-login` when needed

#### Known Limitations with Proxy Setup

**Feature Compatibility:**

- `/compress` command may fail with custom models
- Sub-agents/tasks may return empty results
- Tool calling inconsistencies possible

**Workarounds:**

- Switch to Factory model temporarily for compression
- Use native Factory models for sub-agent tasks
- Consider alternative tools like `clewdr` for full feature parity

#### Production Deployment Strategies

**Systemd Service (Linux):**

```ini
# /etc/systemd/system/factory-droid.service
[Unit]
Description=Factory AI Droid CLI Service
After=network.target

[Service]
Type=simple
User=developer
WorkingDirectory=/workspace/projects/active
Environment="PATH=/home/developer/.factory/bin:/usr/local/bin:/usr/bin"
ExecStart=/home/developer/.factory/bin/droid --daemon
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable factory-droid
sudo systemctl start factory-droid
```

**Docker Containerization:**

```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    bash \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Factory AI
RUN curl -fsSL https://app.factory.ai/cli | bash

# Setup user
RUN useradd -m -s /bin/bash developer
USER developer
WORKDIR /workspace

# Configure PATH
ENV PATH="/home/developer/.factory/bin:${PATH}"

CMD ["/bin/bash"]
```

Build and run:

```bash
docker build -t factory-droid .
docker run -it -v $(pwd):/workspace factory-droid
```

#### CI/CD Integration

**GitHub Actions Example:**

```yaml
name: Factory AI Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  droid-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Factory AI CLI
        run: curl -fsSL https://app.factory.ai/cli | bash

      - name: Authenticate
        env:
          FACTORY_API_KEY: ${{ secrets.FACTORY_API_KEY }}
        run: |
          echo "$FACTORY_API_KEY" > ~/.factory/credentials

      - name: Run Code Review
        run: |
          export PATH="$HOME/.factory/bin:$PATH"
          droid --non-interactive "Review these changes for security and quality issues"

      - name: Post Results
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs')
            const review = fs.readFileSync('droid-review.md', 'utf8')
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: review
            })
```

#### Integration with Jira

Configure Jira integration in Factory AI settings:

```bash
droid /settings
# Enable Jira integration
# Provide Jira URL and API token
```

Usage:

```bash
droid
> Implement the feature described in PROJ-123
> Create subtasks for PROJ-456 based on this technical design
```

#### Integration with Slack

Enable Slack notifications for:

- Deployment completions
- Code review requests
- Build failures
- Security scan results

```bash
droid /settings
# Enable Slack integration
# Authorize workspace access
# Configure notification preferences
```

#### Team Collaboration

**Shared Custom Droids:**

Commit project droids to version control:

```bash
git add .factory/droids/
git commit -m "Add security-reviewer custom droid"
git push
```

Team members automatically get droids on pull:

```bash
git pull origin main
droid
> Use security-reviewer on AuthController.ts
```

**Shared Skills:**

Version control skills for team consistency:

```bash
git add .factory/skills/
git commit -m "Add API endpoint creation skill"
```

**Configuration Sharing:**

Share non-sensitive configuration:

```bash
# .factory/config.json.example (commit this)
{
  "default_model": "inherit",
  "custom_droids_enabled": true,
  "skills_enabled": true
}

# .factory/config.json (gitignore this)
# Individual developers customize locally
```

#### Monitoring and Logging

**Enable Verbose Logging:**

```bash
export FACTORY_DEBUG=true
droid
```

**View Logs:**

```bash
# Factory AI logs location
tail -f ~/.factory/logs/droid.log
```

**Monitor Usage:**

```bash
# Check API usage and costs
droid /settings
# View usage dashboard
```

#### Security Best Practices

**Credential Management:**

- Never commit `~/.factory/credentials`
- Use environment variables in CI/CD
- Rotate API keys regularly

**Network Security:**

- Use HTTPS only (Factory AI default)
- Configure firewall for outbound connections
- Review network policies for corporate environments

**Code Review:**

- Always review Droid's proposed changes
- Test changes before merging
- Use custom droids to enforce security checks

**Access Control:**

- Limit who can modify shared droids
- Protect `.factory/` directory permissions
- Use branch protection rules

---

## Managing Factory AI Droid

Factory AI Droid is part of the **ai-tools** extension. Use these commands to manage the entire ai-tools suite:

### Status Check

```bash
# Check ai-tools extension status (includes Droid)
extension-manager status ai-tools
```

### Upgrade

```bash
# Upgrade all AI tools (includes Droid)
extension-manager upgrade ai-tools
```

**Note**: Factory AI CLI manages its own updates automatically. Running the upgrade command will check for updates
across all AI tools.

### Uninstall

```bash
# Remove entire ai-tools extension (includes all AI CLIs)
extension-manager remove ai-tools
```

You'll be prompted whether to keep or remove:

- Factory AI configuration (`~/.factory/`)
- Custom droids and skills
- API keys and credentials
- Other AI tool configurations (Ollama, Fabric, etc.)

---

## Troubleshooting

### Command Not Found

If `droid` command is not found after installation:

```bash
# Reload shell
exec bash

# Or manually source
source ~/.bashrc

# Verify PATH
echo $PATH | grep .factory
```

### Authentication Issues

If authentication fails:

```bash
# Check credentials
ls -la ~/.factory/credentials

# Re-authenticate
rm ~/.factory/credentials
droid  # Will prompt for authentication
```

### Connection Issues

If Factory AI services are unreachable:

```bash
# Test connectivity
curl -I https://app.factory.ai

# Check DNS resolution
nslookup app.factory.ai

# Verify firewall rules (corporate networks)
```

### Permission Errors

If you encounter permission errors:

```bash
# Fix Factory AI directory permissions
chmod -R u+rw ~/.factory/
chmod +x ~/.factory/bin/droid
```

### Browser Authentication on Headless Systems

For systems without a GUI:

1. Copy the authentication URL from terminal output
2. Open URL on a machine with browser
3. Complete authentication
4. Copy credentials back to headless system:

   ```bash
   scp user@desktop:~/.factory/credentials ~/.factory/
   ```

---

## Additional Resources

### Official Documentation

- **Getting Started**: https://docs.factory.ai/cli/getting-started/overview
- **Quickstart Guide**: https://docs.factory.ai/cli/getting-started/quickstart
- **Custom Droids**: https://docs.factory.ai/cli/configuration/custom-droids
- **Skills Configuration**: https://docs.factory.ai/cli/configuration/skills
- **AGENTS.md Guide**: https://docs.factory.ai/cli/configuration/agents-md

### Community Resources

- **CLI Proxy Integration**: https://gist.github.com/chandika/c4b64c5b8f5e29f6112021d46c159fdd
- Factory AI Community Forums
- GitHub Discussions
- Stack Overflow tag: `factory-ai`

### Support

For issues specific to this extension:

```bash
extension-manager validate factory-ai-droid
```

For Factory AI CLI issues:

- Visit Factory AI support portal
- Contact support@factory.ai
- Check status page for service issues

---

## Version History

- **2.0.0** - Initial release with Extension API v2.0 support
  - Installation and configuration automation
  - Custom droids directory setup
  - Skills directory setup
  - Comprehensive documentation
  - Upgrade support

---

## License

This extension follows Sindri's licensing. Factory AI CLI is subject to Factory AI's terms of service.
