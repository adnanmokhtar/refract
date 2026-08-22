---
name: performance-principles
description: Performance Principles
kind: rule
pack: performance
severity: must
applies-to: performance-track, every-code-writing-task-in-performance
---

# Performance Principles

> **Hard rule.** Every "perf" PR MUST attach a baseline AND a post-change measurement from the SAME harness (p50 / p95 / p99 + RPS). An adjective where a number belongs — "faster", "snappier" — is a failed measurement, not a result. Optimization without a profile, N+1 queries, unbounded caches, sync I/O on the event loop, and external calls held inside DB transactions are forbidden.

Prevents the two failure modes: optimizing the wrong thing, and shipping a regression because no one measured. The always-loaded floor; depth lives in `.claude/skills/` and `ai/patterns/`.

## Must

- The baseline the Hard rule demands also carries **memory and error rate**, not latency alone — a latency win paid for in RSS or in 5xx is not a win, and you cannot discover that after the fact.
- **Define the noise band before reading any delta.** Re-run the unchanged baseline ≥3× and take the spread; a before→after delta inside that spread is `NO-CHANGE`, not a win and not a regression. "(noise)" asserted without that spread is the same defect as "faster" — a judgement standing where a measurement belongs.
- **"It got slow" is a different question from "it is slow."** A regression means a known-good state existed: recover it and diff — deploy range, migration, data volume, query plan, cache hit-rate, downstream latency — *before* opening any bottleneck taxonomy. A taxonomy tells you what is sometimes slow; only the diff tells you what changed.
- Profile before optimizing, with your runtime's sampling profiler (`STACK.md` names it per stack). The hot path is routinely somewhere nobody predicted — that is what the profiler is for, and guessing costs a release.
- Every list endpoint paginates. Cursor pagination (`WHERE id > :lastId LIMIT N`) for deep lists; offset is fine for shallow.
- Every cache entry has a TTL or an explicit invalidation path. Unbounded caches = memory leak you'll find at 3am.
- Cache stampede protection on hot keys — a single-flight / coalescing primitive, which every mainstream runtime ships.
- Indexes on every column appearing in WHERE, ORDER BY, or JOIN of slow queries. Verify with the DB's plan-explainer, not by assumption.
- Async I/O on the event loop / async runtime. Sync filesystem reads or blocking DB drivers in a request handler are a stop-the-world bug.
- Browser input handlers keep per-interaction main-thread work under the INP budget (≤200ms at p75). Break long tasks and defer non-urgent state updates with the framework's transition primitive. See `inp-responsiveness.md`.

## Must not

- N+1 queries — fetching parent then looping single-row child fetches. Use `IN (...)`, JOINs, or batch-loader primitives.
- `SELECT *` on large rows when you need 3 columns. Network + parse cost adds up at scale.
- Hold a DB transaction across an external API call. Connection pool exhaustion at peak.
- Regex compilation inside a hot loop — compile once, reuse.
- Direct stdout / unstructured print calls in hot paths (request handlers, render loops). Logging is I/O.
- Block the async runtime / event loop with CPU work — offload to a worker thread / pool / queue / separate process. The bound is fixed only in the browser, where a task "whose duration exceeds 50ms" is a **long task** by definition (https://w3c.github.io/longtasks/) and is what INP charges you for. On a server there is no such constant: measure event-loop lag against that endpoint's own latency budget rather than borrowing 50.
- Cache responses that depend on user/tenant identity without including that identity in the cache key.

## Should

- Prefer architecture wins over micro-wins: add a queue, CDN, or read replica before optimizing a mapper function.
- Run independent I/O through the language's structured-concurrency primitive — sequential `await` of independent calls is forbidden in hot paths (see `concurrency-discipline.md`).
- Bound worker pools and concurrency limits — unbounded fan-out kills downstreams.
- Set each SLO from **your own measured** p95 on that endpoint, not a borrowed number — gate just under what you already achieve and ratchet. A threshold nobody measured either fires on everything and gets muted, or fires on nothing.
- An SLA/SLO is only validated by a load / stress / soak campaign on a prod-parity env — single-VU or laptop numbers describe the laptop. See `load-test.md`.
- Instrument SPA route transitions and budget route-change-to-paint; the Soft Navigations heuristic is still emerging, so gate any reliance on it behind `where available`. See `web-vitals-field.md`.
- A monotonically-growing heap under steady load is a leak — hunt it with a heap diff over time, never a memory-limit bump or a periodic restart. See `memory-leak-hunt.md`.

## Enforcement

- Frontend bundle-size CI check (framework-native budget or equivalent) — fail-on-regression.
- Lab CI gates what the lab can actually measure: LCP and CLS load-shift via Lighthouse CI, plus a `server-response-time` budget for TTFB. **INP is not lab-measurable** — Lighthouse scripts one synthetic interaction and real users are the only source of the real number, so INP is gated on field p75 (CrUX / RUM), never on a Lighthouse run. Core Web Vitals "good" thresholds, judged at p75 of real users: LCP ≤ 2.5s, INP ≤ 200ms, CLS ≤ 0.1 (https://web.dev/articles/vitals). See `web-vitals-field.md`.
- Load tests on critical endpoints in staging using the project's load-tester — pick one and keep results comparable.
- Slow query log enabled in dev + staging; review weekly.
- APM with alerts on p95 regression, on a threshold outside the measured noise band.
