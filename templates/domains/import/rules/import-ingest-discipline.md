---
name: import-ingest-discipline
description: Bulk import & data-ingest discipline
kind: rule
---

# Bulk import & data-ingest discipline

## Hard rule

Any bulk import (CSV / XLSX / JSON upload that can carry many rows or take longer than ~1s) MUST run as an asynchronous, idempotent, resumable job that STREAMS rows at constant memory and returns a `job_id` — NEVER on the request thread, NEVER by loading the whole file into memory. EVERY row written MUST carry the caller's tenant scope from the auth context, baked into both the upsert and its conflict target; a missing tenant scope is a cross-tenant DATA WRITE — rows overwriting or polluting another tenant's data, which is more damaging than a read leak. Rows MUST be validated PER ROW into a structured error report (one bad row never aborts the good rows, and bad rows are never silently dropped); the partial-commit vs. reject-batch policy MUST be explicit. Upserts MUST key on a stable business/natural key with a declared conflict strategy (merge / skip / error per column) — blind insert is FORBIDDEN. File size, row count, and column count MUST be capped before parsing; encoding/content-type/column order MUST be detected and validated, never trusted from the client; and any cell re-exported to a spreadsheet MUST be neutralized against formula injection.

An import bug is a silently corrupted dataset, another tenant's records overwritten, or a 2M-row file that OOMs the box — all far harder to detect and undo than a failed request.

## Must

- **Async for anything bulk**: any import that can exceed ~1s or carry more than a screenful of rows is enqueued as a job that returns a `job_id` + status URL immediately. The HTTP request NEVER parses the file inline and NEVER holds the worker for the duration of the ingest.
- **Stream, never load-all**: rows are parsed and processed from a streaming reader (`createReadStream().pipe(parser)` / `for await` over a row stream) at constant memory. `readFile()` then `parse(wholeBuffer)` on a large file is FORBIDDEN — a 2M-row CSV OOMs the box.
- **Idempotent re-import**: every batch carries an import-batch idempotency key (`import:<tenant>:<fileHash>` or a client-supplied key); re-uploading the same file returns the existing batch result and NEVER double-inserts. Replay safety is at the batch level AND at the row level (upsert, not insert).
- **Tenant scope on every upsert**: `tenant_id` is taken from the verified auth context and baked into every upserted row AND the conflict target (`ON CONFLICT (tenant_id, <business_key>)`). A row's natural key is unique WITHIN a tenant, never globally — omitting `tenant_id` from the conflict target lets tenant A's import overwrite tenant B's row.
- **Per-row validation + structured error report**: each row is validated against the import spec's schema (types, required fields, ranges, references) and a per-row error report is collected (`{ row, column, code, message }`) — never all-or-nothing. The report is returned with the job result; bad rows are surfaced, not silently skipped.
- **Explicit partial-failure policy**: the spec declares `reject-batch` (any invalid row fails the whole import, nothing committed — atomic) OR `partial-commit` (valid rows upsert, invalid rows go to the error report) — chosen deliberately per import type, never left implicit.
- **Business-key upsert with a conflict strategy**: the upsert targets a declared natural/business key (e.g. `(tenant_id, external_sku)`), and each column declares a merge rule on conflict — overwrite, skip-if-present, coalesce, or error. Blind `INSERT` that collides on a unique constraint, or last-write-wins that silently clobbers newer data, is FORBIDDEN.
- **Caps before parsing**: max file size, max row count, max column count, and max field length are enforced BEFORE the parser runs (from the upload metadata + a streaming row counter that aborts past the cap) — an unbounded file is a DoS.
- **Detect, don't trust, the envelope**: encoding (BOM / charset sniff), content-type, and delimiter are detected and validated against the spec; columns are mapped BY HEADER NAME, never by position. A client-declared `text/csv` that is actually a 4GB file, or a reordered column set, must not corrupt the mapping.
- **Formula-injection neutralization on re-export**: any cell whose value is echoed back into a downloadable artifact (an error-row CSV, a "rejected rows" export) is neutralized — a leading `=`, `+`, `-`, `@`, tab, or CR is prefixed so it cannot execute as a formula when opened in Excel/Sheets.
- **Resumable checkpointed job**: the worker checkpoints progress (last committed row offset / cursor + running counts) so a job that dies mid-stream resumes from the last commit — never restarts from row 0 and never double-applies committed rows.
- **Imports are audited write events**: who imported, which file (hash + name), row counts (parsed / committed / rejected), and the batch key are written to the audit log (see `<rules-path>/audit-log-integrity.md`) — an import mutates data and MUST be attributable.

## Must not

- Parse a large import synchronously on the request thread (it times out, holds a worker, and OOMs the box).
- `readFile()` the whole upload then `parse()` the buffer — load-whole-file is the canonical OOM.
- Omit `tenant_id` from the upserted row OR from the conflict target — cross-tenant write / overwrite.
- Derive the tenant from a column in the file or a client-supplied field instead of the auth context.
- Abort the entire import on the first invalid row, OR silently drop invalid rows with no report.
- Blind-`INSERT` rows (collides on unique constraints / duplicates on re-import) — upsert on a business key instead.
- Last-write-wins overwrite with no per-column merge rule (silently clobbers newer/edited data).
- Parse before enforcing file-size / row-count / column-count caps — unbounded input is a DoS.
- Trust the client-declared encoding / content-type / column order; map columns by position.
- Echo a raw cell into a re-exported artifact without formula-injection neutralization.

## Should

- Wrap ingest behind a project-internal `<ImportRunner>` / `<ImportJob>` interface so streaming, tenant-scoping, per-row validation, the upsert conflict strategy, and audit are enforced in ONE place — feature code declares an `ImportSpec`, not a hand-rolled parse loop.
- Express each import as a declarative `ImportSpec` (column map by header, per-column type + validation, business key, conflict/merge rules, partial-failure policy, caps) so the streaming + scoping + validation + upsert are derived, not re-written per endpoint.
- Run an AV / content scan on the uploaded file before parsing (see `<rules-path>/file-upload-safety.md`) — the file arrives via upload and is untrusted bytes.
- Batch upserts (e.g. 500–5,000 rows per statement) inside a transaction per batch so throughput is high and a failed batch rolls back to a clean checkpoint, not a half-applied row.
- Return a downloadable, formula-neutralized "rejected rows" artifact (original row + per-row error) so the user can fix and re-upload — re-upload is idempotent via the batch key.
- Log structured `{ importType, tenantId, fileHash, rowsParsed, rowsCommitted, rowsRejected, durationMs, batchKey }` per run; alert on imports that breach a row/size cap, exceed a duration budget, or produce an abnormal reject ratio.

## Review checklist (PRs touching imports / bulk ingest / file-upload-to-DB / data loaders)

- [ ] Bulk import runs as an async job returning a `job_id`, not inline parsing; batch key is deterministic + resumable.
- [ ] Rows are streamed from a reader at constant memory — no `readFile()` + `parse(buffer)`, no whole-file array.
- [ ] EVERY upsert carries `tenant_id` from the auth context, in BOTH the row AND the conflict target; cite `<path:line>`.
- [ ] Each row is validated per-row into a structured error report; one bad row does not abort the good rows.
- [ ] Partial-failure policy is explicit (reject-batch vs. partial-commit) and matches the import type.
- [ ] Upsert keys on a declared business key with a per-column conflict/merge strategy — no blind `INSERT`, no silent last-write-wins.
- [ ] File-size / row-count / column-count caps are enforced BEFORE parsing.
- [ ] Encoding / content-type / delimiter detected + validated; columns mapped by header name, not position.
- [ ] Any cell re-exported to a CSV/XLSX artifact is formula-injection-neutralized.
- [ ] Import is audit-logged (actor / file hash / row counts / batch key).

## Anti-patterns

- **Load-whole-file** — `const buf = await readFile(path); const rows = parse(buf)` on a 2M-row CSV → OOM. Stream rows: `createReadStream(path).pipe(csvParser())` and process `for await`.
- **Sync import on the request thread** — `POST /import` parses + upserts inline → 30s+ request → gateway timeout → user retries → three workers re-ingesting the same file. Enqueue a job; return a `jobId`.
- **Non-idempotent re-import** — re-uploading the same file `INSERT`s every row again → duplicates. Upsert on a business key; gate the batch on `import:<tenant>:<fileHash>`.
- **Missing tenant scope on the upsert** — `ON CONFLICT (external_sku)` with no `tenant_id` → tenant A's import overwrites tenant B's product row. The most damaging import bug — a cross-tenant WRITE. Scope the row AND the conflict target.
- **Tenant from the file** — a `tenant_id` column read from the CSV → trivially set to anyone's id. Tenant comes from the verified auth context, never the file.
- **All-or-nothing** — one malformed row throws and aborts 1M good rows; OR invalid rows are caught and dropped with no report → silent data loss. Validate per row; collect an error report; declare the policy.
- **Blind insert** — `INSERT INTO products (...)` with no conflict clause → collides on the unique constraint on re-run, or duplicates. Upsert with a declared conflict strategy per column.
- **Formula injection** — an error-export CSV writes a cell `=cmd|'/c calc'!A1` verbatim → executes when opened in Excel. Neutralize: prefix `=`/`+`/`-`/`@`/tab/CR-leading cells.
- **Unbounded file** — no size/row/column cap → a 4GB upload is parsed into the box → DoS. Cap before parsing; abort the stream past the row cap.
- **Trust the envelope** — `content-type: text/csv` taken at face value, columns mapped by index → a reordered or mislabeled file silently writes the wrong columns. Sniff encoding, validate the delimiter, map by header name.

## Enforcement

- `<commands-path>/dry-run-import.md` (slash: `/dry-run-import`) — validates an import file/endpoint WITHOUT committing: detected schema vs. spec, per-row errors with row numbers, idempotency-key collisions, tenant-scope of the upsert (or MISSING = cross-tenant write), the streaming/size check, and formula-injection exposure — cite-or-halt, never an assumed parse.
- `<agents-path>/import-reviewer.md` — review gate hard-failing on load-whole-file, sync import, non-idempotent re-import, missing tenant scope on the upsert, all-or-nothing validation, blind insert, formula injection, unbounded input, and trusted-envelope mapping.
- CI lint MUST reject `readFile(` / `fs.readFileSync(` feeding a CSV/XLSX parser in import code paths (heuristic; flag for review) — imports stream.
- CI lint MUST reject an upsert / `ON CONFLICT` in an import path whose conflict target does not include `tenant_id` (AST heuristic; flag for review).
- CI lint MUST reject a bare `INSERT` (no `ON CONFLICT` / upsert) in an import writer — imports are idempotent.
- TODO: `scripts/validate-import-scoping.sh` to AST-walk import writers and assert every one (1) streams, (2) scopes the upsert + conflict target on `tenant_id` from the auth context, and (3) routes invalid rows to an error report rather than aborting.

## Cross-references

- `<patterns-path>/bulk-import.md` — streaming parse + per-row validation + idempotent batched upsert + formula-neutralization + resumable job code shapes.
- `<patterns-path>/report-generation.md` — the export twin: same async-job / streaming / idempotency / tenant-scope spine, in the outbound direction.
- `<rules-path>/audit-log-integrity.md` — an import is an audited write event; what to record per import.
- `<rules-path>/file-upload-safety.md` — the import file arrives via upload (AV scan, content-type, size) before it is parsed.
- `<rules-path>/rate-limit-enforcement.md` — per-tenant/user import rate limits so one tenant cannot exhaust the workers.
- `<commands-path>/dry-run-import.md` — pre-commit validation tool.
- `<agents-path>/import-reviewer.md` — review gate.
- `<adr-path>/<NNN>-import-conflict-strategy.md` — ADR pinning the business-key choice, per-column merge rules, and the partial-failure policy per import type.
