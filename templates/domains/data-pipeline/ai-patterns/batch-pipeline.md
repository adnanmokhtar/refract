---
name: batch-pipeline
description: "Pattern: Batch pipeline (idempotent, checkpointed, schema-validated, backfill-safe)"
kind: ai-pattern
---

# Pattern: Batch pipeline (idempotent, checkpointed, schema-validated, backfill-safe)

> **Hard rule** — A pipeline reads INCREMENTALLY from a watermark / CDC offset (never a full re-scan by default), validates every record against an explicit SCHEMA CONTRACT and QUARANTINES violators (never drops, never propagates), STREAMS at constant memory (never load-all), loads through an IDEMPOTENT sink (upsert/merge/partition-replace — a re-run never duplicates), CHECKPOINTS progress so a failure resumes from the last committed point (never restarts from zero), handles LATE / out-of-order data via a declared lateness window, isolates BACKFILLS to a versioned/partitioned target (never overwrites live data in place), and asserts DATA-QUALITY invariants before promotion.

**When to apply**
- Any scheduled / triggered batch or micro-batch that moves rows source → sink: ETL into a warehouse, fact/dimension hydration, a CDC consumer applying change events, a periodic sync between systems.
- Backfills and re-loads of historical windows where a re-run must converge, not accumulate.
- Multi-tenant data movement where every row is owned by one tenant and aggregates must never blend tenants.

**When NOT to apply**
- A single small lookup / one-shot fixup of a handful of rows — the watermark + checkpoint + DLQ machinery is overhead; just write the idempotent statement and move on.
- A user-initiated file import (CSV upload) — use `<patterns-path>/bulk-import` (shares the streaming + idempotent-upsert + tenant-scope + quarantine spine, but adds upload/progress/UX concerns this pattern omits).
- A long-lived, human-in-the-loop business process with timers and signals — that's `workflow-orchestration` (Temporal-style durable workflow), not a data load.
- Model training / feature-store materialization where the MODEL contract dominates — that's `mlops`; reuse this load discipline but defer the model concerns there.

**Halt conditions / mandatory cites**
- Cite the watermark/offset read + advance at `<path:line>`. A `SELECT *` with no incremental predicate on a re-runnable path = halt (full re-scan).
- Cite the idempotent sink (upsert / merge / partition-replace) at `<path:line>`. A blind `INSERT`/append = halt (re-run duplicates).
- Cite the durable checkpoint commit + the resume read at `<path:line>`. No checkpoint = halt (restart-from-zero on failure).
- Cite the schema-contract validation at the boundary at `<path:line>`, and the DLQ/quarantine write at `<path:line>`. No contract, or a dropped/`continue`'d bad row with no DLQ = halt.
- Cite the streaming read loop at `<path:line>`. A `fetchAll()` collector before transform = halt (OOM).
- Cite the backfill target + atomic swap at `<path:line>`. An in-place `UPDATE`/`TRUNCATE`+reload of live data = halt.
- Cite the late-data window + the post-load assertions at `<path:line>` each.
- Grep ban: "the pipeline is idempotent / safe / incremental" without file:line for the sink key, the watermark advance, the checkpoint commit, the contract, and the DLQ.

## Why

A pipeline is the one workload whose bugs are invisible until the warehouse is already wrong — and by then the corruption is several runs deep and feeding every dashboard. The failure modes recur:

1. **It duplicates / corrupts on retry** — a blind insert re-runs and doubles the window; a job has no idempotency key so at-least-once delivery becomes at-least-twice data. The sink must converge: upsert on a business key, or replace the partition.
2. **It can't recover cheaply** — a failure at 80% restarts from zero because progress was never checkpointed, so a transient blip turns a 5-minute retry into a 6-hour re-run and the pipeline falls permanently behind. Checkpoint after each batch; resume from it.
3. **It absorbs upstream drift silently** — no schema contract, so a renamed/retyped field writes nulls for days; a malformed row gets `continue`'d into a void or, worse, propagated into an aggregate that's now wrong N joins deep. Validate at the boundary; quarantine violators with their reason.
4. **A backfill clobbers live data** — an in-place `UPDATE` with a wrong window overwrites a month of production rows with no path back. Backfill into a versioned/partitioned shadow target; validate; swap.

The pattern: declare a pipeline SPEC, read incrementally from a watermark, validate-or-quarantine each record, stream bounded batches through an idempotent sink, checkpoint after each batch, handle lateness explicitly, isolate backfills, and assert invariants before promotion.

## Pipeline spec (declarative)

```ts
// src/pipelines/core/pipeline-spec.ts

export interface PipelineSpec<Src, Row> {
  name: string;                          // 'orders-fact', 'cdc-customers'
  /** Incremental cursor: the column / log position the watermark advances on. */
  watermark: { column: keyof Src; kind: 'updated_at' | 'sequence' | 'cdc_lsn' };
  /** Pinned input contract. A record failing this is quarantined, never transformed. */
  contract: SchemaContract<Src>;
  contractVersion: string;
  /** Stable business key for the idempotent sink — upsert/merge/partition-replace key. */
  businessKey: ReadonlyArray<keyof Row>;
  /** How the sink converges. 'upsert' = MERGE on businessKey; 'partition' = delete+write a partition. */
  sinkStrategy: 'upsert' | 'partition-replace';
  partitionKey?: keyof Row;              // required for partition-replace
  /** Event-time lateness the pipeline will reprocess for; out-of-order beyond this is flagged. */
  latenessWindow: { eventTime: keyof Row; allowed: Duration };
  /** Invariants asserted AFTER load, BEFORE promotion. A failure halts promotion. */
  assertions: ReadonlyArray<DataQualityAssertion<Row>>;
}
```

Feature code authors a spec — not hand-rolled SQL per job. The watermark advance, contract validation, DLQ routing, idempotent sink, and post-load assertions are derived from it.

## Runner: incremental watermark loop, streamed, checkpointed

> The TypeScript below uses a NestJS-style processor + helpers for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the framework/DI, the cursor/stream API your driver exposes, the durable store for the checkpoint. The SHAPE — read from the committed watermark → stream bounded batches → validate-or-quarantine → idempotent sink → commit checkpoint AFTER the sink — is what's universal, not the helper names.

```ts
// src/pipelines/runners/batch-runner.ts

@Processor('run-pipeline')
export class BatchRunner {
  constructor(
    @Inject(SOURCE_DB) private source: ReadDb,        // server-side cursor / streaming reads
    @Inject(SINK_DB) private sink: WriteDb,
    @Inject(CHECKPOINTS) private checkpoints: CheckpointStore,   // durable, one record per pipeline
    @Inject(DLQ) private dlq: DeadLetterSink,
    @Inject(AUDIT_LOG) private audit: AuditLog,
  ) {}

  @Process()
  async run(job: Job<RunData>): Promise<void> {
    const spec = SPECS[job.data.name];
    const runId = job.data.runId;

    // Resume: read the LAST COMMITTED watermark. A crash mid-run resumes here, never row 0.
    const cp = await this.checkpoints.get(spec.name);     // { watermark, rowsWritten } | null
    let watermark = cp?.watermark ?? EPOCH;
    let read = 0, written = 0, quarantined = 0;

    // Incremental + streamed: pull ONLY rows past the watermark, in key order, as a cursor.
    // NO `SELECT *` full scan, NO fetchAll() — bounded batches at constant memory.
    const BATCH = 5_000;
    for await (const batch of this.streamSince(spec, watermark, BATCH, job.data.tenantId)) {
      const good: Row[] = [];

      for (const raw of batch) {
        read++;
        // Schema contract at the boundary — BEFORE transform. Violators are quarantined, not dropped.
        const checked = spec.contract.validate(raw, spec.contractVersion);
        if (!checked.ok) {
          await this.dlq.write({
            pipeline: spec.name, runId, reason: checked.error,   // e.g. 'missing:amount_cents' / 'type:created_at'
            rawPayload: raw,                                     // full raw row — recoverable, triageable
          });
          quarantined++;
          continue;                                             // good rows keep flowing; bad row is OUT, with a record
        }
        good.push(transform(checked.value, spec));
      }

      // Idempotent sink: a re-run of this same window converges — never duplicates.
      await this.loadIdempotent(spec, good, job.data.tenantId);
      written += good.length;

      // Advance the watermark from the data ACTUALLY read, then checkpoint AFTER the sink commit.
      // Order matters: sink commits, then checkpoint commits. A crash between them re-processes
      // the last batch (at-least-once) — safe because the sink is idempotent. Never at-most-once.
      watermark = maxWatermark(watermark, good, batch, spec);
      await this.checkpoints.commit(spec.name, { watermark, rowsWritten: written });
    }

    // Late / out-of-order data: reprocess the windows touched by records that arrived late.
    await this.reprocessLateWindows(spec, runId, job.data.tenantId);

    // Data-quality assertions GATE promotion — a silently-wrong dataset must not ship.
    const failures = await this.assertQuality(spec, job.data.tenantId);
    if (failures.length) {
      await this.audit.record({ action: 'pipeline.run', pipeline: spec.name, runId, status: 'assert_failed',
        read, written, quarantined, failures });
      throw new DataQualityError(spec.name, failures);          // halt promotion; alert; do NOT promote
    }

    await this.audit.record({ action: 'pipeline.run', pipeline: spec.name, runId, status: 'ok',
      windowFrom: cp?.watermark ?? EPOCH, windowTo: watermark, read, written, quarantined });
  }

  /** Incremental, streamed read. Cursor over rows past the watermark, in key order. */
  private async *streamSince(spec: PipelineSpec<any, any>, since: Watermark, batchSize: number, tenantId: string) {
    let cursor = since;
    while (true) {
      const rows = await this.source.query(
        `SELECT ${spec.contract.columns.join(', ')}
           FROM ${spec.sourceTable}
          WHERE tenant_id = $1                                  -- tenant scope travels end-to-end
            AND ${String(spec.watermark.column)} > $2           -- INCREMENTAL: only new/changed rows
          ORDER BY ${String(spec.watermark.column)}, id         -- ordered for a stable watermark
          LIMIT $3`,
        [tenantId, cursor, batchSize],
      );
      if (rows.length === 0) break;
      yield rows;
      cursor = rows[rows.length - 1][spec.watermark.column];     // advance from data read
      if (rows.length < batchSize) break;
    }
  }
}
```

Memory stays flat regardless of source size. Only rows past the watermark are read. Bad rows go to the DLQ with their reason; good rows keep flowing. The checkpoint commits after the sink, so a crash resumes — never restarts from zero, never skips.

## Idempotent sink: upsert or partition-replace (never blind insert)

```ts
// src/pipelines/runners/idempotent-sink.ts

private async loadIdempotent(spec: PipelineSpec<any, Row>, rows: Row[], tenantId: string): Promise<void> {
  if (rows.length === 0) return;

  if (spec.sinkStrategy === 'upsert') {
    // MERGE on the business key — a re-run of the same window UPDATEs in place, never inserts a dup.
    await this.sink.batchUpsert(spec.sinkTable, rows, {
      conflictKey: ['tenant_id', ...spec.businessKey.map(String)],     // stable key, tenant-scoped
      update: spec.contract.updatableColumns,
    });
    // SQL shape:
    //   INSERT INTO fact_orders (tenant_id, order_id, amount_cents, status, updated_at) VALUES ...
    //   ON CONFLICT (tenant_id, order_id) DO UPDATE SET
    //     amount_cents = EXCLUDED.amount_cents, status = EXCLUDED.status, updated_at = EXCLUDED.updated_at
    //   WHERE fact_orders.updated_at < EXCLUDED.updated_at;          -- last-write-wins by source time
    return;
  }

  // partition-replace: delete the partition, write the partition — atomically idempotent per window.
  const partition = rows[0][spec.partitionKey!];
  await this.sink.transaction(async (tx) => {
    await tx.exec(
      `DELETE FROM ${spec.sinkTable} WHERE tenant_id = $1 AND ${String(spec.partitionKey)} = $2`,
      [tenantId, partition],
    );
    await tx.batchInsert(spec.sinkTable, rows);     // re-running this window replaces it; never accumulates
  });
}
```

A blind `INSERT INTO fact SELECT * FROM staging` doubles the window on retry. Upsert on the business key, or replace the partition transactionally — either way a re-run converges to the same rows.

## Late / out-of-order data: reprocess the owning window

```ts
// src/pipelines/runners/late-data.ts

/** A record's event-time decides its window; arrival time does not. Late records re-aggregate
 *  their OWNING window — they are neither dropped nor appended as if fresh. */
private async reprocessLateWindows(spec: PipelineSpec<any, Row>, runId: string, tenantId: string): Promise<void> {
  // Find records whose event-time falls into an already-closed window but within the lateness allowance.
  const lateWindows = await this.sink.query(
    `SELECT DISTINCT ${windowExpr(spec.latenessWindow.eventTime)} AS w
       FROM ${spec.stagingTable}
      WHERE tenant_id = $1
        AND ${String(spec.latenessWindow.eventTime)} < $2          -- before the current window
        AND ${String(spec.latenessWindow.eventTime)} >= $3`,       -- but within the lateness allowance
    [tenantId, currentWindowStart(), minus(now(), spec.latenessWindow.allowed)],
  );

  for (const { w } of lateWindows) {
    // Re-aggregate the WHOLE owning window idempotently (partition-replace) so the late record is
    // counted exactly once — not dropped (undercount), not appended as fresh (double-count).
    await this.recomputeWindow(spec, w, tenantId);
  }
}
```

`if (event.ts < windowStart) return` silently undercounts; appending a late record into the current window double-counts. Reprocess by event-time into its owning window, idempotently — exactly once.

## Backfill isolation: shadow target + atomic swap (never in-place)

```ts
// src/pipelines/backfill/backfill-runner.ts

/** A backfill writes to a VERSIONED shadow target and is promoted only after it validates against
 *  the live data it will replace. It NEVER UPDATEs/TRUNCATEs live rows in place. */
async backfill(spec: PipelineSpec<any, Row>, window: DateRange, tenantId: string): Promise<void> {
  const shadow = `${spec.sinkTable}__backfill_${window.from.toISOString().slice(0, 10)}`;   // versioned

  // 1. Stream the backfill into the SHADOW table (live reads keep seeing current data).
  await this.runIncrementalInto(spec, shadow, window, tenantId);

  // 2. Validate the shadow against live BEFORE swapping — counts + aggregate parity within tolerance.
  const live = await this.aggregate(spec.sinkTable, window, tenantId);
  const back = await this.aggregate(shadow, window, tenantId);
  const drift = parityDrift(live, back);                 // row-count delta, sum delta, null-rate delta
  if (drift.exceeds(BACKFILL_TOLERANCE)) {
    throw new BackfillParityError(spec.name, window, drift);   // do NOT promote a divergent backfill
  }

  // 3. Atomic partition swap — replace ONLY the backfilled window, keep the prior version for rollback.
  await this.sink.transaction(async (tx) => {
    await tx.exec(`ALTER TABLE ${spec.sinkTable} DETACH PARTITION ${partitionFor(window)}`);   // -> kept for rollback
    await tx.exec(`ALTER TABLE ${spec.sinkTable} ATTACH PARTITION ${shadow} FOR VALUES ${rangeFor(window)}`);
  });
}
```

`UPDATE fact SET ... WHERE date BETWEEN ...` run with a wrong window overwrites live production data with no path back. Backfill into a versioned shadow, validate parity, swap the partition atomically, keep the prior version for rollback.

## Schema contract + quarantine (PII masked in lower envs)

```ts
// src/pipelines/core/contract.ts

/** The contract is PINNED to a version. Upstream drift is DETECTED, not silently absorbed. */
export function validate<Src>(raw: unknown, contract: SchemaContract<Src>, version: string):
  { ok: true; value: Src } | { ok: false; error: string } {
  if (contract.version !== version) return { ok: false, error: `contract_drift:${contract.version}!=${version}` };
  for (const field of contract.required) {
    if (raw[field] == null) return { ok: false, error: `missing:${String(field)}` };       // renamed/removed upstream
  }
  for (const [field, type] of contract.types) {
    if (!matchesType(raw[field], type)) return { ok: false, error: `type:${String(field)}` }; // retyped upstream
  }
  return { ok: true, value: raw as Src };
}

// PII masking for any extract copied to a lower env / sample dataset (see <rules-path>/compliance).
export function maskForLowerEnv<Row>(row: Row, spec: PipelineSpec<any, Row>): Row {
  if (process.env.ENV === 'production') return row;
  return spec.piiColumns.reduce((r, col) => ({ ...r, [col]: tokenize(r[col]) }), { ...row });
  // emails/SSNs/names tokenized or synthesized — production PII never lands unmasked in dev/staging.
}
```

A renamed/retyped/removed upstream field is caught at the boundary and quarantined with a precise reason; it never writes nulls for days or poisons a downstream aggregate. And no extract leaves production with PII intact.

## Data-quality assertions (gate promotion)

```ts
// src/pipelines/core/assertions.ts — run AFTER load, BEFORE promotion. A failure halts; it does not ship.

export const ORDERS_FACT_ASSERTIONS: DataQualityAssertion<OrderRow>[] = [
  rowCountWithin({ expectedDeltaPct: 20 }),                 // a 0-row or 10x load is a join-fanout / empty-source bug
  noNullsIn(['order_id', 'tenant_id', 'amount_cents']),    // required columns never null after load
  uniqueBusinessKey(['tenant_id', 'order_id']),            // the idempotent key is actually unique
  freshness({ column: 'updated_at', within: hours(2) }),   // max(updated_at) within SLA — not stale
  referentialIntegrity({ fk: 'customer_id', to: 'dim_customers' }),   // no orphan facts
];
```

The load "succeeding" is not the same as the data being right. Assert invariants; a failure halts promotion and alerts — never ships a silently-wrong table downstream.

## Common mistakes

### Blind-insert load
`INSERT INTO fact SELECT * FROM staging` on a retry-able job → a retry double-loads the window → revenue doubles. Upsert on the business key, or delete+replace the partition.

### Full-table re-scan
Every run rebuilds the whole table because there's no `updated_at`/CDC cursor → run time grows with history until it can't finish in its window. Pull `WHERE updated_at > :watermark`.

### Restart-from-zero
A crash at 4M of 5M rows restarts at row 0 because nothing was checkpointed → the job never catches up. Commit the watermark after each batch; resume from it.

### Silent schema drift
Upstream renames `amount` → `amount_cents`; the transform reads `row.amount` → `undefined` → nulls for days. Validate against a pinned contract; fail on drift.

### Swallowed bad row
`try { transform(row) } catch { continue }` → malformed rows vanish with no trace; totals undercount. Route to a DLQ with raw payload + reason + runId.

### Poison-row propagation
A bad row passes validation-less into an aggregate → every metric on that partition is wrong, N joins deep. Quarantine at the boundary, before transform.

### In-place backfill
`UPDATE fact SET ... WHERE date BETWEEN ...` with a wrong window → a month of live rows overwritten, no rollback. Backfill into a versioned shadow; validate; swap.

### Load-all extract
`const all = await source.fetchAll(); all.map(transform)` → OOM at scale. Stream a cursor loop in bounded batches.

### Dropped late event
`if (event.ts < windowStart) return` → a record 40 min late is lost and the hour undercounts. Declare a lateness window; reprocess the owning window.

### Double-counted late event
A late record appended as fresh AND counted in its own window → over-count. Reprocess by event-time key, don't append by arrival.

### No post-load assertion
The load writes 0 rows (or 10x via join fan-out) and ships with no check → the dashboard is silently wrong. Assert invariants; halt promotion on failure.

### PII in staging
A prod dump restored to staging carries real emails/SSNs → a lower-env breach is a production-PII breach. Mask on extract.

## Cross-references

- `<rules-path>/data-pipeline-discipline.md` — the hard-rule list (idempotent sink, checkpoint, incremental watermark, schema contract, DLQ, streaming, backfill isolation, late data, assertions, PII).
- `<patterns-path>/bulk-import` — shared spine (streaming + idempotent upsert + tenant scope + bad-row quarantine) for user-initiated file imports.
- `<rules-path>/background-jobs` — orchestration, retries, backoff, and run-level DLQ for pipeline runs.
- `<rules-path>/compliance` — PII masking/tokenization for lower-env and sample extracts.
- `<rules-path>/audit-log` — per-run provenance so a wrong number traces to the run that produced it.
- `<rules-path>/reporting-export-discipline.md` — the downstream read side (replica routing, tenant scope, streaming) consuming the tables this pipeline loads.
- `<commands-path>/audit-pipeline.md` — audit a specific pipeline (idempotency, checkpoint, incremental, contract, DLQ, backfill, memory, PII).
- `<agents-path>/data-pipeline-reviewer.md` — review gate enforcing this pattern.
- Boundary: `mlops` owns the MODEL lifecycle (training data, feature store, deploy/rollback); `workflow-orchestration` (Temporal) owns durable long-lived business processes. This pack owns DATA movement — ETL/batch/backfill/CDC/warehouse loads.
- `<adr-path>/<NNN>-pipeline-load-strategy.md` — ADR pinning load strategy (upsert vs. partition-replace), watermark source, lateness window, and backfill/rollback contract.
