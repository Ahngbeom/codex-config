# Terraform Plan Review Checklist

- Confirm workspace/environment is correct.
- Highlight resources with `delete` or `replace` actions.
- Verify IAM/network/security-group deltas.
- Check autoscaling and capacity side effects.
- Confirm alarms/dashboards still cover failure modes.
- Ensure rollback path is feasible and documented.
