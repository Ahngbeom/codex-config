# Full-stack Codex Configuration (MVP)

This repository provides a baseline Codex operating setup for app, infra, and DBA workflows.

## Included
- Global guardrails: `AGENTS.md`
- Domain skills:
  - `skills/app-dev/SKILL.md`
  - `skills/infra-ops/SKILL.md`
  - `skills/dba-ops/SKILL.md`
- CI guardrails workflows:
  - Reusable: `.github/workflows/codex-guardrails-reusable.yml`
  - Local caller: `.github/workflows/codex-guardrails.yml`
- Validation scripts:
  - `scripts/check-app.sh`
  - `scripts/check-iac.sh`
  - `scripts/check-db-migrations.sh`
- Multi-repo sync tooling:
  - Inventory: `config/repos.txt`
  - Sync script: `scripts/sync-codex-config.sh`
  - Scenario verifier: `scripts/verify-sync-scenarios.sh`
  - Caller workflow template: `templates/workflows/codex-guardrails.yml`
  - Custom script templates: `templates/scripts/*.sh`

## Stage modes
- `CODEX_ENFORCEMENT_MODE=warn`: Stage 1 visibility mode (non-blocking warnings).
- `CODEX_ENFORCEMENT_MODE=enforce`: Stage 2 enforcement mode (blocking failures).

## Multi-repo usage
1. Register target repos in `config/repos.txt` (`path|project_type|stage`).
2. Preview changes: `scripts/sync-codex-config.sh --plan`
3. Apply changes: `scripts/sync-codex-config.sh --apply`
4. Validate behavior: `scripts/verify-sync-scenarios.sh`

See detailed runbook: `docs/multirepo-sync-guide-ko.md`.
