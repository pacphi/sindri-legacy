---
description: Analyze git changes and create an intelligent commit
allowed-tools: [Bash]
argument-hint: "[optional custom message]"
---

Analyze the current git changes and create a well-crafted commit message, then commit the changes.

**Steps to follow:**

1. Run `git status` to check the repository state
2. Run `git diff` to see unstaged changes and `git diff --cached` to see staged changes
3. If there are no changes to commit, inform the user and stop
4. Carefully analyze all the changes across all modified files
5. If the user provided arguments via $ARGUMENTS, use that as the commit message. Otherwise, generate an intelligent commit message following these rules:
   - Use imperative mood (e.g., "Add feature" not "Added feature")
   - Keep the first line under 50 characters
   - Add a blank line followed by detailed explanation if the changes are complex
   - Focus on the "why" and "what", not the "how"
   - Check if the project uses conventional commit prefixes (feat:, fix:, docs:, refactor:, chore:, etc.) by examining recent git log, and follow that convention
6. Run `git add -A` to stage all changes
7. Execute `git commit` with the generated message using proper heredoc formatting
8. Show the user the final commit message and confirm the commit was successful

**Important:** Review all changes carefully to ensure the commit message accurately reflects the modifications. If files contain sensitive information (credentials, keys), warn the user before committing.
