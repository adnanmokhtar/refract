---
name: parallel-io
description: "Pattern: Parallel I/O — overlap independent I/O safely with a bounded cap"
kind: ai-pattern
---

# Pattern: Parallel I/O

> **Hard rule:** Independent I/O overlaps via the project's existing concurrency primitive with a bounded cap; sequential `await`-in-a-loop on independent ops is a bug. Parallel inside a transaction, unbounded fan-out from user input, and concurrency caps above pool size are forbidden.

> **Status:** baseline stub. Populated at `/setup-project` from `.claude/_extracted-codebase.md` (concurrency primitive) and — in `--refine` mode — from `.claude/_refine-extract.md § Hot paths` (the `extract-hotpaths` skill cites the project's sequential-await hot paths here). Until populated the project-specific block holds placeholders + a TODO; Phase 5 surfaces it under "Open questions". If a `--refine` run lands and this file is somehow absent, the hot-path enrichment creates it (NEW-FILE) from this shape.

## Overview

Most backend latency is wall-clock spent waiting on I/O (DB, cache, HTTP, queue, file). Independent waits SHOULD overlap. The mistake LLMs (and tired engineers) make is sequential `await`-in-a-loop where iteration N+1 doesn't depend on iteration N — turning a 100ms-each × 8 batch into 800ms wall when it could be 100ms.

This pattern documents **how to overlap independent I/O in *this* codebase, using *this* project's primitive** — not generic best-practice prose. If the project has no I/O-bound hot paths (pure-CPU tool, static-site generator, etc.), this file is allowed to stay a stub — record that as the finding rather than inventing fan-out the project doesn't need.

> **Project-specific block** — Phase 4.6 fills this in from `.claude/_extracted-codebase.md`; Phase 4.7-DEEP refreshes the hot-path rows from `.claude/_refine-extract.md § Hot paths`. If extraction is empty, leave the placeholder + open a TODO; Phase 5 will surface it under "Open questions".
>
> - **Concurrency primitive in use**: `<extracted: native Promise.all | Promise.allSettled | p-limit | Bluebird.map | asyncio.gather | asyncio.Semaphore | errgroup | CompletableFuture | Parallel.ForEachAsync | …>`
> - **Project-shipped helper(s)** (if any): `<path:line>` (e.g., `libs/concurrency/run-with-limit.ts:12 — runWithLimit(items, fn, { concurrency, signal })`)
> - **Default concurrency caps observed**: outbound HTTP `<N>`; DB `<N ≤ pool-size − margin>`; CPU work in workers `<W>`
> - **Cancellation primitive**: `<AbortController | context.Context | CancellationToken | asyncio.CancelledError>`
> - **Telemetry / tracing wrapper**: `<extracted: e.g. tracer.startActiveSpan around each task | OpenTelemetry auto-instrumentation | none>`
> - **Hot paths to fix** (from `_refine-extract.md § Hot paths`): `<file:line>` — current sequential-await / N+1 site → recommended uplift. One row per extracted hot path; empty until `--refine` runs.

## When to use

| Signal | Reach for |
|---|---|
| Heterogeneous fixed-N reads (`getUser` + `getOrg` + `getPrefs`) | `Promise.all` / `asyncio.gather` (no cap needed; N is small + known) |
| Homogeneous fan-out over a large or user-controlled array | **Bounded** parallel (`p-limit` / `Bluebird.map({concurrency})` / `asyncio.Semaphore`) |
| Partial failure is acceptable (collect what you can) | `Promise.allSettled` / `gather(..., return_exceptions=True)` |
| Order matters or B reads A's output | **Sequential** — do not parallelize |
| n queries to the same table by primary key | **Batch API** (`findByIds`) — parallelism is the wrong tool |
| Inside a DB transaction | **Sequential** — most ORMs serialise on the single tx connection anyway |
| Two writes share a key | **CAS / atomic SQL** (`UPDATE … SET x = x + ?`) — parallel writes race |

## Project-shipped helper

> If the project has its own bounded-parallel helper (extraction detects `runWithLimit` / `parallel` / `concurrentMap` / `each_concurrently` / etc.), use **only** that — don't introduce a new dependency. Phase 4.6 inserts the helper signature here verbatim.

If the project has no helper and the language ecosystem has a canonical one (e.g., `p-limit` for Node, `errgroup` for Go), prefer that over hand-rolling.

## Recipes (project-flavoured)

### Heterogeneous fixed-N reads

```ts
// PROJECT-CITED EXAMPLE: <file:line> — Phase 4.6 anchors this
const [user, org, prefs] = await Promise.all([
  this.userRepo.findById(id),
  this.orgRepo.findById(orgId),
  this.prefsRepo.findById(id),
]);
```

### Bounded fan-out (fail-fast)

```ts
// Use the project's primitive — replace `<projectPrimitive>` with what extraction found
const results = await <projectPrimitive>(items, item => this.process(item), { concurrency: 8 });
```

### Bounded fan-out (partial-failure tolerant)

```ts
const settled = await Promise.allSettled(items.map(it => limit(() => process(it))));
const ok = settled.flatMap(s => (s.status === 'fulfilled' ? [s.value] : []));
```

### Cancellation on first error

```ts
const ac = new AbortController();
try {
  await Promise.all(urls.map(u => limit(() => this.http.fetch(u, { signal: ac.signal, timeout: 2000 }))));
} catch (e) {
  ac.abort();
  throw e;
}
```

## Pitfalls

1. **Sequential disguised as parallel.** `await` inside a `for` loop runs sequentially even if the body looks parallel.
2. **Parallel inside a transaction** — most ORMs (TypeORM, Prisma interactive tx, SQLAlchemy sync, Sequelize) bind the tx to one connection; `Promise.all` of two queries either deadlocks or serialises.
3. **Concurrency cap above pool size** — a cap of 50 with a pool of 10 means 40 tasks block on connection acquisition; you've optimised queue length, not throughput.
4. **Forgotten timeouts** — one slow tail call drags the whole batch's wall-clock; per-task timeout < parent budget, cancel siblings on hard failure.
5. **Race conditions on shared mutable state** — prefer pure functions returning their own slice; `flat()` at the end.
6. **Unbounded fan-out from user input** — cap input length at the validator AND cap concurrency.

## When NOT to use

- `n ≤ 3` known-at-author-time independent reads — `Promise.all` is fine but don't add a `runWithLimit` ceremony.
- Inside a transaction (restated — most-common mistake).
- Strict ordering required (sequential migrations, FIFO handlers, sequence-generated idempotency keys).
- CPU-pinned throughput jobs — adding I/O concurrency on top of saturated CPU just queues; profile first.

## Examples from THIS codebase

> Phase 4.6 inserts 2–3 grep'd `file:line` citations of the project's existing correct parallel I/O. If extraction finds **zero** correct examples, that's a signal: open a finding in `ai/dynamic/feedback-learned.md` ("project ships no parallel I/O — likely sequential-await regressions in N hot paths") and let `/learn-from-task` track follow-ups.

## Related

- `ai/patterns/data-access.md` — Repository batch APIs (`findByIds`, `whereIn`) are the *first* thing to reach for over parallel fan-out.
- `.claude/rules/concurrency-discipline.md` *(if the backend pack is applied)* — the MUST/MUST-NOT review checklist that enforces this pattern.
- `.claude/skills/parallelize-independent-ops.md` *(if the backend pack is applied)* — the procedure for converting an existing sequential code path.
