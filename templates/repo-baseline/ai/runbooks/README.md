# ai/runbooks/

Step-by-step operational guides — what to do WHEN something happens. Distinct from patterns (how to write code) and ADRs (why we chose X).

## What goes here

### Lifecycle runbooks
- `phase-1-mvp-plan.md` — the 7-day plan to ship v1.
- `phase-2-monetization-plan.md`, `phase-3-...`, etc. — later-phase plans.

### Operational runbooks
- `deployment.md` — how to ship to prod.
- `rollback.md` — how to revert.
- `incident-response.md` — outage playbook.
- `dependency-upgrade.md` — major version bump procedure.
- `perf-investigation.md` — when latency spikes.
- `debugging.md` — common issues + diagnostic commands.

### Domain-specific runbooks
- `tenant-onboarding.md` — admin-side flow.
- `tenant-offboarding.md` — suspension + retention + export.
- `dlq-triage.md` — handling failed background jobs.
- `shard-cutover.md` — when sharding triggers (write BEFORE you need it; rehearse).
- `pii-removal.md` — GDPR Article 17 erasure.

## Format

See `_template.md` in this folder — copy it for any new runbook.

## When to write a runbook

- After resolving an incident — capture the steps so the next responder doesn't re-derive them.
- Before a high-stakes operation that you'll do rarely (sharding, major migration, vendor swap).
- When onboarding a new team member — write what you wish you'd had.

## Empty?

`repo-baseline` ships only `_template.md` here. **`phase-1-mvp-plan.md` and other phase plans are authored at `/setup-project` run time** (Phase 4.7 / domain-flavored plans) — they are not checked in as static seeds. Until that step runs, start from `_template.md`. Other runbooks accrete as the team faces operations.
