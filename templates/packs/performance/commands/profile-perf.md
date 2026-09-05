---
description: "Profile a slow endpoint / page / flow. Identify the dominant bottleneck (CPU / IO / network / lock contention / GC). Output: targeted fix proposals ranked by impact."
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /profile-perf

> **`--plan` / `--plan-only`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/profile-perf <subject> --plan` runs the read-only profiling phases (1-3 + the Phase 4 report), writes the ranked fix proposals as a plan to `.claude/plans/`, and exits before applying any fix — execute it later with `/execute-plan <file>`. Honesty clause: a plan-only run still profiles real load; it never proposes a fix without the measured `<before>` it's reducing.

## The Premise (read this first, internalize, do not deviate)

**The bottleneck is real. The pattern almost always repeats — same import / same query / same render path.** An N+1 in `orders.list` is an N+1 in `invoices.list` and `customers.list` because they share the same loader shape. A sequential `await` in one vendor-API enrichment is a sequential `await` in every enrichment that copy-pasted from it. A regex compiled-per-call in one validator is compiled-per-call wherever the project's "validate inline" idiom landed. The profile's job is to find ONE concrete hot path with measurement, then **scan for the same shape across the rest of the codebase** before reporting.

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

## Phase 2 — Organize (dispatch, don't hand-run)

This command **orchestrates two specialists** rather than restating the profiling mechanics inline:

- **Dispatch the `profile-endpoint` skill** to do the actual capture — warm-up, baseline + ramp load runs, flamegraph, slow-query log, per-axis attribution. It owns the halt conditions (no p95 without the load-tool output it came from; refuse empty-table runs). Feed it the resolved subject from Phase 1.
- **Dispatch `@performance-optimizer`** to turn the captured artifacts into ranked fix proposals (`<before>` → `<after>`, `impact / risk`). It owns the "no measurement → no finding" rule.

The five axes below are what the dispatched skill measures — they are the contract this command expects back, not a procedure for this command to run by hand:

1. **Wall-clock breakdown** — what fraction is CPU vs IO vs network vs idle?
2. **CPU profiling** — flame graph; hottest functions.
3. **IO profiling** — DB queries, cache hits/misses, file I/O.
4. **Network profiling** — external API calls; latency per call; sequential vs parallel.
5. **Memory + GC** — allocation rate; GC pause frequency + duration.

After both return, this command's own job is the **similar-pattern scan** (the premise above) + the mechanical balance equation — the part neither specialist does.

## Phase 3 — Retrieve

Tools by ecosystem (illustrative; pick the one available in the project's stack — every mainstream language has at least one sampling profiler + an IO/SQL log + a tracing integration):

| Stack | CPU profile | IO profile | Network |
|---|---|---|---|
| Node.js | `--prof` + `0x`, Clinic.js | structured logger + APM | OpenTelemetry |
| Python | `py-spy`, `cProfile`, `pyinstrument` | SQL log + APM | OpenTelemetry |
| Go | `pprof` (CPU + heap + goroutine + mutex) | `database/sql` traces | net/http/httptrace |
| Java / JVM | JFR + Mission Control, async-profiler | JDBC events | OpenTelemetry |
| Rust | `perf`, `flamegraph`, `samply` | tracing crate | tracing-opentelemetry |
| Ruby | `stackprof`, `rbspy` | rack-mini-profiler | OpenTelemetry / Skylight |
| .NET | `dotnet-trace`, dotMemory, PerfView | EF Core logs | OpenTelemetry |
| PHP | xdebug, Blackfire, SPX | DB driver logs | OpenTelemetry |
| Elixir / BEAM | observer, fprof, eprof | Ecto logs | OpenTelemetry |
| Browser | Browser dev-tools Performance panel + web-vitals profiler | dev-tools Network | dev-tools Network |
| Mobile native | Xcode Instruments (iOS), Android Studio Profiler (Android) | platform's network inspector | platform's network inspector |

Read project's:
- APM / tracing / metrics dashboards (whatever the project's observability stack uses).
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
| <payment-vendor charges/get> | 50 | 80 ms | YES — total 4000 ms wall |
| <email vendor send> | 1 | 200 ms | n/a |

50 sequential awaits of independent calls. With the language's structured-concurrency primitive (e.g., `Promise.all` / `asyncio.gather` / errgroup) → ~80 ms total instead of 4000 ms.

### Memory + GC
- Allocation rate: <MB/s>
- GC pause P99: <ms>
- Heap headroom: <%>

No GC pressure; not a contributor here.

### Bottleneck ranking (by impact on P95)

| # | Cause | Current contribution | Fixed contribution | Effort |
|---|---|---|---|---|
| 1 | N+1 DB query (order_items) | 400 ms | 12 ms (single JOIN) | 1h |
| 2 | Sequential vendor-API awaits | 4000 ms | 80 ms (structured concurrency + 10-bound) | 2h |
| 3 | Per-item regex validation | 240 ms | 50 ms (compile once + skip on N most-trusted fields) | 4h |

### Targeted fixes (ranked by impact / effort)

#### Fix 1 (highest impact / lowest effort) — N+1 query
File: `<orders list use-case file:line>`. Replace the per-order `SELECT * FROM order_items WHERE order_id = $1` loop with a single `SELECT … FROM orders LEFT JOIN order_items …` aggregating items per order (or use the project's batch-loader primitive).
Impact: -388 ms P95.
Effort: 1 hour incl. test update.
Risk: low (preserves API shape).

#### Fix 2 — Parallel vendor-API calls (bounded)
File: `<orders enrich file:line>`. Replace the sequential `for ... await` loop with the language's structured-concurrency primitive (`Promise.all` / `asyncio.gather` / errgroup / `Task.WhenAll`) bounded by a concurrency limiter (e.g., a semaphore / `p-limit` / language-native equivalent) at ≤ vendor's rate-limit budget.
Impact: -3920 ms P95.
Effort: 2 hours incl. testing rate-limit handling.
Risk: medium (vendor rate limits; must validate behavior under burst).

#### Fix 3 — Regex compile-once
File: `<orders validate file:line>`. Move the regex literal out of the per-call function body to a module-scope constant; `.test()` against the precompiled pattern.
Impact: -190 ms P95.
Effort: 30 min.
Risk: low.

### Projected total impact — PROJECTION, not a measurement
After all 3 fixes: P95 <current> → ~<projected> (-<delta>) `PROJECTED`. Phase 6 replaces this with the re-profiled number; a `PROJECTED` value that reaches the final report unlabelled has been laundered into a result.

### Out of scope (flagged for future)
- Cold-cache scenario shows additional <ms> hit; consider warm-up or pre-fetching.
- Authentication middleware adds <ms> per request; not the dominant bottleneck today.
```

## Phase 6 — Validate (after applying fixes — production-grade, not merely faster)

- Re-profile under same conditions, **same harness** that produced `<before>`. An adjective ("feels faster") is not a re-measurement — it is `SKIPPED [no-harness]`, never a pass.
- **Verify P95 hits the budget, not just beats the before.** Faster-than-before but still over budget is `INCOMPLETE — over budget (<after> vs <budget>)`, not done.
- **Re-measure the guardrail neighbor, not only the metric you improved** (per the Guardrail matrix in `@performance-optimizer`: index → write p95; fan-out → downstream RPS + pool; cache → memory/staleness; bundle-split → INP + waterfall). ANY guardrail worse than baseline beyond noise → `INCOMPLETE — regressed <metric>`, HALT, keep behind review.
- Verify no functional regression (test suite + spot-check).
- Verify the fix in production / staging telemetry, not just synthetic.
- **Terminal verdict:** `PRODUCTION-GRADE` only when the re-profile is measured, at/under budget, and every guardrail held; otherwise `INCOMPLETE — <unmet items named>`. Never a bare "done".

## Output format

```
## /profile-perf — <subject> — <PRODUCTION-GRADE | INCOMPLETE | PROFILE-ONLY>

Subject: <name>
Harness: <profiler / load-tester that produced both numbers>
P95: <before> → <after> (budget <ms>)   # or "<before> — no fix applied" on a PROFILE-ONLY run
Bottleneck (#1): <cause, from <profile artifact:line>>
Guardrails re-checked: <metric> <delta> (noise band ±<n>%)

Status: PRODUCTION-GRADE      # re-profiled on the same harness, at/under budget, guardrails held
  # OR
Status: INCOMPLETE — <unmet items named>     # over budget, regressed guardrail, or SKIPPED [no-harness]
  # OR
Status: PROFILE-ONLY — diagnosis delivered, no fix applied; end-state values are PROJECTED

Report: ai/runtime/profile-<subject>-<date>.md
```

This block prints the verdict Phase 6 just decided. A bare `complete` is not one of the options — Phase 6's own closing line ("Never a bare 'done'") is the rule, and this output used to break it twelve lines later.

## Hard rules

- **Profile before optimizing.** "I think it's the DB" is a guess; profile it.
- **One change per PR for >50ms optimizations.** Easier to revert if regression.
- **Re-measure after applying.** "Should be faster" is not "is faster."
- **Note effort vs impact.** A 4-hour fix that saves 50ms vs a 30-min fix that saves 3 seconds — pick the second.
- **Production-like data.** Synthetic data with 10 rows hides N+1; production has 10,000.

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the ranked fixes re-expressed as ONE ordered, numbered to-do — **ordered by measured time saved**, not severity: **BIGGEST WIN** (the largest P95 / wall-clock reduction first — the N+1, the sequential-await fan-out) → **SMALLER** → **MARGINAL** — each step carrying the hot path's `<file:line>` + **Fix** (concrete — the named JOIN / batch-loader / structured-concurrency primitive / compile-once move) + **Verify** (the measurement: re-profile under the same load and confirm the `<before> → <after>` ms it claimed). Drop any line below the lightweight `< 50 ms P95` budget into OPTIONAL or `Out of scope` — never above a real win. Close with: re-run `/profile-perf` under the same conditions to confirm P95 hits target, `/learn-from-task`, then ship one change per PR. A clean run collapses to a single line ("Within budget — no bottleneck above threshold"). The reader must never re-rank the bottleneck table themselves. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes

- Profiled in dev → numbers wrong; production data shape differs.
- Optimized the function showing in flame graph that's only called 1% of the time.
- Benchmarked once; variance hid the real bottleneck.
- Applied parallel I/O on a path that has data dependency between calls.
- Replaced regex with hand-rolled string check; introduced a bug missed in tests.

## Related

- `profile-endpoint` skill — the capture engine this command dispatches in Phase 2 (load runs + flamegraph + slow-query log).
- `@performance-optimizer` — the agent this command dispatches to rank fixes; also a broader perf agent that runs this command + others.
- `database/optimize-query` — for DB-specific deep optimization.
- `mobile/optimize-bundle` — for mobile cold-start / bundle-size.
- `caching-strategy` pattern — apply when this command surfaces repeated reads.
- `parallel-io` pattern (backend) — apply when this command surfaces sequential awaits.
