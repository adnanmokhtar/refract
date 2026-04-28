---
name: n-plus-one-scan
description: Static + runtime scan for N+1 ORM patterns. Catches the #1 silent performance killer.
---

# n-plus-one-scan

Find loops that issue one query per iteration when one batched query would do.

## When to use

- Before merging any new list / collection endpoint.
- When `profile-endpoint` shows "many fast queries" instead of "one slow query".
- After adding a new ORM relation — lazy by default in many ORMs.
- During code review of any `.map(async ...)` or `for ... of` over entities.

## Prerequisites

- `ripgrep` for the static pass.
- Coverage of which files use the ORM (TypeORM/Prisma/Sequelize/SQLAlchemy/ActiveRecord).
- Optional: ability to enable query logging on the dev DB.

## Procedure — static pass

1. Find loops with awaited repo calls inside:
   ```bash
   rg -n -U --multiline --multiline-dotall \
     '(for\s*\([^)]+\)\s*\{[^}]*await\s+\w+\.(find|findOne|findById|findBy)\b)' \
     --type ts apps libs src
   ```
2. Find `Promise.all(list.map(async ...))` patterns — parallel N+1 still hits the DB N times:
   ```bash
   rg -n -U --multiline-dotall 'Promise\.all\(\s*\w+\.map\(\s*(async\s+)?\([^)]*\)\s*=>\s*[^)]*\.(find|findOne|findById)\b' --type ts
   ```
3. Find lazy-relation access in response loops (TypeORM `RelationOptions { eager: false }`, Prisma without `include`):
   ```bash
   rg -n '\.(items|customer|orders|products)\b' --type ts apps libs src \
     | rg -B 2 'forEach|map\(' 
   ```
4. Cross-check repository methods — if the method's name doesn't include `WithRelations` or `WithIncludes` but the caller iterates the relation, that's a N+1 smell.

## Procedure — runtime pass

1. Enable query log on the dev DB:
   ```bash
   psql "$DATABASE_URL" -c "ALTER SYSTEM SET log_min_duration_statement=0; SELECT pg_reload_conf();"
   ```
2. Hit the suspect endpoint once and count queries:
   ```bash
   curl -sS "http://localhost:3000/orders?limit=20" -H "Authorization: Bearer $JWT" >/dev/null
   tail -n 200 /var/log/postgresql/postgresql-15-main.log | grep -c 'duration:'
   ```
3. Rule of thumb: a list endpoint should issue 1-3 queries — not `1 + N`. Ten orders returning 11+ queries = confirmed N+1.

## Output

```
N+1 scan — src/modules/orders

CONFIRMED N+1 (static + runtime):
  src/modules/orders/application/list-orders.use-case.ts:24
    `await customerRepo.findById(o.customerId)` inside `orders.map`
    Runtime: list of 20 orders → 21 queries.
    Fix: include customer via leftJoinAndSelect, OR batch with DataLoader.

LIKELY N+1 (static):
  src/modules/invoices/adapters/invoice.controller.ts:45
    `invoice.items` accessed in response; relation is lazy.
    Fix: eager-load items in the repo query, OR project only item IDs.

NOT N+1 (false alarm):
  src/modules/reports/application/monthly.use-case.ts:67
    `await productRepo.findByIds([...allIds])` — single batched call, OK.
```

## Fixes (in order of preference)

1. **Eager-load via JOIN** — `leftJoinAndSelect`, Prisma `include`, SQLAlchemy `selectinload`, ActiveRecord `includes`.
2. **DataLoader** — batches N parallel calls into one per tick. Best for GraphQL or repeated cross-cutting fetches.
3. **Denormalize** — last resort. Counter cache or flat copy maintained in subscribers.

## False positives / gotchas

- `findByIds([...])` is a single query, not N+1, even though the call is "in a loop" — read closely.
- Pagination + relation include can be a different N+1 (the OUTER query becomes huge) — measure both.
- Eager-loading EVERYTHING is a different bug — load only what the response needs.
- Some ORMs (TypeORM with `findOne` + `relations`) issue extra queries even when they look like one — verify with the runtime pass.
- DataLoader requires a per-request scope (Nest `REQUEST` scope) — leaking across requests = cache pollution.
