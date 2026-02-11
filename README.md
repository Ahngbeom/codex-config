# Full-stack Codex Configuration (MVP)

This repository provides a baseline Codex operating setup for app, infra, and DBA workflows.

## Included
- Global guardrails: `AGENTS.md`
- Domain skills:
  - `skills/app-dev/SKILL.md`
  - `skills/infra-ops/SKILL.md`
  - `skills/dba-ops/SKILL.md`
- CI guardrails workflow: `.github/workflows/codex-guardrails.yml`
- Validation scripts:
  - `scripts/check-app.sh`
  - `scripts/check-iac.sh`
  - `scripts/check-db-migrations.sh`

## Customize for your projects
- Add `scripts/app-check.sh` for lint/unit/integration checks.
- Add `scripts/iac-check.sh` and `scripts/iac-plan.sh` for environment-specific Terraform checks.
  - If Terraform files exist, `scripts/iac-plan.sh` is required.
- Add `scripts/db-check.sh` if your migration framework needs custom validation.

## Goal
Move from ad-hoc code generation to verified, auditable automation.
