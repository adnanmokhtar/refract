---
name: zero-downtime-deploys
kind: example
pack: infrastructure
---

# Pattern: Zero-Downtime Deploys

> **Hard rule** — DB migrations follow expand-contract over multiple deploys; old + new versions must run simultaneously without breaking. Readiness probes gate traffic; graceful shutdown drains in-flight requests on SIGTERM. Deploy without readiness probe or migration that breaks N-1 is forbidden.

**Halt conditions / mandatory cites**
- Cite the readiness probe config as `<path:line>` (`/ready` endpoint + handler) before claiming zero-downtime; missing probe is a halt.
- Cite the migration phase script per step (expand → backfill → contract) as `<path:line>` for renames / NOT-NULL adds; single-shot breaking migrations are forbidden.
- Cite the SIGTERM handler as `<path:line>` proving graceful drain (close server, finish jobs, end DB pool); ungraceful shutdown is a halt.
- Cite the `preStop` delay (or the platform's equivalent connection-draining setting) before claiming zero-downtime on a rolling update. Endpoint removal and SIGTERM are issued in parallel, so a readiness probe alone does NOT prove requests are not dropped.
- Cite the migration's lock profile per statement: which lock it takes and whether it scans the table. A schema change with no stated lock profile is a halt, not a pass.
- Cite the rollback runbook (`ai/runbooks/rollback-<service>.md`) by path; rollback designed after the fact is a halt.
- Hand-wave grep ban — never claim "all migrations are backward-compatible" without citing the migration directory listing + lint rule.

Users don't care that you shipped. They notice when you break. Every deploy strategy has tradeoffs.

## Strategies

### Rolling update (most common)

Replace old pods/instances one (or few) at a time. Old + new run simultaneously during rollout.

```
[v1][v1][v1][v1]   →   [v2][v1][v1][v1]   →   [v2][v2][v1][v1]   →   [v2][v2][v2][v2]
```

**Pros**: simple, low resource overhead, managed by K8s/ECS/Swarm natively.
**Cons**: partial rollout = mixed versions. Requires backward-compatible APIs + DB schema.

**Config (K8s)**:
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1          # one extra pod during rollout
    maxUnavailable: 0    # never fewer than replicas
```

### Blue-green

Run TWO full environments. Switch traffic atomically.

```
Blue (v1) serving traffic     →     Blue (v1) idle, Green (v2) serving
```

**Pros**: instant rollback (flip back). Clean separation — no mixed versions.
**Cons**: 2x resource cost during deploy. DB migrations still need compatibility.

**Implementation**:
- Run two deployments, two Services.
- Ingress / DNS / LB points to blue initially.
- Deploy green. Smoke test.
- Switch traffic: update Ingress or LB target.
- Keep blue idle for N minutes — if green misbehaves, flip back instantly.

### Canary

Gradual rollout — 1% → 10% → 50% → 100%. Gated by metrics.

```
[v1 × 100%]  →  [v1 × 99%, v2 × 1%]  →  [v1 × 90%, v2 × 10%]  →  [v2 × 100%]
```

**Pros**: early detection of issues in prod-like conditions. Bad canary rolls back before full blast.
**Cons**: requires traffic splitting (Ingress / service mesh / Argo Rollouts / Flagger). Mixed versions longer.

**Gating signals** (auto-rollback):
- Error rate on canary > X% above baseline.
- p95 latency > Y% above baseline.
- Business metric (conversions, orders) not recovering.

### Dark launch / feature flag

Ship the code, keep the feature OFF. Enable per user / tenant / percentage.

**Pros**: decouple deploy from release. Instant rollback without redeploy.
**Cons**: code complexity (conditional paths). Flag tech debt. Cleanup discipline required.

### Shadow traffic

Send a copy of real traffic to v2 without using its response.

**Pros**: realistic load testing without user impact.
**Cons**: read-only workloads only — shadowed writes cause duplicates.

## Choosing

| Scenario | Strategy |
|---|---|
| Standard stateless service | Rolling update |
| High-risk change, need instant rollback | Blue-green |
| Performance-sensitive change, gradual validation | Canary |
| Behavior change for a subset of users | Feature flag |
| Validating performance under real load | Shadow |

## DB migrations (expand-contract)

NEVER break the old version's DB expectations. Apply migrations in phases that keep BOTH versions working.

**The lock is the outage, not the migration.** A statement holding `ACCESS EXCLUSIVE` blocks every read and write on the table for as long as it runs, and a statement that scans the table runs for as long as the table is big. Set `lock_timeout` on every migration session so a blocked statement fails fast instead of queueing every query behind it.

### Adding a column (required NOT NULL)

**Phase 1** (with v1 still running):
```sql
ALTER TABLE users ADD COLUMN phone text;  -- nullable
```
v1 ignores it.

**Phase 2** (deploy v2): v2 writes to `phone` on every write.

**Phase 3** (after v2 stable, backfill): `UPDATE users SET phone = '...' WHERE phone IS NULL;` (batched).

**Phase 4** (make it NOT NULL — the step people get wrong):

A bare `ALTER TABLE users ALTER COLUMN phone SET NOT NULL;` takes `ACCESS EXCLUSIVE` **and scans the whole table** to prove no NULLs exist — on a large table that is the app-freezing outage this pattern exists to prevent. PostgreSQL documents the way out: *"if a valid CHECK constraint exists (and is not dropped in the same command) which proves no NULL can exist, then the table scan is skipped"*, and `VALIDATE CONSTRAINT` *"acquires only a SHARE UPDATE EXCLUSIVE lock"* (https://www.postgresql.org/docs/current/sql-altertable.html):

```sql
-- 4a: add the proof, unvalidated — fast, no scan
ALTER TABLE users ADD CONSTRAINT users_phone_not_null CHECK (phone IS NOT NULL) NOT VALID;
-- 4b: validate — scans, but under SHARE UPDATE EXCLUSIVE, so reads and writes continue
ALTER TABLE users VALIDATE CONSTRAINT users_phone_not_null;
-- 4c: the scan is now skipped, so this is a brief catalog-only lock
ALTER TABLE users ALTER COLUMN phone SET NOT NULL;
```

Other engines have their own equivalents; the principle transfers — find the form that avoids a full scan under an exclusive lock, and verify it in the engine's own docs before running it on prod.

### Adding an index

`CREATE INDEX` blocks writes for the duration of the build. Use the engine's concurrent form (`CREATE INDEX CONCURRENTLY` in PostgreSQL) — no write block, at the cost of two passes and a possible INVALID index to drop and retry on failure. It also cannot run inside a transaction block, which most migration frameworks wrap statements in by default.

### Renaming a column

**Phase 1**: add new column.
**Phase 2**: dual-write (app writes to both old + new).
**Phase 3**: backfill old → new.
**Phase 4**: switch reads to new.
**Phase 5**: drop old column.

Each phase is its own deploy. Don't skip.

**This sequencing IS the answer to "migration first or code first?"** — expand-contract is deliberately BOTH, ordered across deploys. Any rule forcing one global choice between "migrate then deploy" and "deploy then migrate" cannot express it. Per change: expand steps before the code that needs them, contract steps after the last deploy that could read the old shape.

## Health checks matter

Zero-downtime requires the platform to KNOW when a new instance is ready.

- **Liveness** — is it running? Failure → restart.
- **Readiness** — is it ready for traffic? Failure → remove from LB pool. This is the critical one for deploys.
- **Startup** — for slow-boot apps, gates liveness until first success.

New instance NOT routed until readiness passes. Old instance drained per grace period.

## Graceful shutdown

When a pod is terminated:
1. Receives SIGTERM.
2. App should: stop accepting new requests, finish in-flight, close DB connections.
3. `terminationGracePeriodSeconds` in K8s (default 30s).

```ts
// Node example
process.on('SIGTERM', async () => {
  server.close();              // stop accepting new
  await jobQueue.drain();      // finish jobs
  await db.end();              // close pool
  process.exit(0);
});
```

**The gap: endpoint removal and SIGTERM are issued IN PARALLEL, not in sequence.** Removal from the Service endpoints has to propagate to every proxy and load balancer in the path, while the kubelet has already sent SIGTERM. For that window the pod has stopped accepting connections and traffic is still arriving. That is where "we have readiness probes and a SIGTERM handler and still drop requests on every deploy" comes from — the fault is the ordering, not the app.

```yaml
lifecycle:
  preStop:
    exec: { command: ["sleep", "10"] }   # serve through endpoint-removal propagation
```

- The delay must exceed your propagation time — measure it (watch for 5xx during a rollout) rather than copying a number.
- `terminationGracePeriodSeconds` must exceed preStop delay + real drain time, or the pod is SIGKILLed mid-drain and the dropped requests have only moved.
- Recent Kubernetes minors offer a native `preStop.sleep` action instead of shelling out to `sleep` (which distroless images lack). Confirm on the target minor with `kubectl explain pod.spec.containers.lifecycle.preStop`.

## Rollback

Plan the rollback before the deploy:
- **Rolling** — redeploy previous image SHA. Same rolling mechanism.
- **Blue-green** — flip traffic back. Seconds.
- **Canary** — stop + redirect all traffic to stable. Automated via Argo Rollouts.
- **Feature flag** — flip the flag off. No redeploy.

Rollback time objective (RTO): seconds for flag, minutes for deploy-based.

## Observability during deploys

- Deploy events logged + tagged in dashboards (see a latency spike → was there a deploy?).
- Error rate alerts scoped per version (`app=api, version=v2.0.1`).
- Canary dashboards side-by-side (canary vs stable).

## Forbidden

- Deploys without readiness probes.
- Rolling updates with no `preStop` delay on a Service-backed workload — the parallel endpoint-removal/SIGTERM window drops in-flight requests on every deploy.
- Schema changes run without `lock_timeout` set — a blocked statement queues every query behind it and turns a migration into an outage.
- DB migrations that break the previous version.
- Rollback plan designed AFTER the failure.
- Manual deploys bypassing CI/CD.
- Ignoring graceful shutdown (dropped requests).
- Feature flags with no TTL / cleanup plan.
- Canary without automated gating (manual watching = human error at 3am).
