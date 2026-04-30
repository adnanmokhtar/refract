---
description: Profile a slow endpoint / page / flow. Identify the dominant bottleneck (CPU / IO / network / lock contention / GC). Output: targeted fix proposals ranked by impact.
---

# /profile-perf

## The Premise (read this first, internalize, do not deviate)

**The bottleneck is real. The pattern almost always repeats — same import / same query / same render path.** An N+1 in `orders.list` is an N+1 in `invoices.list` and `customers.list` because they share the same loader shape. A sequential `await` in one Stripe enrichment is a sequential `await` in every enrichment that copy-pasted from it. A regex compiled-per-call in `validate.ts` is compiled-per-call wherever the project's "validate inline" idiom landed. The profile's job is to find ONE concrete hot path with measurement, then **scan for the same shape across the rest of the codebase** before reporting.

**The agent's job is exactly this:**
1. Profile the slow subject under representative load (CPU / IO / network / GC axes).
2. Identify the dominant cause with `<file:line>` + ms attribution + flame-graph evidence.
3. **Scan for the same pattern.** `grep` the loader, the await-in-loop, the per-call compile. Count occurrences. Report N — not 1.
4. Propose targeted fixes ranked by impact / effort, citing every site.

**The agent does NOT:**
- Guess. "I think it's the DB" without a profile is forbidden.
- Stop at the first hot function. The pattern that produced it usually shows up in 3-10 more places.
- Optimize a 1%-of-time function because it looked ugly in the flame graph.
- Ship "should be faster" without before/after measurement.

**Closure verbs (mandatory per finding):**
- `report-with-fix` — profile evidence + `<file:line>` + sibling-occurrence count + concrete patch sketch + impact estimate.
- `report-flagged` — profile confirms hot, but fix needs schema change / cross-service work / architectural ADR; surfaced for review.
- `dismiss` — profiled, NOT a real bottleneck against budget; documented so the next pass doesn't re-flag it.

**Mechanical halt (similar-pattern scan accounting):**

Before writing the report, the agent MUST resolve this equation for every finding class:

```
N_found  ==  N_fixed  +  N_explained  +  N_followup
```

- `N_found` — every site where the bottleneck pattern (N+1 loader / sequential await / per-call compile / sync FS read / unbounded fan-out) appears.
- `N_fixed` — sites the report's targeted fixes actually cover.
- `N_explained` — sites legitimately exempt (cold path, admin tool, batch nightly, low-cardinality).
- `N_followup` — sites parked to a follow-up ticket with rationale.

If the equation does not balance, HALT and re-scan. **Hand-wave grep ("probably the same elsewhere") is forbidden** — every count is an actual occurrence list with file paths.

**Lightweight default:** if the profile finds < 3 sites for a pattern AND the aggregate impact is < 50 ms P95, close with `dismiss` and skip the full report section — note in `Out of scope`. Don't promote sub-budget findings to top-line bottlenecks.

Use when something is slow + you don't know why. Avoids the trap of optimizing-the-wrong-thing.

## Phases applied

1, 2, 3, 4, 6 (skips Update/Improve — read-only audit + fix proposal).

## When to use / NOT to use

- USE: P95 latency on a specific path exceeded budget.
- USE: user-reported "feels slow" (subjective, valid).
- USE: post-deploy regression in a known-good metric.
- USE: cost spike traced to compute hours.
- NOT: bundle / startup perf (mobile) → `/optimize-bundle`.
- NOT: DB query specifically → `database/optimize-query`.

## Phase 1 — Understand

Confirm:
- Subject: endpoint path, page route, background job, batch process.
- Budget: P50 / P95 / P99 latency targets.
- Current measurement: actual P50 / P95 / P99 over last 24h or representative window.
- Environment: production-like? Synthetic test?
- Reproducibility: does it manifest under specific conditions (cold cache, specific tenant, large dataset, peak hours)?

## Phase 2 — Organize

Profile across 5 axes in parallel:

1. **Wall-clock breakdown** — what fraction is CPU vs IO vs network vs idle?
2. **CPU profiling** — flame graph; hottest functions.
3. **IO profiling** — DB queries, cache hits/misses, file I/O.
4. **Network profiling** — external API calls; latency per call; sequential vs parallel.
5. **Memory + GC** — allocation rate; GC pause frequency + duration.

## Phase 3 — Retrieve

Tools by ecosystem:

| Stack | CPU profile | IO profile | Network |
|---|---|---|---|
| Node.js | `--prof` + `0x`, Clinic.js | `pino-http` + APM | OpenTelemetry |
| Python | `py-spy`, `cProfile`, `pyinstrument` | SQL log + APM | OpenTelemetry |
| Go | `pprof` (CPU + heap + goroutine + mutex) | `database/sql` traces | net/http/httptrace |
| Java | JFR + Mission Control, async-profiler | JDBC events | OpenTelemetry |
| Rust | `perf`, `flamegraph` | tracing crate | tracing-opentelemetry |
| Ruby | `stackprof`, `rbspy` | rack-mini-profiler | Skylight |
| .NET | dotnet-trace, dotMemory | EF Core logs | OpenTelemetry |
| Browser | Chrome DevTools Performance, Lighthouse | DevTools Network | DevTools Network |

Read project's:
- APM / tracing / metrics dashboards (Datadog / New Relic / Grafana / Honeycomb / Jaeger).
- Last successful baseline metrics if any.
- `ai/runtime/perf-budgets.md` if exists.

## Phase 4 — Generate (the report)

```
## Perf profile — <subject> — <date>

### Subject
- Path / endpoint / job: <name>
- Budget: P95 ≤ <ms>; current P95 = <ms>
- Reproduce: <steps>

### Wall-clock breakdown (median of N=<count> requests)
- CPU:      <ms>  (<%>)
- DB IO:    <ms>  (<%>)
- Cache:    <ms>  (<%>)
- External: <ms>  (<%>)
- Other:    <ms>  (<%>)

Dominant: <e.g., DB IO 68%>

### CPU profile (top 10 hottest)
[flame graph link OR table]
| Function | Self time | Cum time |
|---|---|---|
| processOrders | 240 ms | 380 ms |
| validateInput | 120 ms | 120 ms |

Hot path: processOrders → validateInput is doing per-item regex against unconstrained input. ~240 ms self time.

### DB profile
| Query | Count | Avg | P95 | Total |
|---|---|---|---|---|
| SELECT * FROM orders WHERE tenant_id=$1 | 1 | 12 ms | 18 ms | 12 ms |
| SELECT * FROM order_items WHERE order_id=$1 | 100 | 4 ms | 8 ms | 400 ms |  ← N+1!

N+1 detected: query #2 fires once per order returned by query #1.

### External calls
| Endpoint | Count | Avg | Sequential? |
|---|---|---|---|
| stripe/charges/get | 50 | 80 ms | YES — total 4000 ms wall |
| sendgrid/send | 1 | 200 ms | n/a |

50 sequential awaits of independent calls. With Promise.all → ~80 ms total instead of 4000 ms.

### Memory + GC
- Allocation rate: <MB/s>
- GC pause P99: <ms>
- Heap headroom: <%>

No GC pressure; not a contributor here.

### Bottleneck ranking (by impact on P95)

| # | Cause | Current contribution | Fixed contribution | Effort |
|---|---|---|---|---|
| 1 | N+1 DB query (order_items) | 400 ms | 12 ms (single JOIN) | 1h |
| 2 | Sequential Stripe awaits | 4000 ms | 80 ms (Promise.all + 10-bound) | 2h |
| 3 | Per-item regex validation | 240 ms | 50 ms (compile once + skip on N most-trusted fields) | 4h |

### Targeted fixes (ranked by impact / effort)

#### Fix 1 (highest impact / lowest effort) — N+1 query
File: `src/orders/list.ts:42`
```sql
-- Before
SELECT * FROM orders WHERE tenant_id = $1
-- Then per-order:
SELECT * FROM order_items WHERE order_id = $1

-- After
SELECT o.*, json_agg(oi.*) as items
FROM orders o LEFT JOIN order_items oi ON oi.order_id = o.id
WHERE o.tenant_id = $1
GROUP BY o.id
```
Impact: -388 ms P95.
Effort: 1 hour incl. test update.
Risk: low (preserves API shape).

#### Fix 2 — Parallel Stripe calls
File: `src/orders/enrich.ts:88`
```ts
// Before
for (const order of orders) {
  order.charge = await stripe.charges.retrieve(order.chargeId)
}

// After (bounded parallel via p-limit)
import pLimit from 'p-limit'
const limit = pLimit(10)
await Promise.all(orders.map(o =>
  limit(async () => o.charge = await stripe.charges.retrieve(o.chargeId))
))
```
Impact: -3920 ms P95.
Effort: 2 hours incl. testing rate-limit handling.
Risk: medium (Stripe rate limits; must validate behavior under burst).

#### Fix 3 — Regex compile-once
File: `src/orders/validate.ts:14`
```ts
// Before — compiled per call
const isValid = (s) => /^[A-Z]{2}\d{8}$/.test(s)

// After — compiled once
const PATTERN = /^[A-Z]{2}\d{8}$/
const isValid = (s) => PATTERN.test(s)
```
Impact: -190 ms P95.
Effort: 30 min.
Risk: low.

### Estimated total impact
After all 3 fixes: P95 <current> → <new> (-<delta>).

### Out of scope (flagged for future)
- Cold-cache scenario shows additional <ms> hit; consider warm-up or pre-fetching.
- Authentication middleware adds <ms> per request; not the dominant bottleneck today.
```

## Phase 6 — Validate (after applying fixes)

- Re-profile under same conditions.
- Verify P95 hits target.
- Verify no functional regression (test suite + spot-check).
- Verify the fix in production / staging telemetry, not just synthetic.

## Output format

```
## /profile-perf complete

Subject: <name>
Current P95: <ms> (target: <ms>)
Bottleneck (#1): <cause>
Recommended fixes: <count>; estimated end-state P95 <ms>

Report: ai/runtime/profile-<subject>-<date>.md
```

## Hard rules

- **Profile before optimizing.** "I think it's the DB" is a guess; profile it.
- **One change per PR for >50ms optimizations.** Easier to revert if regression.
- **Re-measure after applying.** "Should be faster" is not "is faster."
- **Note effort vs impact.** A 4-hour fix that saves 50ms vs a 30-min fix that saves 3 seconds — pick the second.
- **Production-like data.** Synthetic data with 10 rows hides N+1; production has 10,000.

## Failure modes

- Profiled in dev → numbers wrong; production data shape differs.
- Optimized the function showing in flame graph that's only called 1% of the time.
- Benchmarked once; variance hid the real bottleneck.
- Applied parallel I/O on a path that has data dependency between calls.
- Replaced regex with hand-rolled string check; introduced a bug missed in tests.

## Related

- `@performance-optimizer` — broader perf agent; runs this command + others.
- `database/optimize-query` — for DB-specific deep optimization.
- `mobile/optimize-bundle` — for mobile cold-start / bundle-size.
- `caching-strategy` pattern — apply when this command surfaces repeated reads.
- `parallel-io` pattern (backend) — apply when this command surfaces sequential awaits.
