---
name: reporting-export-discipline
description: Reporting & export discipline
kind: rule
---

# Reporting & export discipline

## Hard rule

Any report or export that can return many rows or take longer than ~1s MUST run as an asynchronous, idempotent, resumable job that produces a downloadable artifact and notifies the caller — NEVER on the request thread. Rows MUST be STREAMED (keyset/cursor pagination or DB streaming) at constant memory — loading the full dataset into memory or `OFFSET`-paginating a large table is FORBIDDEN. Heavy aggregation MUST hit a READ REPLICA / analytics store / pre-aggregated view with a statement timeout — never the primary OLTP path. EVERY report query MUST carry the caller's tenant + permission scope as a row-level predicate; a missing tenant filter is a cross-tenant DATA LEAK. Date ranges MUST be bounded; sensitive/PII columns require an explicit allowlist + redaction + audit; download URLs MUST be signed and short-lived.

A report bug is silently wrong numbers, a melted primary database, or a cross-tenant leak — all of which erode trust far more than a failed request.

## Must

- **Async for anything heavy**: any report that can exceed ~1s or return more than a screenful of rows is enqueued as a job that produces an artifact (CSV/XLSX/PDF/Parquet) and notifies on completion (in-app / email / webhook). The HTTP request returns a `job_id` + status URL, never the data.
- **Idempotent + resumable jobs**: the job key derives from stable request params (`report:<type>:<tenant>:<paramsHash>`); a re-run with the same key returns the existing artifact, and a job that dies mid-stream resumes from the last committed keyset cursor — never restarts from row 0 and never double-emits.
- **Stream, never load-all**: write rows to the artifact as they are read (DB cursor / server-side stream / `for await` over a keyset page loop) at constant memory. The full result set is NEVER materialized in a list/array before formatting.
- **Keyset pagination on large tables**: deep pagination uses `WHERE (sort_key, id) > (:lastKey, :lastId) ORDER BY sort_key, id LIMIT :n`. `OFFSET`-based deep pagination on a large table is FORBIDDEN — it re-scans skipped rows and degrades linearly.
- **Read replica / analytics store**: heavy aggregation runs against a read replica, a dedicated analytics warehouse, or pre-aggregated materialized views — not the transactional primary. The reporting connection is a SEPARATE pool with a statement timeout so a runaway report cannot lock or starve the OLTP path.
- **Tenant + permission scope on every query**: every report query is row-level-scoped to the caller's tenant AND their permission set (`WHERE tenant_id = :ctxTenant AND ...`), enforced server-side from the auth context — never from a client-supplied tenant/org id. Endpoint auth is not enough; the WHERE clause is the boundary.
- **Bounded date ranges**: every time-windowed report rejects an unbounded or absurd range (default + max window, e.g. <= 366 days) and computes boundaries in the org's timezone, stored/queried as UTC.
- **As-of snapshot semantics**: a long export reads at a consistent point (snapshot isolation / `AS OF` / a captured high-watermark id or timestamp) so rows committed mid-export don't half-appear; the artifact is labeled with the as-of instant.
- **Column allowlist + redaction**: each report declares an explicit column allowlist; sensitive/PII columns are masked or omitted unless the caller's permission grants them; no secrets, internal ids, or unredacted PII reach an export.
- **Export access is audited**: who exported what, when, which columns, which tenant, row count, and the as-of instant are written to the audit log (see `<rules-path>/audit-log-integrity.md`) BEFORE the artifact link is handed out.
- **Signed, short-lived delivery**: artifacts live in a private bucket and are delivered via signed URLs with a short expiry (minutes–hours); generated artifacts are cleaned up on a TTL. Public buckets / permanent URLs are FORBIDDEN.
- **Rate-limited generation**: report generation is rate-limited per tenant/user (see `<rules-path>/rate-limit-enforcement.md`) so one tenant cannot exhaust the replica or the job workers.
- **Edge formatting**: currency uses the `Money` integer-minor-unit type (see `<patterns-path>/payment-integration.md § Money`); numbers/dates/locale are formatted at the serialization edge per the org's locale + timezone — never baked into the stored query result.

## Must not

- Generate a large/slow report synchronously on the request thread (it times out, holds a worker, and can OOM the box).
- Load the full result set into memory (`const rows = await query.all()`, `rows.map(toCsv)`) before writing the artifact.
- Use `OFFSET`/`LIMIT` for deep pagination over a large table — re-scans skipped rows; page 10,000 scans millions.
- Run heavy aggregation against the primary OLTP database / connection pool — locks, lock waits, and replica-less starvation of the transactional path.
- Omit the tenant/permission predicate on ANY report query, or derive the tenant from a client-supplied field instead of the auth context — cross-tenant leak.
- Accept an unbounded date range (`WHERE created_at > :start` with no end / no max window) — unbounded scan + unbounded memory + unbounded cost.
- Put PII / secret / internal columns into an export without an allowlist, redaction, and an audit entry.
- Hand out a public or non-expiring download URL, or leave generated artifacts in the bucket forever.
- Recompute the same expensive aggregate on every request with no caching / no scheduled rollup.
- Format money as a float, or format dates/numbers without an explicit timezone + locale.

## Should

- Wrap report execution behind a project-internal `<ReportRunner>` / `<ReportJob>` interface so the replica routing, statement timeout, streaming, and audit are enforced in one place — feature code declares a report spec, not raw SQL on the primary.
- Pre-aggregate expensive metrics via scheduled rollups (materialized views / summary tables refreshed by the jobs layer); serve dashboards from the rollup, not from live aggregation.
- Cache expensive aggregate responses with a freshness label ("data as of <ts>") and explicit invalidation (event-driven or TTL); never silently serve stale numbers as if live.
- Express each report as a declarative spec (columns, filters, sort key, tenant scope, allowlisted PII columns, format) so the streaming + scoping + redaction are derived, not hand-written per endpoint.
- Schedule recurring reports through the jobs layer (see `<patterns-path>/queue-producer-consumer.md`) with the same idempotency + audit + delivery contract as on-demand ones.
- Log structured `{ reportType, tenantId, rowCount, durationMs, targetedReplica, asOf, bytesOut }` per run; alert on reports that hit the primary, exceed the statement timeout, or breach a row/time budget.

## Review checklist (PRs touching reports / exports / dashboards / analytics queries)

- [ ] Heavy/large report runs as an async job returning a `job_id`, not inline data; job key is deterministic + resumable.
- [ ] Rows are streamed to the artifact at constant memory — no full-set materialization, no `.map()` over the whole dataset.
- [ ] Deep pagination is keyset/cursor — no `OFFSET` on a large table.
- [ ] Query targets a read replica / analytics store / materialized view with a statement timeout on a separate pool — not the primary.
- [ ] EVERY report query carries `tenant_id` + permission predicate from the auth context (not client-supplied); cite the predicate at `<path:line>`.
- [ ] Date range is bounded (default + max) and computed in the org timezone, queried as UTC.
- [ ] Long export reads at a consistent as-of instant; the artifact is labeled with it.
- [ ] Exported columns come from an explicit allowlist; PII/sensitive columns are redacted/gated by permission.
- [ ] Export is audit-logged (who/what/when/columns/rowCount/asOf) before the link is issued.
- [ ] Download URL is signed + short-expiry from a private bucket; artifact has a cleanup TTL.
- [ ] Generation is rate-limited per tenant/user.
- [ ] Money uses the integer-minor-unit type; numbers/dates formatted at the edge with explicit locale + timezone.

## Anti-patterns

- **Sync mega-export** — `GET /reports/orders.csv` builds the whole file inline -> 30s request -> gateway timeout -> user retries -> three workers stuck building the same file.
- **Load-all-then-map** — `const rows = await repo.findAll(filter); return rows.map(toRow)` for a 4M-row table -> OOM. Stream a keyset page loop straight into the writer.
- **OFFSET deep pagination** — `LIMIT 100 OFFSET 900000` re-scans 900k rows per page; export wall-time goes quadratic. Use `WHERE (created_at, id) > (:k, :id)`.
- **Reporting on the primary** — a marketing "all-time revenue by day" query table-scans the orders table on the primary at 9am -> checkout latency spikes for everyone. Route to the replica with a statement timeout.
- **Missing tenant filter** — `SELECT * FROM invoices WHERE created_at BETWEEN ...` with no `tenant_id` -> tenant A exports tenant B's invoices. The single most damaging report bug. The WHERE clause is the security boundary.
- **Client-supplied tenant** — `WHERE tenant_id = :req.query.tenantId` -> trivially set to anyone's id. Tenant comes from the verified auth context only.
- **Unbounded range** — "export everything" with no end date -> full-history scan that grows forever; eventually times out and never completes. Reject; cap the window.
- **PII leak in export** — a CSV includes `password_hash` / `ssn` / internal `cost_price` because the query was `SELECT *`. Allowlist columns; redact; audit.
- **Public download URL** — artifact uploaded to a public bucket, URL emailed -> indexed / shared / forwarded -> anyone reads the report. Signed short-lived URL from a private bucket; cleanup on TTL.
- **Uncached repeated aggregate** — the dashboard recomputes "MRR by plan" on every page load -> replica saturated by the dashboard alone. Pre-aggregate / cache with a freshness label.
- **Naive timezone boundary** — "today's orders" computed in UTC for an org in GMT+8 -> the daily report is shifted 8 hours and the totals never tie out. Compute boundaries in the org timezone, store/query UTC.
- **Float money in reports** — `SUM(price)` as a float -> fractional-cent drift -> the report total disagrees with the ledger. Sum integer minor units; format at the edge.

## Enforcement

- `<commands-path>/profile-report-query.md` (slash: `/profile-report-query`) — profiles a specific report query end-to-end: the SQL, EXPLAIN/EXPLAIN ANALYZE plan, estimated/actual row count, replica targeting, and the tenant-scope predicate at `<path:line>` — cite-or-halt, never an assumed plan.
- `<agents-path>/reporting-reviewer.md` — review gate hard-failing on sync heavy reports, load-all-in-memory, OFFSET deep pagination, primary-DB reporting, missing tenant/permission scope, unbounded ranges, un-redacted PII exports, and public/non-expiring URLs.
- CI lint MUST reject `OFFSET` in any query file tagged as a report/analytics query (heuristic; flag for review).
- CI lint MUST reject `SELECT *` in report query builders — exports require an explicit column allowlist.
- CI lint MUST reject report query builders that read a tenant/org id from request input rather than the auth context (AST heuristic; flag for review).
- CI MUST assert the reporting DB connection is configured with a non-null statement timeout and points at the replica/analytics DSN, not the primary.
- TODO: `scripts/validate-report-scoping.sh` to AST-walk report query builders and assert every one applies a tenant + permission predicate from the auth context AND streams (no full-set collector) before formatting.

## Cross-references

- `<patterns-path>/report-generation.md` — async job + streaming writer + keyset loop + replica routing + as-of snapshot + signed delivery code shapes.
- `<rules-path>/audit-log-integrity.md` — export access is an audited event; what to record per export.
- `<rules-path>/rate-limit-enforcement.md` — per-tenant/user generation rate limits.
- `<patterns-path>/queue-producer-consumer.md` — async job semantics (idempotency, resumability, DLQ, observability) for report jobs + scheduled reports.
- `<patterns-path>/payment-integration.md § Money` — integer-minor-unit money type for monetary columns in reports.
- `<commands-path>/profile-report-query.md` — query-profiling tool.
- `<agents-path>/reporting-reviewer.md` — review gate.
- `<adr-path>/<NNN>-reporting-read-store.md` — ADR pinning the read replica / analytics store choice + the snapshot/freshness contract.
