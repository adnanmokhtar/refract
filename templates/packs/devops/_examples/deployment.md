# Pattern: Deployment

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
