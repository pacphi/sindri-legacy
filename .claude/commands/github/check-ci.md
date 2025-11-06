---
description: Check GitHub Actions workflow status, identify failures, and suggest fixes based on logs
---

Check the status of GitHub Actions workflows and provide intelligent analysis of failures:

1. **Workflow Status Check**:
   - Use `gh run list` to get recent workflow runs
   - Filter by workflow name if {{args}} is provided
   - Show status (success, failure, in_progress, cancelled)
   - Display run duration and conclusion
   - Link to workflow run URL

2. **Failure Analysis**:
   For failed runs:
   - Use `gh run view <run-id>` to get detailed information
   - Identify which jobs failed
   - Identify which steps failed in each job
   - Extract error messages and stack traces
   - Download logs if needed for deeper analysis

3. **Common Failure Patterns**:

   **Extension Tests**:
   - Command not found: Missing PATH or installation issue
   - Timeout: Long-running installation or network issues
   - Idempotency failures: Non-idempotent operations
   - API compliance: Missing or incorrect function signatures

   **Integration Tests**:
   - Fly.io deployment timeout: Machine not starting, health checks failing
   - SSH connection refused: Port conflicts, daemon not running
   - Volume persistence: File not found, 0-byte files
   - Machine readiness: Status not transitioning correctly

   **Validation Tests**:
   - Shellcheck violations: Shell script syntax errors
   - YAML syntax errors: Invalid workflow configuration
   - Markdown lint: Formatting issues

4. **Root Cause Identification**:
   - Parse error messages for specific failures
   - Check for environment variable issues
   - Identify network/registry connection problems
   - Detect resource exhaustion (memory, disk, timeout)
   - Find dependency version conflicts

5. **Fix Suggestions**:
   Based on failure patterns, suggest:
   - Code changes with specific file:line references
   - Configuration adjustments
   - Workflow modifications
   - Environment variable additions
   - Retry strategies
   - Timeout increases

6. **Recent Run Summary**:

   ```text
   Workflow: extension-tests
   Status: ✗ Failed
   Duration: 8m 32s
   Run ID: 12345678
   URL: https://github.com/owner/repo/actions/runs/12345678

   Failed Jobs:
   - test-nodejs (step: Validate installation)
   - test-python (step: Run tests)

   Analysis:
   - nodejs: Command 'node' not found - PATH not set correctly
   - python: Timeout after 300s - network registry issue
   ```

7. **Log Analysis**:
   For deep failures:
   - Download full logs with `gh run download`
   - Search for error patterns
   - Extract relevant context around failures
   - Identify cascading failures

8. **Comparison with Successful Runs**:
   - Compare failed run with last successful run
   - Identify what changed (commits, dependencies, environment)
   - Show diff of relevant changes

9. **Actionable Recommendations**:
   Provide specific next steps:
   - Re-run with debug logging: `gh run rerun <run-id> --debug`
   - Fix code at specific locations
   - Update workflow configuration
   - Check Fly.io status
   - Review recent dependency changes

10. **Quick Actions**:
    If {{args}} contains:
    - Workflow name: Check that specific workflow
    - Run ID: Analyze that specific run
    - `latest`: Check most recent run across all workflows
    - `failed`: Show all recent failures
    - `rerun <id>`: Rerun failed jobs for specified run

**Integration with gh CLI**:

```bash
gh run list --limit 10
gh run view <run-id>
gh run view <run-id> --log
gh run rerun <run-id>
gh run watch <run-id>
```

**Output Format**:

- Clear status indicators (✓ ✗ ⏳)
- Clickable URLs to workflow runs
- Specific error excerpts with context
- Prioritized fix recommendations
- Commands to investigate further

**Example Usage**:

- `/check-ci` - Check all recent workflow runs
- `/check-ci extension-tests` - Check specific workflow
- `/check-ci 12345678` - Analyze specific run
- `/check-ci failed` - Show all recent failures
- `/check-ci latest` - Check most recent run
