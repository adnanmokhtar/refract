---
name: chaos-test
description: Inject failures (network, latency, crashes) against a running service to verify resilience. Find the cracks before prod does.
---

# chaos-test

Prove resilience by breaking dependencies on purpose. Unit tests don't cover "Redis is down for 60 seconds".

## Premise

Real signals only. Every "PASSED" / "FAILED" cites a measured baseline + during-chaos + after-recovery comparison from the actual run. Hypothesis stated upfront with concrete numbers (error rate, p99). The fault injection cites the exact tool command (`toxiproxy-cli toxic add ...`, `kubectl apply -f ...`). Root cause cites `<path:line>` of the code that failed under contention. No "should be resilient" conclusions — either the metrics show it held, or they don't.

## Halt conditions

- Refuse to declare "resilient" without baseline + during-chaos + recovery numbers captured.
- Refuse to run chaos in prod without explicit window + customer comms confirmed.
- Halt if synthetic load is < 10% of prod RPS — failure modes won't surface.
- Don't claim a fix works without re-running the same experiment after the patch.
- Always verify cleanup of chaos rules (`toxiproxy-cli list`, `kubectl get networkchaos`) after each run.

## When to use

- After adding a new external dependency (cache, queue, third-party API).
- Before promoting a service to a higher SLO tier.
- Before a high-traffic event (sale, campaign, launch).
- After incidents to verify the fix actually closes the failure mode.

## Prerequisites

- Running service in **STAGING** with realistic data + traffic generator.
- One of these chaos tools installed:
  - `toxiproxy` (`brew install toxiproxy` — homebrew-core; the old `shopify/shopify` tap path is retired) — TCP-layer faults.
  - `pumba` — Docker-container chaos (kill, pause, netem).
  - `chaos-mesh` — Kubernetes-native chaos (network partitions, pod kills).
  - `gremlin` — SaaS chaos with prod-grade safety.
- Observability: metrics dashboard (Grafana/Datadog) + structured logs to confirm hypotheses.
- Approved blast-radius limits + a "stop button" (revoke the chaos rule).

## Procedure (one experiment at a time)

1. Pick **one** hypothesis: "If Redis is unavailable for 60s, the app serves cached data from DB and error rate stays < 1%."
2. Define success criteria — concrete numbers: error rate < 1%, p99 < 2x baseline, no page errors visible to user.
3. Capture baseline (5 minutes of synthetic load with no chaos):
   ```bash
   k6 run --duration 5m --vus 50 load.js | tee baseline.txt
   ```
4. Inject the failure with a precise scope:
   ```bash
   # toxiproxy: cut Redis for 60s
   toxiproxy-cli toxic add redis -t timeout -a timeout=0 --downstream
   sleep 60
   toxiproxy-cli toxic remove redis -n timeout_downstream

   # pumba: kill one container at random
   pumba kill --signal SIGKILL re2:^api-

   # chaos-mesh: NetworkChaos manifest
   kubectl apply -f experiments/redis-partition.yaml
   ```
5. Run the same load profile during the experiment.
6. Compare metrics during the window: error rate, p50/p95/p99, retry counts, queue depths, DB pool usage, log-level mix.
7. Record the verdict — hypothesis HOLDS or FAILED — and either close out or file a fix.
8. Re-run after the fix to confirm.

## Experiment catalogue

**Network**
- 500ms added latency on DB calls → does p95 stay within SLO?
- 5% packet loss on external API → do retries kick in, or does it hang?
- Full disconnect for 60s → does circuit breaker open + recover?

**Dependencies**
- Kill Redis → cache fallback works? error rate stays low?
- Kill one DB replica → traffic fails over without read errors?
- Exhaust DB connection pool → graceful 503 or hard crash?

**Process**
- Random pod kill → in-flight requests drain or drop?
- OOM kill → auto-restart works + alerts fire?
- Deploy during load → zero-downtime verified?

## Output

```
Experiment: Redis outage for 60s (toxiproxy timeout)
Hypothesis: error rate < 1%, p99 < 2x baseline (200ms), zero user-visible errors.

Baseline (5m, 50 VUs):     error 0.02%   p50 38ms   p95 88ms   p99 121ms
During chaos (60s):        error 18%     p50 410ms  p95 1.8s   p99 4.2s    FAILED
After recovery (5m):       error 0.04%   p50 41ms   p95 92ms   p99 130ms

Root cause:
  Fallback path calls DB without timeout; pool exhausted under retry storm.

Action items:
  1. Add 200ms timeout on the DB fallback path (src/modules/cache/fallback.ts).
  2. Cap concurrent DB calls during Redis outage with a bulkhead.
  3. Re-run experiment after fix — must show error rate < 1%.
```

## False positives / gotchas

- Synthetic load that doesn't match prod traffic shape gives misleading results — record and replay real traces if possible.
- Chaos in dev with `--vus 5` tests almost nothing — failure modes appear under contention.
- Chaos tools often leak rules if killed mid-run — always verify cleanup with `toxiproxy-cli list` / `kubectl get networkchaos`.
- Never run destructive chaos on prod without an explicit window + customer comms — even "safe" experiments have surprised teams.
- A single passing run isn't proof — re-run weekly. Drift in dependencies turns a green experiment red.
