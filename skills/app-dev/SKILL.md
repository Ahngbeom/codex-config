---
name: app-dev
description: Use this skill for backend, frontend, and API code changes that require minimal diffs, tests, and security checks.
---

# app-dev Skill

## Purpose
Accelerate safe application changes for backend, frontend, and APIs.

## Input
- Requirement or bug description
- Related modules/files
- Failing tests or logs

## Procedure
1. Identify the smallest set of modules to update.
2. Implement behavior change with minimal refactor.
3. Add or update tests first around risk boundaries.
4. Run lint and tests.
5. Validate security-sensitive paths (input validation, auth/authz, data exposure).

## Output format
- Summary of behavior change
- Files changed
- Test commands and results
- Known risks + rollback note

## Quick checklist
- No hardcoded secrets
- Error handling preserves useful diagnostics
- Public API changes documented

## References
- For PR output shape, use `templates/pr-summary-template.md`.
