---
name: parallel-io
kind: example
pack: backend
---

# Pattern: Parallel I/O

> **Hard rule:** Independent I/O overlaps via the project's existing concurrency primitive with a bounded cap; sequential `await`-in-a-loop on independent ops is a bug. Parallel inside a transaction, unbounded fan-out from user input, and concurrency caps above pool size are forbidden.

**Halt conditions / mandatory cites**
- The proposal MUST cite the project's concurrency primitive at `<path:line>` (helper or library) — no new dependency without justification.
- The concurrency cap MUST cite the pool size / rate limit / FD limit it respects.
- A diff that introduces unbounded `Promise.all(userInput.map(...))` is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "these calls are independent".
- If the project's primitive + cancellation token aren't extracted, halt before introducing parallelism.

> **Project-specific block** — Phase 4.6 fills this in from `.claude/_extracted-codebase.md` + `.claude/_extracted-idioms.md`. If extraction is empty leave the placeholder + open a TODO; Phase 5 will surface it under "Open questions".
>
> - **Concurrency primitive in use**: `<extracted: native Promise.all | Promise.allSettled | Bluebird.map | p-limit | asyncio.gather | asyncio.Semaphore | errgroup | CompletableFuture | Parallel.ForEachAsync | …>`
> - **Project-shipped helper(s)** (if any): `<path:line>` (e.g., `libs/concurrency/run-with-limit.ts:12 — runWithLimit(items, fn, { concurrency, signal })`)
> - **Default concurrency caps observed**: outbound HTTP `<N>`; DB `<N ≤ pool-size − margin>`; CPU work in workers `<W>`
> - **Cancellation primitive**: `<AbortController | context.Context | CancellationToken | asyncio.CancelledError>`
> - **Telemetry / tracing wrapper**: `<extracted: e.g. tracer.startActiveSpan around each task | OpenTelemetry instrumentation auto-applied | none>`
> - **Where this pattern lives in the codebase**: `<file:line>` examples — first 3 grep hits where the project uses parallel I/O correctly today

## Overview

Most backend latency is wall-clock spent waiting on I/O (DB, cache, HTTP, queue, file). Independent waits SHOULD overlap. The mistake LLMs (and tired engineers) make is sequential `await`-in-a-loop where iteration N+1 doesn't depend on iteration N — turning a 100ms-each × 8 batch into 800ms wall when it could be 100ms.

This pattern documents **how to overlap independent I/O** in *this* codebase, using *this* project's primitive — not generic best-practice prose.

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

> If the project has its own bounded-parallel helper (extraction Step 2.5 detects `runWithLimit` / `parallel` / `concurrentMap` / `each_concurrently` / etc.), use **only** that — don't introduce a new dependency.
>
> Phase 4.6 inserts the helper signature here verbatim, e.g.:
> ```ts
> // libs/concurrency/run-with-limit.ts:12
> export async function runWithLimit<T, R>(
>   items: readonly T[],
>   fn: (item: T, index: number) => Promise<R>,
>   opts: { concurrency: number; signal?: AbortSignal },
> ): Promise<R[]>
> ```

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
const failed = settled.flatMap(s => (s.status === 'rejected' ? [{ item: '<id>', error: s.reason }] : []));
```

### Cancellation on first error

```ts
const ac = new AbortController();
try {
  await Promise.all(urls.map(u =>
    limit(() => this.http.fetch(u, { signal: ac.signal, timeout: 2000 }))
  ));
} catch (e) {
  ac.abort();
  throw e;
}
```

### Staged pipeline (fetch ‖ → transform ‖ → write ‖)

```ts
// Stage 1 — fetch inputs in parallel
const inputs = await runWithLimit(ids, id => fetchInput(id), { concurrency: 10 });

// Stage 2 — transform (CPU-bound; offload if > 50ms each)
const transformed = await runWithLimit(inputs, x => workerPool.run(x), { concurrency: cpus });

// Stage 3 — write results in parallel
await runWithLimit(transformed, r => writeResult(r), { concurrency: 5 });
```

### Decision: parallel vs batch vs sequential

```
Need n results from n calls to the same source?
├── Source has a batch API (findByIds, multiGet, IN clause) → BATCH ✓
├── Source has no batch API + calls are independent → BOUNDED PARALLEL ✓
├── Each call depends on the previous result → SEQUENTIAL (correct)
└── n is fixed and small (≤ 3) and calls to *different* sources → Promise.all / gather (no cap)
```

## Concurrency caps (project-observed)

| Workload | Cap | Reason |
|---|---|---|
| Outbound HTTP to 3rd-party APIs | `<extracted, default 5–10>` | Rate limits + provider fairness |
| DB queries from a request | `≤ <pool_size> − <margin>` | Connection pool exhaustion |
| CPU work via workers | `<#cores>` | Beyond cores → context-switch overhead |
| Queue producers | `<extracted>` | Provider throughput + backpressure |
| File I/O | `<extracted>` | OS file-descriptor limits |

> Phase 4.6 fills these from observed config (pool config, env vars, `axios.create` defaults, retry libs) — no guessing.

## Tracing / observability

> Phase 4.6 anchors this section to the project's tracing primitive. Examples that are typical post-extraction:
>
> - "Each task in a parallel fan-out runs inside a child span (`tracer.startActiveSpan('process-item', …)`); parent span closes when `Promise.all` resolves."
> - "OpenTelemetry SDK auto-instruments `pg` / `axios` / `redis` — no manual wrapping needed."
> - "Correlation ID propagated via AsyncLocalStorage — no per-task plumbing."

If the project has none of the above, **add a TODO**: "Add tracing around bounded fan-out so slow tasks are visible in p99."

## Pitfalls

1. **Sequential disguised as parallel.** `await` outside `Promise.all` runs sequentially even if the array literal looks parallel:
   ```ts
   for (const id of ids) {
     await Promise.resolve(getUser(id));   // still sequential — Promise.resolve doesn't parallelize
   }
   ```
2. **Parallel inside a transaction** — most ORMs (TypeORM, Prisma in interactive tx, SQLAlchemy sync, Sequelize) bind the tx to one connection. `Promise.all` of two queries either deadlocks or executes serially.
3. **Concurrency cap above pool size** — a cap of 50 with a pool of 10 means 40 tasks block on connection acquisition; you've optimised for queue length, not throughput.
4. **Forgotten timeouts** — one slow tail call (p99 = 30s) drags the whole batch's wall-clock to 30s. Per-task timeout < parent budget; cancel siblings on hard failure.
5. **Race conditions on shared mutable state** — `for await` accumulating into a shared object is "fine" sequentially; convert to parallel and you race. Prefer pure functions returning their own slice; `flat()` at the end.
6. **Unbounded fan-out from user input** — endpoint takes `ids: string[]`; client sends 10K IDs; `Promise.all(ids.map(fetch))` melts the downstream. Cap input length at the validator AND cap concurrency.
7. **`Promise.race` for "fast path"** — only correct when losers are idempotent + harmless (e.g., redundant cache reads). For writes, `race` is a bug.
8. **Single connection saturation** — if the pool is 1 (e.g., dev SQLite) parallel queries serialise; the speedup you measure on prod doesn't appear. Always test at prod-like pool size.

## When NOT to use

- `n ≤ 3` known-at-author-time independent reads on hot paths — `Promise.all` is fine but the win is sub-millisecond; don't add a `runWithLimit` ceremony for it.
- Throughput-bound jobs already CPU-pinned — adding I/O concurrency on top of saturated CPU just queues; profile first.
- Strict ordering required (idempotency keys generated by sequence; sequential migrations; FIFO queue handlers).
- Inside a transaction (already noted; restated because this is the most-common-mistake).

## Examples from THIS codebase

> Phase 4.6 / Phase 2.5 inserts 2–3 grep'd examples here — concrete file:line citations of the project's existing parallel I/O. If extraction finds **zero** correct examples, that's a signal: open a finding in `ai/dynamic/feedback-learned.md` ("project ships no parallel I/O — likely sequential-await regressions in N hot paths") and let `/learn-from-task` track follow-ups.

## Related

- `ai/patterns/data-access.md` — Repository batch APIs (`findByIds`, `whereIn`) are the *first* thing to reach for over parallel fan-out.
- `ai/patterns/caching-strategy.md` — Cache fan-out (`mget`) batches naturally; avoid loops of single `get` calls.
- `.claude/rules/concurrency-discipline.md` — the MUST/MUST-NOT review checklist that enforces this pattern.
- `.claude/skills/parallelize-independent-ops/SKILL.md` — the procedure for converting an existing sequential code path.
