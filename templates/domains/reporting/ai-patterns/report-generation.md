---
name: report-generation
description: "Pattern: Report generation (async job, streamed, replica-routed, tenant-scoped)"
kind: ai-pattern
---

# Pattern: Report generation (async job, streamed, replica-routed, tenant-scoped)

> **Hard rule** — A heavy/large report runs as an idempotent async job, never on the request thread; rows are STREAMED via keyset pagination at constant memory, never loaded all-at-once; the query targets a READ REPLICA / analytics store with a statement timeout, never the primary; EVERY query carries the caller's tenant + permission predicate from the auth context; delivery is a signed, short-lived URL and the export is audit-logged.

**When to apply**
- Any tabular export (CSV / XLSX / Parquet) or dashboard aggregate over a table that grows unbounded with usage.
- Multi-tenant products where every row is owned by exactly one tenant and reports must never cross that line.
- Scheduled / recurring reports, or any report whose p95 runtime or row count exceeds an interactive budget.

**When NOT to apply**
- A small, bounded lookup (a single entity's detail view, a < 100-row config list) — the async + streaming machinery is overhead.
- Real-time operational counters served from a cache / counter store — that's a metrics pattern, not a batch report.
- An OLAP product where the warehouse + its own access layer is the system of record — use its native scoping, don't reimplement.

**Halt conditions / mandatory cites**
- Cite the async job enqueue + artifact-producing worker at `<path:line>`. A heavy report computed inline in the request handler = halt.
- Cite the streaming writer + keyset page loop at `<path:line>`. A `findAll()` / `.map()` over the full set = halt.
- Cite the replica/analytics connection + its statement timeout at `<path:line>`. Reporting on the primary pool = halt.
- Cite the tenant + permission predicate, sourced from the auth context, at `<path:line>`. Missing predicate or client-supplied tenant = halt (cross-tenant leak).
- Cite the bounded date-range guard, the column allowlist, the audit-log write, and the signed-URL issuance at `<path:line>` each.
- Grep ban: "the report is scoped/safe/fast" without file:line for the tenant predicate, the streaming loop, the replica routing, and the audit write.

## Why

Reports are the one workload that is simultaneously heavy (full-table scans, big result sets), security-critical (they cross every row a tenant owns), and trust-critical (the numbers are taken as truth). The three failure modes recur:

1. **It melts the primary** — a heavy aggregation on the transactional DB takes locks / saturates the pool / starves checkout. Reporting belongs on a read replica or analytics store with a statement timeout.
2. **It leaks across tenants** — one missing `tenant_id` in a WHERE clause exports another tenant's data. Endpoint auth doesn't help; the predicate is the boundary, applied from the auth context on every query.
3. **It blocks or OOMs** — a synchronous export builds the whole file in memory, times out the request, holds a worker, and falls over at scale. Reports run async and stream at constant memory.

The pattern: declare a report SPEC, run it as an async job, stream keyset pages from a replica with the tenant predicate baked in, write to an artifact, audit, and deliver a signed short-lived URL.

## Report spec (declarative)

```ts
// src/modules/reporting/core/report-spec.ts

export interface ReportSpec<Row> {
  type: string;                         // 'orders-export', 'revenue-by-day'
  /** Allowlisted output columns. SELECT * is forbidden; PII columns gated by permission. */
  columns: ReadonlyArray<ColumnDef<Row>>;
  /** Stable sort key for keyset pagination — MUST be unique-with-id, indexed. */
  sortKey: keyof Row;
  /** Hard bound on the time window the report will accept. */
  maxWindowDays: number;
  /** Permissions the caller must hold to include each sensitive column. */
  redactions: ReadonlyArray<{ column: keyof Row; requires: Permission }>;
  format: 'csv' | 'xlsx' | 'parquet';
}

export type ColumnDef<Row> = {
  key: keyof Row;
  header: string;
  /** Edge formatter — money via Money.format, dates in org tz, numbers per locale. */
  render: (value: Row[keyof Row], ctx: FormatCtx) => string;
};
```

The spec — not raw SQL in a controller — is what feature code authors. Scoping, streaming, redaction, and formatting are derived from it.

## Request handler: enqueue, never compute

> The TypeScript example below uses NestJS-style decorators + helpers like `findOrThrow` for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the framework decorators (Express / FastAPI / Spring / etc.), the lookup-or-throw helper your repository exposes, the DI mechanism your project uses. The SHAPE — validate + bound the params -> derive an idempotent job key -> enqueue -> return a job id — is what's universal, not the specific helper names.

```ts
// src/modules/reporting/reporting.controller.ts

@Controller('/reports')
export class ReportingController {
  constructor(
    @Inject(QUEUE) private queue: Queue,
    @Inject(REPORT_JOBS) private jobs: ReportJobsRepo,
    @Inject(RATE_LIMITER) private limiter: RateLimiter,
  ) {}

  @Post('/:type/export')
  async requestExport(
    @Param('type') type: string,
    @Body() body: ExportRequestDto,
    @Ctx() ctx: AuthContext,           // tenant + permissions come from HERE, never the body
  ): Promise<{ jobId: string; statusUrl: string }> {
    await this.limiter.consume(`report:${ctx.tenantId}:${ctx.userId}`);   // per-tenant/user cap

    const range = boundDateRange(body.from, body.to, SPECS[type].maxWindowDays, ctx.orgTimezone);
    if (!range.ok) throw new UnboundedRangeError(range.reason);

    // Deterministic key — re-request with same params returns the existing artifact.
    const paramsHash = hashParams({ type, range, filters: body.filters, cols: body.columns });
    const jobKey = `report:${type}:${ctx.tenantId}:${paramsHash}`;

    const existing = await this.jobs.findByKey(jobKey);
    if (existing && existing.status !== 'failed') {
      return { jobId: existing.id, statusUrl: `/reports/jobs/${existing.id}` };
    }

    const job = await this.jobs.create({ key: jobKey, type, status: 'queued', tenantId: ctx.tenantId });
    await this.queue.add('generate-report', {
      jobId: job.id,
      type,
      range,
      filters: body.filters,
      tenantId: ctx.tenantId,          // captured scope — the worker re-asserts it
      permissions: ctx.permissions,
      orgTimezone: ctx.orgTimezone,
      requestedBy: ctx.userId,
    });
    return { jobId: job.id, statusUrl: `/reports/jobs/${job.id}` };
  }
}
```

The request returns in milliseconds with a `jobId`. It NEVER returns the data and NEVER builds the file.

## Worker: stream a keyset loop into the artifact

```ts
// src/modules/reporting/workers/generate-report.worker.ts

@Processor('generate-report')
export class GenerateReportWorker {
  constructor(
    @Inject(REPLICA_DB) private replica: ReadDb,      // SEPARATE pool, replica DSN, statement timeout
    @Inject(REPORT_JOBS) private jobs: ReportJobsRepo,
    @Inject(ARTIFACTS) private artifacts: ArtifactStore,
    @Inject(AUDIT_LOG) private audit: AuditLog,
    @Inject(NOTIFY) private notify: Notifier,
  ) {}

  @Process()
  async run(job: Job<GenerateReportData>): Promise<void> {
    const { jobId, type, range, filters, tenantId, permissions, orgTimezone, requestedBy } = job.data;
    const spec = SPECS[type];

    // As-of snapshot: capture a high-watermark so rows committed mid-export don't half-appear.
    const asOf = await this.replica.snapshotInstant();
    const columns = allowlistColumns(spec, permissions);   // drops PII the caller can't see

    // Resume from the last committed cursor if the job died mid-stream.
    const resumeFrom = await this.jobs.lastCursor(jobId);
    const writer = await this.artifacts.openWriter(jobId, spec.format);
    if (!resumeFrom) await writer.writeHeader(columns.map(c => c.header));

    let cursor = resumeFrom ?? null;
    let rowCount = resumeFrom?.rowCount ?? 0;

    // Keyset page loop — constant memory. NO OFFSET, NO findAll().
    for await (const page of this.keysetPages(spec, { range, filters, tenantId, asOf, cursor })) {
      for (const row of page) {
        await writer.writeRow(columns.map(c => c.render(row[c.key], { orgTimezone, locale: spec.locale })));
        rowCount++;
      }
      cursor = page.lastKey;
      await this.jobs.commitCursor(jobId, { ...cursor, rowCount });   // resumable checkpoint
    }

    const artifact = await writer.finalize();   // uploads to PRIVATE bucket, returns key + TTL

    // Audit BEFORE handing out the link.
    await this.audit.record({
      action: 'report.export',
      tenantId, actorId: requestedBy, reportType: type,
      columns: columns.map(c => String(c.key)), rowCount, asOf, artifactKey: artifact.key,
    });

    const url = await this.artifacts.signedUrl(artifact.key, { expiresIn: '1h' });   // short-lived
    await this.jobs.markReady(jobId, { artifactKey: artifact.key, rowCount, asOf });
    await this.notify.reportReady(requestedBy, { jobId, url, rowCount });
  }

  /** Keyset pagination against the REPLICA, tenant + permission predicate ALWAYS applied. */
  private async *keysetPages(spec: ReportSpec<any>, q: KeysetQuery) {
    let last = q.cursor;
    const PAGE = 5_000;
    while (true) {
      const rows = await this.replica.query(
        `SELECT ${q.columnList}
           FROM ${spec.table}
          WHERE tenant_id = $tenant            -- tenant scope, from captured auth context
            AND created_at >= $from AND created_at < $to
            ${last ? 'AND (created_at, id) > ($lastKey, $lastId)' : ''}
          ORDER BY created_at, id
          LIMIT $page`,
        { tenant: q.tenantId, from: q.range.from, to: q.range.to,
          lastKey: last?.key, lastId: last?.id, page: PAGE, asOf: q.asOf },
      );
      if (rows.length === 0) break;
      const lastRow = rows[rows.length - 1];
      yield Object.assign(rows, { lastKey: { key: lastRow.created_at, id: lastRow.id } });
      if (rows.length < PAGE) break;
      last = { key: lastRow.created_at, id: lastRow.id };
    }
  }
}
```

Memory stays flat regardless of result size. The tenant predicate is on every page. The job is resumable from `commitCursor`. A re-run with the same `jobKey` finds the existing artifact and never re-streams.

## Bounded date range, computed in the org timezone

```ts
// src/modules/reporting/core/date-range.ts

export function boundDateRange(
  fromInput: string | undefined,
  toInput: string | undefined,
  maxWindowDays: number,
  orgTimezone: string,
): { ok: true; from: Date; to: Date } | { ok: false; reason: string } {
  // Boundaries are interpreted in the ORG's timezone, then converted to UTC for the query.
  const to = toInput ? zonedDayEnd(toInput, orgTimezone) : zonedDayEnd('today', orgTimezone);
  const from = fromInput
    ? zonedDayStart(fromInput, orgTimezone)
    : zonedDayStart(subDays(to, 30), orgTimezone);          // default window, never unbounded

  if (from > to) return { ok: false, reason: 'from_after_to' };
  if (differenceInDays(to, from) > maxWindowDays) {
    return { ok: false, reason: `range_exceeds_max_${maxWindowDays}d` };
  }
  return { ok: true, from: toUtc(from, orgTimezone), to: toUtc(to, orgTimezone) };   // stored/queried UTC
}
```

"Today" for an org in GMT+8 is not "today" in UTC. Compute boundaries in the org timezone; query in UTC.

## Column allowlist + redaction (PII gating)

```ts
// src/modules/reporting/core/allowlist.ts

export function allowlistColumns<Row>(
  spec: ReportSpec<Row>,
  permissions: ReadonlyArray<Permission>,
): ReadonlyArray<ColumnDef<Row>> {
  const blocked = new Set(
    spec.redactions
      .filter(r => !permissions.includes(r.requires))   // caller lacks the permission for this column
      .map(r => r.column),
  );
  // Only columns declared in the spec ship — never SELECT *. PII the caller can't see is dropped.
  return spec.columns.filter(c => !blocked.has(c.key));
}
```

The export carries exactly the declared columns, minus any sensitive column the caller isn't permitted to see. No `SELECT *`, no incidental PII.

## Pre-aggregation + freshness labeling

```ts
// Scheduled rollup — dashboards read THIS, not live aggregation on the replica every page load.

@Cron('*/15 * * * *')   // refresh every 15 min
async refreshRevenueByDay(): Promise<void> {
  await this.replica.exec('REFRESH MATERIALIZED VIEW CONCURRENTLY mv_revenue_by_day');
  await this.cache.set('mv_revenue_by_day:refreshed_at', new Date().toISOString());
}

// Dashboard read: serve from the rollup with an explicit freshness label.
async revenueByDay(tenantId: string): Promise<{ rows: Row[]; dataAsOf: string }> {
  const rows = await this.replica.query(
    `SELECT day, revenue_minor, currency FROM mv_revenue_by_day WHERE tenant_id = $1 ORDER BY day`,
    [tenantId],     // tenant scope on the rollup too
  );
  const dataAsOf = await this.cache.get('mv_revenue_by_day:refreshed_at');
  return { rows, dataAsOf };    // UI shows "data as of <dataAsOf>" — never stale-as-if-live
}
```

Repeated expensive aggregates are pre-computed; responses carry "data as of …" so stale is visible, not silent.

## Money columns

Monetary values in reports use the integer-minor-unit `Money` type — see `<patterns-path>/payment-integration.md § Money`. SUM in the query over `amount_minor` (integer), and format at the edge:

```ts
render: (v, ctx) => Money.of(v as number, row.currency).format(ctx.locale)
```

Never `SUM` a float column and never format money without a currency tag — the report total must tie out to the ledger to the cent.

## Common mistakes

### Synchronous mega-export
`GET /reports/orders.csv` builds the file inline → request times out → user retries → workers stuck rebuilding the same file. Enqueue a job; return a `jobId`; stream in the worker.

### Load-all-then-map
`const rows = await repo.findAll(filter); return rows.map(toCsvRow)` → OOM at scale. Stream a keyset page loop straight into the writer at constant memory.

### OFFSET deep pagination
`LIMIT 100 OFFSET 900000` re-scans 900k rows per page; export goes quadratic. Keyset: `WHERE (created_at, id) > (:k, :id)`.

### Reporting on the primary
A heavy aggregation on the transactional DB takes locks and starves checkout. Route to a read replica / analytics store on a separate pool with a statement timeout.

### Missing tenant predicate
One forgotten `tenant_id` in a WHERE clause = cross-tenant export. The predicate is the security boundary; apply it from the auth context on every query.

### Client-supplied tenant
`WHERE tenant_id = :req.query.tenantId` is settable to anyone's id. Tenant comes from the verified auth context, never the request body/query.

### Unbounded range
"Export everything" with no end date → full-history scan that never completes. Reject; cap the window; default to a bounded range.

### PII leak via SELECT *
`SELECT *` drags `password_hash` / `ssn` / `cost_price` into the CSV. Declare a column allowlist; gate sensitive columns by permission; redact.

### Public download URL
Artifact in a public bucket → URL forwarded / indexed → anyone reads the report. Signed short-lived URL from a private bucket; clean up artifacts on a TTL.

### Naive timezone boundary
"Today's orders" computed in UTC for a GMT+8 org → the daily total is shifted 8 hours and never ties out. Compute boundaries in the org timezone; query UTC.

### Stale-as-if-live aggregate
Serving a cached aggregate with no freshness label → users trust a stale number as current. Label "data as of <ts>"; invalidate on event or TTL.

### Non-resumable job
A job that dies at row 3M and restarts from row 0 either never finishes or double-emits. Checkpoint the keyset cursor; resume from it; key the job idempotently.

## Cross-references

- `<rules-path>/reporting-export-discipline.md` — the hard-rule list (async, streaming, replica, tenant scope, bounded range, PII, signed delivery).
- `<rules-path>/audit-log-integrity.md` — export is an audited event; what to record per export.
- `<rules-path>/rate-limit-enforcement.md` — per-tenant/user generation rate limits.
- `<patterns-path>/queue-producer-consumer.md` — async job + worker semantics (idempotency, resumability, DLQ) for report jobs and scheduled reports.
- `<patterns-path>/payment-integration.md § Money` — integer-minor-unit money type for monetary columns.
- `<commands-path>/profile-report-query.md` — profile a specific report query (plan, row count, replica targeting, tenant predicate).
- `<agents-path>/reporting-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-reporting-read-store.md` — ADR pinning the read replica / analytics store + the snapshot/freshness contract.
