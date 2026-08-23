---
name: parallel-io
description: "Pattern: Parallel I/O"
kind: ai-pattern
pack: backend
---

# Pattern: Parallel I/O

> **Hard rule:** Independent I/O overlaps via the project's existing concurrency primitive with a bounded cap; sequential `await`-in-a-loop on independent ops is a bug. Parallel inside a transaction, unbounded fan-out from user input, and concurrency caps above pool size are forbidden.

**When to apply**
- A loop awaits N independent I/O calls (HTTP, DB read, cache get) where iteration N+1 doesn't depend on N's result.
- Heterogeneous fixed-N reads that currently serialize (e.g., `getUser` then `getOrg` then `getPrefs`).
- Fan-out over a user-controlled list where input length and concurrency are both bounded.

**When NOT to apply**
- Inside a DB transaction (single tx connection — parallelism deadlocks or serializes).
- A batch API exists (`findByIds`, `IN (...)`, `multiGet`) — use that, not fan-out.
- Each iteration depends on the previous result, or strict ordering is required.

**Halt conditions / mandatory cites**
- The proposal MUST cite the project's concurrency primitive at `<path:line>` (helper or library) — no new dependency without justification.
- The concurrency cap MUST cite the pool size / rate limit / FD limit it respects.
- A diff that introduces unbounded `Promise.all(userInput.map(...))` is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "these calls are independent".
- If the project's primitive + cancellation token aren't extracted, halt before introducing parallelism.

> **Project-specific block** — Phase 4.6 fills this in from `.claude/_extracted-codebase.md` + `.claude/_extracted-idioms.md`.
>
> **If extraction found nothing, the placeholders below are NOT the answer — they are the question.** An unresolved `<extracted: …>` token left in a code line is worse than an empty file: an agent copies it verbatim, or silently substitutes `Promise.all`, which is the exact generic leak `rules/concurrency-discipline.md` § Must not exists to stop. Degraded behaviour is specified, not improvised:
>
> | What extraction found | What this pattern is allowed to do |
> |---|---|
> | A project helper (`runWithLimit`, `concurrentMap`, …) | Use it, cite its `<path:line>`, use no other. |
> | No helper, but a library already in `package.json` / `requirements.txt` / `go.mod` (`p-limit`, `errgroup`, `anyio`) | Use it, cite the dependency manifest line. |
> | Neither | **Name the language default explicitly and mark the recipe `[UNANCHORED]`** — e.g. "no bounded-parallel primitive found; the language default is `Promise.all` (unbounded)". An `[UNANCHORED]` recipe may not be applied to a user-controlled list at all: bound the input at the validator first, or halt and ask. Adding a new dependency is a decision, not a default — it needs a stated reason. |
>
> Never leave a bare `<projectPrimitive>` / `<extracted: …>` token inside a fenced code block that an agent will read as code.
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

**This table dispatches; the header block above decides.** *Whether* to overlap is settled by
**When to apply** / **When NOT to apply**; what is left is *which primitive*, and picking the wrong
one is its own failure — an unbounded `Promise.all` where a bounded fan-out belonged is the most
common of them.

| Signal | Reach for |
|---|---|
| Heterogeneous fixed-N reads (`getUser` + `getOrg` + `getPrefs`) | `Promise.all` / `asyncio.gather` (no cap needed; N is small + known) |
| Homogeneous fan-out over a large or user-controlled array | **Bounded** parallel (`p-limit` / `Bluebird.map({concurrency})` / `asyncio.Semaphore`) |
| Partial failure is acceptable (collect what you can) | `Promise.allSettled` / `gather(..., return_exceptions=True)` |
| Order matters or B reads A's output | **Sequential** — do not parallelize |
| n queries to the same table by primary key | **Batch API** (`findByIds`) — parallelism is the wrong tool |
| Inside a DB transaction | **Sequential** — most ORMs serialise on the single tx connection anyway |
| Two writes share a key | **CAS / atomic SQL** (`UPDATE … SET x = x + ?`) — parallel writes race |

## Recipes (project-flavoured)

### Heterogeneous fixed-N reads

```ts
// Phase 4.6 replaces this comment with a real <file:line> from the project.
// Unresolved, this is illustrative only — do not cite it as the project's convention.
const [user, org, prefs] = await Promise.all([
  this.userRepo.findById(id),
  this.orgRepo.findById(orgId),
  this.prefsRepo.findById(id),
]);
```

### Bounded fan-out (fail-fast)

```ts
// `runWithLimit` here stands for THE PROJECT'S primitive, resolved by the table above —
// the project helper, else the already-installed library, else an [UNANCHORED] recipe.
// It is a placeholder NAME in valid syntax, deliberately: a reader who has not resolved it
// gets an undefined-function error at once, not a silently-unbounded Promise.all.
const results = await runWithLimit(items, item => this.process(item), { concurrency: 8 });
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

## Concurrency caps (project-observed)

| Workload | Cap | Reason |
|---|---|---|
| Outbound HTTP to 3rd-party APIs | `<extracted, default 5–10>` | Rate limits + provider fairness |
| DB queries from a request | `≤ <pool_size> − <margin>` | Connection pool exhaustion |
| CPU work via workers | `<#cores>` | Beyond cores → context-switch overhead |
| Queue producers | `<extracted>` | Provider throughput + backpressure |
| File I/O | `<extracted>` | OS file-descriptor limits |

> Phase 4.6 fills these from observed config (pool config, env vars, HTTP-client defaults, retry libs) — no guessing. The degraded-behaviour rule above governs these cells too: if the config is not found, write `NOT FOUND` in the Cap column and treat the workload as `[UNANCHORED]`. A surviving `<extracted…>` token here is read as a number, which is the same leak in a quieter place.

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

## Detectors (cite-or-halt)

Each finding cites `<path:line>` + the matched shape + the fix. "This could be parallel" without the cited loop and the independence argument is not a finding — independence is a claim about the code, and the hand-wave halt above applies to it.

### 1. Sequential `await` over independent iterations

A loop whose body awaits I/O where iteration N+1 does not consume N's result. Cite the loop AND name what makes the iterations independent (no shared mutable accumulator, no ordering requirement, no dependency on the prior result) → `parallelize-bounded`.

### 2. Fan-out with no concurrency bound

`Promise.all(xs.map(...))` / `asyncio.gather(*[...])` / an unbounded goroutine spawn over a list whose length is not capped at the validator → `bound-the-fanout`. Where `xs` derives from request input this is a **user-triggerable** downstream melt, not a style nit — cite the validator that should have capped the length and does not.

### 3. Fan-out where a batch API exists

Parallel single-key reads (`findById` × N, `GET /x/:id` × N) against a source that ships `findByIds` / `IN (…)` / `multiGet` → `use-batch-api`. Parallelism is the wrong tool here even when it is bounded; N round-trips stay N round-trips.

### 4. Concurrency cap above the resource it consumes

A declared cap that exceeds the pool size / provider rate limit / FD limit it draws on — cite the cap AND the config line stating the resource ceiling. A cap with no cited ceiling is itself the finding (this pattern's halt condition) → `right-size-the-cap`.

### 5. Parallel inside a transaction

Concurrent awaits between a transaction's begin and commit → `serialize-in-transaction`. Most ORMs bind the transaction to one connection: this either deadlocks or silently serialises, so the "optimisation" is at best zero and at worst an outage.

### 6. Fan-out with no per-task timeout  `[self-policed]`

A bounded fan-out where individual tasks carry no timeout, so one p99 tail sets the whole batch's wall clock. grep can find the fan-out but cannot always see whether a timeout is applied by an interceptor, a client default, or an ambient deadline — mark `[self-policed]`: the reviewer asserts the per-task budget was located, or the finding is not emittable.

**Closure verbs:** `parallelize-bounded`, `bound-the-fanout`, `use-batch-api`, `right-size-the-cap`, `serialize-in-transaction`.

> **Examples from THIS codebase** — Phase 4.6 / Phase 2.5 inserts 2–3 grep'd `<file:line>` citations of the project's existing parallel I/O directly under the recipes above. If extraction finds **zero** correct examples, that is itself the finding: open a note in `ai/dynamic/feedback-learned.md` ("project ships no bounded parallel I/O — expect sequential-await regressions on hot paths") and let `/learn-from-task` track it. This paragraph replaces the empty section that used to sit here; an empty heading reads as an unfinished template, and this pattern ships in minimal mode where nobody is around to finish it.

## Related

- `ai/patterns/data-access.md` — Repository batch APIs (`findByIds`, `whereIn`) are the *first* thing to reach for over parallel fan-out.
- `ai/patterns/caching-strategy.md` — Cache fan-out (`mget`) batches naturally; avoid loops of single `get` calls.
- `.claude/rules/concurrency-discipline.md` — the MUST/MUST-NOT review checklist that enforces this pattern.
- `.claude/skills/parallelize-independent-ops/SKILL.md` — the procedure for converting an existing sequential code path.
