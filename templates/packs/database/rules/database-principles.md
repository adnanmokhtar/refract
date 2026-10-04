---
paths:
  - "**/*.{ts,tsx,mts,cts,js,jsx,mjs,cjs,vue,svelte,astro}"
  - "**/*.{py,pyi,rb,php,go,rs,java,kt,kts,scala,groovy,cs,fs,vb,swift,m,mm,dart}"
  - "**/*.{ex,exs,erl,hrl,clj,cljs,cljc,hs,ml,elm,lua,pl,pm,r,R,jl,zig,nim,cr,c,h,cc,cpp,cxx,hpp}"
  - "**/*.{sql,prisma,graphql,gql,proto}"
  - "**/*.{html,htm,css,scss,sass,less,styl,pcss}"
  - "**/*.{erb,haml,slim,hbs,handlebars,ejs,njk,liquid,twig,cshtml,razor,jinja,jinja2,j2,mustache,pug,mjml,tex}"
  - "**/*.{yml,yaml,json,jsonc,json5,toml,ini,cfg,conf,properties,xml,env,plist,gradle}"
  - "**/migrations/**"
  - "**/migrate/**"
  - "**/alembic/versions/**"
  - "**/prisma/migrations/**"
  - "**/db/migrate/**"
paths-origin: pack-default-6d96769b
name: database-principles
description: Database Principles
kind: rule
pack: database
severity: must
applies-to: database-track, every-code-writing-task-in-database
---

# Database Principles

> **Hard rule.** Schema changes ship via reviewed migrations only — `synchronize: true` / auto-migrate / `db.create_all()` in production are forbidden. Every list query MUST paginate with `LIMIT`; every FK MUST have a usable index; every transaction MUST stay local (no external HTTP / queue / API call held inside).

This file states the **invariant**; the linked `ai/patterns/<x>.md` carries the method *and the vendor citation for every engine claim below*, `.claude/references/<engine>.md` the syntax. Never assert an engine behaviour named here without following its pointer.

## Must

- Primary keys: UUID v7 (time-ordered, B-tree friendly) or bigint sequences. Never `int` — overflow is a real outage at scale.
- Timestamps stored UTC + timezone-aware (`TIMESTAMPTZ` in Postgres, `DATETIME(6)` + always-UTC convention in MySQL).
- Foreign keys declared at the DB level with `ON DELETE` semantics chosen explicitly (`RESTRICT` / `CASCADE` / `SET NULL`). ORM-only FKs do not protect data.
- Every FK column has a usable index — without one, deletes and joins do full scans. **Engine split:** Postgres does not create it, so declare it; InnoDB creates one automatically, so on MySQL the finding inverts. → `ai/patterns/indexing-strategy.md`.
- Money per `THR-MONEY` (DATA-9); never `FLOAT` / `DOUBLE`.
- `NOT NULL` is the default; nullability is a documented design choice, not laziness.
- Unique constraints for natural keys (`email`, `slug + tenant_id`, `idempotency_key`) — the DB is where the race is actually lost.
- Parameterized queries / prepared statements / ORM bind params only. Never interpolate into SQL.
- Pagination on every list query. `LIMIT` mandatory.
- Soft-delete / multi-tenant projects: every custom query carries the `deleted_at IS NULL` and `tenant_id = :tenantId` filters, or uses the base repo that adds them.
- Contended read-modify-write (balance, inventory, counter, seat, sequence) is `SELECT … FOR UPDATE`-locked or version-guarded on `rowcount == 1` — never load-mutate-save unguarded. Serialization failures (`40001` / `40P01`) retry; multi-row locks take one fixed order. → `ai/patterns/transaction-isolation.md`.
- Every PII column is classified, with a declared retention window enforced by a real mechanism (partition-drop / TTL job / purge), and an erasure path that resolves every dependent FK — no orphan, no FK that silently blocks it. → `ai/patterns/data-retention-pii.md`.
- Text search on a large table uses the engine's real FTS primitive, kept in sync by a `GENERATED … STORED` column or trigger, returning **ranked** results — never `LIKE '%term%'` forcing a full scan. → `ai/patterns/full-text-search.md`.
- Every process reaches the DB through a **bounded** pool satisfying `per_instance_pool_max × instance_count + other_clients ≤ server_max_connections − reserve` — never a connection per request, never a guessed size. → `ai/patterns/connection-pooling.md`.
- A read routed to a replica tolerates lag; read-your-writes and correctness-sensitive reads (auth / authorization / balance / inventory / uniqueness pre-check) go to the **primary** or carry a consistency token. → `ai/patterns/read-replicas.md`.

## Must not

- `synchronize: true` (TypeORM) / `db.create_all()` in production / auto-migrate flags. Schema by migration only.
- Ship an `ALTER TABLE` without naming **(a)** the algorithm the engine will pick and **(b)** whether a long transaction currently holds a metadata lock on the target. The algorithm — not the row count — sets the lock window, and every `ALTER`, INSTANT included, queues behind the oldest open transaction. Check `information_schema.INNODB_TRX` / `pg_stat_activity` first and bound the wait (`lock_wait_timeout` / `lock_timeout`). Per-operation split, `LOCK=NONE`'s cascade limit, and when `gh-ost` / `pt-osc` earn their place: → `ai/patterns/migrations.md`, `migration-safety`.
- Hold a transaction across an HTTP / queue / external API call. The pool exhausts at peak, and the pinned snapshot blocks reclaim (Postgres vacuum / InnoDB purge).
- `SELECT *` on wide rows (BLOB / JSON / TEXT) when you need 3 fields. Bandwidth + parse cost.
- Choose composite index column order at random. Leftmost prefix decides: `(tenant_id, status, created_at)` serves `WHERE tenant_id = ? AND status = ?`, not `WHERE status = ?` — unless PG 18+ skip scan serves a few-valued leading column; prove it with a plan (`index-coverage-scan`).
- Over-index. Every index slows writes. Drop what `pg_stat_user_indexes` / `sys.schema_unused_indexes` never records — never one backing a unique constraint or an FK. On InnoDB the FK-index advice inverts: read `SHOW INDEX` before reporting "missing FK index" or proposing a drop. → `ai/patterns/indexing-strategy.md`.
- Put business logic in triggers without a documented reason — invisible to code review, painful to debug.

## Should

- `EXPLAIN ANALYZE` (Postgres; MySQL 8, always `TREE` format) on any new query whose predicate is not already served by an existing index's leading columns — index coverage is the trigger, not a row-count threshold. Reject a full scan whose filter discards most of what it read, unless documented.
- CHECK constraints for invariants the app should not re-enforce (`CHECK (price >= 0)`, `CHECK (status IN (…))`).
- Migrations reversible (ship a `down`) where feasible; otherwise document the forward-fix plan in the migration header.
- Expand-contract for breaking changes — add → backfill → switch reads → switch writes → drop — each step its own deploy. → `ai/patterns/migrations.md`.
- `pg_stat_statements` / MySQL `events_statements_summary_by_digest` enabled; review the top statements by total exec time weekly.

## Review + enforcement

Detection is the detectors' job (`n-plus-one-scan`, `query-shape-scan`, `index-coverage-scan`, `schema-integrity-scan`, `migration-safety`, `transaction-scan`, `connection-config-scan`): `/db-audit` runs them, `/db-fix` closes their findings, `@schema-reviewer` grades a diff (APPROVE gate). None is restated here (duplicated context).

CI-side: a migration linter blocks unsafe migrations; slow-query logging on in dev + staging; backups automated and the **restore** tested on a schedule — an untested backup does not exist.
