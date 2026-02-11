---
name: infra-ops
description: Use this skill for Terraform, Helm, and Kubernetes change reviews with format, validation, plan risk checks, and rollback planning.
---

# infra-ops Skill

## Purpose
Deliver infrastructure changes with explicit safety checks and rollback planning.

## Input
- IaC change request
- Target environment (`dev`, `stage`, `prod`)
- Platform constraints and maintenance window

## Procedure
1. Run `fmt` and `validate`.
2. Produce and inspect `plan` output.
3. Detect destructive actions (replace/delete/recreate).
4. Analyze monitoring and alerting impact.
5. Define rollout order and rollback path.

## Output format
- Key plan diff summary
- Risk classification (low/medium/high)
- Rollout steps
- Rollback steps

## Guardrails
- Do not apply prod-impacting destructive actions without explicit approval.
- Any stateful resource recreation must include data protection steps.

## References
- For plan review detail, use `references/plan-review-checklist.md`.
