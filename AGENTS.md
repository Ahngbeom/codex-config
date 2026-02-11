# Codex Operating Guide (Full-stack: App + Infra + DBA)

## 1. Priority and scope
- Follow instruction precedence: system > developer > user > repository docs.
- Use local repository context first. Prefer `adr/`, `runbooks/`, `standards/`, and skill references before external search.
- Minimize blast radius: change only files required for the requested outcome.

## 2. Safety defaults
- Never expose secrets. Mask values that look like tokens, keys, certificates, or `.env` contents.
- Destructive operations require explicit user confirmation:
  - Infrastructure recreation/deletion
  - Database drop/truncate or irreversible migration
  - Force-push or history rewrite
- For production-impacting changes, include rollback steps in the output.

## 3. Command and editing rules
- Prefer `rg` for file and text search.
- Check workspace status before and after edits: `git status --short --branch`.
- Keep edits deterministic and reviewable; avoid unrelated refactors.
- For substantial changes, provide a concise change plan before editing.

## 4. Standard workflow
1. Discover relevant context from local docs and code.
2. Implement minimal safe change.
3. Run domain checks.
4. Summarize diff, risks, and rollback.

## 5. Domain checks
### App
- Required: lint + unit tests (and integration tests when available).
- Verify input validation and auth/authz impact for API changes.

### Infra (Terraform/K8s/Helm)
- Required: `fmt`, `validate`, and `plan` review.
- Flag destructive plan actions and propose deployment order.

### Database
- Required: migration lint + dry-run checks + rollback scenario.
- Enforce paired migration strategy where applicable (up/down or equivalent).
- For large table or lock-heavy changes, require online/backfill strategy.

## 6. Commit and PR policy
- Use Conventional Commits.
- PR description must include:
  - Scope and impacted systems
  - Risk level and mitigation
  - Rollback steps
  - Validation evidence (commands and key results)

## 7. Observability gate
Before finalizing changes, answer:
- Which metrics/logs/traces detect regressions?
- Which SLO or error budget could be affected?
- Does this increase alert noise?

## 8. Skill routing
- Use `skills/app-dev/SKILL.md` for product code tasks.
- Use `skills/infra-ops/SKILL.md` for IaC and deployment tasks.
- Use `skills/dba-ops/SKILL.md` for schema and query tasks.
