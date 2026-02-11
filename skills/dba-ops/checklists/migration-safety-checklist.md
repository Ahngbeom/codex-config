# Migration Safety Checklist

- Migration files follow naming convention and ordering.
- Rollback step exists and is tested (or explicitly justified if forward-only).
- Lock-heavy operations assessed for online alternatives.
- Backfill strategy includes batching and retry behavior.
- Post-migration verification queries are prepared.
