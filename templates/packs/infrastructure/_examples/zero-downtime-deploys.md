# Pattern: Zero-Downtime Deploys

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

### Adding a column (required NOT NULL)

**Phase 1** (with v1 still running):
```sql
ALTER TABLE users ADD COLUMN phone text;  -- nullable
```
v1 ignores it.

**Phase 2** (deploy v2): v2 writes to `phone` on every write.

**Phase 3** (after v2 stable, backfill): `UPDATE users SET phone = '...' WHERE phone IS NULL;` (batched).

**Phase 4** (migration): `ALTER TABLE users ALTER COLUMN phone SET NOT NULL;`

### Renaming a column

**Phase 1**: add new column.
**Phase 2**: dual-write (app writes to both old + new).
**Phase 3**: backfill old → new.
**Phase 4**: switch reads to new.
**Phase 5**: drop old column.

Each phase is its own deploy. Don't skip.

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
- DB migrations that break the previous version.
- Rollback plan designed AFTER the failure.
- Manual deploys bypassing CI/CD.
- Ignoring graceful shutdown (dropped requests).
- Feature flags with no TTL / cleanup plan.
- Canary without automated gating (manual watching = human error at 3am).
