---
name: file-upload
kind: pattern
pack: backend
---

# Pattern: File upload / ingest

Accepting a file from a client is a security + resource surface, not a form field. The failures LLMs ship by default: trusting the client's `Content-Type` / filename, buffering the whole file in memory, no size cap, and serving user files back from the app origin. This pattern owns the *inbound* ingest contract; streaming *out* is `response-streaming.md`.

## Rules

1. **Cap the size before you read it.** Enforce a max at the proxy/gateway AND the app (`413 Payload Too Large` over the limit). Never read an unbounded body into memory.
2. **Validate the real type by magic bytes, not the header.** The client's `Content-Type` and filename extension are attacker-controlled — sniff the leading bytes (`file-type`, `python-magic`, `Tika`) and check against an allow-list of expected types. Reject a mismatch (`415`).
3. **Prefer direct-to-storage via presigned URLs.** For anything non-trivial, hand the client a short-lived presigned PUT (S3/GCS/Azure) so the bytes never transit the app; the client then confirms and the app validates the stored object. Removes the app as a bandwidth/memory bottleneck.
4. **When the app does receive bytes, stream them** to object storage / disk in chunks (`stream.pipeline`, `UploadFile`, `StreamedResponse`) — never `await request.body()` into a buffer for a large file.
5. **Sanitise the stored path + name.** Store under a generated key (uuid), never the client filename; strip path traversal (`../`); store outside the web root / not on the app origin. Serve back through a CDN or a signed URL, never by echoing the upload path.
6. **Scan untrusted uploads.** Route user-supplied files through a malware scan (ClamAV / a scanning service) before they're marked available, especially anything re-served to other users.
7. **Set safe response headers when serving** user content: `Content-Type` from the *validated* type (not the stored guess), `Content-Disposition: attachment` for downloads, `X-Content-Type-Options: nosniff`. Serve from a separate origin/domain to contain stored-XSS.
8. **Resumable / large uploads** use multipart/chunked upload (S3 multipart, tus) with a per-upload id + a completion step; make the completion idempotent.

## Detectors (cite-or-halt)

Each finding cites `<file:line>` + the matched pattern + the fix.

### 1. No size cap

Flag an upload handler with no max-size enforcement (no gateway limit + no app check) → memory/disk DoS. Fix: cap + `413`.

### 2. Type trusted from the header/extension

```
BAD:   if (req.file.mimetype === 'image/png') save(req.file)     // client-controlled
GOOD:  const kind = await fileTypeFromBuffer(head); if (!ALLOW.has(kind.mime)) reject(415)
```
Flag an allow/deny decision based on `mimetype`/filename extension with no magic-byte check.

### 3. Whole file buffered in memory

Flag `await request.body()` / reading the full upload into a variable before writing → stream it instead.

### 4. Client filename used as the storage path

```
BAD:   fs.writeFile(`/uploads/${req.file.originalname}`, buf)     // path traversal + collision
GOOD:  const key = `${uuid()}${extFromValidatedType}`; storage.put(key, stream)
```
Flag the client filename (or an un-sanitised path) used as the on-disk/object key.

### 5. User content served from the app origin without `nosniff`/attachment

Flag user files served back inline from the app origin without `X-Content-Type-Options: nosniff` + `Content-Disposition` (stored-XSS / MIME-sniffing risk).

### 6. No scan on re-served user files

Flag an upload that is re-served to other users with no malware scan step in the pipeline.

## Closure verbs

- `report-with-fix` — matched at `<file:line>` + the concrete size-cap / magic-byte / stream / uuid-key / header patch.
- `report-flagged` — the fix is a design call (move to presigned direct-to-storage; add a scanning service) → surface for ADR.
- `dismiss` — carve-out applies (a trusted internal-only admin import; a bounded config file) → documented.

## Related

- `response-streaming.md` — the outbound counterpart (streaming a file *out*).
- `conditional-requests.md` — ETag on served files for revalidation.
- `security` pack — SSRF (a presigned/fetch-by-URL upload path), content-security, malware policy.
- `distributed-systems` pack — the async scan/process hand-off (upload → 202 → job).
