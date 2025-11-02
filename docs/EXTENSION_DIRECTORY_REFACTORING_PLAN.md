# Extension Directory Structure Refactoring Plan

## Executive Summary

This document outlines a comprehensive plan to refactor the Sindri extension system from a flat file structure to a directory-based structure. The refactoring will improve organization, maintainability, and scalability of the extension system while preserving existing file names.

**Current Structure:**
```
docker/lib/extensions.d/
├── agent-manager.extension
├── agent-manager.aliases
├── claude-config.extension
├── claude-config.aliases
├── rust.extension
├── ...
```

**Proposed Structure:**
```
docker/lib/extensions.d/
├── agent-manager/
│   ├── agent-manager.extension
│   └── agent-manager.aliases
├── claude-config/
│   ├── claude-config.extension
│   └── claude-config.aliases
├── rust/
│   └── rust.extension
├── ...
```

**Key Principle:** Keep existing file names unchanged, only reorganize into directories.

**Scope:** This refactoring affects:
- **28 extensions** with **85 total files**
- **File types**: 28 .extension, 4 .aliases, 8 .toml, 45 .template
- **Core scripts**: 2 (extension-manager.sh, extensions-common.sh)
- **GitHub workflows**: 21
- **Documentation files**: 9
- **Test scripts**: 17+

---

## 1. Current State Analysis

### 1.1 Extension Inventory

Based on comprehensive analysis of `/docker/lib/extensions.d/`:

**Total Extensions:** 28
**Total Files:** 85 extension-related files + 4 configuration files

#### Complete File Breakdown by Extension

**Simple Extensions (1 file only):**
- `github-cli`: 1 file (.extension)
- `monitoring`: 1 file (.extension)
- `post-cleanup`: 1 file (.extension)

**Extensions with Aliases (2 files):**
- `agent-manager`: .extension, .aliases
- `context-loader`: .extension, .aliases
- `tmux-workspace`: .extension, .aliases

**Extensions with Templates (2-3 files):**
- `docker`: .extension, .bashrc.template
- `jvm`: .extension, .bashrc.template
- `ssh-environment`: .extension, .sshd-config.template
- `workspace-structure`: .extension, .readme.template

**Extensions with TOML Configs (3-4 files):**
- `golang`: .extension, .toml, -ci.toml, .create-project-script.template
- `nodejs`: .extension, .toml, -ci.toml
- `python`: .extension, .toml, -ci.toml, .bashrc-mise.template, .create-project.template
- `rust`: .extension, .toml, -ci.toml, .create-project.template

**Extensions with Multiple Templates (3-4 files):**
- `ai-tools`: .extension, .bashrc.template, .readme.template
- `claude-config`: .extension, .aliases, .claude-md.template, .settings-json.template
- `cloud-tools`: .extension, .bashrc.template, .readme.template
- `infra-tools`: .extension, .bashrc.template, .mise-config.template, .readme.template
- `php`: .extension, .bashrc-aliases.template, .cs-fixer-config.template, .development-ini.template
- `playwright`: .extension, .playwright-config.template, .test-spec.template, .tsconfig.template
- `ruby`: .extension, .bashrc-aliases.template, .gemfile-template.template, .rubocop-config.template

**Complex Extensions (5-7 files):**
- `mise-config`: .extension + 4 templates (bash-profile-activation, bashrc-activation, global-config, profile-d)
- `nodejs-devtools`: .extension, .toml, -ci.toml + 3 templates (eslintrc, prettierrc, tsconfig)
- `dotnet`: .extension + 6 templates (bashrc-aliases, directory-build-props, editorconfig, global-json, nuget-config, nuget-wrapper)

#### File Type Summary

| File Type | Count | Purpose |
|-----------|-------|---------|
| `.extension` | 28 | Main extension scripts (required) |
| `.aliases` | 4 | Shell aliases for convenience |
| `.toml` | 4 | mise tool configurations (base) |
| `-ci.toml` | 4 | mise CI-optimized configurations |
| `.template` | 45 | Configuration templates for users |
| **Total** | **85** | **Extension-related files** |

#### Configuration Files (Root Level)

- `active-extensions.conf.example` - Extension activation manifest template
- `active-extensions.ci.conf` - CI mode activation manifest
- `README.md` - Extensions directory documentation
- `upgrade-history.template` - Standalone template for upgrade tracking

### 1.2 Affected Components

#### 1.2.1 Core Scripts
- **`docker/lib/extension-manager.sh`** (1,916 lines)
  - Primary script that manages extensions
  - Contains all file path references and discovery logic
  - Functions that need updates:
    - `find_extension_file()` (lines 440-468)
    - `get_activated_file()` (lines 470-483)
    - Multiple manifest operations

- **`docker/lib/extensions-common.sh`** (910 lines)
  - Shared utilities for extension scripts
  - Contains dependency checking that references file paths
  - Function `check_dependent_extensions()` (lines 67-107)

#### 1.2.2 GitHub Workflows (21 workflows)
Located in `.github/workflows/`:
- `extension-tests.yml` - Main extension testing workflow
- `per-extension.yml` - Individual extension tests
- `api-compliance.yml` - API compliance testing
- `syntax-validation.yml` - Shellcheck validation
- `manager-validation.yml` - Extension manager validation
- `test-extensions-metadata.yml` - Metadata testing
- `test-extensions-upgrade-vm.yml` - Upgrade testing
- `extension-combinations.yml` - Combination testing
- `protected-extensions-tests.yml` - Protected extension tests
- `cleanup-extensions-tests.yml` - Cleanup extension tests
- `manifest-operations-tests.yml` - Manifest operations
- `dependency-chain-tests.yml` - Dependency chain tests
- `integration.yml` - Integration tests
- `integration-test.yml` - Integration test suite
- `mise-stack-integration.yml` - Mise stack tests
- `developer-workflow.yml` - Developer workflow tests
- `validate.yml` - General validation
- `test-documentation.yml` - Documentation tests
- `test-upgrade-helpers.yml` - Upgrade helper tests
- `release.yml` - Release workflow
- `report-results.yml` - Results reporting

All workflows reference `docker/lib/extensions.d/**` pattern in path filters.

#### 1.2.3 GitHub Actions (Multiple composite actions)
Located in `.github/actions/`:
- `setup-fly-test-env/action.yml`
- `test-vm-configuration/action.yml`
- Other actions that may reference extension paths

#### 1.2.4 Test Scripts (17 scripts)
Located in `.github/scripts/extension-tests/`:
- `verify-commands.sh`
- `test-key-functionality.sh`
- `test-api-compliance.sh`
- `test-idempotency.sh`
- `add-extension.sh`
- `verify-manifest.sh`
- `test-dependency.sh`
- `test-protected.sh`
- `lib/test-helpers.sh`
- `lib/assertions.sh`

Located in `.github/scripts/integration/`:
- `test-basic-workflow.sh`
- `verify-volume.sh`
- `setup-manifest.sh`
- `verify-protected.sh`
- `test-extension-system.sh`
- `verify-manifest.sh`

#### 1.2.5 Documentation (9 files)
Located in `docs/`:
- `EXTENSIONS.md` - Primary extension documentation
- `EXTENSION_API_V2.md` - API v2.0 specification
- `EXTENSION_API_V2_MIGRATION_GUIDE.md` - Migration guide
- `EXTENSION_TESTING.md` - Testing documentation
- `CONTRIBUTING.md` - Contributor guide
- `CUSTOMIZATION.md` - Customization guide
- `REFERENCE.md` - Reference documentation
- `ARCHITECTURE.md` - Architecture overview
- `QUICKSTART.md` - Quick start guide

---

## 2. Proposed New Structure

### 2.1 Directory Organization

Each extension will have its own directory containing all related files with original names preserved:

```
docker/lib/extensions.d/
├── agent-manager/
│   ├── agent-manager.extension
│   └── agent-manager.aliases
├── ai-tools/
│   ├── ai-tools.extension
│   ├── ai-tools.bashrc.template
│   └── ai-tools.readme.template
├── claude-config/
│   ├── claude-config.extension
│   ├── claude-config.aliases
│   ├── claude-config.claude-md.template
│   └── claude-config.settings-json.template
├── dotnet/
│   ├── dotnet.extension
│   ├── dotnet.bashrc-aliases.template
│   ├── dotnet.directory-build-props.template
│   ├── dotnet.editorconfig.template
│   ├── dotnet.global-json.template
│   ├── dotnet.nuget-config.template
│   └── dotnet.nuget-wrapper.template
├── golang/
│   ├── golang.extension
│   ├── golang.toml
│   ├── golang-ci.toml
│   └── golang.create-project-script.template
├── mise-config/
│   ├── mise-config.extension
│   ├── mise-config.bash-profile-activation.template
│   ├── mise-config.bashrc-activation.template
│   ├── mise-config.global-config.template
│   └── mise-config.profile-d.template
├── nodejs/
│   ├── nodejs.extension
│   ├── nodejs.toml
│   └── nodejs-ci.toml
├── nodejs-devtools/
│   ├── nodejs-devtools.extension
│   ├── nodejs-devtools.toml
│   ├── nodejs-devtools-ci.toml
│   ├── nodejs-devtools.eslintrc.template
│   ├── nodejs-devtools.prettierrc.template
│   └── nodejs-devtools.tsconfig.template
├── playwright/
│   ├── playwright.extension
│   ├── playwright.playwright-config.template
│   ├── playwright.test-spec.template
│   └── playwright.tsconfig.template
├── python/
│   ├── python.extension
│   ├── python.toml
│   ├── python-ci.toml
│   ├── python.bashrc-mise.template
│   └── python.create-project.template
├── rust/
│   ├── rust.extension
│   ├── rust.toml
│   ├── rust-ci.toml
│   └── rust.create-project.template
├── [... all other extensions ...]
├── active-extensions.conf.example  # Remains at root level
├── active-extensions.ci.conf       # Remains at root level
├── README.md                        # Remains at root level
└── upgrade-history.template         # Remains at root level (shared)
```

### 2.2 File Naming Convention

All files preserve their original names when moved to directories:

- **Primary extension script**: `<extension-name>.extension` (required)
- **Aliases file**: `<extension-name>.aliases` (optional)
- **mise configuration**: `<extension-name>.toml` (base config)
- **mise CI config**: `<extension-name>-ci.toml` (CI-optimized)
- **Templates**: `<extension-name>.<purpose>.template` (e.g., `dotnet.editorconfig.template`)
- **Additional resources**: `<extension-name>.<descriptor>.<type>` (maintaining full original name)

**File Extension Patterns Found:**
- `.extension` - Main extension script (28 files)
- `.aliases` - Shell aliases (4 files)
- `.toml` / `-ci.toml` - mise configurations (8 files)
- `.template` - Configuration templates (45 files)
  - Examples: `.bashrc.template`, `.eslintrc.template`, `.global-json.template`

**Rationale for Preserving Names:**
- Minimal disruption to existing tooling
- Clear file identification in directory listings
- No need to update file references within scripts
- Easier git history tracking
- Template file discovery remains straightforward

### 2.3 Benefits

1. **Organization**: Related files grouped together
2. **Scalability**: Easy to add new extension-related files
3. **Clarity**: Clear ownership and structure
4. **Maintenance**: Easier to locate and update extension files
5. **Future-proofing**: Room for extension-specific resources (configs, templates, hooks)

---

## 3. Migration Strategy

### 3.1 Phase 1: Core Script Updates

#### Step 1.1: Update `extension-manager.sh`

**Location**: `docker/lib/extension-manager.sh`

**Changes Required:**

1. **Update `find_extension_file()` function** (lines 440-468):
   ```bash
   # NEW: Search pattern for directory-based structure only
   find_extension_file() {
       local ext_name="$1"

       # Directory structure: extensions.d/<name>/<name>.extension
       if [[ -f "$EXTENSIONS_BASE/${ext_name}/${ext_name}.extension" ]]; then
           echo "$EXTENSIONS_BASE/${ext_name}/${ext_name}.extension"
           return 0
       fi

       # Extension not found
       print_error "Extension not found: $ext_name"
       print_status "Expected location: $EXTENSIONS_BASE/${ext_name}/${ext_name}.extension"
       return 1
   }
   ```

2. **Update list_extensions() function** (lines 523-600):
   - Modify discovery logic to scan both directories and files
   - Update display to show directory-based extensions

3. **Add migration helper function**:
   ```bash
   # Migrate extension from flat to directory structure (preserving file names)
   migrate_extension_to_directory() {
       local ext_name="$1"

       # Check if already migrated
       if [[ -d "$EXTENSIONS_BASE/${ext_name}" ]]; then
           print_status "Extension '$ext_name' already in directory structure"
           return 0
       fi

       # Find all related files with the extension name prefix
       local ext_file="$EXTENSIONS_BASE/${ext_name}.extension"

       if [[ ! -f "$ext_file" ]]; then
           print_error "Extension file not found: $ext_file"
           return 1
       fi

       # Create directory
       mkdir -p "$EXTENSIONS_BASE/${ext_name}"

       # Find and move ALL files that start with the extension name
       # This handles: .extension, .aliases, .toml, -ci.toml, .*.template, etc.
       local moved_count=0
       for file in "$EXTENSIONS_BASE/${ext_name}".* "$EXTENSIONS_BASE/${ext_name}"-*; do
           if [[ -f "$file" ]]; then
               local filename=$(basename "$file")
               mv "$file" "$EXTENSIONS_BASE/${ext_name}/${filename}"
               ((moved_count++))
               print_debug "  Moved: $filename"
           fi
       done

       if [[ $moved_count -eq 0 ]]; then
           print_warning "No files found for extension '$ext_name'"
           return 1
       fi

       print_success "Migrated '$ext_name' to directory structure"
       return 0
   }

   # Migrate all extensions
   migrate_all_extensions() {
       print_status "Migrating extensions to directory structure..."

       for ext_file in "$EXTENSIONS_BASE"/*.extension; do
           [[ ! -f "$ext_file" ]] && continue
           local ext_name=$(get_extension_name "$(basename "$ext_file")")
           migrate_extension_to_directory "$ext_name"
       done

       print_success "All extensions migrated"
   }
   ```

#### Step 1.2: Update `extensions-common.sh`

**Location**: `docker/lib/extensions-common.sh`

**Changes Required:**

1. **Update `check_dependent_extensions()` function** (lines 67-107):
   ```bash
   check_dependent_extensions() {
       local provided_commands=("$@")
       local dependent_extensions=()

       # Get manifest file location
       local manifest_file="$SCRIPT_DIR/active-extensions.conf"
       [[ ! -f "$manifest_file" ]] && manifest_file="/workspace/scripts/lib/extensions.d/active-extensions.conf"

       if [[ ! -f "$manifest_file" ]]; then
           return 0
       fi

       # Read active extensions from manifest
       while IFS= read -r line; do
           [[ "$line" =~ ^[[:space:]]*# ]] && continue
           [[ -z "${line// }" ]] && continue

           local ext_name=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
           [[ "$ext_name" == "${EXT_NAME:-}" ]] && continue

           # Directory-based structure only
           local ext_file="$SCRIPT_DIR/${ext_name}/${ext_name}.extension"

           [[ ! -f "$ext_file" ]] && continue

           # Check if extension references any of the provided commands
           for cmd in "${provided_commands[@]}"; do
               if grep -q "$cmd" "$ext_file" 2>/dev/null; then
                   dependent_extensions+=("$ext_name")
                   break
               fi
           done
       done < "$manifest_file"

       printf '%s\n' "${dependent_extensions[@]}"
   }
   ```

2. **Update `install_mise_config()` function** (lines 338-425):
   - Update search paths to check directory structure first

### 3.2 Phase 2: File Structure Migration

#### Step 2.1: Create Migration Script

**Location**: `scripts/migrate-extensions.sh`

**Purpose**: Automated migration tool to convert flat structure to directory structure

```bash
#!/bin/bash
# migrate-extensions.sh - Migrate extensions from flat to directory structure
# Note: This preserves original file names for minimal disruption

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EXTENSIONS_DIR="$PROJECT_ROOT/docker/lib/extensions.d"

echo "Extension Structure Migration Tool"
echo "===================================="
echo ""
echo "This script will migrate extensions from:"
echo "  OLD: docker/lib/extensions.d/name.extension"
echo "  NEW: docker/lib/extensions.d/name/name.extension"
echo ""
echo "Original file names will be preserved."
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Function to migrate a single extension
migrate_extension() {
    local ext_file="$1"
    local base_name=$(basename "$ext_file" .extension)

    echo "Migrating: $base_name"

    # Create directory
    mkdir -p "$EXTENSIONS_DIR/$base_name"

    # Track files moved
    local moved_count=0

    # Move ALL files that match the extension name pattern
    # Pattern: <base_name>.* or <base_name>-*
    # This captures:
    #   - base_name.extension
    #   - base_name.aliases
    #   - base_name.toml
    #   - base_name-ci.toml
    #   - base_name.*.template (any template)
    for file in "$EXTENSIONS_DIR/${base_name}".* "$EXTENSIONS_DIR/${base_name}"-*; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            git mv "$file" "$EXTENSIONS_DIR/$base_name/${filename}"
            ((moved_count++))
            echo "    → $filename"
        fi
    done

    if [[ $moved_count -gt 0 ]]; then
        echo "  ✓ $base_name migrated ($moved_count files)"
    else
        echo "  ⚠ $base_name - no files found"
    fi
}

# Migrate all extensions
for ext_file in "$EXTENSIONS_DIR"/*.extension; do
    [[ ! -f "$ext_file" ]] && continue
    migrate_extension "$ext_file"
done

# Keep configuration files at root
echo ""
echo "Migration complete!"
echo "Configuration files remain at: $EXTENSIONS_DIR/"
echo "  - active-extensions.conf.example"
echo "  - active-extensions.ci.conf"
```

#### Step 2.2: Execute Migration

1. Commit all pending changes
2. Create new branch: `git checkout -b feature/extension-directory-structure`
3. Run migration script: `./scripts/migrate-extensions.sh`
4. Verify structure: `tree docker/lib/extensions.d/`

### 3.3 Phase 3: Documentation Updates

Update all documentation files to reflect new structure:

#### Files to Update:

1. **`docs/EXTENSIONS.md`**
   - Update directory structure examples
   - Update path references
   - Add migration notes

2. **`docs/EXTENSION_API_V2.md`**
   - Update extension file locations
   - Update examples

3. **`docs/EXTENSION_TESTING.md`**
   - Update test script examples
   - Update path references

4. **`docs/CONTRIBUTING.md`**
   - Update extension creation instructions
   - Update directory structure

5. **`docs/CUSTOMIZATION.md`**
   - Update extension customization examples

6. **`docs/REFERENCE.md`**
   - Update path references

7. **`docs/ARCHITECTURE.md`**
   - Update architecture diagrams/descriptions

8. **`docs/QUICKSTART.md`**
   - Update quick start examples

9. **`CLAUDE.md`** (root)
   - Update extension directory references

### 3.4 Phase 4: GitHub Workflow Updates

#### Step 4.1: Update Path Filters

All workflows monitoring `docker/lib/extensions.d/**` paths remain compatible (glob pattern matches subdirectories).

**No changes required** for most workflows, but verify:
- `.github/workflows/extension-tests.yml`
- `.github/workflows/syntax-validation.yml`
- `.github/workflows/validate.yml`

#### Step 4.2: Update Test Scripts

Update scripts that directly reference extension file paths:

1. **`.github/scripts/extension-tests/test-api-compliance.sh`**
   - Update extension discovery logic

2. **`.github/scripts/extension-tests/verify-commands.sh`**
   - Update file path references

3. **`.github/scripts/extension-tests/lib/test-helpers.sh`**
   - Update helper functions for extension discovery

4. **`.github/scripts/integration/test-extension-system.sh`**
   - Update system test logic

### 3.5 Phase 5: Testing and Validation

#### Step 5.1: Local Testing

```bash
# Test extension manager
./docker/lib/extension-manager.sh list

# Test extension installation
./docker/lib/extension-manager.sh install rust

# Test extension validation
./docker/lib/extension-manager.sh validate rust

# Test all extensions
./docker/lib/extension-manager.sh install-all
./docker/lib/extension-manager.sh validate-all
```

#### Step 5.2: CI Testing

1. Push branch to trigger GitHub Actions
2. Monitor all workflow runs
3. Verify all tests pass
4. Check for any path-related failures

#### Step 5.3: Integration Testing

1. Deploy test VM with new structure
2. Verify extension installation works
3. Test extension upgrades
4. Verify all extension discovery works correctly

### 3.6 Phase 6: Rollout

1. **Pre-rollout checks:**
   - All tests passing
   - Documentation reviewed
   - Migration script tested

2. **Rollout steps:**
   - Merge feature branch to `develop`
   - Monitor CI/CD pipeline
   - Deploy to staging
   - Test on staging environment
   - Merge to `main`

3. **Post-rollout:**
   - Update release notes
   - Notify users of new structure
   - Monitor for issues

---

## 4. Risks and Mitigations

### 4.1 Identified Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Extension discovery breaks | High | Low | Update all discovery logic in same PR |
| CI/CD workflows fail | High | Low | Comprehensive testing before merge |
| Test scripts fail | Medium | Medium | Update all test scripts in same PR |
| Documentation out of sync | Low | High | Update all docs in same PR |
| Git history obscured | Low | Medium | Use `git mv` for all migrations |

### 4.2 Mitigation Strategies

1. **Comprehensive Testing**: Run full test suite before merge
2. **Complete Migration**: All changes in single atomic PR
3. **Clear Documentation**: Update all references in same commit
4. **Thorough Review**: Test on develop branch before main
5. **Rollback Plan**: Keep ability to revert changes if needed

---

## 6. Testing Strategy

### 6.1 Unit Tests

```bash
# Test extension discovery
test_find_extension_file_directory_structure() {
    local result=$(find_extension_file "rust")
    assert_equals "$EXTENSIONS_BASE/rust/rust.extension" "$result"
}

test_find_extension_file_not_found() {
    local result=$(find_extension_file "nonexistent")
    assert_failure
    assert_error_message_contains "Extension not found: nonexistent"
}
```

### 6.2 Integration Tests

```bash
# Test complete workflow
test_extension_installation() {
    extension-manager install rust
    assert_success

    extension-manager validate rust
    assert_success
}

test_extension_discovery() {
    # Test that all extensions are discovered
    extension-manager list
    assert_contains_all_extensions
    assert_all_in_directory_structure
}
```

### 6.3 CI/CD Tests

- All existing GitHub workflows must pass
- Syntax validation for all extension files
- API compliance tests
- Integration tests on actual VM

---

## 7. Rollback Plan

### 7.1 Immediate Rollback

If critical issues are discovered post-deployment:

```bash
# Revert migration
git revert <migration-commit-sha>

# Redeploy
git push origin main
```

### 7.2 Graceful Rollback

If issues are discovered but not critical:

1. Keep both structures working
2. Fix issues in hotfix branch
3. Deploy hotfix
4. Resume migration

---

## 8. Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Core Script Updates | 1 day | None |
| Phase 2: File Migration | 1 day | Phase 1 |
| Phase 3: Documentation | 1 day | Phase 2 |
| Phase 4: Workflow Updates | 1 day | Phase 2 |
| Phase 5: Testing | 2 days | Phase 1-4 |
| Phase 6: Rollout | 1 day | Phase 5 |
| **Total** | **7 days** | |

---

## 9. Success Criteria

1. ✅ All extensions successfully migrated to directory structure
2. ✅ All existing functionality preserved
3. ✅ All tests passing in CI/CD
4. ✅ Documentation fully updated
5. ✅ Zero production incidents related to migration
6. ✅ All extension discovery updated to new structure
7. ✅ Clean git history preserved via `git mv`

---

## 10. Appendices

### Appendix A: Complete File Inventory

**Detailed Extension File Breakdown:**

**Simple Extensions (1 file):**
1. `github-cli` (1): .extension
2. `monitoring` (1): .extension
3. `post-cleanup` (1): .extension

**2 Files:**
4. `agent-manager` (2): .extension, .aliases
5. `context-loader` (2): .extension, .aliases
6. `docker` (2): .extension, .bashrc.template
7. `jvm` (2): .extension, .bashrc.template
8. `ssh-environment` (2): .extension, .sshd-config.template
9. `tmux-workspace` (2): .extension, .aliases
10. `workspace-structure` (2): .extension, .readme.template

**3 Files:**
11. `ai-tools` (3): .extension, .bashrc.template, .readme.template
12. `cloud-tools` (3): .extension, .bashrc.template, .readme.template
13. `nodejs` (3): .extension, .toml, -ci.toml

**4 Files:**
14. `claude-config` (4): .extension, .aliases, .claude-md.template, .settings-json.template
15. `golang` (4): .extension, .toml, -ci.toml, .create-project-script.template
16. `infra-tools` (4): .extension, .bashrc.template, .mise-config.template, .readme.template
17. `php` (4): .extension, .bashrc-aliases.template, .cs-fixer-config.template, .development-ini.template
18. `playwright` (4): .extension, .playwright-config.template, .test-spec.template, .tsconfig.template
19. `ruby` (4): .extension, .bashrc-aliases.template, .gemfile-template.template, .rubocop-config.template

**5 Files:**
20. `mise-config` (5): .extension + 4 templates (bash-profile-activation, bashrc-activation, global-config, profile-d)
21. `python` (5): .extension, .toml, -ci.toml, .bashrc-mise.template, .create-project.template
22. `rust` (4): .extension, .toml, -ci.toml, .create-project.template

**6 Files:**
23. `nodejs-devtools` (6): .extension, .toml, -ci.toml, .eslintrc.template, .prettierrc.template, .tsconfig.template

**7 Files:**
24. `dotnet` (7): .extension, .bashrc-aliases.template, .directory-build-props.template, .editorconfig.template, .global-json.template, .nuget-config.template, .nuget-wrapper.template

**Total: 28 extensions, 85 files**

**Configuration Files (remain at root):**
- active-extensions.conf.example
- active-extensions.ci.conf
- README.md
- upgrade-history.template

### Appendix B: Script Changes Summary

**Modified Scripts:**
1. `docker/lib/extension-manager.sh`
   - `find_extension_file()` - Update discovery logic
   - `list_extensions()` - Update display logic
   - Add `migrate_extension_to_directory()`
   - Add `migrate_all_extensions()`

2. `docker/lib/extensions-common.sh`
   - `check_dependent_extensions()` - Update file discovery
   - `install_mise_config()` - Update search paths

3. **New Script:** `scripts/migrate-extensions.sh`
   - Automated migration tool

### Appendix C: Workflow Changes Summary

**Workflows requiring review (21 total):**
- Path filters remain compatible (`docker/lib/extensions.d/**`)
- Test scripts may need updates for file discovery
- No structural changes to workflow YAML required

### Appendix D: Documentation Changes Summary

**Files requiring updates (9):**
1. docs/EXTENSIONS.md
2. docs/EXTENSION_API_V2.md
3. docs/EXTENSION_API_V2_MIGRATION_GUIDE.md
4. docs/EXTENSION_TESTING.md
5. docs/CONTRIBUTING.md
6. docs/CUSTOMIZATION.md
7. docs/REFERENCE.md
8. docs/ARCHITECTURE.md
9. docs/QUICKSTART.md
10. CLAUDE.md (root)

---

## 11. Notes and Considerations

### 11.1 Future Enhancements

Once directory structure is established, future enhancements become easier:

1. **Extension-specific hooks**: `.hooks/pre-install`, `.hooks/post-install`
2. **Extension templates**: `.templates/config.example`
3. **Extension metadata**: `.metadata/dependencies.json`
4. **Extension tests**: `.tests/validate.sh`
5. **Extension documentation**: `README.md` per extension

### 11.2 Naming Rationale

Original file names (`name.extension`, `name.aliases`) are preserved to:
- Minimize disruption to existing tooling and scripts
- Maintain clear file identification in directory listings
- Preserve git history and blame information
- Avoid breaking any hard-coded references to file names
- Simplify the migration process

### 11.3 Configuration File Placement

Configuration files (`active-extensions.conf.example`, `active-extensions.ci.conf`) remain at root level because they:
- Apply globally to all extensions
- Are not extension-specific
- Should be easily discoverable

---

## Conclusion

This refactoring plan provides a comprehensive roadmap for migrating the Sindri extension system from a flat file structure to a more organized directory-based structure. The plan prioritizes:

1. **Completeness**: Single atomic migration with all changes together
2. **Clarity**: Clear documentation and updated references
3. **Maintainability**: Better organization for future development
4. **Scalability**: Room for extension-specific resources

The migration can be completed within 7 days with minimal risk when following the outlined phases and testing strategy. All changes will be made in a single PR to ensure consistency and eliminate any transition period.

---

**Document Version**: 1.0
**Last Updated**: 2025-11-02
**Status**: Ready for Review
