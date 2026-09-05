---
description: Audit a specific data pipeline (ETL / batch / backfill / CDC / warehouse load) end-to-end — sink idempotency, checkpoint/resume, incremental-vs-full, schema contract + bad-row quarantine, watermark + late data, backfill isolation, streaming-vs-load-all, PII in lower envs — from the REAL pipeline code, never an assumed shape.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /audit-pipeline

Diagnose whether a specific pipeline is safe to re-run, cheap to recover, and correct under drift: does a re-run duplicate? does a failure force a full re-run? does it read incrementally? does upstream drift get caught? does a backfill clobber live data? — all from the ACTUAL pipeline source, not a guess.

## Premise

Real signals only. Cite the pipeline entry point at `<path:line>`, the sink statement at `<path:line>` (and say whether it is an upsert/merge/partition-replace or a blind insert), the checkpoint commit + resume read at `<path:line>`, the watermark/incremental predicate at `<path:line>`, the schema-contract validation + the DLQ write at `<path:line>` each, the backfill target + swap at `<path:line>`, and the source read loop at `<path:line>` (cursor/stream vs. `fetchAll()`) — never narrate a shape you didn't read. Read before auditing: locate the pipeline in source and confirm the source table, the sink table, the watermark column, and the run trigger BEFORE judging anything.

## Mechanical halt

Cite-or-halt: every run MUST print (1) the pipeline at `<path:line>`, (2) the SINK statement at `<path:line>` + its idempotency verdict (UPSERT/MERGE/PARTITION-REPLACE = idempotent · BLIND INSERT/APPEND = NOT idempotent · cannot tell = HALT), (3) the CHECKPOINT/resume at `<path:line>` (or "MISSING — restart-from-zero"), (4) the INCREMENTAL predicate at `<path:line>` (or "FULL RE-SCAN"), (5) the SCHEMA CONTRACT + DLQ at `<path:line>` (or "MISSING — drift absorbed / bad rows dropped"), (6) the WATERMARK + LATE-DATA stance, (7) the BACKFILL target (isolated/versioned vs. in-place), (8) the READ loop (streamed vs. load-all), and (9) PII handling in lower envs. If any cannot be produced from real source, HALT and say which — never an assumed idempotency, never an assumed checkpoint.

This is a READ-ONLY audit. Do NOT run the pipeline, do NOT trigger a backfill, do NOT execute the sink statement. If you must observe behavior, reason from the code and the existing run records — never by loading or mutating live data.

## What it does

1. **Locate** the pipeline — entry point, runner, source table, sink table, watermark column, run trigger (cron / event / CDC). Cite `<path:line>`.
2. **Judge the sink** — read the actual load statement. Upsert/merge on a stable key? Partition-replace in a transaction? Or a blind `INSERT`/`append`/`COPY`? Print the statement at `<path:line>` and the verdict. A blind insert on a re-runnable path = BLOCKER (re-run duplicates).
3. **Check checkpoint/resume** — is progress (watermark/offset) committed durably AFTER the sink, and read back on restart? Cite `<path:line>`. None = BLOCKER (any failure forces a full re-run).
4. **Check incremental vs. full** — does the default path read only rows past the watermark/CDC offset, or re-scan the whole source every run? Cite the predicate at `<path:line>`. Full re-scan on a growing table = BLOCKER (cost + lock blowup).
5. **Check the schema contract + quarantine** — is each record validated against a pinned contract at the boundary, and are violators written to a DLQ with payload + reason? Or are bad rows `continue`'d / filtered / propagated? Cite both at `<path:line>`. No contract, or dropped/propagated bad rows = BLOCKER.
6. **Check the watermark + late-data stance** — is there a declared lateness window and an event-time vs. processing-time stance? Are late records reprocessed into their owning window, dropped, or appended as fresh? Cite `<path:line>`.
7. **Check backfill isolation** — does a backfill write to a versioned/partitioned/shadow target and swap atomically, or `UPDATE`/`TRUNCATE`+reload live data in place? Cite the target + swap at `<path:line>`. In-place = BLOCKER.
8. **Check memory** — is the source read via a cursor/stream in bounded batches, or `fetchAll()` then `.map()`? Cite the read loop at `<path:line>`. Load-all = finding (OOM at scale).
9. **Check PII in lower envs** — is any extract copied to dev/staging/a sample masked? Cite the masking (or its absence). Unmasked = finding (cross-ref compliance).
10. **Check post-load assertions** — are data-quality invariants asserted before promotion (row-count delta, null checks, key uniqueness, freshness, referential integrity)? None = finding.
11. **Report** — sink verdict, checkpoint verdict, incremental verdict, contract/DLQ verdict, backfill verdict, memory verdict, plus the top fix.

## Flow

```text
locate pipeline (<path:line>)  [source table, sink table, watermark column, trigger]
  -> read the SINK statement                         [BLOCKER if blind INSERT/append]
  -> find checkpoint commit + resume read             [BLOCKER if missing — restart-from-zero]
  -> find incremental predicate (watermark/CDC)        [BLOCKER if full re-scan]
  -> find schema contract + DLQ write                  [BLOCKER if missing / bad rows dropped or propagated]
  -> find lateness window + late-data handling         [finding if dropped / double-counted]
  -> find backfill target + swap                       [BLOCKER if in-place overwrite of live]
  -> find source read loop                             [finding if fetchAll() / load-all]
  -> find PII masking in lower envs                    [finding if unmasked]
  -> find post-load data-quality assertions            [finding if none]
  -> report: verdicts + top fix
```

## Output

```
/audit-pipeline — <pipeline name> @ <path:line>

Pipeline (<path:line>):
  source: orders (updated_at watermark)   sink: fact_orders   trigger: cron */15m

Sink (<path:line>):
  INSERT INTO fact_orders ... ON CONFLICT (tenant_id, order_id) DO UPDATE ...
  Idempotency:    UPSERT on (tenant_id, order_id)         [or: BLIND INSERT — BLOCKER (re-run duplicates)]
Checkpoint:       watermark committed after sink @ runner.ts:61   [or: MISSING — restart-from-zero — BLOCKER]
Incremental:      WHERE updated_at > $watermark @ runner.ts:88    [or: FULL RE-SCAN — BLOCKER]
Schema contract:  validate(raw, v3) @ contract.ts:14              [or: MISSING — drift absorbed — BLOCKER]
Bad-row routing:  DLQ write @ runner.ts:40 (payload+reason+runId) [or: continue/dropped/propagated — BLOCKER]
Late data:        lateness 1h, reprocess owning window @ late-data.ts:9   [or: dropped — finding / double-counted — finding]
Backfill:         shadow table + atomic partition swap @ backfill.ts:22   [or: in-place UPDATE — BLOCKER]
Memory:           cursor stream, batch=5000 @ runner.ts:80        [or: fetchAll().map() — finding (OOM)]
PII (lower env):  tokenized @ contract.ts:31                      [or: UNMASKED — finding]
Assertions:       rowCount/null/unique/freshness @ assertions.ts  [or: NONE — finding]

Verdict: OK | NOT-IDEMPOTENT | NO-CHECKPOINT | FULL-RESCAN | NO-CONTRACT | BACKFILL-UNSAFE | BLOCKER

Top fix:
  - <e.g. change blind INSERT -> ON CONFLICT upsert on (tenant_id, order_id); add watermark checkpoint; quarantine to DLQ>
```

## Rules

- READ-ONLY audit. Never run the pipeline, never trigger a backfill, never execute the sink, never load or mutate live data.
- Cite-or-halt: real entry point, real sink statement, real checkpoint, real incremental predicate, real contract + DLQ, real backfill target — or halt naming what's missing.
- Always print the sink idempotency verdict first; a blind insert on a re-runnable path is the most damaging pipeline bug (re-run duplicates/corrupts).
- Never report an idempotency, a checkpoint, or an incremental read you didn't read in source.
- If the backfill overwrites live data in place, say so — that is a BLOCKER, not an aside.
- A dropped/`continue`'d bad row with no DLQ is a finding even if "it never happens" — upstream drift is when, not if.

## Cross-references

- `.claude/rules/data-pipeline-discipline.md` — the hard-rule list this command enforces (idempotent sink, checkpoint, incremental, contract, DLQ, backfill isolation, streaming, late data, assertions, PII).
- `ai/patterns/batch-pipeline.md` — the watermark loop + idempotent sink + checkpoint/resume + contract + DLQ + backfill swap code shapes.
- `<patterns-path>/bulk-import` — shared streaming + idempotent-upsert + quarantine spine for user-initiated imports.
- `<rules-path>/background-jobs` — orchestration / retries / run-level DLQ the pipeline runs under.
- `<rules-path>/compliance` — PII masking for lower-env extracts.
- `<rules-path>/audit-log` — per-run provenance.
- `<agents-path>/data-pipeline-reviewer.md` — review gate that consumes these findings.
