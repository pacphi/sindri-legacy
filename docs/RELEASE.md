# Release Process

This guide explains how to create and publish new releases for Sindri.

## Overview

Sindri uses **automated releases** triggered by Git tags. The entire release workflow is defined in
`.github/workflows/release.yml` and follows semantic versioning principles.

When you push a version tag, GitHub Actions automatically:

- Validates the tag format
- Generates a changelog from commit messages
- Updates CHANGELOG.md
- Creates release assets
- Publishes a GitHub Release
- Updates documentation (for stable releases)

## Quick Release

For maintainers who want to quickly cut a release:

```bash
# 1. Ensure all changes are committed and pushed
git add .
git commit -m "feat: add new feature"
git push origin main

# 2. Create and push a version tag
git tag v1.2.3
git push origin v1.2.3

# 3. Monitor the release at:
# https://github.com/pacphi/sindri/actions
```

That's it! The automation handles the rest.

## Detailed Release Process

### Prerequisites

Before creating a release, ensure:

- [ ] All tests are passing (check GitHub Actions)
- [ ] Documentation is up to date
- [ ] Breaking changes are documented
- [ ] Security scans are clean
- [ ] All PRs for this release are merged

### Step 1: Determine Version Number

Use [Semantic Versioning](https://semver.org/) (MAJOR.MINOR.PATCH):

- **MAJOR** (v2.0.0): Breaking changes to APIs or workflows
- **MINOR** (v1.1.0): New features, backward-compatible
- **PATCH** (v1.0.1): Bug fixes, security updates

Examples:

- Adding a new extension → MINOR version bump
- Fixing a bug in vm-setup.sh → PATCH version bump
- Changing the extension API → MAJOR version bump

### Step 2: Update Version References (Optional)

The automation will handle most version updates, but you may want to manually update:

```bash
# Check for hardcoded version references
grep -r "v[0-9]\+\.[0-9]\+\.[0-9]\+" docs/
```

### Step 3: Create and Push Git Tag

#### For Stable Releases

```bash
# Create the tag
git tag v1.2.3

# Push to trigger the release workflow
git push origin v1.2.3
```

#### For Pre-releases

Use pre-release identifiers for alpha, beta, or release candidate versions:

```bash
# Alpha release
git tag v1.2.3-alpha.1
git push origin v1.2.3-alpha.1

# Beta release
git tag v1.2.3-beta.1
git push origin v1.2.3-beta.1

# Release candidate
git tag v1.2.3-rc.1
git push origin v1.2.3-rc.1
```

**Pre-release behavior:**

- Marked as "Pre-release" on GitHub
- Not set as the "latest" release
- Documentation is not updated
- Good for testing new features with early adopters

### Step 4: Monitor the Release Workflow

1. Go to [GitHub Actions](https://github.com/pacphi/sindri/actions)
2. Watch the "Release Automation" workflow
3. Verify all jobs complete successfully:
   - Validate Release Tag
   - Generate Changelog
   - Update CHANGELOG.md
   - Create GitHub Release
   - Update Documentation (stable only)
   - Notify Release

### Step 5: Verify the Release

After the workflow completes:

1. **Check the Release Page**: Visit https://github.com/pacphi/sindri/releases
2. **Verify Release Assets**:
   - `install.sh` - Installation script
   - `fly.toml.example` - Example configuration
   - `QUICK_REFERENCE.md` - Quick reference guide
3. **Review Changelog**: Ensure generated changelog is accurate
4. **Test Installation**: Run the install.sh script in a clean environment

```bash
# Download and test the release
curl -fsSL https://github.com/pacphi/sindri/releases/download/v1.2.3/install.sh | bash
```

## Tag Format Requirements

Tags must follow this pattern:

```text
v[MAJOR].[MINOR].[PATCH](-[PRERELEASE])?
```

**Valid tags:**

- `v1.0.0` - Stable release
- `v1.2.3` - Stable release
- `v2.0.0-alpha.1` - Alpha pre-release
- `v1.5.0-beta.2` - Beta pre-release
- `v1.0.0-rc.1` - Release candidate

**Invalid tags:**

- `1.0.0` - Missing 'v' prefix
- `v1.0` - Missing patch version
- `release-1.0.0` - Wrong prefix
- `v1.0.0-SNAPSHOT` - Invalid pre-release format

## Changelog Generation

The automation generates changelogs from commit messages. For best results, use [Conventional Commits](https://www.conventionalcommits.org/):

### Commit Message Format

```text
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Commit Types

Commits are automatically categorized:

- `feat:` or `feat(scope):` → **Features** section
- `fix:` or `fix(scope):` → **Bug Fixes** section
- `docs:` or `docs(scope):` → **Documentation** section
- `deps:` → **Dependencies** section
- Other types → **Other Changes** section

### Examples

```bash
# Feature
git commit -m "feat: add Ruby extension support"
git commit -m "feat(extensions): add Python data science stack"

# Bug fix
git commit -m "fix: resolve SSH key permission issues"
git commit -m "fix(ci): make health check CI-mode aware"

# Documentation
git commit -m "docs: update QUICKSTART with new extension system"
git commit -m "docs(api): document extension manager commands"

# Dependencies
git commit -m "deps: update Node.js to LTS v20"

# Other
git commit -m "chore: clean up temporary files"
git commit -m "style: format shell scripts"
```

## What Gets Automated

### Changelog Generation

The workflow automatically:

1. Compares current tag with previous tag
2. Extracts all commits since last release
3. Categorizes by commit type
4. Generates formatted changelog with:
   - Features section
   - Bug Fixes section
   - Documentation section
   - Dependencies section
   - Other Changes section
5. Adds installation instructions
6. Includes full diff link

### CHANGELOG.md Updates

For both stable and pre-releases:

- Adds new version section to CHANGELOG.md
- Preserves existing changelog entries
- Commits and pushes updates back to main branch

### Release Assets

Three files are automatically created and attached:

#### install.sh

- Quick installation script
- Downloads specific version
- Validates prerequisites
- Provides next steps

#### fly.toml.example

- Example Fly.io configuration
- Based on current fly.toml

#### QUICK_REFERENCE.md

- Common commands
- Setup instructions
- Documentation links

### Documentation Updates (Stable Releases Only)

For stable releases (not pre-releases):

- Updates version references in README.md
- Version badges auto-update via shields.io
- Commits documentation changes to main branch

## Rollback and Recovery

### Delete a Tag Locally and Remotely

```bash
# Delete local tag
git tag -d v1.2.3

# Delete remote tag
git push origin :refs/tags/v1.2.3
```

### Delete a Release on GitHub

1. Go to https://github.com/pacphi/sindri/releases
2. Click the release to delete
3. Click "Delete" button
4. Confirm deletion

### Fix a Bad Release

If a release has issues:

1. **Delete the release and tag** (see above)
2. **Fix the issues** in your code
3. **Create a new patch version** with the fixes:

   ```bash
   git tag v1.2.4
   git push origin v1.2.4
   ```

Never reuse a version number that has already been published.

## Release Checklist

Use this checklist for each release:

### Pre-Release

- [ ] All tests passing on main branch
- [ ] All planned PRs merged
- [ ] Documentation reviewed and updated
- [ ] Breaking changes documented (if any)
- [ ] Security vulnerabilities addressed
- [ ] Version number decided (MAJOR.MINOR.PATCH)
- [ ] Commit messages follow conventional format

### Release

- [ ] Tag created with correct format
- [ ] Tag pushed to GitHub
- [ ] Workflow started successfully
- [ ] All workflow jobs completed

### Post-Release

- [ ] Release visible on GitHub releases page
- [ ] Release assets present (install.sh, etc.)
- [ ] Changelog accurate and complete
- [ ] CHANGELOG.md updated in repository
- [ ] Documentation updated (stable releases)
- [ ] Installation tested from release artifacts
- [ ] Community notified (if applicable)

## Versioning Strategy

### Patch Releases (v1.0.x)

Create patch releases for:

- Bug fixes
- Security updates
- Documentation corrections
- Minor script improvements

**Example:**

```bash
git tag v1.0.1
git push origin v1.0.1
```

### Minor Releases (v1.x.0)

Create minor releases for:

- New extensions
- New features
- Backward-compatible enhancements
- Tool updates

**Example:**

```bash
git tag v1.1.0
git push origin v1.1.0
```

### Major Releases (vx.0.0)

Create major releases for:

- Breaking API changes
- Incompatible extension system changes
- Major architectural changes
- Workflow breaking changes

**Example:**

```bash
git tag v2.0.0
git push origin v2.0.0
```

### Pre-releases

Use pre-releases for:

- Testing new features
- Early access for contributors
- Release candidates before stable

**Alpha** - Early development, unstable:

```bash
git tag v1.2.0-alpha.1
git push origin v1.2.0-alpha.1
```

**Beta** - Feature complete, testing needed:

```bash
git tag v1.2.0-beta.1
git push origin v1.2.0-beta.1
```

**Release Candidate** - Stable, final testing:

```bash
git tag v1.2.0-rc.1
git push origin v1.2.0-rc.1
```

## Troubleshooting

### Workflow Fails

If the release workflow fails:

1. Check the [Actions tab](https://github.com/pacphi/sindri/actions)
2. Review the failed job logs
3. Fix the issue
4. Delete the tag and recreate:

   ```bash
   git tag -d v1.2.3
   git push origin :refs/tags/v1.2.3
   # Fix the issue
   git tag v1.2.3
   git push origin v1.2.3
   ```

### Tag Already Exists

```bash
# If you need to move a tag
git tag -d v1.2.3
git push origin :refs/tags/v1.2.3
git tag v1.2.3 <commit-sha>
git push origin v1.2.3
```

### Changelog Not Generated

The workflow generates changelog from commits. Ensure:

- Commits exist between tags
- Commit messages are properly formatted
- Previous tag exists and is valid

### Release Not Marked as Latest

Only stable releases (without pre-release suffix) are marked as "latest":

- `v1.2.3` → Marked as latest
- `v1.2.3-beta.1` → Not marked as latest

## Best Practices

### Before Each Release

1. **Run Local Tests**

   ```bash
   ./scripts/validate-changes.sh
   ```

2. **Test VM Deployment**

   ```bash
   ./scripts/vm-setup.sh --app-name release-test
   ssh developer@release-test.fly.dev -p 10022 "/workspace/scripts/vm-configure.sh"
   ./scripts/vm-teardown.sh --app-name release-test
   ```

3. **Review Recent Commits**

   ```bash
   git log $(git describe --tags --abbrev=0)..HEAD --oneline
   ```

### After Each Release

1. **Announce the Release** (for significant releases)
   - Update project README if needed
   - Post in discussions
   - Share with community

2. **Monitor for Issues**
   - Watch GitHub issues
   - Monitor deployment reports
   - Respond to user feedback

3. **Plan Next Release**
   - Review roadmap
   - Prioritize features
   - Update milestones

## Release Schedule

Sindri follows a rolling release model:

- **Patch releases**: As needed for bug fixes and security updates
- **Minor releases**: When new features are ready and tested
- **Major releases**: When breaking changes are necessary

There is no fixed schedule. Releases happen when:

1. Sufficient changes have accumulated
2. All tests pass
3. Documentation is current
4. No blocking issues exist

## Questions?

- Review [CONTRIBUTING.md](CONTRIBUTING.md) for development workflow
- Check [GitHub Issues](https://github.com/pacphi/sindri/issues) for known problems
- Start a [Discussion](https://github.com/pacphi/sindri/discussions) for questions
- Contact maintainers for release-specific questions
