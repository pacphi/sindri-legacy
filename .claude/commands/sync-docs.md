---
description: Ensure consistency between CLAUDE.md, extension READMEs, and inline documentation
---

Synchronize and validate documentation consistency across the Sindri codebase:

1. **Primary Documentation Sources**:
   - `/CLAUDE.md` - Main project instructions
   - `docker/lib/extensions.d/*/README.md` - Extension-specific documentation
   - Extension inline comments and metadata
   - `.github/actions/README.md` - Composite actions documentation
   - `.github/scripts/extension-tests/README.md` - Test scripts documentation

2. **Extension Consistency Checks**:
   - Compare extension list in CLAUDE.md with actual extensions in `docker/lib/extensions.d/`
   - Verify extension descriptions match between manifest and docs
   - Check that all extensions mentioned in CLAUDE.md exist
   - Identify undocumented extensions
   - Validate dependency relationships are correctly documented

3. **Version Synchronization**:
   - Check tool versions mentioned in docs match actual versions
   - Verify mise tool versions are current
   - Check Node.js, Python, Go, Rust version references
   - Validate API version references (Extension API v2.0)
   - Check Docker image versions

4. **Command Documentation**:
   - Verify all extension-manager commands are documented
   - Check that example commands are accurate
   - Validate script paths and filenames
   - Ensure all utility scripts are documented

5. **Cross-Reference Validation**:
   - Check links between documentation files
   - Verify file path references are correct
   - Validate code examples still work
   - Check that referenced features actually exist

6. **Mise-Powered Extensions**:
   - Verify all mise-powered extensions list mise-config as dependency
   - Check that mise commands in docs are accurate
   - Validate mise.toml examples
   - Ensure mise benefits are consistently explained

7. **Workflow Documentation**:
   - Verify workflow descriptions in CLAUDE.md match actual workflows
   - Check that composite actions are documented
   - Validate test script documentation

8. **Common Issues to Fix**:
   - Outdated command syntax
   - Removed features still documented
   - New features not yet documented
   - Inconsistent terminology
   - Broken internal links
   - Incorrect file paths

9. **Update Recommendations**:
   - Generate list of documentation updates needed
   - Prioritize by impact (critical inaccuracies vs minor improvements)
   - Suggest specific text changes with before/after
   - Identify documentation gaps

**Output Format**:

- Summary of inconsistencies found
- Category breakdown (extensions, versions, commands, etc.)
- Specific file:line references for issues
- Recommended updates with exact text changes
- New documentation sections to add
- Documentation sections to remove

**Actions to Take**:

After identifying inconsistencies, offer to:

- Update CLAUDE.md with current information
- Generate missing extension README files
- Fix version references
- Add missing command documentation
- Remove outdated information
