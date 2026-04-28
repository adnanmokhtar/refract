# Upload safety rules

User-uploaded files are the #1 RCE / DoS / privacy surface in any web app. Rules below are non-negotiable.

## Where uploads go

- Direct to S3 / GCS / R2 via presigned URL for files > 5 MB. Backend NEVER proxies large bodies.
- Small uploads (avatars < 5 MB) MAY go through backend with hard size limit in body parser.
- Bucket is PRIVATE — `BlockPublicAccess: true`, no public ACLs.
- Server-side encryption mandatory (`AES256` minimum, KMS for sensitive).
- Path: `tenants/<tenantId>/<entity>/<entityId>/<uuid>.<ext>` — UUID generated server-side, NEVER user filename.

## Size cap

- Cap declared at presign time AND enforced at S3 (`content-length-range` condition).
- Cap declared per content type — e.g. images 25 MB, PDFs 50 MB, videos 5 GB chunked.
- No cap = upload bomb (50 GB file fills bucket, runs cost up).

## Type validation (defense in depth)

- Presign request validates declared `contentType` against an allowlist.
- After upload, server reads file magic bytes (`file-type` package) and confirms it matches declared type. Mismatch → reject + delete.
- ZIP / RAR / 7z rejected unless explicitly required (then unpack into quarantine, scan inner files, never serve raw).
- Trusting file extension alone = `evil.html.jpg` ships as HTML on download = XSS / cookie theft.

## Filename hygiene

- User filename NEVER becomes the S3 key. Generate UUID.
- Sanitize the original name only for `Content-Disposition` — strip `../`, control chars, length cap (255 chars).
- `Content-Disposition: attachment` for non-image downloads — prevents inline rendering of unexpected types.

## Image processing

- Process in worker, not request handler.
- Cap decode size: `Sharp(input, { limitInputPixels: 8000 * 8000 })` — defends against pixel-bomb.
- Strip metadata: `.withMetadata(false)` after `.rotate()` (rotate uses EXIF, then drop it).
- Generate variants atomically — all variants persist or none (rollback on partial failure).
- Originals stored in `originals/` prefix (private); derived variants in `derived/` (CDN-served).

## Virus scan

- Scan after upload, BEFORE marking file `ready`. Files in `pending/` until clean.
- ClamAV inline for typical sizes (< 30s). S3 + Lambda scan for larger or async pipelines.
- Infected → move to `quarantine/`, alert security, notify uploader generically (don't reveal what was found).
- PDF / Office: macro detection (oletools, pdfid).

## Download serving

- Always via signed URL. NEVER static-serve a private bucket through your origin.
- TTL 5-60 min depending on use (avatars longer, financial docs shorter).
- `Content-Disposition: attachment; filename="..."` for non-image downloads.
- Inline image display via CloudFront with origin access identity, not direct backend proxy.
- No `Referer`-based hot-link protection — trivially spoofed; use signed URLs.

## Signed URL TTL

- Presigned upload: ≤ 5 minutes (`expiresIn: 300`).
- Presigned download: ≤ 60 minutes typical; ≤ 5 minutes for sensitive content.
- Long-lived "share" links: separate concept — DB-backed share record with expiry, NOT the raw signed URL.

## CORS

- Bucket CORS limits `AllowedOrigins` to your frontend domains (no wildcard `*`).
- `AllowedMethods`: `PUT, POST` for upload; `GET` for download.
- `AllowedHeaders` minimal — never `*`.

## Rate limiting

- Per-user presign rate cap (e.g. 30/min).
- Per-tenant daily storage growth cap with alert (e.g. > 10 GB/day for a free tier).
- Per-IP cap on presign endpoint (defense against credential-stuffing exploit).

## Lifecycle

- Incomplete multipart uploads: abort after 24h (`AbortIncompleteMultipartUpload`).
- Original-resolution variants: cold-tier transition after 90 days.
- Deletion follows tenant data retention policy (typically 30 days post-delete soft retention).

## Forbidden

- Public bucket holding user content.
- Validating file type by extension alone.
- Presign without `content-length-range`.
- Signed URL TTL > 1 hour for downloads, > 5 min for uploads.
- Marking file ready before virus scan completes.
- Server-proxied upload > 5 MB.
- Image processing without `limitInputPixels`.
- User filename used as storage key.
- Storing the file path in DB before upload completion (orphan rows on user abandon).
- Trusting `Referer` for hot-link protection.
- CORS `AllowedOrigins: '*'` on a private bucket.
