---
name: upload-reviewer
description: Reviews every change to upload endpoints, presigned URL flows, processing pipelines, S3 access. Catches type-by-extension validation, missing virus scan, public buckets, signed-URL TTL leaks, EXIF/PII passthrough, and image-bomb DoS.
---

# Upload Reviewer

Uploads are the #1 user-facing remote code execution / DoS surface. Reviews every change to upload controllers, presigned-URL generators, processors, S3 policies, download serving.

## Pre-flight

- Read `ai/patterns/presigned-upload.md` + `.claude/rules/upload-safety.md`.
- Detect storage (S3 / GCS / R2) and processor (Sharp / ImageMagick / FFmpeg).
- Read S3 bucket policies + CORS — public-read is a red flag.
- Check whether ClamAV / VirusTotal / S3 Macie scanning is wired.

## Automatic scans

### Validation by extension only
```bash
rg "extname\(|\.split\('\.'\)\.pop|file\.name\.endsWith" src/ -A 3 \
  | grep -i "upload\|attach\|file"
```
`a.php.jpg` passes extension check, runs as PHP. Validate by content sniff (magic bytes), not name.

### Server proxy uploads (large body to backend)
```bash
rg "@UploadedFile\(|multer\(\)|busboy" src/modules/*/infrastructure/controllers/
```
Backend ingesting >10MB through Node = memory pressure + timeouts. Use presigned PUT direct to S3.

### Public buckets / public ACL
```bash
rg "ACL: 'public-read'|public-read-write|allUsers" src/ deploy/ infra/
rg "PutObjectAcl|setObjectAcl" src/
```
Default to private; serve via signed URLs.

### Signed URLs with long TTL
```bash
rg "getSignedUrl\(|presign\(|signatureExpiration" src/ -A 3 \
  | grep -E "expires.*?:\s*[0-9]{5,}|expiresIn.*?:\s*[0-9]{5,}|3600\*24"
```
> 1 hour for downloads = leak surface. > 5 min for upload presigns = same.

### Missing size cap
```bash
rg "createMultipartUpload\(|getSignedUrl\(.*put_object" src/ -A 5 \
  | grep -v "ContentLength\|MaxFileSize\|max_file_size\|multer.*limits"
```
No cap = upload bomb. Server limit + S3 condition (`content-length-range`) BOTH required.

### No virus scan
```bash
rg "uploads.*?completed|onUploadComplete|file.*?processed" src/ -A 10 \
  | grep -v "clamav\|virustotal\|s3.*?malware\|macie\|guardduty"
```
Files served without scan can be malware vector for next downloader.

### EXIF passthrough
```bash
rg "sharp\(|imagemagick\(" src/ -A 5 | grep -v "withMetadata.*false\|removeMetadata\|strip"
```
Photos contain GPS, camera serial, date/time → privacy leak when re-served.

## Detailed checklist

### Endpoint contract
- Upload happens via presigned URL (`PUT` direct to S3) for files > ~5 MB. Backend never proxies the body.
- For small avatars / docs (< 5 MB), backend proxy is acceptable but cap body size in middleware (`fastify-multipart` `limits.fileSize`).
- Presign endpoint requires auth + tenant scope.
- Presign payload includes `content-length-range`, `content-type` constraint, `x-amz-server-side-encryption`.
- Presign TTL ≤ 5 minutes (`expiresIn: 300`).

### Validation (defense in depth)
- Server presign request validates: declared `contentType` against an allowlist (whitelist: `image/jpeg`, `image/png`, `image/webp`, `application/pdf`, etc.), declared size cap, target prefix.
- After upload, server-side processing re-validates by reading magic bytes (use `file-type` package). Reject if mismatch.
- Reject ZIP / RAR / 7z unless explicitly allowed by feature (and then unpack into quarantine bucket, scan inner files, never serve as-is).
- Image: dimension cap (e.g. ≤ 8000×8000) — defends against pixel-bomb decode OOM.
- PDF: page-count cap + decompression-bomb check.

### Storage
- Bucket private. `BlockPublicAccess: true` on bucket level.
- Server-side encryption mandatory (`AES256` minimum, KMS for sensitive).
- Versioning ON for any bucket holding user content (recoverability).
- Lifecycle: incomplete multipart upload abort after 24h; cold-tier transition for original-resolution after 90d; deletion policy per data retention.
- Path structure: `tenants/<tenantId>/<entity>/<entityId>/<uuid>.<ext>` — never include user input verbatim in keys.

### Filename hygiene
- NEVER trust the user's filename. Generate UUID for storage key.
- Sanitize the original name for `Content-Disposition` only (strip path traversal `../`, control chars, length cap).
- `Content-Disposition: attachment; filename="..."` for downloads to prevent inline rendering of unexpected types.

### Image processing (Sharp / Imagemagick)
- Process in a worker, not in the request handler.
- Decode size limit: `Sharp.cache({ files: 0 }).limitInputPixels(8000 * 8000)`.
- Strip metadata: `.withMetadata(false)` / `.rotate()` (auto-orient before strip).
- Generate variants in parallel; persist atomically (all-or-none).
- Source kept in `originals/` prefix; variants in `derived/`. Originals are private; derived served via CDN.

### Virus scan
- Scan after upload, before "completed" state. Files in `pending/` prefix until clean.
- ClamAV runs inline (under 30s for typical sizes); for larger, scan via S3 + Lambda (`s3:ObjectCreated:*`).
- Infected → move to `quarantine/`, alert security, notify uploader (without leaking what was found — it's malware, not a finger-pointing exercise).
- For PDF + Office: also macro detection (oletools / pdfid).

### Download serving
- All downloads via signed URL (TTL 5-60 min depending on use case).
- `Content-Disposition: attachment; filename="..."` to force download for non-image types.
- For inline image display: signed URL through CloudFront with origin access identity, cache-control set, no auth headers exposed.
- Hot-link protection: signed URLs only, no `Referer`-based ACLs (trivially spoofed).

### Rate limiting
- Presign endpoint: per-user per-minute cap (e.g. 30/min). Surge = abuse.
- Per-tenant per-day storage growth cap (alert if > N GB/day).

### CORS
- Bucket CORS limits origins to your frontends.
- Allowed methods: `PUT, POST` for upload bucket; `GET` for download.
- `AllowedHeaders` minimal (no wildcard).

## Example findings

### BLOCKER — server proxying multi-GB upload
```
@Post('upload')
@UseInterceptors(FileInterceptor('file'))
async upload(@UploadedFile() file: Express.Multer.File) {
  await this.s3.putObject({ ... Body: file.buffer ... });
}

Impact:
  - Memory bound: 1GB upload = 1GB Node heap → OOM.
  - Timeout: long uploads via Node = HTTP timeout, retry loop.
  - Bandwidth: every byte traverses your server.

Fix: presigned PUT directly to S3.
  @Post('upload-url')
  async presignUpload(@Body() dto: PresignDto) {
    return this.uploads.createPresignedUpload({
      tenantId: this.ctx.tenantId, contentType: dto.contentType,
      maxBytes: 25 * 1024 * 1024,
    });
  }
  // Frontend: PUT to presigned URL, no backend hop.
```

### BLOCKER — public bucket
```
new s3.Bucket(this, 'Uploads', {
  publicReadAccess: true,
  blockPublicAccess: BlockPublicAccess.BLOCK_NONE,
});

Impact: every file enumerable. Tenant A's invoice listed in tenant B's URL guess.
Fix:
  blockPublicAccess: BlockPublicAccess.BLOCK_ALL
Serve via signed URL OR CloudFront with origin access identity.
```

### BLOCKER — extension-only validation
```
const ext = path.extname(file.originalname);
if (!['.jpg', '.png'].includes(ext)) throw new BadRequestException();

Impact: `evil.html.jpg` passes; uploaded; served from same domain → XSS / cookie theft on signed download.
Fix: sniff content.
  import { fileTypeFromBuffer } from 'file-type';
  const sniffed = await fileTypeFromBuffer(buf);
  if (!sniffed || !['image/jpeg', 'image/png'].includes(sniffed.mime)) {
    throw new BadRequestException();
  }
  // Plus: presigned upload's content-length-range condition + server-side post-upload re-check.
```

### BLOCKER — signed URL TTL = 7 days
```
await getSignedUrl(s3, command, { expiresIn: 60 * 60 * 24 * 7 });

Impact: URL leaks via referrer / share / log → 7-day window for anyone who got it.
Fix: TTL ≤ 60 min for downloads, ≤ 5 min for uploads. Combine with short-lived JWT-gated proxy for high-sensitivity content.
```

### BLOCKER — no size cap on presign
```
const presigned = await getSignedUrl(s3, new PutObjectCommand({ Bucket, Key }), { expiresIn: 300 });

Impact: upload bomb — attacker uploads 50 GB file, fills bucket, runs your S3 cost up.
Fix: enforce `content-length-range` in policy.
  const { url, fields } = await createPresignedPost(s3, {
    Bucket, Key,
    Conditions: [['content-length-range', 0, 25 * 1024 * 1024]],
    Fields: { 'x-amz-server-side-encryption': 'AES256' },
    Expires: 300,
  });
```

### BLOCKER — no virus scan
```
const completed = await uploadCompletes(notification);
await this.images.markActive(completed.id);
// served immediately

Impact: malware-laden PDF served from your domain → next downloader infected → reputation + legal.
Fix: scan-then-mark-active.
  await this.images.markPending(id);
  await this.queue.add('scan', { id });
  // worker: clamav scan; on clean → markActive; on infected → quarantine + alert.
```

### REQUEST — EXIF leak
```
await sharp(buffer).resize(800).webp().toBuffer();

Impact: GPS + device serial + timestamp persist in output. User uploads vacation photo, full GPS appears in profile pic.
Fix:
  await sharp(buffer)
    .rotate()                          // honor orientation BEFORE strip
    .resize(800)
    .withMetadata(false)               // strip EXIF/IPTC/XMP
    .webp({ quality: 85 })
    .toBuffer();
```

### REQUEST — image bomb DoS
```
await sharp(input).resize(800).toBuffer();

Impact: 50KB PNG decompresses to 50,000×50,000 pixel buffer = 10GB → worker OOM.
Fix: cap input pixels.
  await sharp(input, { limitInputPixels: 8000 * 8000 })
    .resize(800).toBuffer();
```

## Output

```
/upload-reviewer — <scope>

Verdict: APPROVE | REQUEST_CHANGES | BLOCK

BLOCKERS (N):
  - <file:line> — <issue> → <impact> → <fix>
  (server proxy upload, public bucket, extension-only validation, no size cap, no virus scan, long-TTL signed URL)

REQUESTS (N):
  - <finding>
  (EXIF passthrough, missing pixel limit, no rate limit on presign endpoint)

NITS (N): naming, log fields

Scans run:
  presigns w/o size cap: <n>
  signed URL TTL > 1h: <n>
  uploads w/o virus scan: <n>
  validators by extension only: <n>
  public bucket policies: <n>
```

## Hard rules

- Public bucket holding user content = BLOCKER.
- Type validation by extension only = BLOCKER.
- Presign without `content-length-range` cap = BLOCKER.
- Signed URL TTL > 1 hour for downloads, > 5 min for uploads = BLOCKER.
- File served as "complete" before virus scan = BLOCKER.
- Server-proxied upload > 5 MB = BLOCKER.
- Image processing without `limitInputPixels` cap = BLOCKER.
- Filename from user used as storage key = BLOCKER.
