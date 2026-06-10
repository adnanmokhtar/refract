---
name: media-processing-discipline
description: Media processing & transcode discipline
kind: rule
---

# Media processing & transcode discipline

## Hard rule

Decoding, transcoding, thumbnailing, or deriving variants from an uploaded image/video MUST run as an asynchronous, idempotent job in a SANDBOXED worker (no network, dropped privileges, hard CPU + memory + wall-time caps) — NEVER on the request thread. Input format MUST be decided by MAGIC BYTES / content sniff against a strict allowlist, NEVER by the client-supplied content-type or file extension; the safe output is a RE-ENCODE, never a pass-through of the original bytes. Decode MUST be guarded against decompression bombs and pixel/frame floods (max pixels, dimensions, frames, duration, output size) checked BEFORE/around decode. The codec (sharp / libvips / ffmpeg / ImageMagick) MUST be hardened — risky coders/protocols disabled (`policy.xml`, `-protocol_whitelist`) — so a crafted file cannot trigger RCE or SSRF. Output MUST have ALL metadata (EXIF, GPS, IPTC, XMP) stripped, raw user SVG MUST never be served from the app origin, and derived variants MUST be stored tenant-scoped in a PRIVATE bucket and delivered via signed, short-lived CDN URLs.

A media-pipeline bug is a melted worker fleet, a server reading `file:///etc/passwd` for an attacker, gigabytes of RAM from a 40 KB PNG, or a victim's home GPS coordinates served to the world. This pack begins where `<rules-path>/upload-safety.md` ends — upload handles AV scan + size cap + storage handoff; THIS rule governs everything that touches the bytes afterward.

## Must

- **Async, sandboxed transcode**: every decode/transcode/thumbnail is enqueued as a job (see `<patterns-path>/queue-producer-consumer.md`) and runs in a worker that has NO outbound network, dropped privileges (non-root, read-only FS except a scratch dir), and a hard CPU + memory + wall-time cap (cgroups / container limits / `ulimit`). The HTTP request returns a `job_id`, never a transcoded file.
- **Magic-byte validation against a format allowlist**: the real format is sniffed from the file's leading bytes (`file-type` / libmagic / `ffprobe`) and checked against a strict allowlist (e.g. `jpeg|png|webp|gif|mp4|webm`). The client `Content-Type` and the filename extension are treated as untrusted hints only. A `.jpg` whose bytes are SVG/HTML/a polyglot is REJECTED.
- **Re-encode, never pass-through**: the delivered variant is always a fresh re-encode produced by the codec — the original uploaded bytes are never served back as a "variant". Re-encoding neutralizes polyglots and embedded payloads.
- **Decompression-bomb + pixel/frame-flood guards BEFORE decode**: dimensions/pixel-count/frame-count/duration are read from the header (`sharp().metadata()` / `ffprobe`) and rejected against hard caps (e.g. `<= 50 MP`, `<= 20000 px` per side, `<= N` frames, `<= D` seconds) BEFORE a full decode allocates memory. `sharp` runs with `limitInputPixels` set; ImageMagick with `-limit` / `policy.xml` resource limits.
- **Bounded resources around decode**: max output dimensions, max output file size, max variants per source, and a hard per-job timeout + memory cap — enforced by the sandbox, not just by hope. A job that exceeds any cap is killed and marked failed, not retried into a loop.
- **Codec hardening (block RCE / SSRF)**: ImageMagick runs with a restrictive `policy.xml` disabling dangerous coders (`MSL`, `MVG`, `URL`, `HTTPS`, `EPHEMERAL`, `TEXT`, `LABEL`, `SVG`) and capping resources. ffmpeg runs with an explicit `-protocol_whitelist file,crop,...` (NO `http`, `https`, `file`, `concat`, `pipe`, `subfile` for untrusted input) so a crafted container cannot make the codec fetch a URL or read a local path.
- **Strip all metadata on output**: EXIF, GPS, IPTC, XMP, and color-profile-borne data are stripped from every output; only an explicit allowlist of safe fields (e.g. orientation, ICC profile if needed) is retained. GPS is NEVER retained.
- **SVG is sanitized or rasterized — never served raw**: SVG carries `<script>`, `<foreignObject>`, and external entities → stored XSS / SSRF. SVG is either rasterized to PNG/WebP in the sandbox or sanitized (DOMPurify with SVG profile, scripts/handlers/external refs stripped) and served from a separate, sandboxed origin — never raw from the app origin.
- **Bounded variant fan-out**: the set of derived renditions per source is a fixed, capped allowlist (e.g. `thumb|small|medium|poster`) with capped output dimensions. One upload may NOT spawn dozens of multi-megapixel renditions.
- **Idempotent transcode jobs**: the job key derives from `sha256(source) + variant-spec` so a re-run returns the existing variant and never re-transcodes or duplicates. A job that dies mid-encode resumes/retries to the same deterministic output key.
- **Tenant-scoped storage + signed short-lived delivery**: every variant is stored under a tenant-scoped key in a PRIVATE bucket and served via a signed, short-lived CDN URL (minutes–hours). Cross-ref `<patterns-path>/report-generation.md` and `<rules-path>/upload-safety.md` for the private-bucket + signed-URL discipline. Public buckets / permanent URLs are FORBIDDEN.

## Must not

- Decode/transcode a large image or video synchronously on the request thread — it holds the worker and times out; a crafted input OOMs the box.
- Decide the format from `req.file.mimetype` / the extension and feed the original bytes straight to the codec or back to the client — that's how polyglots, SVG-XSS, and ImageTragick get in.
- Call `sharp(buf)` / `convert in out` / `ffmpeg -i in` with NO pixel/dimension/frame/duration/time/memory limits — a 40 KB decompression-bomb PNG decodes to tens of thousands of pixels per side and exhausts RAM.
- Run ImageMagick with the default `policy.xml` or ffmpeg with the default protocol set on untrusted input — `MSL`/`MVG`/`URL` coders and `http`/`file`/`concat` protocols are RCE/SSRF vectors.
- Run the codec on a worker that has network access, root, or a writable root FS — sandbox escape + SSRF become reachable.
- Serve output with EXIF/GPS intact — leaks the uploader's home location and device.
- Serve raw user-supplied SVG from the application origin.
- Let one upload fan out into an unbounded/huge set of renditions, or produce a variant larger than a hard output-size cap.
- Store variants in a public bucket, with no tenant scoping, or behind permanent URLs — cross-tenant media access.
- Re-transcode the same source+spec on every request with no idempotency / cache.

## Should

- Wrap the codec behind a project-internal `<MediaTranscoder>` / `<VariantPipeline>` interface so the sandbox flags, resource limits, format allowlist, metadata stripping, and tenant-scoped storage are enforced in ONE place — feature code declares a variant spec, not raw `ffmpeg`/`convert` args.
- Probe with `ffprobe` / `sharp().metadata()` first and reject on header (codec, dimensions, duration, stream count) BEFORE spawning the heavy decode.
- Run the codec process under an explicit `seccomp` profile / gVisor / Firecracker / a dedicated container with `--network none --read-only --cap-drop ALL` and a `--memory` + `--cpus` cap.
- Make variant generation observable: log `{ sourceHash, variant, codec, inBytes, outBytes, durationMs, peakMemMb, killed }` and alert on jobs killed for resource caps or codec errors (a spike of kills can be an attack).
- Rate-limit transcode enqueues per tenant/user (see `<rules-path>/rate-limit-enforcement.md`) so one tenant cannot exhaust the worker fleet.
- Pin the codec + container image versions and patch promptly — ImageMagick/ffmpeg/libvips CVEs are frequent and directly exploitable on untrusted input.

## Review checklist (PRs touching decode / transcode / thumbnailing / variant generation)

- [ ] Decode/transcode runs as an async job in a sandboxed worker (no network, non-root, RO FS) — not on the request thread; cite the enqueue + worker at `<path:line>`.
- [ ] Format is validated by magic bytes / `ffprobe` against an allowlist — NOT the client content-type/extension; cite the sniff at `<path:line>`.
- [ ] Output is a re-encode, never a pass-through of the original bytes.
- [ ] Pixel/dimension/frame/duration caps + `limitInputPixels` / `-limit` are enforced BEFORE full decode; cite at `<path:line>`.
- [ ] Hard per-job CPU + memory + wall-time cap is enforced by the sandbox (cgroups/container/`ulimit`).
- [ ] ImageMagick `policy.xml` disables risky coders; ffmpeg uses an explicit `-protocol_whitelist` excluding `http`/`file`/`concat`; cite at `<path:line>`.
- [ ] All metadata (EXIF/GPS/IPTC/XMP) is stripped on output; only a safe-field allowlist retained.
- [ ] SVG is rasterized or sanitized + served off-origin — never raw from the app origin.
- [ ] Variant set + output dimensions are a capped allowlist (no unbounded fan-out).
- [ ] Transcode job is idempotent on `sha256(source)+spec`; re-run returns the existing variant.
- [ ] Variants are stored tenant-scoped in a private bucket and delivered via signed short-lived URLs; cite the key + signer at `<path:line>`.

## Anti-patterns

- **Sync transcode** — `POST /avatar` runs `sharp(buf).resize(...)` inline on the request thread → a 4K HEIC holds the worker for seconds; a decompression bomb OOMs the box. Enqueue a job; return a `job_id`.
- **Decompression bomb** — a 40 KB PNG with header dimensions `50000x50000` decodes to ~7.5 GB of pixels and kills the worker. Read dimensions from the header and reject `> maxPixels` BEFORE decode; set `limitInputPixels`.
- **Trusting content-type** — `if (req.file.mimetype === 'image/jpeg')` then feeding the bytes to the codec → an SVG/HTML polyglot named `cat.jpg` slips through. Sniff magic bytes against an allowlist; re-encode.
- **ImageTragick** — ImageMagick with the default `policy.xml` processes an `MVG`/`MSL` file that runs `url(...)` / shell payloads → RCE/SSRF. Disable the coders in `policy.xml`; sandbox the process.
- **ffmpeg protocol SSRF** — `ffmpeg -i playlist.m3u8` (or a `concat:`/`subfile:`/`http:` reference inside a crafted container) makes the server fetch `http://169.254.169.254/...` or read `file:///etc/passwd`. Pass `-protocol_whitelist file,crop` only; no `http`/`https`/`file`/`concat` for untrusted input.
- **EXIF/GPS leak** — the uploaded photo's EXIF GPS tags survive into the served thumbnail → the uploader's home address is public. Strip all metadata on output.
- **Raw SVG served** — user SVG stored and served from `app.example.com/media/x.svg` → `<script>` runs as stored XSS in the app origin. Rasterize or sanitize + serve off-origin.
- **Variant fan-out blowup** — one upload triggers 30 renditions at up to 8K each → storage + transcode cost explodes per upload. Cap the variant allowlist and output dimensions.
- **Public variant bucket** — variants written to a public, non-tenant-scoped bucket → tenant A guesses/enumerates tenant B's media URLs. Tenant-scoped key, private bucket, signed short-lived URL.
- **Non-idempotent transcode** — re-processing the same source on every retry/webhook duplicates renditions and wastes the fleet. Key on `sha256(source)+spec`; return the existing variant.

## Enforcement

- `<commands-path>/audit-media-pipeline.md` (slash: `/audit-media-pipeline`) — traces a specific pipeline end-to-end: where the codec is invoked at `<path:line>`, sync vs async, magic-byte vs trusted-extension validation, resource/dimension/duration/output caps, decompression-bomb guard, codec hardening (`policy.xml` / `-protocol_whitelist`), EXIF/GPS stripping, signed-vs-public delivery, and tenant scoping — cite-or-halt, never an assumed config.
- `<agents-path>/media-processing-reviewer.md` — review gate hard-failing on sync transcode, missing resource limits, content-type trust, unhardened ImageMagick/ffmpeg, retained EXIF/GPS, raw SVG, unbounded fan-out, and public/non-tenant-scoped delivery.
- CI MUST assert the transcode worker is configured with `--network none` (or equivalent) + a memory cap + non-root; reject a transcode path that runs in the API process.
- CI MUST reject `ffmpeg` invocations on untrusted input that omit `-protocol_whitelist`, and assert an ImageMagick `policy.xml` exists with risky coders disabled.
- CI lint MUST flag a codec call (`sharp(`, `convert`, `ffmpeg -i`) whose format gate reads `mimetype`/extension rather than a magic-byte sniff (AST heuristic; flag for review).
- TODO: `scripts/validate-media-pipeline.sh` to assert every codec invocation is preceded by a header-probe + pixel/duration cap, carries a metadata-strip step, and writes to a tenant-scoped private key.

## Cross-references

- `<patterns-path>/media-pipeline.md` — validated-input + sandboxed-async-transcode + bomb-guard + codec-hardening + metadata-strip + signed-delivery code shapes.
- `<rules-path>/upload-safety.md` — the boundary: upload handles AV scan, size cap, and storage handoff; THIS rule starts after the bytes land. Re-read the handoff contract.
- `<patterns-path>/presigned-upload.md` — how the source bytes arrive (presigned PUT to a private bucket) before this pipeline runs.
- `<patterns-path>/report-generation.md` — signed short-lived URL + private-bucket + async-job spine shared with this pack.
- `<rules-path>/job-design.md` + `<patterns-path>/queue-producer-consumer.md` — transcode is a queued, idempotent, resumable job; idempotency key + DLQ + observability.
- `<rules-path>/rate-limit-enforcement.md` — per-tenant/user transcode-enqueue rate limits.
- `<agents-path>/media-processing-reviewer.md` — review gate.
- `<commands-path>/audit-media-pipeline.md` — pipeline-audit tool.
- `<adr-path>/<NNN>-media-sandbox.md` — ADR pinning the codec, the sandbox mechanism (container / gVisor / Firecracker), the format allowlist, and the variant set.
