---
name: file-upload
kind: example
pack: backend
---

# Pattern: File upload / ingest

A client file is a security + resource surface. Failures: trusting Content-Type/filename, buffering the whole file, no size cap, serving user files from the app origin. Owns inbound ingest; streaming out is response-streaming.

## Rules

1. Cap size BEFORE reading (gateway + app; 413 over limit).
2. Validate the real type by MAGIC BYTES, not the header/extension (415 on mismatch).
3. Prefer presigned direct-to-storage PUT so bytes never transit the app.
4. When the app receives bytes, STREAM to storage (never buffer a large file).
5. Store under a generated uuid key (not the client filename); strip `../`; outside web root.
6. Scan untrusted / re-served uploads (ClamAV / service) before marking available.
7. Serve with validated Content-Type + `Content-Disposition: attachment` + `nosniff`; separate origin.
8. Resumable/large → multipart/tus with idempotent completion.

## Detectors (cite-or-halt)

1. No size cap → 413.
2. Type trusted from `mimetype`/extension with no magic-byte check.
3. Whole file buffered (`await request.body()`) → stream.
4. Client filename used as the storage path → uuid key.
5. User content served inline from app origin without `nosniff`/`Content-Disposition`.
6. Re-served user file with no scan step.

Closure verbs: `report-with-fix` / `report-flagged` (presigned / scanning service — ADR) / `dismiss` (trusted internal import).

## Related

`response-streaming.md` (out), `conditional-requests.md` (ETag), security pack (SSRF/malware), distributed-systems (async scan → 202).
