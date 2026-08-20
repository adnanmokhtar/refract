---
name: n-plus-one-scan
description: Static + runtime scan for N+1 ORM patterns — the silent per-element query that turns one request into hundreds. Run before merging a new list or collection endpoint, after adding an ORM relation (lazy by default in many ORMs), and when `profile-endpoint` shows many fast queries rather than one slow one. Finds the pattern; it does not run a load campaign.
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
- During code review of any per-element await loop / parallel mapping over entities that issues a per-element fetch.

## Prerequisites

- `ripgrep` (or any code-search tool) for the static pass.
- Coverage of which files use the project's ORM / data-access layer (the project's stack-native ORM — e.g., TypeORM/Prisma/Drizzle for Node, SQLAlchemy/Django ORM for Python, ActiveRecord/Sequel for Ruby, GORM for Go, JPA/Hibernate for Java, EF Core for .NET, Ecto for Elixir, Diesel/SeaORM for Rust).
- Optional: ability to enable query logging on the dev DB.

## Procedure — static pass

1. Find loops with awaited repo / fetch-by-id calls inside (use the project's stack-native loop / iteration / await idiom — for-of over a collection, foreach, etc.). The signal: a single-row fetch primitive (`findOne`, `findById`, `findBy`, `where(...).first`, `get(...)`) called inside the loop body.
2. Find parallel-mapping patterns that still hit the DB once per element — e.g., `Promise.all(list.map(async ...))` for Node, `asyncio.gather([...])` for Python, errgroup over a slice for Go, `Task.WhenAll` for .NET, etc. Parallelism does not eliminate N+1; it just runs N queries concurrently.
3. Find lazy-relation access in response loops (an ORM relation that defaults to lazy and is iterated in the response shape — e.g., the parent's `items` / `customer` / nested associations accessed during JSON serialization).
4. Cross-check repository / data-access methods — if the method's name doesn't include a "with-relations" / "include" / "eager" qualifier but the caller iterates the relation, that's an N+1 smell.

## Procedure — runtime pass

1. Enable query log on the dev DB (each engine has its own knob — Postgres `log_min_duration_statement`, MySQL slow-query log, etc.).
2. Hit the suspect endpoint once and count queries (tail the DB log; count `duration:` lines or equivalent).
3. Rule of thumb: a list endpoint should issue 1-3 queries — not `1 + N`. Ten parent rows returning 11+ queries = confirmed N+1.

## Output (illustrative)

```
N+1 scan — <orders module>

CONFIRMED N+1 (static + runtime):
  <list-orders use-case file:24>
    a per-row fetch-by-id call (`findById(o.customerId)`) inside the orders mapper
    Runtime: list of 20 orders → 21 queries.
    Fix: include customer via the ORM's join / include directive, OR batch via the project's batch-loader.

LIKELY N+1 (static):
  <invoice controller file:45>
    `invoice.items` accessed in response; relation is lazy.
    Fix: eager-load items in the repo query, OR project only item IDs.

NOT N+1 (false alarm):
  <monthly report use-case file:67>
    a batched-by-ids call (`findByIds([...allIds])`) — single batched call, OK.
```

## Fixes (in order of preference)

1. **Eager-load via JOIN** — the ORM's eager-load / include directive (every ORM has one — e.g., `leftJoinAndSelect`, `include`, `selectinload`, `includes`, `Preload`, `JOIN FETCH`).
2. **Batch-loader** — batches N parallel calls into one per tick. Best for GraphQL or repeated cross-cutting fetches (e.g., DataLoader for Node, equivalent libraries / patterns in other languages).
3. **Denormalize** — last resort. Counter cache or flat copy maintained in subscribers.

## False positives / gotchas

- A batched-by-ids call (`findByIds([...])` / `WHERE id IN (...)`) is a single query, not N+1, even though the call is "in a loop" — read closely.
- Pagination + relation include can be a different N+1 (the OUTER query becomes huge) — measure both.
- Eager-loading EVERYTHING is a different bug — load only what the response needs.
- Some ORMs issue extra queries even when they look like one — verify with the runtime pass.
- Batch-loaders require a per-request scope; leaking across requests = cache pollution.
