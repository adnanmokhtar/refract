---
name: n-plus-one-scan
description: Static + runtime scan for N+1 ORM patterns. Catches the #1 silent performance killer.
---

# n-plus-one-scan

Find loops that issue one query per iteration when one batched query would do.

## Premise

Find real N+1 issues, cite `<path:line>` for every confirmed pattern and back it with a query count from the runtime pass. "CONFIRMED" requires both a static hit AND a counted query log. "LIKELY" requires a static hit with a clearly lazy relation. No accusation without coordinates — every finding points at a specific call site and a specific log excerpt. Fixes are concrete (eager-load with named relation, DataLoader at named scope), not "consider batching".

## Halt conditions

- Refuse to mark "CONFIRMED" without a query-count from the DB engine's query log or equivalent.
- Halt on hand-waves like "this pattern looks N+1" — cite the line or drop the finding.
- Don't flag batched / `IN (...)` calls (e.g., `findByIds([...])`) — those are single batched queries; read closely.
- Don't propose a fix without naming the relation / loader / index involved.

## When to use

- Before merging any new list / collection endpoint.
- When `profile-endpoint` shows "many fast queries" instead of "one slow query".
- After adding a new ORM relation — lazy by default in many ORMs.
- During code review of any `.map(async ...)` or `for ... of` over entities.

## Prerequisites

- `ripgrep` for the static pass.
- Coverage of which files use the project's ORM / data-mapper.
- Optional: ability to enable query logging on the dev DB.

## Procedure — static pass

1. Find loops with awaited repo / fetch-by-id calls inside, using the project's own iteration idiom (for-of, foreach, comprehension, range). The signal is a **single-row fetch primitive** — `findOne` / `findById` / `where(...).first` / `get(...)` — called inside the loop body.
2. Find parallel-mapping patterns that still hit the store once per element (`Promise.all(list.map(async …))`, `asyncio.gather`, errgroup over a slice, `Task.WhenAll`). **Parallelism does not eliminate N+1** — it runs the same N queries concurrently, and often makes the database worse off.
3. Find lazy-relation access inside response loops — an association that defaults to lazy and gets touched during serialization, once per row.
4. Cross-check data-access methods — if the method's name carries no "with-relations" / "include" / "eager" qualifier but the caller iterates the relation, that is an N+1 smell.

> The static pass **locates candidates; it never confirms one.** An N+1 is a claim about query COUNT, and only the runtime pass below can make it. Ship a static hit as a finding and you are asserting a measurement you did not take.

## Procedure — runtime pass

1. Enable query log on the dev DB:
   ```bash
   # Turn the engine's slow-query log down to zero for the run (statement is engine-specific —
   # `references/<engine>.md`), and reset it afterwards. Counting statements is the whole point:
   # N+1 is a claim about query COUNT, so a run that did not count is not evidence.
   ```
2. Hit the suspect endpoint once and count queries:
   ```bash
   curl -sS "http://localhost:3000/orders?limit=20" -H "Authorization: Bearer $JWT" >/dev/null
   # Count the statements the engine logged for ONE request. The engine's log path comes from
   # its own config — never a distro default.
   ```
3. Rule of thumb: a list endpoint should issue 1-3 queries — not `1 + N`. Ten orders returning 11+ queries = confirmed N+1.

## Output

```
N+1 scan — src/modules/orders

CONFIRMED N+1 (static + runtime):
  src/modules/orders/application/list-orders.use-case.ts:24
    `await customerRepo.findById(o.customerId)` inside `orders.map`
    Runtime: list of 20 orders → 21 queries.
    Fix: eager-load the relation in the same statement, OR batch the child fetch through a per-request batch loader.

LIKELY N+1 (static):
  src/modules/invoices/adapters/invoice.controller.ts:45
    `invoice.items` accessed in response; relation is lazy.
    Fix: eager-load items in the repo query, OR project only item IDs.

NOT N+1 (false alarm):
  src/modules/reports/application/monthly.use-case.ts:67
    `await productRepo.findByIds([...allIds])` — single batched call, OK.
```

## Fixes (in order of preference)

1. **Eager-load via JOIN / batched select** — the mapper's include/join primitive, so parent and children arrive together.
2. **DataLoader** — batches N parallel calls into one per tick. Best for GraphQL or repeated cross-cutting fetches.
3. **Denormalize** — last resort. Counter cache or flat copy maintained in subscribers.

## False positives / gotchas

- `findByIds([...])` is a single query, not N+1, even though the call is "in a loop" — read closely.
- Pagination + relation include can be a different N+1 (the OUTER query becomes huge) — measure both.
- Eager-loading EVERYTHING is a different bug — load only what the response needs.
- Some mappers issue extra statements even when the call site reads like a single query — never conclude from the source alone; the runtime count is the evidence.
- A batch loader MUST be scoped per request. One shared across requests is a cache that serves one user's rows to another — a correctness and tenancy bug, not a perf detail.
