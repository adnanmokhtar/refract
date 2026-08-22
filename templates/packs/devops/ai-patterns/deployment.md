---
name: deployment
description: Pattern: Deployment
kind: ai-pattern
pack: devops
---

# Pattern: Deployment

> **Hard rule** — Every deploy is from an immutable artifact, reversible by one command, and gated by automated smoke tests on staging. Hand-edits on prod and `:latest` tags are forbidden. A deploy nobody is willing to make on a Friday afternoon is a deploy path that is not actually safe on a Tuesday either — fix the path (rehearsed rollback, monitoring window, expand-contract sequencing), don't move the calendar.

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
- Cite the migration ordering declaration in the PR / ADR as `<path:line>` for any schema change — additive / destructive / which step of an expand-contract sequence. "TBD ordering" is a halt, and so is "expand-contract" with no step named.
- Cite the secrets-manager binding as `<path:line>` for any new env var; secrets in `.env` shipped to prod is forbidden.
- Cite the **readiness** handler as `<path:line>` before traffic is shifted (whatever the project names it) and confirm it is distinct from liveness; if missing, or if one handler serves both, halt.
- Hand-wave grep ban — never claim "no manual prod changes" without citing the audit-log query or change-management record path.

Zero-downtime. Reversible. Automated. No hand-edits on prod.

## Pipeline

```
PR merged to main
  ├─ CI: lint + typecheck + test + build
  ├─ Build artifact (Docker image / bundle / binary)
  ├─ Scan the artifact, THEN push to registry / artifact store
  │    (scanning after publish gates the deploy, not the artifact)
  ├─ Deploy to staging
  ├─ Smoke test staging (automated)
  ├─ Manual approval (or tag-based) → promote to prod
  ├─ Migrations run (backward-compatible)
  ├─ Rolling deploy of app instances
  ├─ Health check → traffic shifts
  └─ Old instances terminated
```

## Migrations vs code ordering

**The invariant, and the only one that matters:** during a rolling deploy, old and new code run at
the same time against one schema. Every ordering rule below is a consequence of that. So the
question is never "before or after" in the abstract — it is *which of the two versions is the one
that would break*, and you sequence to protect it.

| The change is | Order | Because |
|---|---|---|
| **Additive** — new nullable column, new table, new index | Migration **before** code | Old code ignores what it doesn't select; new code finds it already there. Safe in both directions |
| **Destructive** — drop, rename, narrow a type, add `NOT NULL` | Migration **after** the code that stopped depending on it has fully rolled out | Run it first and the old replicas still serving traffic query something that no longer exists |
| **Both at once** — a rename, a type change, a column moving | Neither. It is **two releases**, see below | There is no single ordering that is safe for a rename, which is why the naive "pick one" framing fails here |

### Expand-contract is deliberately both, sequenced

A breaking change is not an ordering choice — it is a *decomposition*. You turn one unsafe change
into a sequence of individually safe ones, and the sequence spans at least two deploys:

```
expand    → migration adds the new shape alongside the old (additive: safe before code)
backfill  → data copied to the new shape, in batches, while both are readable
deploy    → code writes BOTH shapes and reads the new one
            ── verify: no reader of the old shape remains (grep + query logs + wait) ──
contract  → migration drops the old shape (destructive: safe only now, in a LATER deploy)
```

The `contract` step is what makes the earlier deploys un-rollbackable, so it belongs in its own
release, after the code that stopped reading the old shape has been running long enough that you
would roll it back to a revision which also does not read it. `devops-principles` mandates this
sequence; `infrastructure/ai-patterns/zero-downtime-deploys.md` gives the phase-by-phase SQL when
that pack is installed.

**Declare, per migration:** which of the three rows above it is, and — if it is a decomposition —
which step of the sequence *this* PR is. A PR that says "expand-contract" without saying which step
it contains is the one that ships expand and contract together.

## Rollback

Must be ONE command (`fly deploy --image <prev-digest>` / `kubectl rollout undo` / etc.) — and
**rolling back the code does not roll back anything else**. The schema, the cache, the queue and the
flag store all stay where the bad deploy left them, which is why `/rollback-deploy` gates on the
migration direction *before* it reverts rather than reconciling after.

- Rolling back schema is harder than rolling back code — plan migrations for zero-downtime FORWARD
  and accept that schema rollback is rare. The `contract` step above is the one that removes the
  rollback path; that is its real cost, and the reason it ships alone.
- Retain enough prior artifacts that a rollback target exists — check the retention that actually
  applies (K8s `revisionHistoryLimit`, the registry's retention policy), because "keep the last N"
  is a setting somewhere, not a habit.
- The previous artifact must be addressable by an **immutable** reference. If the last deploy used a
  moving tag, that tag now points at the bad build and "roll back to the previous tag" is a no-op.
- Rollback runbook at `ai/runbooks/rollback.md`.

## Health checks

Two endpoints because there are two questions, and one endpoint answering both is the defect:

- **Liveness** — is the process alive? A failure here means *restart me*. It must not check
  downstreams: if liveness fails when the database is briefly unreachable, a transient outage
  becomes a restart loop that guarantees a real one.
- **Readiness** — can this instance serve traffic right now? DB reachable, cache warm, migrations
  applied. A failure here means *stop routing to me*, not restart. The load balancer / service
  gates on this.

**Paths follow the project, not this document.** Mirror whatever the service already exposes; for a
new service the pack default is `/healthz` (liveness) and `/readyz` (readiness), per
`devops-principles`. Whatever it is, it is recorded once — `/dockerize` captures it as `$HEALTH_PATH`
and `monitor-deploy` resolves it rather than assuming — so no tool in the pack hardcodes a path.

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

## Review checklist

Run on any PR that touches a migration, a manifest, a Dockerfile, or a deploy job. It lives here
rather than in the always-loaded rule because it is a checklist for *this* moment, not an invariant
to carry into every task.

- [ ] Migration classified — additive / destructive / which step of an expand-contract sequence.
- [ ] If destructive: the code that stopped reading the old shape is already deployed and has been
      running long enough that a rollback target also doesn't read it.
- [ ] Migration reviewed for lock impact on the tables it touches — a long exclusive lock on a large
      table freezes the app for its duration. The database pack's tooling owns the specifics; what
      this checklist asks is that someone looked, and named the expected lock and duration.
- [ ] Reversible, or a documented forward-fix exists and is faster than the outage it prevents.
- [ ] No secrets in the diff (`git diff | gitleaks detect --pipe`).
- [ ] Liveness and readiness both declared, and distinct.
- [ ] Container runs as non-root in the **final** stage.
- [ ] Image built from a pinned base that is still receiving upstream security patches.
- [ ] Deployed reference is immutable (digest or git SHA), so a rollback target exists.
- [ ] CI green on lint, type, test, build, scan.

## Forbidden

- **Deploying when you could not roll back** — no rehearsed rollback path, no monitoring window, or
  nobody available to watch it. This is what a "no Friday deploys" rule is actually protecting
  against; the calendar version treats the symptom and leaves the unsafe path in place Monday
  through Thursday.
- Shipping `expand` and `contract` in the same release — that is the un-rollbackable deploy, whatever
  day it goes out.
- Manual changes on prod servers.
- Deploying untested migrations to prod.
- Skipping staging.
- Merging to main without CI green.
- Secrets in Docker image layers (use runtime injection).
- `:latest` image tags in production.
- A liveness probe that checks a downstream — it converts a transient dependency blip into a
  cluster-wide restart loop.
