---
name: dba-ops
description: Use this skill for schema migration and query tuning tasks that require lock-impact analysis, staged rollout, and rollback safety.
---

# dba-ops Skill

## Purpose
Reduce risk for schema changes and query performance tuning.

## Input
- DDL/DML migration request
- Database engine/version
- Table sizes, traffic window, and lock sensitivity

## Procedure
1. Assess lock/index impact and expected runtime.
2. Decide online migration or backfill strategy.
3. Validate rollback viability.
4. Define staged release plan.
5. Run migration safety checks.

## Output format
- Migration impact summary
- Execution checklist
- Rollback procedure
- Post-deploy verification queries

## Guardrails
- Avoid single-step destructive schema changes in high traffic windows.
- Use expand/migrate/contract for `NOT NULL`, type changes, and column drops.

## References
- For migration readiness checks, use `checklists/migration-safety-checklist.md`.
