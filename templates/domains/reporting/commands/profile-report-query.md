---
description: Profile a specific report / analytics query — plan, row count, replica targeting, and tenant-scope predicate — against real EXPLAIN output, never an assumed plan.
---

# /profile-report-query

Diagnose whether a specific report query is safe + fast: what it scans, how many rows, whether it runs on a replica, and whether it is tenant-scoped — from the REAL query plan, not a guess.

## Premise

Real signals only. Cite the actual query text at `<path:line>`, the verbatim EXPLAIN / EXPLAIN ANALYZE output, the estimated AND actual row count, the connection/DSN the query runs on (primary vs. replica/analytics), and the tenant-scope predicate at `<path:line>` — never narrate a plan you didn't run. Read before profiling: locate the query in source and confirm the bound parameters (tenant id, date range) BEFORE executing anything.

## Mechanical halt

Cite-or-halt: every run MUST print (1) the query at `<path:line>`, (2) the EXPLAIN/EXPLAIN ANALYZE output as returned by the DB, (3) estimated vs. actual rows, (4) whether the target connection is the primary or a replica/analytics store, and (5) the tenant + permission predicate at `<path:line>` (or "MISSING — cross-tenant leak"). If any of these cannot be produced from real output, HALT and say which — never an assumed plan, never an assumed row count.

EXPLAIN ANALYZE EXECUTES the query. Run `EXPLAIN ANALYZE` ONLY against a read replica / analytics store / non-prod copy — NEVER against the production primary, and NEVER for a mutating statement. Use plain `EXPLAIN` (no ANALYZE) if only a non-prod plan is available.

## What it does

1. **Locate** the query in source — cite `<path:line>` and the exact SQL / query-builder chain.
2. **Resolve the connection** — which pool/DSN does this query use? Primary, read replica, or analytics store? Print it. Reporting on the primary is a finding, not a footnote.
3. **Bind realistic params** — a representative `tenant_id` and a representative bounded date range. Note if the range is unbounded (finding).
4. **Run EXPLAIN (and EXPLAIN ANALYZE on a replica/non-prod)** — capture the verbatim plan: scan types (Seq Scan vs. Index Scan), join strategy, sort, the largest node's estimated AND actual rows + the index used (or "none").
5. **Check the tenant + permission predicate** — confirm `tenant_id = <auth-context>` (and permission filters) appear in the WHERE clause AND are bound from the auth context, not request input. Cite `<path:line>`; if absent, flag CROSS-TENANT LEAK.
6. **Check pagination shape** — keyset vs. `OFFSET`. Flag `OFFSET` on a large table.
7. **Check streaming + materialization** — is this query consumed via a cursor/stream, or `findAll().map()`? Cite the consumer at `<path:line>`.
8. **Report** — plan summary, row counts, replica verdict, scope verdict, pagination verdict, and the top index/rewrite recommendation.

## Flow

```text
locate query (<path:line>)
  -> resolve connection (primary | replica | analytics)        [finding if primary]
  -> bind tenant + bounded range                               [finding if unbounded]
  -> EXPLAIN  (plan)  / EXPLAIN ANALYZE on replica (actuals)
  -> read plan: scan type, rows est vs actual, index used
  -> assert tenant + permission predicate from auth context    [BLOCKER if missing]
  -> assert keyset (not OFFSET) on large tables                [finding if OFFSET]
  -> assert streamed consumption (not load-all)                [finding if materialized]
  -> report: plan + counts + verdicts + top recommendation
```

## Output

```
/profile-report-query — <report type> @ <path:line>

Query (<path:line>):
  SELECT ... FROM <table> WHERE tenant_id = $1 AND created_at >= $2 AND created_at < $3 ORDER BY created_at, id LIMIT 5000

Connection:        replica  (dsn: reports-ro)  statement_timeout=30s     [or: PRIMARY — BLOCKER]
Tenant scope:      tenant_id = $1  bound from ctx.tenantId  @ service.ts:41   [or: MISSING — cross-tenant leak]
Date range:        bounded 30d (max 366d), org-tz boundaries               [or: UNBOUNDED — finding]
Pagination:        keyset (created_at, id)                                  [or: OFFSET — finding]
Consumption:       streamed via cursor @ worker.ts:52                       [or: findAll().map() — finding]

Plan (EXPLAIN ANALYZE on replica):
  <verbatim plan>
  Largest node:  Index Scan using idx_orders_tenant_created  (est 5,000  actual 4,981)
  Seq Scan:      none                                                       [or: Seq Scan on orders (est 4.1M) — finding]

Verdict: OK | NEEDS-INDEX | NEEDS-KEYSET | NEEDS-REPLICA | BLOCKER(scope)

Top recommendation:
  - <e.g. add composite index (tenant_id, created_at, id); or rewrite OFFSET -> keyset; or route to replica>
```

## Rules

- READ-ONLY profiling. `EXPLAIN ANALYZE` runs ONLY on a replica / analytics store / non-prod copy — never the production primary, never a mutating statement.
- Cite-or-halt: real query, real plan, real row counts, real connection, real predicate — or halt naming what's missing.
- Always print the tenant + permission predicate verdict; a missing one is a CROSS-TENANT LEAK, reported first.
- Never report a plan or row count you didn't obtain from actual DB output.
- If the query runs on the primary, say so — that is a finding, not an aside.

## Cross-references

- `.claude/rules/reporting-export-discipline.md` — the hard-rule list this command enforces (replica, tenant scope, keyset, streaming, bounded range).
- `ai/patterns/report-generation.md` — the keyset loop + replica routing + tenant-scoped query shape.
- `<agents-path>/reporting-reviewer.md` — review gate that consumes these findings.
