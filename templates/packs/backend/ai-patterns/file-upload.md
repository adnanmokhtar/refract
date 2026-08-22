---
name: file-upload
kind: pattern
pack: backend
---

# Pattern: File upload / ingest

Accepting a file from a client is a security + resource surface, not a form field. The failures LLMs ship by default: trusting the client's `Content-Type` / filename, buffering the whole file in memory, no size cap, and serving user files back from the app origin. This pattern owns the *inbound* ingest contract; streaming *out* is `response-streaming.md`.

## Rules

1. **Cap the size before you read it.** Enforce a max at the proxy/gateway AND the app (`413 Content Too Large` over the limit — RFC 9110 §15.5.14 renamed it from "Payload Too Large"). Never read an unbounded body into memory.
2. **Validate the real type by magic bytes, not the header.** The client's `Content-Type` and filename extension are attacker-controlled — sniff the leading bytes (`file-type`, `python-magic`, `Tika`) and check against an allow-list of expected types. Reject a mismatch (`415`).
3. **Pick the upload shape from the table below, not from "prefer presigned".** Presigned direct-to-storage is the usual answer at scale and it is *not free*: it moves validation after the write, which changes what "the file is here" means and introduces an object state — stored, unvalidated, unreferenced — that nothing in the app owns unless you build the owner.
4. **When the app does receive bytes, stream them** to object storage / disk in chunks (`stream.pipeline`, `UploadFile`, `StreamedResponse`) — never `await request.body()` into a buffer for a large file.
5. **Sanitise the stored path + name.** Store under a generated key (uuid), never the client filename; strip path traversal (`../`); store outside the web root / not on the app origin. Serve back through a CDN or a signed URL, never by echoing the upload path.
6. **Scan untrusted uploads.** Route user-supplied files through a malware scan (ClamAV / a scanning service) before they're marked available, especially anything re-served to other users.
7. **Set safe response headers when serving** user content: `Content-Type` from the *validated* type (not the stored guess), `Content-Disposition: attachment` for downloads, `X-Content-Type-Options: nosniff`. Serve from a separate origin/domain to contain stored-XSS.
8. **Resumable / large uploads** use multipart/chunked upload (S3 multipart, tus) with a per-upload id + a completion step; make the completion idempotent.

## The three upload shapes — and what each one moves

The choice is not a performance preference. Each shape puts validation, scanning and cleanup in a different place, and picking one implicitly picks all three.

| | **App-proxied** (bytes through your process) | **Presigned + confirm** (client → storage direct) | **Resumable multipart / tus** |
|---|---|---|---|
| **When it is right** | Small files (avatars, CSVs), an app that must reject before anything is stored, or a compliance rule that the app sees every byte. | The default above roughly a few MB, or any file the app has no reason to read. | Large files over unreliable networks — mobile, video, anything where a 90%-complete upload failing is a real cost. |
| **Size cap enforced** | Before the read, at the gateway + the app. Cheap and total. | **At presign time**, via the policy conditions in the signed URL (`content-length-range`) — *not* by checking after the fact. A cap you enforce only on confirm has already paid for the storage. | Per part, plus a declared total at initiation. |
| **Validation timing** | Before storage. A rejected file was never written. | **After storage.** The object exists before you know it is a PNG. Validate on the confirm call by reading the object's first bytes, and treat the pre-confirm object as untrusted. | After completion, on the assembled object. Parts are individually meaningless. |
| **Scan timing** | Inline (small files) or async before marking available. | Necessarily async — the object exists, so it needs a state (`quarantined` → `available`) rather than a boolean. | Async, post-assembly. |
| **What the client can lie about** | Nothing that matters — you have the bytes. | `Content-Type` on the PUT (bind it in the policy), the key (**generate it server-side at presign; never let the client name the object**), and whether it ever calls confirm at all. | The declared total size; per-part checksums are the guard. |
| **Orphan objects** | None — nothing is stored until it is accepted. | **The failure mode nobody plans for.** A client that uploads and never confirms leaves a paid-for object no row points at. It is invisible in the app and grows forever. | Same, plus *incomplete multipart uploads*, which are billed and do not appear in a normal bucket listing. |

**Orphan cleanup is a required deliverable of the presigned and multipart shapes, not an operational nicety.** Two mechanisms, and you want both:

- **A storage-side lifecycle rule** — expire objects under the pending prefix after N days, and abort incomplete multipart uploads after N days. This is the backstop that runs even when your app is down; every major object store has it, and on multipart it is the only thing that reclaims parts a listing will not show you.
- **An app-side reconciliation** — a pending-upload row written *at presign time* with the key and an expiry, so an orphan is a row you can find and a metric you can alert on. Without the row you cannot distinguish "the user abandoned it" from "confirm is broken for everyone since Tuesday."

Choose the prefix and the expiry deliberately: they are the only two numbers in this section, and both are product decisions (how long may a user resume an interrupted upload?) rather than defaults to import.

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

### 7. Presigned upload with no orphan reclamation

Flag a presigned or multipart upload flow with **neither** a storage lifecycle/expiry rule on the pending prefix **nor** an app-side pending-upload record → unbounded paid storage that nothing references, and no way to tell abandonment from a broken confirm step. Cite the presign site and the absence of both. → `report-flagged` (the fix is a lifecycle policy plus a schema row — a design call, not a patch).

### 8. Client-supplied object key at presign

```
BAD:   presign({ Key: req.body.filename })      // client names the object it is about to write
GOOD:  presign({ Key: `${pendingPrefix}/${uuid()}` })
```
Flag a presign handler whose object key derives from client input. Rule 5 forbids the client filename as a storage path; on the presigned path the same hole reappears one layer earlier, where an over-write of an existing key is also in reach.

## Closure verbs

Exactly one verb per finding. What each means for *this* pattern:

- `report-with-fix` — matched at `<file:line>` + the concrete size-cap / magic-byte / stream / uuid-key / header patch.
- `report-flagged` — the fix is a design call (move to presigned direct-to-storage; add a scanning service) → surface for ADR.
- `dismiss` — carve-out applies (a trusted internal-only admin import; a bounded config file) → documented.

## Related

- `response-streaming.md` — the outbound counterpart (streaming a file *out*).
- `request-validation.md` — boundary validation of the non-file fields on a multipart request (bounds, allow-list, `422` field errors); this pattern owns the upload stream itself.
- `conditional-requests.md` — ETag on served files for revalidation.
- `security` pack — SSRF (a presigned/fetch-by-URL upload path), content-security, malware policy.
- `distributed-systems` pack — the async scan/process hand-off (upload → 202 → job).
