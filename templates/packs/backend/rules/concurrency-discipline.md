---
name: concurrency-discipline
description: Backend Rule: Concurrency discipline (parallelize independent I/O)
kind: rule
pack: backend
severity: must
applies-to: backend-track, every-code-writing-task-in-backend
---

# Backend Rule: Concurrency discipline (parallelize independent I/O)

> **Hard rule.** Independent I/O calls in a per-request / per-batch / per-job code path MUST run concurrently with a bounded primitive. Sequential `await` of independent calls, unbounded `Promise.all` over user-controlled arrays, and parallel work inside a DB transaction are forbidden — each is a review halt.

> **Project-specific values** — concurrency primitive in use, bounded-concurrency helper path, default outbound-HTTP concurrency cap, default DB concurrency cap — are auto-injected by `scripts/apply-anchors.sh` during `/setup-project --refresh` into the `<!-- project-specific:start --> ... <!-- project-specific:end -->` block at the bottom of this file. Sourced from `.claude/_extracted-codebase.md` + `.claude/_extracted-idioms.md`. Do **not** edit those values here; edit the extraction sources and re-run `apply-anchors.sh` (or `/setup-project --refresh`) to propagate.

This rule prevents the most common backend perf failure: **sequential `await` of independent I/O**. The agent that writes `for (const x of xs) await f(x)` when `f` calls are independent is leaving 70–95% of wall-clock time on the table. This rule makes that mistake a review halt.

## Must

- **Identify independence first.** Before writing any sequential loop with `await`, ask: "Does iteration N+1 read any value produced by iteration N?" If no → it's parallelizable. If yes → it's sequential by data dependency, leave it.
- **Use the project's primitive.** Match the concurrency helper already used in the codebase. Mixing `Promise.all` with `Bluebird.map` with hand-rolled semaphores in the same project is a code-smell — pick the one that's already there.
- **Bound concurrency on every fan-out.** Unbounded `Promise.all([...largeArray.map(fetch)])` melts downstreams. Use `p-limit` / `Bluebird.map({concurrency})` / `asyncio.Semaphore` / `errgroup` with a cap. Default cap = 5–10 for HTTP, ≤ pool-size for DB.
- **Use `Promise.allSettled` (or equivalent) when partial failure is acceptable.** Reading 100 user profiles, 1 fails → don't fail the whole request; collect the 99 successes + log the 1.
- **Prefer batch APIs over fan-out.** Calling `findUserById` 100 times in parallel is wrong even bounded — the right answer is `findUsersByIds([...])`. Parallelism is a fallback when no batch API exists, not a default.
- **Cancel in-flight work on early exit.** When one parallel task fails and others must abort, propagate cancellation (`AbortController` / `context.Context` / `CancellationToken` / `asyncio.CancelledError`). Otherwise CPU + connections leak after the request returns.
- **Add timeouts on every parallel task.** A slow tail in a fan-out becomes the whole request's wall-clock. Per-task timeout < parent request budget.
- **Measure before AND after** when a change touches a parallelizable call site. Phase 5 verification needs a number, not "looks faster". Capture: count of upstream calls × per-call latency × concurrency = expected wall-clock. Compare to actual.

## Must not

- **Sequential `await` of independent calls** in any code path that runs per-request, per-batch, or per-job:
  ```js
  // ❌
  for (const id of ids) {
    const u = await getUser(id);
    results.push(u);
  }
  // ✅ (bounded)
  const limit = pLimit(8);
  const results = await Promise.all(ids.map(id => limit(() => getUser(id))));
  // ✅✅ (preferred — batch API)
  const results = await getUsersByIds(ids);
  ```
- **Unbounded `Promise.all` over user-controlled or large arrays.** A 10K-element fan-out hammers downstreams + breaks rate limits + can OOM. Always bound.
- **Parallelize writes that share a key.** `Promise.all([updateBalance(u, +5), updateBalance(u, -5)])` is a race. If order matters, sequential is correct; if order doesn't matter, the operation should be commutative (use `INCREMENT` / `UPDATE … SET x = x + ?`, not read-modify-write).
- **Parallelize inside a DB transaction.** Most ORM transactions are bound to a single connection — concurrent queries either deadlock, race, or serialize anyway. Sequential within a transaction is correct.
- **Mix concurrency primitives ad-hoc.** A new feature using `p-limit` in a codebase that already standardised on `Bluebird.map({concurrency})` adds cognitive load + dual maintenance. Either follow the standard or write an ADR for the change.
- **Ignore partial failures silently.** `Promise.all` on heterogeneous sources rejects on the first failure and discards the rest. If the caller cares which succeeded, use `Promise.allSettled` and surface the partition.
- **Parallelize for "future-proofing".** If `n` is provably ≤ 3 (e.g., reading three known config values), the readability cost of `Promise.all` exceeds the wall-clock win. Sequential is fine. The rule fires when `n` is variable, request-driven, or large.
- **Race two writes hoping the "right one wins".** `Promise.race([dbWrite, cacheWrite])` is not invalidation; it's a bug.

## Should

- **Express data dependencies, not control flow.** Tasks A + B are independent if neither reads the other's output. If you write parallel code first then add a dependency later, the structure decays — re-shape into a clear "phase N → phase N+1" pipeline.
- **Convert pipelines to staged parallelism**: Stage 1 fetches all inputs in parallel, Stage 2 transforms each (CPU-bound, possibly worker pool), Stage 3 writes results in parallel. This is more legible than nested `Promise.all` chains.
- **Use streams for large datasets.** Loading 1M rows into memory then `Promise.all`-mapping them is wrong even with bounded concurrency — you'll OOM before the cap helps. Stream + bounded transform is the answer.
- **Hoist independent reads above sequential mutations.** Common refactor: a service does 5 reads then 1 write — the 5 reads should run in parallel.
- **Run independent CPU work via worker threads / processes.** Node single-threaded event loop + 50ms+ CPU work = head-of-line blocking. Workers are the parallel primitive for compute, not `Promise.all`.

## Examples (language-specific recipes)

### Node.js / TypeScript

```ts
// Bounded parallel fan-out (preferred when no batch API)
import pLimit from 'p-limit';
const limit = pLimit(8);
const results = await Promise.all(items.map(item => limit(() => process(item))));

// Heterogeneous independent reads (fixed N, all required)
const [user, org, prefs] = await Promise.all([
  getUser(id),
  getOrg(orgId),
  getPrefs(id),
]);

// Partial-failure tolerant
const settled = await Promise.allSettled(items.map(fetchOne));
const ok = settled.flatMap(s => (s.status === 'fulfilled' ? [s.value] : []));
const failures = settled.flatMap(s => (s.status === 'rejected' ? [s.reason] : []));

// Cancellation
const ac = new AbortController();
try {
  await Promise.all(urls.map(u => fetch(u, { signal: ac.signal })));
} catch (e) {
  ac.abort();
  throw e;
}
```

### Python

```python
# asyncio.gather for fixed N independent awaitables
user, org, prefs = await asyncio.gather(get_user(id), get_org(org_id), get_prefs(id))

# Bounded fan-out via Semaphore
sem = asyncio.Semaphore(8)
async def bounded(item):
    async with sem:
        return await process(item)
results = await asyncio.gather(*(bounded(i) for i in items))

# Partial failure
results = await asyncio.gather(*(fetch_one(i) for i in items), return_exceptions=True)
ok = [r for r in results if not isinstance(r, Exception)]
```

### Go

```go
// errgroup for bounded parallel I/O with first-error cancellation
g, ctx := errgroup.WithContext(ctx)
g.SetLimit(8)
for _, id := range ids {
    id := id
    g.Go(func() error {
        u, err := getUser(ctx, id)
        if err != nil { return err }
        results.Store(id, u)
        return nil
    })
}
if err := g.Wait(); err != nil { return err }
```

### Java / Kotlin

```java
// CompletableFuture for fixed N
CompletableFuture<User> fU = userSvc.getAsync(id);
CompletableFuture<Org>  fO = orgSvc.getAsync(orgId);
CompletableFuture.allOf(fU, fO).join();

// Bounded parallel via virtual threads (Java 21+) or thread pool
try (var scope = StructuredTaskScope.<Result>open()) {
    var subtasks = ids.stream().map(id -> scope.fork(() -> fetch(id))).toList();
    scope.join().throwIfFailed();
    return subtasks.stream().map(StructuredTaskScope.Subtask::get).toList();
}
```

## Review checklist

- [ ] Every `await` inside a `for` / `forEach` / `map` was checked for independence — sequential ones have a written reason.
- [ ] Every parallel fan-out has a concurrency cap (no naked `Promise.all([...largeArray.map(...)])`).
- [ ] Heterogeneous fixed-N reads (`getUser` + `getOrg` + `getPrefs`) used `Promise.all` / `gather` / equivalent.
- [ ] Batch API was preferred over parallel fan-out when one exists.
- [ ] `Promise.allSettled` / `return_exceptions=True` used when partial failure is acceptable.
- [ ] No parallel work inside a DB transaction.
- [ ] No parallel writes share a key without a CAS / atomic primitive.
- [ ] Per-task timeout set; cancellation propagates on early failure.
- [ ] Wall-clock measurement attached to the change (before/after, or expected-vs-actual).

## Enforcement

- **Lint**: ESLint rule `no-await-in-loop` flags every `await` inside a loop — review each finding against the "data dependency?" question. Equivalent linters per stack: Pyright `reportAwaitInsideLoop`, golangci-lint `noctx`, etc.
- **Phase 5 audit** flags this rule as load-bearing for backend track. Enforcement is convention: PR review should halt on a sequential-await fan-out without a justification comment (no CI gate ships for this).
- **Phase 4.6 STUDY-DECIDE-ACT** anchors this rule to the project's actual primitive (extraction step). A rule body that talks about generic `Promise.all` while the project uses `Bluebird.map({concurrency})` is a leak.
- **Telemetry hint**: when `/learn-from-task` records a slowness regression and the touched code contains `await` inside a loop, Phase 6 promotes a candidate correction to `ai/dynamic/feedback-learned.md` referencing this rule.

## Anti-patterns (named)

- **The Sequential Loop Trap** — `for (const x of xs) await f(x)` where `f` is independent. Single biggest cause of "why does this endpoint take 8 seconds for 80 items?"
- **The Unbounded Fan-out** — `Promise.all(allUserIds.map(fetchProfile))` with 10K IDs. Hammers downstream, blows rate limits, OOMs the runtime.
- **The Hidden Sequential** — `async function f() { const x = await a(); const y = await b(); return [x, y]; }` when `a` and `b` are independent. Looks innocent, halves throughput.
- **The Transaction Fan-out** — `await tx.run(() => Promise.all([repo.update(a), repo.update(b)]))` — most ORMs serialise this on a single connection anyway, and you get the worst of both worlds.
- **The Race-as-Coordination** — `Promise.race([dbWrite, cacheWrite])` to "make it fast". This is non-deterministic broken.
