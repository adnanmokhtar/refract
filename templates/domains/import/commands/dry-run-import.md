---
description: Validate a bulk-import file / endpoint WITHOUT committing — detected schema vs. spec, per-row errors with row numbers, idempotency-key collisions, tenant scope of the upsert, streaming/size check, and formula-injection exposure — from real parse output, never an assumed one.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /dry-run-import

Diagnose whether a bulk import is safe to run: what schema the file actually has vs. what the spec expects, which rows fail validation (and at what row number), whether a re-run would collide / double-insert, whether the upsert is tenant-scoped, whether the path streams, and whether re-exported cells are formula-safe — WITHOUT writing a single row.

## Premise

Real signals only. Cite the import spec at `<path:line>`, the import writer (the upsert) at `<path:line>`, the detected header row + delimiter + encoding from the ACTUAL file, the per-row validation errors WITH their row numbers as produced by running the spec's validator, and the upsert's conflict target at `<path:line>` — never narrate a parse you didn't run. Read before diagnosing: locate the spec, the parser, and the writer in source and confirm the tenant comes from the auth context BEFORE asserting anything.

## Mechanical halt

Cite-or-halt: every run MUST print (1) the detected schema (headers / delimiter / encoding) vs. the spec at `<path:line>`, (2) the per-row validation errors with row numbers, (3) the idempotency/batch key + whether a prior batch for this file hash exists (collision), (4) whether the upsert carries `tenant_id` from the auth context in BOTH the row AND the conflict target at `<path:line>` (or "MISSING — cross-tenant WRITE"), (5) whether the path streams or loads the whole file, and (6) any cell that would inject a formula on re-export. If any of these cannot be produced from real source + a real (dry) parse, HALT and say which — never an assumed schema, never an assumed row-error set.

This command is READ-ONLY and NON-COMMITTING. It parses + validates in a dry pass and inspects the upsert SQL; it MUST NOT run the `INSERT`/upsert, MUST NOT write to the target tables, and MUST NOT mutate the import-jobs ledger. If validation cannot be done without a write, HALT.

## What it does

1. **Locate** the spec, parser, and writer — cite `<path:line>` for the `ImportSpec`, the streaming parser, and the upsert statement.
2. **Detect the schema** — from the ACTUAL file: header row, delimiter, encoding (BOM/charset), column count. Compare to the spec's expected headers. Flag missing / extra / reordered columns. Confirm mapping is BY HEADER NAME, not position.
3. **Dry-validate each row** — run the spec's per-row validator over the file WITHOUT upserting; collect `{ row, column, code }`. Report the count and the first N with row numbers. Note the partial-failure policy (reject-batch vs. partial-commit) and what it implies for this file.
4. **Check idempotency** — compute the batch key (`import:<tenant>:<type>:<fileHash>`); does a prior batch for this hash exist? A re-run either no-ops (good) or double-inserts (finding if the writer is a blind `INSERT`).
5. **Check tenant scope of the upsert** — confirm `tenant_id` is in the inserted row AND the `ON CONFLICT` target, bound from the auth context (not a file column / client field). Cite `<path:line>`; if absent, flag CROSS-TENANT WRITE.
6. **Check conflict strategy** — is there an `ON CONFLICT` / upsert at all (not a blind `INSERT`)? Are per-column merge rules declared (overwrite/skip/coalesce/error)? Is there a newer-row guard, or silent last-write-wins?
7. **Check streaming + caps** — does the path stream (`readStream().pipe(parser)`) or `readFile()` the whole upload? Are size/row/column caps enforced before parsing? Cite `<path:line>`.
8. **Check formula-injection exposure** — for any artifact this import re-exports (a rejected-rows CSV), are cells neutralized? Scan a sample for leading `=`/`+`/`-`/`@`/tab/CR.
9. **Report** — schema diff, row-error summary, idempotency verdict, tenant-scope verdict, conflict-strategy verdict, streaming verdict, injection verdict, and the top fix.

## Flow

```text
locate spec + parser + writer (<path:line>)
  -> detect schema from the file (headers/delimiter/encoding)   [finding if drift / mapped-by-position]
  -> dry-validate each row (NO upsert) -> per-row errors         [report with row numbers]
  -> compute batch key -> prior batch exists?                    [finding if blind INSERT -> double-insert]
  -> assert tenant_id in row AND conflict target (auth context)  [BLOCKER if missing -> cross-tenant write]
  -> assert upsert + per-column conflict strategy               [finding if blind INSERT / silent LWW]
  -> assert streaming + caps-before-parse                        [finding if readFile / no caps]
  -> assert re-exported cells formula-neutralized                [finding if raw echo]
  -> report: schema diff + row errors + verdicts + top fix
```

## Output

```
/dry-run-import — <import type> @ <file>  (DRY RUN — no rows written)

Spec:        src/modules/import/specs/product-catalog.ts:8
Writer:      src/modules/import/workers/run-import.worker.ts:74

Schema (detected vs. spec):
  delimiter: ,   encoding: utf-8 (BOM stripped)   columns: 7
  headers:   sku, name, price_minor, currency, stock, ...        [or: 'Price' expected 'price_minor' — DRIFT]
  mapping:   by header name                                      [or: BY POSITION — finding]

Row validation (dry, 12,043 rows):
  valid:     11,990
  rejected:  53     policy: partial-commit
    row 14   price_minor   not_an_integer   "12.50"
    row 88   currency      unknown_code     "US$"
    row 211  sku           required         ""
    ... (+50 more)

Idempotency:   batch key import:t_42:product-catalog:9f3a…  prior batch: NONE   [or: EXISTS — re-run no-ops]
Tenant scope:  tenant_id in row + ON CONFLICT (tenant_id, sku)  from ctx.tenantId @ worker.ts:96
                                                                [or: MISSING — cross-tenant WRITE — BLOCKER]
Conflict:      upsert, per-column merge, updated_at guard       [or: blind INSERT — finding / silent LWW — finding]
Streaming:     streamed via readStream().pipe @ worker.ts:71    [or: readFile(buffer) — finding]
Caps:          maxBytes/maxRows/maxColumns enforced pre-parse   [or: NONE — finding]
Injection:     rejected-rows CSV neutralized @ csv-safe.ts:9    [or: raw echo — finding]

Verdict: OK | NEEDS-VALIDATION-FIX | NEEDS-STREAMING | NEEDS-IDEMPOTENCY | BLOCKER(scope)

Top recommendation:
  - <e.g. add tenant_id to the ON CONFLICT target; or upsert instead of INSERT; or stream the parse>
```

## Rules

- READ-ONLY, NON-COMMITTING. Dry-parse + dry-validate + inspect SQL only. NEVER run the upsert, NEVER write to target tables, NEVER mutate the import-jobs ledger.
- Cite-or-halt: real spec, real detected schema, real per-row errors with row numbers, real conflict target, real streaming shape — or halt naming what's missing.
- Always print the tenant-scope verdict; a missing `tenant_id` in the row or the conflict target is a CROSS-TENANT WRITE, reported first.
- Never report a schema, a row-error set, or an idempotency verdict you didn't obtain from a real (dry) parse of the actual file + the actual source.
- If the writer is a blind `INSERT`, say so — a re-run double-inserts; that is a finding, not an aside.

## Cross-references

- `.claude/rules/import-ingest-discipline.md` — the hard-rule list this command enforces (streaming, tenant-scoped upsert, per-row validation, idempotency, caps, formula-neutralization).
- `ai/patterns/bulk-import.md` — the streaming parse + per-row validator + tenant-scoped batched upsert shape.
- `<agents-path>/import-reviewer.md` — review gate that consumes these findings.
