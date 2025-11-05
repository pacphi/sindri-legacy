---
description: Test a specific extension with full API compliance validation, idempotency checks, and functionality tests
---

Test the extension named "{{args}}" by performing comprehensive validation:

1. **API Compliance Testing**:
   - Verify all required functions exist: prerequisites, install, configure, validate, status, remove, upgrade
   - Check function implementations follow Extension API v2.0 standards
   - Validate error handling and return codes
   - Ensure idempotent behavior (multiple runs produce same result)

2. **Functional Testing**:
   - Run prerequisites check and verify system requirements
   - Execute install and verify command availability
   - Run validate to check functionality
   - Test status reporting
   - Verify proper cleanup with remove (if safe to test)

3. **Integration Testing**:
   - Check dependency order in active-extensions.conf
   - Verify dependencies are installed
   - Test interaction with mise (if mise-powered)
   - Validate environment variable handling

4. **Documentation Review**:
   - Check inline documentation completeness
   - Verify extension description and metadata
   - Ensure README exists (if applicable)

Use the test helper scripts in `.github/scripts/extension-tests/` for standardized validation:

- `test-api-compliance.sh` for API validation
- `test-idempotency.sh` for idempotency checks
- `test-key-functionality.sh` for functional tests
- `lib/test-helpers.sh` and `lib/assertions.sh` for utilities

**Test execution steps**:

1. Read the extension file from `docker/lib/extensions.d/{{args}}/` or `docker/lib/extensions.d/{{args}}.extension`
2. Source the extension and run each API function
3. Validate outputs and return codes
4. Report any issues with specific line numbers and recommended fixes

**Output format**:

- ✓ for passing tests
- ✗ for failing tests with detailed error messages
- Summary of test results with pass/fail counts
- Specific recommendations for fixing any issues found

If no extension name is provided in args, list all available extensions and prompt for selection.
