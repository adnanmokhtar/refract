---
name: deployment
description: Pattern: Deployment
kind: ai-pattern
pack: devops
---

# Pattern: Deployment

> **Hard rule** — Every deploy is from an immutable artifact, reversible by one command, and gated by automated smoke tests on staging. Hand-edits on prod, `:latest` tags, and Friday-afternoon prod deploys (without explicit override) are forbidden.

**When to apply**
- Service has a separate staging environment that mirrors prod topology.
- Migration vs code ordering is declared per change (BEFORE-code or AFTER-code).
- Rollback can complete within an SLO-relevant time window.

**When NOT to apply**
- Local dev only, no remote target.
- One-off scripts run by hand with no audit requirement.
- Greenfield project before any environment exists — set up environments first.

**Halt conditions / mandatory cites**
- Cite the rollback runbook as `<path>` (`ai/runbooks/rollback.md`) before promoting to prod; missing runbook is a halt.
- Cite the migration ordering declaration in the PR / ADR as `<path:line>` for any schema change; "TBD ordering" is a halt.
- Cite the secrets-manager binding as `<path:line>` for any new env var; secrets in `.env` shipped to prod is forbidden.
- Cite the `/ready` health-check handler as `<path:line>` before traffic is shifted; if missing, halt.
- Hand-wave grep ban — never claim "no manual prod changes" without citing the audit-log query or change-management record path.

Zero-downtime. Reversible. Automated. No hand-edits on prod.

## Pipeline

```
PR merged to main
  ├─ CI: lint + typecheck + test + build
  ├─ Build artifact (Docker image / bundle / binary)
  ├─ Push to registry / artifact store
  ├─ Deploy to staging
  ├─ Smoke test staging (automated)
  ├─ Manual approval (or tag-based) → promote to prod
  ├─ Migrations run (backward-compatible)
  ├─ Rolling deploy of app instances
  ├─ Health check → traffic shifts
  └─ Old instances terminated
```

## Migrations vs code ordering

Two patterns — pick ONE and declare it:

**Migrations BEFORE code (backward-compatible):**
- Migration adds new column (nullable).
- Old code ignores new column.
- New code reads + writes new column.
- Works for: additive changes, rolling deploys.

**Migrations AFTER code (forward-compatible):**
- New code deploys first, understands both old + new schema.
- Migration runs once all instances updated.
- Works for: breaking changes, big-bang deploys.

NEVER mix. Declare per migration.

## Rollback

Must be ONE command (`fly deploy --image <prev-tag>` / `kubectl rollout undo` / etc.).

- Rolling back schema is harder than rolling back code — plan migrations for zero-downtime FORWARD + accept that schema rollback is rare.
- Keep last 3 deployments' artifacts ready.
- Rollback runbook at `ai/runbooks/rollback.md`.

## Health checks

Every service exposes:
- `GET /health` — liveness (is the process up?)
- `GET /ready` — readiness (can it serve traffic? DB up, cache up, migrations complete?)

Load balancer checks `/ready` before routing. `/health` triggers restart on failure.

## Secrets

- Dev: `.env` (gitignored), `.env.example` committed.
- Prod: secrets manager (AWS SM / Vault / fly secrets / Doppler).
- NEVER in code, logs, or Docker layers.
- Rotated on compromise or quarterly — whichever sooner.

## Observability

- Logs: JSON, shipped to centralized sink.
- Metrics: rate / errors / duration (RED) per endpoint.
- Traces: correlation id flows through every service.
- Alerts: error rate spike, p95 latency regression, saturation, SLO burn.

## Forbidden

- Deploying on Friday afternoon (empirically high rollback rate).
- Manual changes on prod servers.
- Deploying untested migrations to prod.
- Skipping staging.
- Merging to main without CI green.
- Secrets in Docker image layers (use runtime injection).
- `:latest` image tags in production.
