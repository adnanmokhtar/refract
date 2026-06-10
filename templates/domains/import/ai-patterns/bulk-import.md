---
name: bulk-import
description: "Pattern: Bulk import (streamed parse, per-row validate, idempotent batched upsert)"
kind: ai-pattern
---

# Pattern: Bulk import (streamed parse, per-row validate, idempotent batched upsert)

> **Hard rule** — A bulk import runs as an idempotent async job, never on the request thread; the file is STREAMED at constant memory, never loaded whole; EVERY row is validated PER ROW into a structured error report, never all-or-nothing; rows are UPSERTED on a stable business key with the caller's `tenant_id` from the auth context baked into both the row AND the conflict target; the import-batch is idempotent on the file hash so a re-upload never double-inserts; any cell re-exported into an artifact is formula-injection-neutralized; and the job is resumable from a committed checkpoint.

**When to apply**
- Any CSV / XLSX / JSON-lines upload that loads many rows into your tables (product catalogs, contacts, transactions, inventory, bulk edits).
- Multi-tenant products where every imported row is owned by exactly one tenant and an import must never write across that line.
- Recurring / scheduled ingests (a nightly partner feed, an SFTP drop) — same idempotency + scoping + audit contract as an on-demand upload.

**When NOT to apply**
- A single-record create from a form — the streaming + batching + resumable-job machinery is overhead.
- A handful of rows pasted into a textarea, bounded and tiny — validate + upsert inline; you still scope by tenant and upsert, but the async job is unnecessary.
- An ETL into a warehouse where the warehouse's own loader + scoping is the system of record — use its native bulk-load, don't reimplement.

**Halt conditions / mandatory cites**
- Cite the async job enqueue + the streaming worker at `<path:line>`. A large import parsed inline in the request handler = halt.
- Cite the streaming parser at `<path:line>`. A `readFile()` / `parse(wholeBuffer)` over the upload = halt.
- Cite the per-row validation + the error-report collector at `<path:line>`. An all-or-nothing parse (one row throws → whole import aborts) or a silent `catch { continue }` = halt.
- Cite the upsert's conflict target including `tenant_id`, sourced from the auth context, at `<path:line>`. Missing `tenant_id` in the row or the conflict target = halt (cross-tenant write).
- Cite the batch idempotency key (file hash) at `<path:line>`. A blind `INSERT` with no upsert / no batch key = halt (double-insert on re-upload).
- Cite the size/row/column cap, the formula-injection neutralizer on any re-exported cell, and the resumable checkpoint at `<path:line>` each.
- Grep ban: "the import is safe / scoped / idempotent" without file:line for the tenant-scoped conflict target, the streaming parser, the per-row error report, and the batch key.

## Why

Imports are the inbound twin of reports — simultaneously heavy (millions of rows), security-critical (they WRITE across every row a tenant owns), and trust-critical (the data they load is taken as truth). The failure modes recur, and a write is harder to undo than a read:

1. **It OOMs the box** — `readFile()` then `parse()` a 2M-row file materializes the whole thing in memory. Stream rows at constant memory; cap size/rows before parsing.
2. **It writes across tenants** — one missing `tenant_id` in the upsert's conflict target lets tenant A's import overwrite tenant B's row. A cross-tenant WRITE is worse than a read leak — it corrupts the victim's data silently. The `tenant_id` is on the row AND the conflict target, from the auth context.
3. **It double-inserts or aborts wholesale** — a non-idempotent re-upload duplicates every row; an all-or-nothing parse lets one bad row abort a million good ones, or silently drops bad rows. Upsert on a business key, gate the batch on the file hash, validate per row into an error report with an explicit partial-failure policy.

The pattern: declare an `ImportSpec`, run it as an idempotent async job, stream the file, validate each row into an error report, and batch-upsert valid rows on a tenant-scoped business key — resumable from a checkpoint.

## Import spec (declarative)

```ts
// src/modules/import/core/import-spec.ts

export interface ImportSpec<Row> {
  type: string;                          // 'product-catalog', 'contacts'
  /** Map source headers -> canonical fields BY NAME, never by column position. */
  columns: ReadonlyArray<ColumnDef<Row>>;
  /** Stable business/natural key — unique WITHIN a tenant. The upsert conflict target. */
  businessKey: ReadonlyArray<keyof Row>;
  /** Per-column merge rule applied on conflict. */
  conflict: ReadonlyArray<{ column: keyof Row; onConflict: 'overwrite' | 'skip' | 'coalesce' | 'error' }>;
  /** Reject the whole batch on any invalid row (atomic), or commit valid rows + report the rest. */
  failurePolicy: 'reject-batch' | 'partial-commit';
  /** Caps enforced BEFORE parsing — unbounded input is a DoS. */
  caps: { maxBytes: number; maxRows: number; maxColumns: number; maxFieldLen: number };
  format: 'csv' | 'xlsx' | 'jsonl';
}

export type ColumnDef<Row> = {
  /** Source header text to match (case/space-normalized). Mapping is by name, not index. */
  header: string;
  key: keyof Row;
  required: boolean;
  /** Per-cell validate + coerce. Returns the typed value or a row-error code. */
  parse: (raw: string) => { ok: true; value: Row[keyof Row] } | { ok: false; code: string; message: string };
};
```

The spec — not a hand-rolled parse loop in a controller — is what feature code authors. Streaming, scoping, validation, and the upsert are derived from it.

## Request handler: enqueue, never parse

> The TypeScript below uses NestJS-style decorators for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md` — the framework decorators (Express / FastAPI / Spring / etc.), the DI mechanism, the upload handling your project exposes. The SHAPE — hash the file for the batch key → cap-check → enqueue → return a job id — is universal, not the helper names.

```ts
// src/modules/import/import.controller.ts

@Controller('/imports')
export class ImportController {
  constructor(
    @Inject(QUEUE) private queue: Queue,
    @Inject(IMPORT_JOBS) private jobs: ImportJobsRepo,
    @Inject(BLOB) private blob: BlobStore,
    @Inject(RATE_LIMITER) private limiter: RateLimiter,
  ) {}

  @Post('/:type')
  async requestImport(
    @Param('type') type: string,
    @UploadedFile() file: UploadedFile,
    @Ctx() ctx: AuthContext,             // tenant + permissions come from HERE, never the file
  ): Promise<{ jobId: string; statusUrl: string }> {
    await this.limiter.consume(`import:${ctx.tenantId}:${ctx.userId}`);   // per-tenant/user cap

    const spec = SPECS[type];
    if (file.size > spec.caps.maxBytes) throw new FileTooLargeError(file.size, spec.caps.maxBytes);

    // Stash the upload to a private blob; the worker streams it (request never reads the bytes).
    const fileHash = await hashStream(file.stream);                       // content hash for idempotency
    const blobKey = await this.blob.put(`imports/${ctx.tenantId}/${fileHash}`, file.stream);

    // Deterministic batch key — re-uploading the same file returns the existing batch, never re-inserts.
    const batchKey = `import:${ctx.tenantId}:${type}:${fileHash}`;
    const existing = await this.jobs.findByKey(batchKey);
    if (existing && existing.status !== 'failed') {
      return { jobId: existing.id, statusUrl: `/imports/jobs/${existing.id}` };
    }

    const job = await this.jobs.create({ key: batchKey, type, status: 'queued', tenantId: ctx.tenantId });
    await this.queue.add('run-import', {
      jobId: job.id,
      type,
      blobKey,
      fileHash,
      tenantId: ctx.tenantId,            // captured scope — the worker re-asserts it on every row
      requestedBy: ctx.userId,
    });
    return { jobId: job.id, statusUrl: `/imports/jobs/${job.id}` };
  }
}
```

The request returns in milliseconds with a `jobId`. It NEVER parses the file and NEVER upserts a row.

## Worker: stream, validate per row, batch-upsert

```ts
// src/modules/import/workers/run-import.worker.ts

const BATCH = 1_000;

@Processor('run-import')
export class RunImportWorker {
  constructor(
    @Inject(DB) private db: Db,
    @Inject(IMPORT_JOBS) private jobs: ImportJobsRepo,
    @Inject(BLOB) private blob: BlobStore,
    @Inject(AUDIT_LOG) private audit: AuditLog,
  ) {}

  @Process()
  async run(job: Job<RunImportData>): Promise<void> {
    const { jobId, type, blobKey, fileHash, tenantId, requestedBy } = job.data;
    const spec = SPECS[type];

    // Resume from the last committed offset if the job died mid-stream — never re-apply committed rows.
    const checkpoint = await this.jobs.lastCheckpoint(jobId);
    let offset = checkpoint?.offset ?? 0;
    let committed = checkpoint?.committed ?? 0;
    let rejected = checkpoint?.rejected ?? 0;

    const errors: RowError[] = [];
    let batch: ValidRow[] = [];

    // Streaming parse — constant memory. NO readFile(), NO parse(wholeBuffer).
    const rows = this.blob.readStream(blobKey).pipe(rowParser(spec.format, spec.caps));   // caps abort the stream

    for await (const { lineNo, headerMap, raw } of withHeaderMap(rows, spec)) {   // map BY HEADER NAME
      if (lineNo <= offset) continue;                       // already committed before a crash — skip

      const parsed = validateRow(spec, headerMap, raw);     // per-row validate + coerce
      if (!parsed.ok) {
        errors.push({ row: lineNo, errors: parsed.errors });
        rejected++;
        if (spec.failurePolicy === 'reject-batch') {
          await this.jobs.markFailed(jobId, { reason: 'invalid-row', firstError: errors[0] });
          return;                                            // atomic: nothing committed
        }
        continue;                                            // partial-commit: skip this row, keep going
      }

      batch.push(parsed.value);
      if (batch.length >= BATCH) {
        committed += await this.upsertBatch(spec, tenantId, batch);   // tenant-scoped upsert (below)
        offset = lineNo;
        await this.jobs.commitCheckpoint(jobId, { offset, committed, rejected });   // resumable
        batch = [];
      }
    }
    if (batch.length) {
      committed += await this.upsertBatch(spec, tenantId, batch);
      await this.jobs.commitCheckpoint(jobId, { offset, committed, rejected });
    }

    // Re-exportable "rejected rows" artifact — every cell formula-neutralized (see below).
    const errorArtifact = errors.length
      ? await this.blob.put(`imports/${tenantId}/${fileHash}.errors.csv`, toErrorCsv(errors))
      : null;

    await this.audit.record({
      action: 'data.import',
      tenantId, actorId: requestedBy, importType: type, fileHash,
      rowsCommitted: committed, rowsRejected: rejected,
    });
    await this.jobs.markDone(jobId, { committed, rejected, errorArtifact });
  }
```

Memory stays flat regardless of file size. Each row is validated independently into `errors`. The job is resumable from `commitCheckpoint`. A re-run with the same `batchKey` finds the existing job and never re-streams.

## Idempotent, tenant-scoped batched upsert

```ts
// The conflict target carries tenant_id — a business key is unique WITHIN a tenant, never globally.

  private async upsertBatch(
    spec: ImportSpec<any>,
    tenantId: string,                    // from the captured auth context, NEVER from the file
    rows: ValidRow[],
  ): Promise<number> {
    const cols = spec.columns.map(c => String(c.key));
    const conflictTarget = ['tenant_id', ...spec.businessKey.map(String)];   // tenant_id IN the conflict key
    const updates = spec.conflict
      .filter(c => c.onConflict === 'overwrite' || c.onConflict === 'coalesce')
      .map(c => c.onConflict === 'coalesce'
        ? `${String(c.column)} = COALESCE(EXCLUDED.${String(c.column)}, t.${String(c.column)})`
        : `${String(c.column)} = EXCLUDED.${String(c.column)}`);

    // Single batched statement inside a transaction — high throughput, clean rollback on failure.
    return this.db.tx(async t => {
      const res = await t.query(
        `INSERT INTO ${spec.table} (tenant_id, ${cols.join(', ')})
         SELECT $1, * FROM jsonb_to_recordset($2::jsonb) AS x(${colTypes(spec)})
         ON CONFLICT (${conflictTarget.join(', ')})        -- tenant_id + business key
         DO UPDATE SET ${updates.join(', ')}
         WHERE t.updated_at <= EXCLUDED.updated_at`,        // don't clobber a NEWER row (no blind last-write-wins)
        [tenantId, JSON.stringify(rows)],
      );
      return res.rowCount;
    });
  }
}
```

`tenant_id` is in the inserted row AND the `ON CONFLICT` target — tenant A's import can never match (and so never overwrite) tenant B's row. `skip`/`error` columns are excluded from the `DO UPDATE` set; the `WHERE updated_at <=` guard prevents silently clobbering a row edited after the file was produced.

## Per-row validation into a structured error report

```ts
// src/modules/import/core/validate-row.ts

export function validateRow<Row>(
  spec: ImportSpec<Row>,
  headerMap: Map<string, number>,        // header name -> source column index (mapping is by NAME)
  raw: string[],
): { ok: true; value: Row } | { ok: false; errors: RowFieldError[] } {
  const out = {} as Row;
  const errors: RowFieldError[] = [];

  for (const col of spec.columns) {
    const idx = headerMap.get(normalizeHeader(col.header));
    const cell = idx === undefined ? '' : (raw[idx] ?? '');
    if (col.required && cell.trim() === '') {
      errors.push({ column: col.header, code: 'required', message: `${col.header} is required` });
      continue;
    }
    if (cell.trim() === '') continue;                     // optional + empty
    const r = col.parse(cell);                            // type/range/reference check + coerce
    if (!r.ok) errors.push({ column: col.header, code: r.code, message: r.message });
    else (out as any)[col.key] = r.value;
  }
  // One bad row never throws — it returns its errors. The caller reports them, not aborts the batch.
  return errors.length ? { ok: false, errors } : { ok: true, value: out };
}
```

A bad row collects its field errors and returns them — it never throws and never silently vanishes. The worker decides reject-batch vs. partial-commit per the spec.

## CSV formula-injection neutralization (on any re-exported cell)

```ts
// src/modules/import/core/csv-safe.ts

const FORMULA_LEAD = /^[=+\-@\t\r]/;   // a cell starting with these executes as a formula in Excel/Sheets

/** Neutralize a cell BEFORE writing it into a downloadable CSV/XLSX (e.g. the rejected-rows artifact). */
export function csvSafeCell(value: string): string {
  const cell = String(value ?? '');
  // Prefix a leading ' so the spreadsheet treats it as text, not a formula. Then standard CSV-quote.
  const neutralized = FORMULA_LEAD.test(cell) ? `'${cell}` : cell;
  return `"${neutralized.replace(/"/g, '""')}"`;
}
```

A rejected-row CSV that echoes a cell `=cmd|'/c calc'!A1` verbatim becomes a live formula when the user opens it. Neutralize EVERY re-exported cell — the import's own error artifact is the most common injection vector because it round-trips attacker-controlled input.

## Common mistakes

### Load-whole-file
`const buf = await readFile(path); const rows = parse(buf)` on a 2M-row CSV → OOM. Stream: `readStream(blobKey).pipe(rowParser())` and process `for await`. Caps abort the stream past `maxRows`/`maxBytes`.

### Synchronous import on the request thread
`POST /import` parses + upserts inline → 30s+ request → gateway timeout → user retries → workers re-ingesting the same file. Enqueue a job; return a `jobId`; stream in the worker.

### Non-idempotent re-import
`INSERT`-ing every row → a re-upload duplicates everything. Upsert on the business key; gate the batch on `import:<tenant>:<fileHash>` so a replay returns the existing result.

### Missing tenant scope on the upsert
`ON CONFLICT (external_sku)` with no `tenant_id` → tenant A's import overwrites tenant B's product. A cross-tenant WRITE — worse than a read leak, it corrupts the victim's data. Scope the row AND the conflict target from the auth context.

### Tenant from the file
A `tenant_id` column read from the CSV is settable to anyone's id. Tenant comes from the verified auth context, never from a cell in the file.

### All-or-nothing validation
One malformed row throws → 1M good rows aborted; OR `catch { continue }` drops bad rows silently. Validate per row into an error report; declare reject-batch vs. partial-commit explicitly.

### Blind insert / silent last-write-wins
`INSERT` with no conflict clause collides on the unique constraint; a naive `DO UPDATE SET ... = EXCLUDED.*` clobbers a row edited after the file was produced. Declare a per-column merge rule; guard on `updated_at`.

### Unbounded file
No size/row/column cap → a 4GB upload is parsed into the box → DoS. Enforce caps BEFORE parsing; abort the stream when a cap is hit.

### Trust the envelope
`content-type: text/csv` taken at face value and columns mapped by index → a reordered/mislabeled file writes the wrong columns. Sniff encoding (BOM/charset), validate the delimiter, map by header NAME.

### Formula injection in the error export
The rejected-rows CSV echoes `=HYPERLINK(...)` verbatim → executes on open. Neutralize every re-exported cell with `csvSafeCell`.

### Non-resumable job
A job that dies at row 1.5M and restarts from row 0 either never finishes or re-applies committed rows. Checkpoint the offset + counts; resume from it; the upsert makes re-applied rows harmless anyway.

## Cross-references

- `<rules-path>/import-ingest-discipline.md` — the hard-rule list (async, streaming, tenant-scoped upsert, per-row validation, idempotency, caps, formula-neutralization).
- `<patterns-path>/report-generation.md` — the export twin: same async-job / streaming / idempotency / tenant-scope spine, outbound. Read it alongside this one — they are mirror images.
- `<rules-path>/audit-log-integrity.md` — an import is an audited write event; what to record (actor / file hash / row counts / batch key).
- `<rules-path>/file-upload-safety.md` — the import file arrives via upload (AV scan, content-type, size) before it is parsed.
- `<rules-path>/rate-limit-enforcement.md` — per-tenant/user import rate limits.
- `<commands-path>/dry-run-import.md` — validate an import file without committing (schema, per-row errors, idempotency collisions, tenant scope).
- `<agents-path>/import-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-import-conflict-strategy.md` — ADR pinning the business-key choice, per-column merge rules, and the partial-failure policy per import type.
