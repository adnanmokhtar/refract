---
name: presigned-upload
description: Pattern: Presigned upload (direct-to-S3)
kind: ai-pattern
---

# Pattern: Presigned upload (direct-to-S3)

> **Hard rule** — Presigned policy MUST include `content-length-range` + `eq $Content-Type` + SSE; actual content type is sniffed post-upload before marking ready; scan + variants run async. No backend that proxies multi-MB user uploads through Node memory.

**When to apply**
- User uploads > 1 MB where backend bandwidth/memory becomes user-facing latency.
- Image/document/video flows that need server-side size caps and async processing.
- Multi-tenant SaaS where files are per-tenant and ACL'd on download.

**When NOT to apply**
- Tiny files (avatars < 1 MB) where simpler server-proxy is acceptable.
- Compliance-critical flows that demand inline PII redaction at ingress (route through backend, cap at low size).
- Files > 5 GB — switch to multipart upload protocol.

**Halt conditions / mandatory cites**
- Cite `content-length-range` + `eq $Content-Type` + SSE conditions in the presign call at `<path:line>`. Missing any condition = halt.
- Cite the post-upload type sniff (`file-type` / magic bytes) at `<path:line>`. Trusting declared MIME = halt.
- Cite the scan-before-ready transition at `<path:line>`. Marking ready directly on upload completion = halt.
- Cite the download URL signer with TTL ≤ 10 min and tenant ACL check at `<path:line>`. Public bucket or long TTL = halt.
- Grep ban: "users upload files" without file:line for presign conditions, sniff, scan, and ACL'd download.

Client gets a presigned URL → uploads direct to S3 → backend gets webhook on completion → processes asynchronously → marks file ready. Backend never sees the file body.

## Decision summary

Default upload pattern: **presigned POST policy + S3 event → SQS → worker**. Reasons:
- Backend bandwidth + memory bound on proxy uploads becomes user-facing latency at multi-MB.
- S3 enforces the size cap server-side (`content-length-range` policy condition).
- S3 + Lambda (or SQS-driven workers) makes processing horizontally scalable.
- Security: the backend never holds the file in RAM, never streams to disk.

When to choose differently:
- Tiny files (avatars < 1 MB): server proxy is acceptable; less moving parts.
- Compliance-critical: route through your backend so you can enforce extra controls (PII detection at ingress) — but cap at low size.
- Multipart for > 5 GB (S3 hard limit on single PUT).

## File layout

```
src/uploads/
├── core/
│   ├── upload.entity.ts                  # `uploads` row
│   ├── upload-status.enum.ts             # pending → uploaded → scanning → processing → ready / failed / infected
│   └── upload-purpose.enum.ts            # avatar / product-image / invoice / etc.
├── application/
│   ├── presign.service.ts                # generate presigned post
│   ├── complete-upload.service.ts        # webhook handler
│   └── process-upload.service.ts         # variant generation
└── infrastructure/
    ├── controllers/
    │   ├── presign.controller.ts
    │   └── s3-events.controller.ts       # S3 → SNS → backend OR poll SQS in worker
    ├── storage/s3.service.ts
    ├── scanners/clamav.scanner.ts
    └── workers/
        ├── scan-upload.worker.ts
        └── process-upload.worker.ts
```

## Upload entity

```ts
@Entity('uploads')
export class UploadEntity {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column() tenantId: string;
  @Column() userId: string;
  @Column({ type: 'enum', enum: UploadPurpose }) purpose: UploadPurpose;

  @Column() bucket: string;
  @Column() key: string;                   // tenants/<tenantId>/<purpose>/<uuid>.<ext>
  @Column() declaredContentType: string;
  @Column({ nullable: true }) actualContentType: string | null;   // sniffed post-upload
  @Column({ type: 'bigint' }) declaredSize: number;
  @Column({ type: 'bigint', nullable: true }) actualSize: number | null;
  @Column({ nullable: true }) etag: string | null;

  @Column({ type: 'enum', enum: UploadStatus, default: 'pending' }) status: UploadStatus;
  @Column({ nullable: true }) failureReason: string | null;

  @Column({ type: 'jsonb', default: {} }) variants: Record<string, { key: string; size: number }>;
  @Column({ nullable: true }) scanResult: 'clean' | 'infected' | null;
  @Column({ nullable: true }) scannedAt: Date | null;

  @CreateDateColumn() createdAt: Date;
  @Column({ nullable: true }) completedAt: Date | null;
}
```

## Presign endpoint

```ts
@Controller('uploads')
export class PresignController {
  constructor(private readonly presign: PresignService, private readonly ctx: TenantContext) {}

  @Post('presign')
  @UseGuards(JwtGuard)
  @Throttle(30, 60)                         // 30 presigns/min/user
  async createPresign(@Body() dto: CreatePresignDto, @CurrentUser() user: AuthUser) {
    return this.presign.generate({
      tenantId: this.ctx.getTenantId(),
      userId: user.id,
      purpose: dto.purpose,
      contentType: dto.contentType,
      size: dto.size,
    });
  }
}

class CreatePresignDto {
  @IsEnum(UploadPurpose) purpose: UploadPurpose;
  @IsIn(['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
  contentType: string;
  @IsInt() @Min(1) @Max(25 * 1024 * 1024)   // hard cap also at validation
  size: number;
}
```

## Presign service

```ts
@Injectable()
export class PresignService {
  private readonly limits: Record<UploadPurpose, { maxBytes: number; types: string[] }> = {
    avatar:        { maxBytes: 2 * 1024 * 1024, types: ['image/jpeg', 'image/png', 'image/webp'] },
    productImage:  { maxBytes: 25 * 1024 * 1024, types: ['image/jpeg', 'image/png', 'image/webp'] },
    invoice:       { maxBytes: 50 * 1024 * 1024, types: ['application/pdf'] },
  };

  constructor(
    private readonly s3: S3Client,
    private readonly uploads: UploadRepository,
  ) {}

  async generate(input: GenerateInput): Promise<PresignResult> {
    const config = this.limits[input.purpose];
    if (!config.types.includes(input.contentType)) {
      throw new BadRequestException('content_type_not_allowed');
    }
    if (input.size > config.maxBytes) {
      throw new BadRequestException('size_exceeds_limit');
    }

    const id = randomUUID();
    const ext = mime.extension(input.contentType) ?? 'bin';
    const key = `tenants/${input.tenantId}/${input.purpose}/${id}.${ext}`;

    const upload = await this.uploads.create({
      id, tenantId: input.tenantId, userId: input.userId, purpose: input.purpose,
      bucket: process.env.UPLOAD_BUCKET!, key,
      declaredContentType: input.contentType, declaredSize: input.size,
      status: 'pending',
    });

    const { url, fields } = await createPresignedPost(this.s3, {
      Bucket: process.env.UPLOAD_BUCKET!,
      Key: key,
      Conditions: [
        ['content-length-range', 0, config.maxBytes],
        ['eq', '$Content-Type', input.contentType],
        { 'x-amz-server-side-encryption': 'AES256' },
        { 'x-amz-meta-upload-id': id },
      ],
      Fields: {
        'Content-Type': input.contentType,
        'x-amz-server-side-encryption': 'AES256',
        'x-amz-meta-upload-id': id,
      },
      Expires: 300,                          // 5 min
    });

    return { uploadId: id, url, fields };
  }
}
```

The `Conditions` array is the S3-enforced contract:
- `content-length-range` — server-side size cap.
- `eq $Content-Type` — must match what we presigned.
- `x-amz-server-side-encryption` — mandatory.

A client trying to upload a 50 GB file to a 25 MB-capped presign gets rejected by S3, not by your backend.

## Client-side upload (frontend reference)

```ts
const { uploadId, url, fields } = await api.post('/uploads/presign', {
  purpose: 'productImage', contentType: file.type, size: file.size,
});

const form = new FormData();
Object.entries(fields).forEach(([k, v]) => form.append(k, v as string));
form.append('file', file);

const res = await fetch(url, { method: 'POST', body: form });
if (!res.ok) throw new Error(`upload failed: ${res.status}`);

await api.post('/uploads/complete', { uploadId });
```

## Completion handler

Two paths — pick based on infrastructure:

### Option A: client notifies completion
```ts
@Post('complete')
async complete(@Body() dto: CompleteDto, @CurrentUser() user: AuthUser) {
  return this.completeUpload.execute({ uploadId: dto.uploadId, userId: user.id });
}
```

### Option B: S3 event-driven (more reliable)
S3 → SNS → SQS → worker. Client doesn't need to call back; the worker reacts to the bucket event.

Either way:

```ts
@Injectable()
export class CompleteUploadService {
  async execute({ uploadId, userId }: CompleteInput) {
    const upload = await this.uploads.findById(uploadId);
    if (!upload || upload.userId !== userId) throw new NotFoundException();
    if (upload.status !== 'pending') return upload;     // idempotent

    // Verify file actually arrived; capture actual size + ETag.
    const head = await this.s3.headObject({ Bucket: upload.bucket, Key: upload.key });
    if (!head) {
      await this.uploads.markFailed(uploadId, 'object_not_found');
      throw new NotFoundException();
    }

    await this.uploads.markUploaded(uploadId, {
      actualSize: head.ContentLength!,
      etag: head.ETag!,
    });

    await this.queue.add('scan', { uploadId }, { jobId: `scan:${uploadId}` });
    return this.uploads.findById(uploadId);
  }
}
```

## Scan worker (ClamAV)

```ts
export class ScanUploadWorker {
  constructor(/* ... */) {
    new Worker('scan', async (job) => {
      const upload = await this.uploads.findById(job.data.uploadId);
      if (!upload || upload.status !== 'uploaded') return;

      await this.uploads.updateStatus(upload.id, 'scanning');

      // Stream from S3 to ClamAV; never load into memory.
      const stream = await this.s3.getObjectStream(upload.bucket, upload.key);
      const result = await this.clamav.scanStream(stream);

      if (result.infected) {
        await this.s3.copy(upload.bucket, upload.key, `quarantine/${upload.key}`);
        await this.s3.delete(upload.bucket, upload.key);
        await this.uploads.markInfected(upload.id);
        await this.security.alertInfected(upload);
        return;
      }

      await this.uploads.recordScan(upload.id, 'clean');
      await this.queue.add('process', { uploadId: upload.id });
    });
  }
}
```

## Process worker (Sharp)

```ts
export class ProcessUploadWorker {
  private readonly variants = [
    { name: 'thumbnail', width: 200 },
    { name: 'medium', width: 800 },
    { name: 'large', width: 1600 },
  ];

  async process(uploadId: string) {
    const upload = await this.uploads.findById(uploadId);
    if (!upload || upload.status !== 'uploaded') return;
    await this.uploads.updateStatus(upload.id, 'processing');

    const buffer = await this.s3.getObject(upload.bucket, upload.key);

    // sniff actual type — defense vs declared mismatch
    const { fileTypeFromBuffer } = await import('file-type');
    const sniffed = await fileTypeFromBuffer(buffer);
    if (!sniffed || !ALLOWED.includes(sniffed.mime)) {
      await this.uploads.markFailed(upload.id, 'mime_mismatch');
      await this.s3.delete(upload.bucket, upload.key);
      throw new UnrecoverableError('mime_mismatch');
    }
    await this.uploads.recordActualMime(upload.id, sniffed.mime);

    const variants: Record<string, { key: string; size: number }> = {};

    for (const variant of this.variants) {
      const out = await sharp(buffer, { limitInputPixels: 8000 * 8000 })
        .rotate()
        .resize({ width: variant.width, withoutEnlargement: true })
        .withMetadata(false)              // strip EXIF
        .webp({ quality: 85 })
        .toBuffer();

      const key = upload.key.replace('originals/', `derived/${variant.name}/`).replace(/\.[^.]+$/, '.webp');
      await this.s3.putObject({
        Bucket: upload.bucket, Key: key, Body: out,
        ContentType: 'image/webp',
        ServerSideEncryption: 'AES256',
        CacheControl: 'public, max-age=31536000, immutable',
      });
      variants[variant.name] = { key, size: out.length };
    }

    await this.uploads.markReady(upload.id, variants);
  }
}
```

## Download (signed URL)

```ts
@Get(':id/url')
@UseGuards(JwtGuard)
async getDownloadUrl(@Param('id') id: string, @Query('variant') variant: string, @CurrentUser() user: AuthUser) {
  const upload = await this.uploads.findById(id);
  await this.access.assertCanRead(user, upload);    // tenant + ACL check

  const key = variant === 'original' ? upload.key : upload.variants[variant]?.key;
  if (!key) throw new NotFoundException();

  const url = await getSignedUrl(this.s3, new GetObjectCommand({
    Bucket: upload.bucket, Key: key,
    ResponseContentDisposition: variant === 'original' ? `attachment; filename="${upload.suggestedFilename}"` : undefined,
  }), { expiresIn: 600 });   // 10 min

  return { url, expiresIn: 600 };
}
```

## Variants

### Multipart upload (files > 5 GB)
```ts
const upload = await this.s3.createMultipartUpload({ Bucket, Key, ContentType });
// Per part: presign UploadPart; client uploads parts in parallel; client POSTs CompleteMultipartUpload.
// Lifecycle: AbortIncompleteMultipartUpload after 24h.
```

### On-the-fly Sharp resize via CloudFront + Lambda@Edge
- Origin: S3 with originals only.
- Lambda@Edge intercepts `?w=800`, generates derived on first request, caches in CloudFront.
- Trade-off: cold-start latency on first hit; lower storage cost; downside is per-request Lambda cost.

### ClamAV via Lambda
- S3 event → Lambda with ClamAV layer → scans → tags object `scan-status: clean|infected`.
- Pros: scales horizontally, no inline ClamAV daemon.
- Cons: slower (Lambda cold start + scan ~20-60s for medium files).

## Trade-off table

| Pattern | Pros | Cons |
|---|---|---|
| Direct-to-S3 presigned POST | scales infinitely; no backend bandwidth | client must implement retry; presigned policy slightly complex |
| Backend-proxied upload | full inline control (sniff, scan, virus, watermark all in-process) | Node memory pressure; multi-second handler |
| S3 multipart | > 5 GB; resumable | client must orchestrate parts |
| Tus protocol | resumable, well-defined | extra server (tusd) or library |

## Common mistakes

- **Presign without `content-length-range`** — attacker uploads 50 GB; bucket fills; cost spikes.
- **Not validating actual content type post-upload** — client lies about content type at presign; uploads `evil.html` as `image/jpeg`; you serve HTML; XSS.
- **Marking ready before scan** — race against the scan worker; user can fetch + share an infected file before the scanner gets to it.
- **Variants generated synchronously in the controller** — request handler busy 5-10s; timeouts; horrible UX.
- **Storing user filename as S3 key** — path traversal (`../../etc/passwd`), collisions across users, predictable URLs.
- **Public bucket "for performance"** — every file enumerable; tenant data leaks via URL-guess.
- **Long-TTL signed URLs** — share / referrer leaks → 7-day window of unauthenticated access.
- **No `limitInputPixels`** — Sharp loads pixel buffer = decompressed size; 50 KB PNG → 10 GB buffer → OOM.
- **EXIF passthrough** — user's vacation GPS coords end up in their public profile photo.
- **Storing presign result in DB before user uploads** — orphan rows on abandonment; cleanup job mandatory.
- **No CORS scoping on bucket** — any site can presign-and-upload as your user via stolen creds.
- **Forgetting `AbortIncompleteMultipartUpload` lifecycle** — incomplete uploads accrete forever, cost growing silently.
