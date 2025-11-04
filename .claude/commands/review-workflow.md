---
description: Analyze a GitHub Actions workflow for best practices, efficiency, and alignment with Sindri's CI/CD patterns
---

Review the GitHub Actions workflow file "{{args}}" for optimization opportunities and best practices:

1. **Workflow Structure Analysis**:
   - Check job dependencies and parallelization opportunities
   - Identify redundant or duplicate steps
   - Verify proper use of conditional execution (if, needs)
   - Check for appropriate timeout settings
   - Validate strategy matrices for efficiency

2. **Composite Action Usage**:
   - Identify repeated step patterns that could be composite actions
   - Check if existing composite actions in `.github/actions/` are being used
   - Verify proper action versioning (pinned to commits vs tags)
   - Validate action inputs and outputs

3. **Performance Optimization**:
   - Check for unnecessary checkouts or setup steps
   - Identify opportunities for caching (dependencies, build artifacts)
   - Verify parallel job execution where possible
   - Check for long-running steps that could be optimized
   - Validate resource allocation (runners, timeouts)

4. **Best Practices Compliance**:
   - Verify secrets handling (using ${{ secrets.* }} correctly)
   - Check environment variable usage
   - Validate permissions declarations (least privilege)
   - Ensure proper error handling and failure conditions
   - Check for shell command safety (quoting, error handling)

5. **Sindri-Specific Patterns**:
   - For Fly.io deployments, check use of composite actions:
     - `setup-fly-test-env` for environment setup
     - `deploy-fly-app` for deployments with retry logic
     - `wait-fly-deployment` for deployment waiting
     - `cleanup-fly-app` for cleanup
   - Verify CI_MODE usage for test deployments
   - Check SSH command execution patterns (explicit bash invocation)
   - Validate volume persistence testing approaches
   - Check extension testing patterns

6. **Security Review**:
   - Check for hardcoded secrets or credentials
   - Verify third-party action trustworthiness
   - Check for command injection vulnerabilities
   - Validate input sanitization
   - Review permissions scope

7. **Documentation & Maintainability**:
   - Check for descriptive job and step names
   - Verify comments for complex logic
   - Check if workflow is documented in .github/actions/README.md
   - Validate consistency with other workflows

8. **Test Coverage**:
   - Verify appropriate test triggers (push, pull_request, schedule)
   - Check for comprehensive test scenarios
   - Validate failure notification setup
   - Check artifact retention policies

**Output Format**:

- Summary of findings with severity (Critical, Warning, Suggestion)
- Specific line references for issues
- Concrete recommendations with code examples
- Estimated time savings from optimizations
- Priority-ordered action items

If no workflow file is provided, list available workflows in `.github/workflows/` and prompt for selection.
