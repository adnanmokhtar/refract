---
description: End-to-end upload smoke — request presigned URL, PUT to S3, trigger backend completion, verify processed variants + CDN URL accessible.
---

# /upload-test

Purpose: in 60 seconds, prove the full upload pipeline works — presign, upload, scan, process, serve.

## What it does

1. POST `/uploads/presign` with auth, declare contentType + size.
2. Receive presigned URL + fields.
3. PUT a fixture file (or generated one) directly to S3 using returned URL.
4. POST `/uploads/complete` (or wait for S3 event-driven completion).
5. Poll `/uploads/<id>` until status = `ready` (or `failed`/`infected`).
6. Verify variants exist (thumbnails, optimized formats).
7. GET each variant via signed URL; verify HTTP 200 + Content-Type + Content-Length.
8. Verify EXIF stripped (for images), virus scan recorded.

## Usage

```bash
.claude/skills/upload-test.sh                                    # default fixture (1MB JPEG)
.claude/skills/upload-test.sh --file=fixtures/sample.pdf         # specific file
.claude/skills/upload-test.sh --size=20MB --type=image/jpeg      # generate test file
.claude/skills/upload-test.sh --bomb                             # decompression bomb test
.claude/skills/upload-test.sh --eicar                            # virus scan test (EICAR)
.claude/skills/upload-test.sh --target=https://staging.example.com
```

## Fixtures

| File | Purpose |
|---|---|
| `sample.jpg` (1.2 MB, GPS-tagged) | normal upload + EXIF strip check |
| `sample.png` (800 KB) | format conversion |
| `sample.pdf` (3 MB, 5 pages) | PDF processing |
| `large.bin` (50 MB) | size cap edge |
| `bomb.png` (50 KB → 50,000 × 50,000) | image-bomb DoS resilience |
| `eicar.com.txt` (68 bytes EICAR) | virus scan smoke |
| `evil.html.jpg` | extension-only-validation regression |

## Step-by-step output

```
/upload-test — fixtures/sample.jpg

[1] Presign request
    POST /uploads/presign
    Body: { contentType: 'image/jpeg', size: 1240892 }
    < 200 (84 ms)
    URL: https://uploads.example.com/...
    Fields: { 'x-amz-server-side-encryption': 'AES256', ... }
    Conditions: ['content-length-range', 0, 26214400]   OK (cap = 25 MB)

[2] PUT to S3
    PUT https://uploads.example.com/...
    Content-Length: 1240892
    < 200 (612 ms)
    ETag: "abc123..."

[3] Notify completion
    POST /uploads/complete  { uploadId }
    < 202 (32 ms)
    queued for processing

[4] Poll status
    GET /uploads/<id>
    > status: pending           (0s)
    > status: scanning          (1.2s)
    > status: processing        (3.4s)
    > status: ready             (5.1s)
    Final: { ready, variants: 4, scan: clean }

[5] Verify variants
    thumbnail (200x200):   GET signed URL → 200, 18 KB, image/webp     OK
    medium (800x600):      GET signed URL → 200, 84 KB, image/webp     OK
    large (1600x1200):     GET signed URL → 200, 220 KB, image/webp    OK
    original:              GET signed URL → 200, 1.2 MB, image/jpeg    OK

[6] EXIF check
    Original: GPS coords stripped from served original                  OK
    Variants: zero metadata block                                       OK

[7] Virus scan record
    DB: scan_status = clean, scanner = clamav, scanned_at = ...         OK

Summary: PASS — full pipeline 5.1s end-to-end.
```

## Negative tests (must fail correctly)

```
.claude/skills/upload-test.sh --eicar
> Expected: status = infected, variants not generated, original quarantined.

.claude/skills/upload-test.sh --bomb
> Expected: processing fails with "input pixel limit exceeded", marked failed, no OOM.

.claude/skills/upload-test.sh --size=100MB
> Expected: presign returns 400 (size > cap) OR S3 rejects PUT (content-length-range).

.claude/skills/upload-test.sh --file=fixtures/evil.html.jpg
> Expected: post-upload sniff fails, marked rejected, file deleted.
```

## When to run

- After any change to upload controller, presign service, processor, channel adapter.
- After S3 bucket policy or CORS update.
- After Sharp / ImageMagick / FFmpeg version bump (decode behavior changes).
- Daily smoke from CI on staging.
- Before any release that touches `infrastructure/storage/`.

## Failure modes the command surfaces

- **403 on PUT** — bucket policy or CORS misconfigured.
- **timeout on poll** — worker stuck (check queue depth).
- **scan: error** — ClamAV definition update broken.
- **variants 0** — Sharp version mismatch / decode error / pixel limit hit unexpectedly.
- **signed GET 403** — TTL too short, or key path mismatch.
- **EXIF still present** — `withMetadata(false)` regression.

## Underlying script outline

```bash
#!/usr/bin/env bash
set -euo pipefail

API="${API:-http://localhost:3000}"
TOKEN="${API_TOKEN}"

presign=$(curl -s -X POST "$API/uploads/presign" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"contentType":"image/jpeg","size":'$(stat -f%z "$FILE")'}')

url=$(echo "$presign" | jq -r .url)
upload_id=$(echo "$presign" | jq -r .uploadId)

curl -s --upload-file "$FILE" "$url"

curl -s -X POST "$API/uploads/complete" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"uploadId\":\"$upload_id\"}"

until [ "$(curl -s "$API/uploads/$upload_id" -H "Authorization: Bearer $TOKEN" | jq -r .status)" = "ready" ]; do
  sleep 1
done

# verify variants ...
```
