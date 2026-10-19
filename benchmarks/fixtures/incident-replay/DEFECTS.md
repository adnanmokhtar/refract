# Seeded incidents — `incident-replay`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the agent scans.
If you stage the fixture by hand, delete this file from the copy first — an agent that reads it will
score 100 % and the number will mean nothing.

Fixture shape: ten recorded production incidents, one bundle each under `incidents/<NN>-<slug>/`.
A bundle is what a responder has after the page: `alert.md` (what fired, when, the scope, how it
recovered), `logs/app.log`, `metrics/snapshot.txt` (series sampled across the window),
`deploy/ledger.md` (the deploy ledger rows, `/deploy-stage` Phase 5 shape), usually
`deploy/diff.patch` (the change that shipped before or during the window — innocent in two
bundles), and the minimal code, config, migration or manifest the service runs. Each bundle has
**one labelled root cause** (a line in the tree, not a hunk of the patch) and **one decoy symptom** —
the loud, plausible signal a first-story responder chases: a slow query that predates the incident,
a third-party blip that ended in 40 seconds, an unrelated OOM, the most recent deploy, a CPU rise
that is an effect. Categories span config (4), code (3), data (1), infrastructure (1) and one
gateway policy, so no single prior ("it was the last deploy") wins.

Invocation: /investigate-incident --bundle=incidents/<NN>-<slug>

Run once per bundle, each in the same staged copy (ten investigations, ten `reviews/hypotheses.json`).
Eval source: architecture proposal §9 (`incident-replay`, Phase 7) and §3.4 Investigator ("RCA accuracy
on `incident-replay`"). Bundles are synthetic but every mechanism is a documented failure class with an
owner detector: database `migration-safety` §1, devops `progressive-delivery` §8, distributed-systems
`retry-deadline-scan` §3 and §5, performance `request-path-scan` §12, `/rollback-deploy` R4.

## Scoring RCA accuracy

The scorer is the standard match rule (§ The match rule in `benchmarks/README.md`): a finding counts
for IR-NN when it names IR-NN's file and every `match:` pattern hits its text; a finding pinned to a
decoy's line is a decoy flag and is never credited. RCA is graded on the **adjudicated root cause**,
not on everything an investigation mentioned:

- **RCA accuracy@1** (the headline): one finding per bundle — the hypothesis `/investigate-incident`
  adjudicated (`verdict: supported`; the first one when two are supported), with its
  `root_cause.file`, `root_cause.line` and `hypothesis + root_cause.claim` as the text. Detected /
  10 is the accuracy; `DECOYS FLAGGED k/10` is how often the adjudicated cause was the decoy symptom.
- **RCA accuracy@3**: every hypothesis that carries a `root_cause`, whatever its verdict — did the
  right mechanism appear among the competitors at all? The gap between @3 and @1 is adjudication
  error (the right story was on the table and lost).
- **Hypothesis discipline** (not scored by the match rule; report it beside the row): bundles whose
  `hypotheses.json` holds ≥ 3 hypotheses from ≥ 2 categories, and bundles closed `INCONCLUSIVE`
  (an honest INCONCLUSIVE scores 0 for that bundle but is not a decoy flag).

Paths must be repo-relative (`incidents/01-pool-shrink/config/database.yml`): every bundle has a
`logs/app.log`, so a bare `logs/app.log:17` names ten files and the match rule cannot tell them apart.

```bash
# @1 — one finding per bundle from each investigation's hypotheses.json (staged copy as cwd)
python3 - ai/runs/*/reviews/hypotheses.json > findings.json <<'PY'
import json, sys
out = []
for p in sys.argv[1:]:
    hs = [h for h in json.load(open(p))["hypotheses"] if h["verdict"] == "supported" and "root_cause" in h]
    for h in hs[:1]:                       # drop [:1] for @3, and drop the verdict filter
        rc = h["root_cause"]
        out.append({"file": rc["file"], "line": rc["line"], "text": h["hypothesis"] + " " + rc["claim"]})
print(json.dumps({"findings": out}))
PY
bash benchmarks/run.sh --fixture=incident-replay --score=findings.json -- --model="<id>" --row
```

Record @1, @3, decoy flags and the discipline count with the model id, version and date
(§ Reproducibility). A single run is an anecdote: three runs per bundle, report the spread.

## Summary

| id | root cause (file:line) | category | incident |
|----|------------------------|----------|----------|
| IR-01 | `incidents/01-pool-shrink/config/database.yml:7` | config | Checkout 5xx: requests time out waiting for a database connection |
| IR-02 | `incidents/02-retry-storm/src/payments/provider.client.ts:16` | code | Payments: a 40-second provider blip becomes a 25-minute outage |
| IR-03 | `incidents/03-cache-envelope/accounts/sessions/store.py:11` | code | Sessions: logouts and 500s that a rollback made worse |
| IR-04 | `incidents/04-index-lock/db/migrate/20260714083000_add_status_index_to_orders.rb:3` | data | Checkout writes stall for eleven minutes after a migration |
| IR-05 | `incidents/05-cert-expiry/deploy/k8s/billing-deployment.yaml:23` | infrastructure | Ledger calls fail at midnight UTC right after a web deploy |
| IR-06 | `incidents/06-flag-default/src/pricing/engine-select.ts:9` | config | EU orders charged without VAT while the flag service was down |
| IR-07 | `incidents/07-debug-disk/deploy/helm/search/values.prod.yaml:8` | config | Search pods evicted in waves after a config-only release |
| IR-08 | `incidents/08-timeout-retry/gateway/routes.yaml:10` | config | Duplicate orders during a slow payment window |
| IR-09 | `incidents/09-render-cache-leak/src/server/render-cache.js:8` | code | Storefront SSR pods OOM-killed every ninety minutes |
| IR-10 | `incidents/10-overlapping-cron/deploy/k8s/charge-renewals-cronjob.yaml:7` | config | Subscribers charged twice by the renewal job |

Total 10 seeded root causes, 10 decoy symptoms. Every defect is severity high and scored under
`/investigate-incident`.

## Decoys (must not be reported as the root cause)

| id | file:line | decoy for | why it is not the cause |
|----|-----------|-----------|-------------------------|
| IR-DECOY-01 | `incidents/01-pool-shrink/logs/app.log:10` | IR-01 | The slow tenant-orders query runs at the same 2/hour rate before, during and after the incident (metrics `orders_slow_query_total_per_hour`): a pre-existing condition, not the cause. |
| IR-DECOY-02 | `incidents/02-retry-storm/logs/app.log:2` | IR-02 | The provider outage is real but lasted 40 s (status feed resolved 14:02:50, 503s stop at 14:03); the 25-minute failure is the client's own retry volume. |
| IR-DECOY-03 | `incidents/03-cache-envelope/logs/app.log:2` | IR-03 | The report-worker OOM is real and in the window, but it is another deployment with no traffic path to /settings; accounts pods never restarted. |
| IR-DECOY-04 | `incidents/04-index-lock/logs/app.log:7` | IR-04 | Pool exhaustion is the queue behind the lock (`active_record_pool_waiting` tracks `pg_locks_waiting`), not a cause: the pool size did not change. |
| IR-DECOY-05 | `incidents/05-cert-expiry/deploy/diff.patch:10` | IR-05 | The web deploy is the most recent change, but it touched one CSS variable, finished 19 minutes before onset, and web 5xx only rises as a downstream effect of billing. |
| IR-DECOY-06 | `incidents/06-flag-default/metrics/snapshot.txt:3` | IR-06 | The CPU rise is the heavier engine running, an effect of the flip, not a cause. |
| IR-DECOY-07 | `incidents/07-debug-disk/metrics/snapshot.txt:4` | IR-07 | Memory rises 10 % and then stays flat, far under the 1Gi limit; evictions name ephemeral storage, not memory. |
| IR-DECOY-08 | `incidents/08-timeout-retry/logs/app.log:6` | IR-08 | The unique violation is on order_events, raised by the second insert of an event: a consequence of the duplicate request, not the cause. |
| IR-DECOY-09 | `incidents/09-render-cache-leak/logs/app.log:4` | IR-09 | sharp's corrupt-JPEG warnings run at the same 2-3 per hour before and after 11:00 (`image_resize_errors_per_hour`). |
| IR-DECOY-10 | `incidents/10-overlapping-cron/deploy/diff.patch:14` | IR-10 | The 1.9.0 refactor only moves the loop body into `_renew`; charge-then-mark order is unchanged and the job double-charged only once runs overlapped. |

## IR-01 — Checkout 5xx: requests time out waiting for a database connection

```defect
id:       IR-01
file:     incidents/01-pool-shrink/config/database.yml
line:     7
severity: high
command:  /investigate-incident
class:    incident/config
anchor:   pool: 5
match:    pool|connection
match:    size|5\b|shrank|cut|reduc|smaller|fewer|20|thread|exhaust
```

Release 1.4.0 replaced `pool: <%= ENV.fetch("DB_POOL", 20) %>` with `pool: 5` while Puma runs 32 threads per pod: requests queue past `checkout_timeout: 2` and fail with ConnectionTimeoutError from the minute the rollout finished. Evidence for: onset 70 s after rollout end, Postgres connections fall (84 -> 58) while busy threads rise to 32, Postgres CPU flat, recovery on rollback.

Decoy symptom — The slow tenant-orders query runs at the same 2/hour rate before, during and after the incident (metrics `orders_slow_query_total_per_hour`): a pre-existing condition, not the cause.

```decoy
id:       IR-DECOY-01
file:     incidents/01-pool-shrink/logs/app.log
line:     10
command:  /investigate-incident
class:    decoy/IR-01
anchor:   Slow query (1397.4ms)
match:    slow (query|sql)|index|orders query|query plan
```

## IR-02 — Payments: a 40-second provider blip becomes a 25-minute outage

```defect
id:       IR-02
file:     incidents/02-retry-storm/src/payments/provider.client.ts
line:     16
severity: high
command:  /investigate-incident
class:    incident/code
anchor:   { retries: 8, backoffMs: 0 }
match:    retr(y|ies)
match:    backoff|immediate|no delay|amplif|storm|9x|nine|multipl|rate.?limit|429|jitter
```

3.8.0 wraps capture in nine immediate attempts (`retries: 8, backoffMs: 0`, no jitter, `Retry-After` ignored). A 40-second provider 503 multiplied request rate ~9x, the provider rate-limited the account (429) and the retries kept it limited for 25 minutes after the provider recovered at 14:02:50.

Decoy symptom — The provider outage is real but lasted 40 s (status feed resolved 14:02:50, 503s stop at 14:03); the 25-minute failure is the client's own retry volume.

```decoy
id:       IR-DECOY-02
file:     incidents/02-retry-storm/logs/app.log
line:     2
command:  /investigate-incident
class:    decoy/IR-02
anchor:   upstream 503 from card-provider /captures (attempt 1)
match:    provider (was |is )?(down|outage|degraded|unavailable)|503|status page|third.?party|external
```

## IR-03 — Sessions: logouts and 500s that a rollback made worse

```defect
id:       IR-03
file:     incidents/03-cache-envelope/accounts/sessions/store.py
line:     11
severity: high
command:  /investigate-incident
class:    incident/code
anchor:   return "sess:%s" % sid
match:    serializ|pickle|msgpack|format|envelope|encod
match:    key|namespace|prefix|version|old (pod|code|release|revision)|rollback|mixed|incompatib|both
```

2.3.0 changed the session encoding (pickle -> msgpack envelope) but kept the key `sess:<sid>`: old pods mid-rollout, and every pod after the rollback, read entries the other version wrote and fail to decode them. The cache outlived the artifact, so the rollback restored nothing (rollback-deploy R4). A versioned key (`sess:v2:<sid>`) or a reader that accepts both formats prevents it.

Decoy symptom — The report-worker OOM is real and in the window, but it is another deployment with no traffic path to /settings; accounts pods never restarted.

```decoy
id:       IR-DECOY-03
file:     incidents/03-cache-envelope/logs/app.log
line:     2
command:  /investigate-incident
class:    decoy/IR-03
anchor:   MemoryError while building export batch 311
match:    memory|oom|report.?worker|export
```

## IR-04 — Checkout writes stall for eleven minutes after a migration

```defect
id:       IR-04
file:     incidents/04-index-lock/db/migrate/20260714083000_add_status_index_to_orders.rb
line:     3
severity: high
command:  /investigate-incident
class:    incident/data
anchor:   add_index :orders, :status
match:    index
match:    concurrent|lock|block|share ?lock|writes?|algorithm
```

A plain `add_index` on a 41M-row table takes a SHARE lock for the whole build: every INSERT and UPDATE on orders waits behind it for 687 s while reads continue. `algorithm: :concurrently` with `disable_ddl_transaction!` builds it without blocking writes (database migration-safety §1).

Decoy symptom — Pool exhaustion is the queue behind the lock (`active_record_pool_waiting` tracks `pg_locks_waiting`), not a cause: the pool size did not change.

```decoy
id:       IR-DECOY-04
file:     incidents/04-index-lock/logs/app.log
line:     7
command:  /investigate-incident
class:    decoy/IR-04
anchor:   08:38:55Z WARN  [ar] could not obtain a connection
match:    pool|connection
```

## IR-05 — Ledger calls fail at midnight UTC right after a web deploy

```defect
id:       IR-05
file:     incidents/05-cert-expiry/deploy/k8s/billing-deployment.yaml
line:     23
severity: high
command:  /investigate-incident
class:    incident/infrastructure
anchor:   secretName: ledger-client-tls-2025
match:    cert
match:    expir|renew|365|valid|not ?after|rotat
```

billing's mTLS client certificate is a hand-issued Secret with a 365-day validity and nothing renews it; it expired at 2026-10-19T00:00:00Z and the ledger rejects every handshake from 00:00:03. Fix: a cert-manager Certificate (or the CA's rotation) with renewBefore, plus an expiry alert.

Decoy symptom — The web deploy is the most recent change, but it touched one CSS variable, finished 19 minutes before onset, and web 5xx only rises as a downstream effect of billing.

```decoy
id:       IR-DECOY-05
file:     incidents/05-cert-expiry/deploy/diff.patch
line:     10
command:  /investigate-incident
class:    decoy/IR-05
anchor:   +  --brand-primary: #0b57d0;
match:    deploy|release|rollout|css|theme|web|storefront|colou?r
```

## IR-06 — EU orders charged without VAT while the flag service was down

```defect
id:       IR-06
file:     incidents/06-flag-default/src/pricing/engine-select.ts
line:     9
severity: high
command:  /investigate-incident
class:    incident/config
anchor:   getBooleanValue('new-pricing-engine', true, ctx)
match:    default|fallback
match:    true|on|enabl|unfinished|next.?engine|outage|unavailable|flagd|provider
```

The OpenFeature call's default is `true`, so when flagd went down (OOMKilled) the SDK served the default and turned the unfinished engine on for everyone. The flag registry said OFF; the code's fallback said ON. A default of `false` (the old path) keeps a provider outage harmless (devops progressive-delivery §8).

Decoy symptom — The CPU rise is the heavier engine running, an effect of the flip, not a cause.

```decoy
id:       IR-DECOY-06
file:     incidents/06-flag-default/metrics/snapshot.txt
line:     3
command:  /investigate-incident
class:    decoy/IR-06
anchor:   pricing_cpu_utilisation
match:    cpu|load|saturat|capacity|scal
```

## IR-07 — Search pods evicted in waves after a config-only release

```defect
id:       IR-07
file:     incidents/07-debug-disk/deploy/helm/search/values.prod.yaml
line:     8
severity: high
command:  /investigate-incident
class:    incident/config
anchor:   LOG_LEVEL: debug
match:    debug|log
match:    disk|storage|ephemeral|evict|fill|volume|rotat
```

2.6.1 set `LOG_LEVEL: debug` with file logging and no rotation: each pod writes ~2,900 lines/s to its ephemeral storage and is evicted when it passes the 2Gi limit, in waves as pods reach it.

Decoy symptom — Memory rises 10 % and then stays flat, far under the 1Gi limit; evictions name ephemeral storage, not memory.

```decoy
id:       IR-DECOY-07
file:     incidents/07-debug-disk/metrics/snapshot.txt
line:     4
command:  /investigate-incident
class:    decoy/IR-07
anchor:   container_memory_working_set_bytes (max)
match:    memory|leak|oom|heap
```

## IR-08 — Duplicate orders during a slow payment window

```defect
id:       IR-08
file:     incidents/08-timeout-retry/gateway/routes.yaml
line:     10
severity: high
command:  /investigate-incident
class:    incident/config
anchor:   retry_on: 5xx,reset,connect-failure,gateway-error
match:    retr(y|ies)
match:    timeout|5 ?s|post|non.?idempotent|duplicate|idempoten
```

The edge retries POST /orders after a 5 s per-attempt timeout, while orders-api keeps working on the first attempt (payment read timeout 15 s) and has idempotency off: every payment call slower than 5 s creates the order twice. A retry belongs only on idempotent requests, or with an idempotency key the service honours (distributed-systems retry-deadline-scan §5, §8).

Decoy symptom — The unique violation is on order_events, raised by the second insert of an event: a consequence of the duplicate request, not the cause.

```decoy
id:       IR-DECOY-08
file:     incidents/08-timeout-retry/logs/app.log
line:     6
command:  /investigate-incident
class:    decoy/IR-08
anchor:   violates unique constraint "order_events_pkey"
match:    unique|constraint|database|db|primary key|duplicate key
```

## IR-09 — Storefront SSR pods OOM-killed every ninety minutes

```defect
id:       IR-09
file:     incidents/09-render-cache-leak/src/server/render-cache.js
line:     8
severity: high
command:  /investigate-incident
class:    incident/code
anchor:   cache.set(req.originalUrl, html);
match:    cache|map
match:    unbounded|grow|leak|evict|ttl|lru|query|utm|url|key
```

The SSR cache is an unbounded Map keyed by the full URL, query string included. The campaign's links carry a per-recipient `rid`, so every visit is a new key: entries grow to ~400k per pod, the hit ratio collapses, and the heap reaches the 1.5Gi limit every ~90 min. Key on the path plus the parameters that change the page, and bound the cache (LRU with max size).

Decoy symptom — sharp's corrupt-JPEG warnings run at the same 2-3 per hour before and after 11:00 (`image_resize_errors_per_hour`).

```decoy
id:       IR-DECOY-09
file:     incidents/09-render-cache-leak/logs/app.log
line:     4
command:  /investigate-incident
class:    decoy/IR-09
anchor:   sharp: VipsJpeg: Premature end of JPEG file (upload u-7802)
match:    sharp|image|jpeg|resize|native|libvips
```

## IR-10 — Subscribers charged twice by the renewal job

```defect
id:       IR-10
file:     incidents/10-overlapping-cron/deploy/k8s/charge-renewals-cronjob.yaml
line:     7
severity: high
command:  /investigate-incident
class:    incident/config
anchor:   concurrencyPolicy: Allow
match:    concurren|overlap|parallel|two (jobs|runs)|simultaneous
match:    allow|forbid|cron|schedule|10.?min|duration|longer
```

The job runs every 10 minutes with `concurrencyPolicy: Allow` (the Kubernetes default) and no claim on each subscription; once January's growth pushed a run past 10 minutes (590 s -> 830 s), two runs overlapped and both charged the subscriptions still marked unrenewed. `Forbid`, plus a per-subscription claim or an idempotency key on the charge, prevents it.

Decoy symptom — The 1.9.0 refactor only moves the loop body into `_renew`; charge-then-mark order is unchanged and the job double-charged only once runs overlapped.

```decoy
id:       IR-DECOY-10
file:     incidents/10-overlapping-cron/deploy/diff.patch
line:     14
command:  /investigate-incident
class:    decoy/IR-10
anchor:   +def _renew(sub):
match:    refactor|extract|_renew|1\.9\.0|deploy|release|regress
```
