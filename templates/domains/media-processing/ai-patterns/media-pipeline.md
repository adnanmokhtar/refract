---
name: media-pipeline
description: "Pattern: Media pipeline (validated, sandboxed async transcode, bounded, signed delivery)"
kind: ai-pattern
---

# Pattern: Media pipeline (validated, sandboxed async transcode, bounded, signed delivery)

> **Hard rule** — Deriving any variant from an uploaded image/video runs as an idempotent async job in a SANDBOXED worker (no network, dropped privileges, hard CPU/memory/time caps), never on the request thread; the input format is decided by MAGIC BYTES against an allowlist (never the client content-type/extension) and the output is always a RE-ENCODE; decode is guarded against decompression bombs + pixel/frame floods BEFORE it allocates memory; ImageMagick/ffmpeg are HARDENED (risky coders/protocols disabled) so a crafted file cannot trigger RCE/SSRF; output has ALL metadata (EXIF/GPS) stripped, raw SVG is never served from the app origin, and variants are stored tenant-scoped + delivered via signed short-lived URLs.

**When to apply**
- Any pipeline that decodes user-uploaded media to produce thumbnails, resized renditions, posters, transcoded video, or format conversions.
- Multi-tenant products where derived media must never cross a tenant boundary and the source is untrusted.
- Anywhere ImageMagick / ffmpeg / libvips / sharp touches bytes a user supplied.

**When NOT to apply**
- A pure storage handoff with no decode (store + serve the original, no derived variants) — that's `<patterns-path>/presigned-upload.md`, governed by `<rules-path>/upload-safety.md`.
- Trusted, first-party assets baked at build time from a checked-in source — the untrusted-input threat model doesn't apply.
- A managed transcode service (e.g. a cloud media service) that already sandboxes + hardens — then this pattern's job spine + tenant-scoped signed delivery still apply, but you don't run the codec yourself.

**Halt conditions / mandatory cites**
- Cite the async enqueue + the sandboxed transcode worker at `<path:line>`. A `sharp(...)` / `ffmpeg` / `convert` on the request thread = halt.
- Cite the magic-byte / `ffprobe` validation against the allowlist at `<path:line>`. A gate on `req.file.mimetype` / extension = halt.
- Cite the decompression-bomb / pixel-flood guard (`limitInputPixels` / header pixel+frame+duration check) at `<path:line>`. An unbounded decode = halt.
- Cite the codec hardening — ImageMagick `policy.xml` AND/OR ffmpeg `-protocol_whitelist` excluding `http`/`file`/`concat` — at `<path:line>`. Default-config codec on untrusted input = halt.
- Cite the metadata-strip step, the SVG handling, the tenant-scoped storage key, and the signed-URL issuance at `<path:line>` each.
- Grep ban: "the pipeline is safe/sandboxed/validated" without file:line for the validation, the bomb guard, the codec hardening, the metadata strip, and the signed delivery.

## Why

A media pipeline is the rare place where an attacker hands you a file and you then run a memory-unsafe C decoder on it at full privilege. The recurring failure modes:

1. **It's a DoS amplifier** — a 40 KB PNG whose header says `50000x50000` decodes to ~7.5 GB of pixels; a crafted video runs ffmpeg for hours. One upload melts a worker. Probe the header and reject pixel/frame/duration floods BEFORE decode; cap CPU/memory/time around it.
2. **It's an RCE/SSRF gateway** — ImageMagick's `MVG`/`MSL`/`URL` coders (ImageTragick, CVE-2016-3714) run shell/fetch payloads; ffmpeg honoring `http:`/`file:`/`concat:` protocols inside a crafted container reads `file:///etc/passwd` or hits `http://169.254.169.254/`. Disable the coders/protocols and sandbox the process with no network + dropped privileges.
3. **It leaks the user** — EXIF GPS in a served thumbnail publishes the uploader's home; raw SVG runs `<script>` as stored XSS in the app origin. Strip all metadata; rasterize/sanitize SVG off-origin.

The pattern: validate by magic bytes → probe + bound → run a hardened codec in a sandbox as an idempotent async job → strip metadata → store tenant-scoped → deliver signed + short-lived.

## Variant spec (declarative)

```ts
// src/modules/media/core/variant-spec.ts

export interface VariantSpec {
  name: string;                         // 'thumb' | 'small' | 'medium' | 'poster'
  width: number;
  height: number;
  format: 'webp' | 'jpeg' | 'png' | 'mp4';
  fit: 'cover' | 'inside';
}

/** Bounded fan-out: a source produces exactly THIS capped set — never an unbounded list. */
export const IMAGE_VARIANTS: ReadonlyArray<VariantSpec> = [
  { name: 'thumb',  width: 160,  height: 160,  format: 'webp', fit: 'cover'  },
  { name: 'small',  width: 480,  height: 480,  format: 'webp', fit: 'inside' },
  { name: 'medium', width: 1024, height: 1024, format: 'webp', fit: 'inside' },
];

/** Hard limits enforced BEFORE/around decode. A header exceeding any of these is rejected pre-decode. */
export const LIMITS = {
  allowedInput: new Set(['jpg', 'png', 'webp', 'gif', 'mp4', 'webm']),  // sniffed, not declared
  maxInputPixels: 50_000_000,           // 50 MP — a 40 KB bomb decodes to billions; reject on header
  maxDimension: 20_000,                 // px per side
  maxFrames: 2_000,
  maxDurationSec: 600,
  maxOutputBytes: 25 * 1024 * 1024,
  jobMemoryMb: 512,
  jobTimeoutSec: 120,
} as const;
```

Feature code declares a spec; the pipeline derives validation, sandbox flags, and storage from it. No raw `convert`/`ffmpeg` args in feature code.

## Magic-byte validation against the allowlist (NOT content-type)

```ts
// src/modules/media/core/sniff.ts
import { fileTypeFromBuffer } from 'file-type';   // reads leading bytes, not the name

/**
 * The REAL format comes from the file's magic bytes — the client Content-Type and the
 * filename extension are untrusted hints. A `.jpg` whose bytes are SVG/HTML/a polyglot
 * is rejected here, before any codec touches it.
 */
export async function sniffAllowedFormat(head: Buffer): Promise<string> {
  const sniffed = await fileTypeFromBuffer(head);          // e.g. { ext: 'png', mime: 'image/png' }
  if (!sniffed) throw new UnsupportedMediaError('unrecognized_bytes');

  // SVG is detected separately (text, no magic number) and routed to the SVG branch — NEVER the raster codec.
  if (looksLikeSvg(head)) throw new SvgRequiresSanitizationError();

  if (!LIMITS.allowedInput.has(sniffed.ext)) {
    throw new UnsupportedMediaError(`format_not_allowed:${sniffed.ext}`);
  }
  return sniffed.ext;                                       // trusted format, drives the codec branch
}

function looksLikeSvg(head: Buffer): boolean {
  const s = head.subarray(0, 1024).toString('utf8').trimStart().toLowerCase();
  return s.startsWith('<?xml') || s.startsWith('<svg') || s.includes('<svg');
}
```

Never branch on `req.file.mimetype` or `path.extname(name)`. The output is always a re-encode — the original bytes are never served back as a "variant", which neutralizes polyglots and embedded payloads.

## Request handler: enqueue, never transcode

```ts
// src/modules/media/media.controller.ts
// NestJS-style decorators shown for illustration. Substitute your project's actual idiom
// from .claude/_extracted-codebase.md (Express / FastAPI / Spring / etc.). The SHAPE —
// validate handoff -> derive an idempotent job key from the source hash + variant set ->
// enqueue -> return a job id — is what's universal, not the helper names.

@Controller('/media')
export class MediaController {
  constructor(
    @Inject(QUEUE) private queue: Queue,
    @Inject(MEDIA_JOBS) private jobs: MediaJobsRepo,
    @Inject(RATE_LIMITER) private limiter: RateLimiter,
  ) {}

  /** Source already landed in a PRIVATE bucket via presigned upload (see presigned-upload.md). */
  @Post('/:sourceId/process')
  async process(
    @Param('sourceId') sourceId: string,
    @Ctx() ctx: AuthContext,            // tenant comes from HERE, never the body
  ): Promise<{ jobId: string; statusUrl: string }> {
    await this.limiter.consume(`media:${ctx.tenantId}:${ctx.userId}`);   // per-tenant enqueue cap

    const source = await this.jobs.findSource(sourceId, ctx.tenantId);   // tenant-scoped lookup
    // Idempotent: same source bytes + same variant set => same job => same outputs. Re-run is a no-op.
    const specHash = hashVariants(IMAGE_VARIANTS);
    const jobKey = `transcode:${source.sha256}:${specHash}`;

    const existing = await this.jobs.findByKey(jobKey);
    if (existing && existing.status !== 'failed') {
      return { jobId: existing.id, statusUrl: `/media/jobs/${existing.id}` };
    }

    const job = await this.jobs.create({ key: jobKey, sourceId, tenantId: ctx.tenantId, status: 'queued' });
    await this.queue.add('transcode-media', {
      jobId: job.id,
      tenantId: ctx.tenantId,           // captured scope; the worker re-asserts it on storage
      sourceKey: source.storageKey,
      sourceSha: source.sha256,
    });
    return { jobId: job.id, statusUrl: `/media/jobs/${job.id}` };
  }
}
```

The request returns in milliseconds with a `jobId`. It NEVER decodes and NEVER returns a file.

## Worker: probe → bound → hardened codec in a sandbox → strip → store

```ts
// src/modules/media/workers/transcode.worker.ts

@Processor('transcode-media')
export class TranscodeWorker {
  constructor(
    @Inject(BLOB) private blob: BlobStore,
    @Inject(MEDIA_JOBS) private jobs: MediaJobsRepo,
    @Inject(SANDBOX) private sandbox: Sandbox,   // runs the codec with --network none, non-root, RO FS, caps
  ) {}

  @Process()
  async run(job: Job<TranscodeData>): Promise<void> {
    const { jobId, tenantId, sourceKey, sourceSha } = job.data;

    // 1) Pull only the HEAD first; sniff format from magic bytes against the allowlist.
    const head = await this.blob.readRange(sourceKey, 0, 4096);
    const fmt = await sniffAllowedFormat(head);              // throws on disallowed / SVG / polyglot

    const localIn = await this.blob.downloadToScratch(sourceKey);   // scratch dir, the only writable path

    // 2) Probe the header and REJECT decompression bombs / floods BEFORE a full decode allocates memory.
    await this.guardAgainstBombs(localIn, fmt);

    // 3) Decode + re-encode each bounded variant inside the SANDBOX (no network, non-root, capped).
    const outputs: StoredVariant[] = [];
    for (const spec of variantsFor(fmt)) {
      const localOut = await this.transcodeInSandbox(localIn, fmt, spec);  // hardened codec, see below
      const stripped = await this.stripAllMetadata(localOut, spec.format); // EXIF/GPS/IPTC/XMP gone

      // 4) Tenant-scoped key in a PRIVATE bucket. Cross-tenant access is structurally impossible.
      const key = `media/${tenantId}/${sourceSha}/${spec.name}.${spec.format}`;
      await this.blob.putPrivate(key, stripped, { cacheControl: 'private, max-age=0' });
      outputs.push({ name: spec.name, key, bytes: stripped.length });
    }

    await this.jobs.markReady(jobId, { variants: outputs });
  }

  /** Header-only guard. The pixel/frame/duration check happens BEFORE the heavy decode. */
  private async guardAgainstBombs(file: string, fmt: string): Promise<void> {
    if (fmt === 'mp4' || fmt === 'webm') {
      const meta = await ffprobe(file);                     // reads the container header, does not decode
      const v = meta.streams.find(s => s.codec_type === 'video');
      if (!v) throw new InvalidMediaError('no_video_stream');
      if (v.width > LIMITS.maxDimension || v.height > LIMITS.maxDimension) throw new MediaTooLargeError('dimension');
      if ((meta.format.duration ?? Infinity) > LIMITS.maxDurationSec) throw new MediaTooLargeError('duration');
      if ((v.nb_frames ?? Infinity) > LIMITS.maxFrames) throw new MediaTooLargeError('frames');
    } else {
      const meta = await sharp(file, { limitInputPixels: LIMITS.maxInputPixels }).metadata();
      const pixels = (meta.width ?? 0) * (meta.height ?? 0) * (meta.pages ?? 1);   // GIF/animated pages count
      if ((meta.width ?? 0) > LIMITS.maxDimension || (meta.height ?? 0) > LIMITS.maxDimension)
        throw new MediaTooLargeError('dimension');
      if (pixels > LIMITS.maxInputPixels)                   // the decompression-bomb gate
        throw new MediaTooLargeError(`pixels:${pixels}`);
    }
  }

  private async stripAllMetadata(file: string, format: string): Promise<Buffer> {
    // Re-encode through sharp WITHOUT .withMetadata() — EXIF/GPS/IPTC/XMP are dropped.
    // Only an explicit allowlist (here: orientation) is retained.
    return sharp(file, { limitInputPixels: LIMITS.maxInputPixels })
      .rotate()                          // applies + then drops the orientation tag
      .toFormat(format as keyof sharp.FormatEnum)
      .toBuffer();                       // no metadata carried forward
  }
}
```

Memory and time are capped by the sandbox; the bomb guard rejects floods before decode; the tenant key makes cross-tenant access structurally impossible; metadata never survives.

## Codec hardening — block RCE / SSRF

```ts
// src/modules/media/core/sandbox-codec.ts

/**
 * The codec runs in a container with NO network, non-root, read-only FS (one scratch mount),
 * and hard CPU/memory/time caps. On top of that, the codec ITSELF is configured to refuse the
 * dangerous coders/protocols that turn a crafted file into RCE/SSRF.
 */
async function transcodeInSandbox(input: string, fmt: string, spec: VariantSpec): Promise<string> {
  const out = scratchPath(`${spec.name}.${spec.format}`);

  if (fmt === 'mp4' || fmt === 'webm') {
    // ffmpeg: explicit protocol allowlist. NO http/https/file/concat/pipe/subfile for untrusted input,
    // so a crafted container cannot make ffmpeg fetch a URL (SSRF) or read a local path (LFI).
    await sandbox.run('ffmpeg', [
      '-protocol_whitelist', 'file,crop',
      '-i', input,
      '-frames:v', '1', '-vf', `scale=${spec.width}:-2`,   // poster frame, bounded
      '-y', out,
    ], { network: 'none', user: 'nobody', readOnlyRootfs: true,
         memoryMb: LIMITS.jobMemoryMb, timeoutSec: LIMITS.jobTimeoutSec });
  } else {
    // sharp/libvips path: limitInputPixels is the in-process bomb guard; the sandbox is the outer cap.
    const buf = await sharp(input, { limitInputPixels: LIMITS.maxInputPixels })
      .resize(spec.width, spec.height, { fit: spec.fit, withoutEnlargement: true })
      .toFormat(spec.format as keyof sharp.FormatEnum, { quality: 82 })
      .toBuffer();
    await writeScratch(out, buf);
  }
  return out;
}
```

```xml
<!-- /etc/ImageMagick-7/policy.xml — only if ImageMagick is in the path at all.
     Disables the coders behind ImageTragick (CVE-2016-3714) and caps resources. -->
<policymap>
  <policy domain="coder" rights="none" pattern="{MSL,MVG,URL,HTTPS,HTTP,FTP,EPHEMERAL,LABEL,TEXT,PANGO,XPS,PDF,PS,SVG}" />
  <policy domain="delegate" rights="none" pattern="*" />
  <policy domain="resource" name="memory" value="512MiB" />
  <policy domain="resource" name="width"  value="20000" />
  <policy domain="resource" name="height" value="20000" />
  <policy domain="resource" name="time"   value="60" />
</policymap>
```

The sandbox stops a successful exploit from reaching the network or the host; the coder/protocol allowlist stops the exploit from triggering in the first place. Use both — defense in depth.

## SVG: rasterize or sanitize, never serve raw

```ts
// src/modules/media/core/svg.ts
import createDOMPurify from 'dompurify';
import { JSDOM } from 'jsdom';

/**
 * Raw user SVG carries <script>, <foreignObject>, on* handlers, and external entity refs ->
 * stored XSS / SSRF if served from the app origin. Two safe paths:
 *   (a) rasterize to PNG/WebP in the sandbox (preferred — no SVG ever leaves), or
 *   (b) sanitize and serve from a SEPARATE sandboxed origin with a restrictive CSP.
 * Never serve the original SVG bytes from the application origin.
 */
export function sanitizeSvg(raw: string): string {
  const DOMPurify = createDOMPurify(new JSDOM('').window as unknown as Window);
  return DOMPurify.sanitize(raw, {
    USE_PROFILES: { svg: true, svgFilters: true },
    FORBID_TAGS: ['script', 'foreignObject', 'use'],
    FORBID_ATTR: ['onload', 'onerror', 'onclick'],
    ADD_URI_SAFE_ATTR: [],               // no external refs
  });
  // Then serve from media-cdn.example.com (NOT app.example.com) with `Content-Security-Policy: default-src 'none'`.
}
```

## Tenant-scoped, signed, short-lived delivery

```ts
// src/modules/media/delivery.service.ts

/** Variants live in a PRIVATE bucket under a tenant-scoped key; delivery is a signed short-lived URL. */
async function variantUrl(ctx: AuthContext, sourceSha: string, variant: string, format: string): Promise<string> {
  const key = `media/${ctx.tenantId}/${sourceSha}/${variant}.${format}`;   // tenant scope in the key
  // The caller must own the source in THIS tenant — checked before signing.
  await this.assertOwnsSource(ctx.tenantId, sourceSha);
  return this.cdn.signedUrl(key, { expiresIn: '15m' });                    // short-lived, private bucket
}
```

Cross-ref `<patterns-path>/report-generation.md` and `<rules-path>/upload-safety.md` for the same private-bucket + signed-URL discipline. Public buckets / permanent URLs / non-tenant-scoped keys are forbidden.

## Common mistakes

### Synchronous transcode on the request thread
`POST /avatar` calls `sharp(buf).resize(...)` inline → a 4K image holds the worker; a bomb OOMs the box. Enqueue a job; return a `jobId`; transcode in the sandboxed worker.

### Decompression bomb / pixel flood
A 40 KB PNG with header `50000x50000` decodes to billions of pixels. Probe the header and reject `> maxInputPixels` BEFORE decode; set `limitInputPixels` / ImageMagick `-limit`.

### Trusting the client content-type / extension
`if (req.file.mimetype === 'image/jpeg')` lets an SVG/HTML polyglot named `cat.jpg` through. Sniff magic bytes against an allowlist; always re-encode.

### Unhardened ImageMagick (ImageTragick)
Default `policy.xml` runs `MVG`/`MSL`/`URL` coders → shell exec / SSRF from a crafted file. Disable the coders in `policy.xml` and sandbox the process.

### ffmpeg protocol SSRF / LFI
A crafted container or playlist with `http:`/`file:`/`concat:` makes ffmpeg fetch `http://169.254.169.254/` or read `/etc/passwd`. Pass `-protocol_whitelist file,crop` only.

### Codec with network + root
Even hardened, run the decoder with `--network none`, non-root, read-only FS, and memory/time caps — so a 0-day can't reach the metadata service or the host.

### Retained EXIF/GPS
The thumbnail keeps the source's GPS tags → the uploader's home address is public. Strip all metadata on output; allowlist only safe fields.

### Raw SVG served from the app origin
`<script>` in user SVG runs as stored XSS. Rasterize, or sanitize + serve off-origin with a strict CSP.

### Unbounded variant fan-out
One upload → 30 renditions at 8K each → storage + cost blowup. Cap the variant allowlist and output dimensions.

### Public / non-tenant-scoped variant bucket
Variants in a public bucket with guessable keys → cross-tenant media access. Tenant-scoped key, private bucket, signed short-lived URL.

### Non-idempotent transcode
Re-processing the same source on every retry/webhook duplicates renditions and wastes the fleet. Key the job on `sha256(source)+spec`; return the existing variant.

## Cross-references

- `<rules-path>/media-processing-discipline.md` — the hard-rule list (async sandbox, magic-byte validation, bomb guard, codec hardening, metadata strip, signed delivery).
- `<rules-path>/upload-safety.md` — the boundary: upload does AV scan + size cap + storage handoff; this pattern starts after the bytes land.
- `<patterns-path>/presigned-upload.md` — how the source arrives (presigned PUT to a private bucket) before this pipeline runs.
- `<patterns-path>/report-generation.md` — shared signed-short-lived-URL + private-bucket + async-job spine.
- `<rules-path>/job-design.md` + `<patterns-path>/queue-producer-consumer.md` — transcode as a queued, idempotent, resumable job (idempotency key, DLQ, observability).
- `<rules-path>/rate-limit-enforcement.md` — per-tenant/user transcode-enqueue rate limits.
- `<commands-path>/audit-media-pipeline.md` — audit a specific pipeline (codec site, sync/async, validation, caps, hardening, metadata, delivery, tenant scope).
- `<agents-path>/media-processing-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-media-sandbox.md` — ADR pinning the codec, sandbox mechanism, format allowlist, and variant set.
