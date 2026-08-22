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
3. **Pick the upload shape; "prefer presigned" is not a decision.** Presigned is usually right at scale and it is not free — it moves validation *after* the write and creates an object state nothing owns unless you build the owner.

   | | App-proxied | Presigned + confirm | Resumable multipart / tus |
   |---|---|---|---|
   | Right when | small files; must reject before storing | the default above a few MB | large files, unreliable networks |
   | Size cap | before the read, gateway + app | **at presign time** via the signed policy (`content-length-range`) — a cap checked on confirm has already paid for the storage | per part + declared total |
   | Validation | before storage; a rejected file was never written | **after storage** — validate on confirm by reading the object's first bytes; treat pre-confirm objects as untrusted | after assembly |
   | Scan | inline or async before available | necessarily async → needs a state (`quarantined` → `available`), not a boolean | async, post-assembly |
   | Client can lie about | nothing that matters | `Content-Type` (bind it in the policy) and **the key — generate it server-side; never let the client name the object** | declared total size; per-part checksums guard it |
   | Orphans | none | **the failure nobody plans for** — upload, never confirm, paid storage nothing points at | same, plus incomplete multipart parts, which are billed and absent from a normal listing |

   Orphan reclamation is a required deliverable of the last two shapes, not an operational nicety: a **storage lifecycle rule** (expire the pending prefix; abort incomplete multipart uploads) as the backstop that runs while your app is down, **and** a pending-upload row written at presign time so an orphan is findable and alertable. Without the row you cannot tell "the user abandoned it" from "confirm has been broken since Tuesday."
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
7. Presigned/multipart flow with **neither** a storage lifecycle rule on the pending prefix **nor** a pending-upload record → unbounded paid storage nothing references → `report-flagged`.
8. Presign handler whose object key derives from client input → the rule-5 hole one layer earlier, with over-write of an existing key also in reach.

Closure verbs: `report-with-fix` / `report-flagged` (presigned / scanning service — ADR) / `dismiss` (trusted internal import).

## Related

`response-streaming.md` (out), `conditional-requests.md` (ETag), security pack (SSRF/malware), distributed-systems (async scan → 202).
