---
description: Validate the extension manifest for dependency order and consistency
---

Validate the extension activation manifest at `docker/lib/extensions.d/active-extensions.conf`:

**Note**: Base system components (workspace-structure, mise-config, ssh-environment, Claude Code CLI) are baked into the Docker image and not managed via the manifest.

1. **Dependency Order Validation**:
   - Verify dependencies are listed before dependents
   - Check mise is available for mise-powered extensions:
     - nodejs, python, rust, golang, nodejs-devtools
   - Validate dependency chains are correct
   - Identify circular dependencies

2. **Extension Existence Check**:
   - Verify each listed extension exists in `docker/lib/extensions.d/`
   - Check for both directory and .extension file formats
   - Identify missing extension files
   - Flag extensions in manifest that don't exist

3. **Duplicate Detection**:
   - Check for duplicate entries in manifest
   - Identify extensions listed multiple times
   - Warn about conflicting versions

4. **Comment Validation**:
   - Verify section comments are accurate
   - Check that extensions are in correct sections:
     - Foundational languages
     - Additional language runtimes
     - Development tools
     - Infrastructure
     - Monitoring & Utilities

5. **Consistency with Available Extensions**:
   - List all available extensions in `docker/lib/extensions.d/`
   - Identify extensions not in manifest
   - Suggest additions for common extensions
   - Check for deprecated extensions

6. **Dependency Graph Analysis**:
   - Build dependency graph from extension files
   - Verify topological sort order
   - Identify missing dependencies
   - Detect dependency conflicts

7. **Mise-Powered Extension Checks**:
   For extensions using mise:
   - Verify mise is available from base system
   - Check extension correctly uses mise commands
   - Validate tool installation patterns
   - Ensure mise tool is available in prerequisites

8. **API Compliance**:
   - Check that all extensions in manifest implement Extension API
   - Verify required functions exist
   - Check for API version compatibility

9. **Manifest Format Validation**:
    - Check for proper comment syntax
    - Verify no trailing whitespace
    - Ensure Unix line endings (LF)
    - Validate bash-compatible syntax

**Validation Output**:

```text
Extension Manifest Validation Report
=====================================

✓ Dependency Order
  ✓ mise available for nodejs
  ✓ mise available for python
  ✓ Dependencies correctly ordered

✗ Issues Found (2)
  ✗ Extension 'ruby' listed but file not found
  ⚠ Extension 'ai-tools' not in manifest but available

📊 Statistics
  - Total extensions in manifest: 15
  - Available extensions: 17
  - Mise-powered extensions: 5

💡 Recommendations
  - Remove 'ruby' from manifest or create extension file
  - Consider adding 'ai-tools' to manifest
  - Move 'docker' before 'infra-tools' (dependency order)
```

**Fix Options**:
After validation, offer to:

- Reorder extensions to fix dependency issues
- Remove non-existent extensions from manifest
- Add missing extensions to manifest
- Update comments to match actual structure
- Fix formatting issues

**Advanced Analysis**:
If {{args}} contains:

- `fix` - Automatically fix issues
- `graph` - Show dependency graph visualization
- `suggest` - Suggest optimal ordering
- `compare` - Compare with a previous version
