---
description: Audit a specific media pipeline end-to-end — codec invocation site, sync vs async, magic-byte validation, resource/dimension/duration caps, decompression-bomb guard, codec hardening, EXIF/GPS stripping, signed-vs-public delivery, and tenant scoping — from the real code + config, never an assumed setup.
---

# /audit-media-pipeline

Diagnose whether a specific image/video pipeline is safe: where the codec is actually invoked, whether it runs off the request thread in a sandbox, whether the input is validated by magic bytes, whether decode is bounded, whether the codec is hardened against RCE/SSRF, whether metadata is stripped, and whether delivery is tenant-scoped + signed — from the REAL code and config, not a guess.

## Premise

Real signals only. Cite the actual codec invocation at `<path:line>` (the `sharp(...)` / `ffmpeg -i` / `convert` / `vips` call), the validation site at `<path:line>`, the resource-limit config, the sandbox flags, the `policy.xml` / `-protocol_whitelist`, the metadata-strip step, the storage key template, and the URL signer — never narrate a pipeline you didn't read. Read before auditing: locate the codec call and trace BACK to where the bytes came from and FORWARD to where the variant is delivered.

## Mechanical halt

Cite-or-halt: every run MUST print (1) the codec invocation at `<path:line>`, (2) whether it runs on the request thread or in an async sandboxed worker, (3) the format-validation site at `<path:line>` and whether it sniffs magic bytes or trusts the client content-type/extension, (4) the pixel/dimension/frame/duration/output caps + the decompression-bomb guard at `<path:line>` (or "MISSING — DoS"), (5) the codec hardening — ImageMagick `policy.xml` / ffmpeg `-protocol_whitelist` — at `<path:line>` (or "MISSING — RCE/SSRF"), (6) the metadata-strip step at `<path:line>` (or "MISSING — EXIF/GPS leak"), and (7) the delivery: signed-short-lived vs public, and the tenant-scoped storage key at `<path:line>` (or "PUBLIC / NOT-SCOPED — cross-tenant"). If any cannot be produced from real code/config, HALT and say which — never an assumed config.

This command is READ-ONLY. It never runs the codec on a sample file, never decodes untrusted input, and never mutates storage — it reads source + config only.

## What it does

1. **Locate the codec call** — cite `<path:line>` for every `sharp(`/`ffmpeg`/`convert`/`magick`/`vips`/`gm` invocation in the pipeline.
2. **Sync vs async** — is the call in a request handler/controller, or in a queue worker? Print the enqueue site. Codec on the request thread is a finding.
3. **Sandbox check** — does the worker run with no network, non-root, read-only FS, and memory/CPU/time caps? Cite the container/cgroup/`ulimit` config. No sandbox on untrusted input is a finding.
4. **Validation site** — is the format decided by a magic-byte sniff / `ffprobe` against an allowlist, or by `req.file.mimetype` / the extension? Cite `<path:line>`. Trusting the client type is a BLOCKER.
5. **Bomb + flood guard** — is there a header probe (dimensions/pixels/frames/duration) with hard caps + `limitInputPixels` / `-limit` BEFORE decode? Cite `<path:line>`. Missing = BLOCKER (DoS).
6. **Codec hardening** — ImageMagick `policy.xml` disabling risky coders; ffmpeg `-protocol_whitelist` excluding `http`/`file`/`concat`. Cite `<path:line>`. Default config on untrusted input = BLOCKER (RCE/SSRF).
7. **Metadata strip** — is EXIF/GPS/IPTC/XMP stripped on output (no `withMetadata()`, explicit strip)? Cite `<path:line>`. Missing = finding (GPS leak).
8. **SVG handling** — is raw SVG rejected/rasterized/sanitized-off-origin, or served as-uploaded from the app origin? Cite `<path:line>`.
9. **Delivery + tenant scope** — is the variant stored under a tenant-scoped private key and delivered via a signed short-lived URL? Cite the key template + signer. Public/non-scoped = BLOCKER.
10. **Report** — the pipeline matrix + the top fix.

## Flow

```text
locate codec call (<path:line>)
  -> sync (request handler) | async (worker)                 [BLOCKER if sync]
  -> sandbox? network=none, non-root, RO FS, mem/time cap     [finding if none]
  -> validation: magic bytes/ffprobe + allowlist | mimetype   [BLOCKER if client-type]
  -> bomb guard: pixel/dim/frame/duration caps + limitInputPixels BEFORE decode [BLOCKER if missing]
  -> hardening: policy.xml coders / -protocol_whitelist        [BLOCKER if default]
  -> metadata strip: EXIF/GPS/IPTC/XMP removed                 [finding if retained]
  -> SVG: rasterized/sanitized/off-origin | raw from app origin [BLOCKER if raw]
  -> delivery: signed short-lived + tenant-scoped private key  [BLOCKER if public/not-scoped]
  -> report: pipeline matrix + top fix
```

## Output

```
/audit-media-pipeline — <pipeline name> @ <path:line>

Codec call (<path:line>):
  sharp(buf).resize(160,160).toFormat('webp')        [or: ffmpeg -i in -protocol_whitelist file,crop ...]

Execution:     async worker @ transcode.worker.ts:34   [or: SYNC in controller @ media.controller.ts:18 — BLOCKER]
Sandbox:       --network none, user=nobody, RO FS, mem=512M, timeout=120s @ worker.yaml:12  [or: NONE — finding]
Validation:    magic-byte sniff (file-type) + allowlist @ sniff.ts:14   [or: req.file.mimetype — BLOCKER]
Bomb guard:    limitInputPixels=50M + header pixel/dim/frame/duration caps @ worker.ts:61  [or: MISSING — BLOCKER(DoS)]
Hardening:     policy.xml coders off + ffmpeg -protocol_whitelist file,crop @ sandbox-codec.ts:22  [or: DEFAULT — BLOCKER(RCE/SSRF)]
Metadata:      stripped (no withMetadata) @ worker.ts:78    [or: RETAINED — finding(GPS leak)]
SVG:           rasterized in sandbox @ svg.ts:9             [or: served raw from app origin — BLOCKER(XSS)]
Variant set:   capped allowlist (thumb/small/medium) @ variant-spec.ts:11  [or: UNBOUNDED — finding]
Delivery:      signed 15m URL, key media/<tenant>/<sha>/... @ delivery.service.ts:7  [or: PUBLIC / NOT-SCOPED — BLOCKER]

Verdict: OK | NEEDS-VALIDATION | NEEDS-BOMB-GUARD | NEEDS-HARDENING | NEEDS-SANDBOX | BLOCKER(scope)

Top recommendation:
  - <e.g. move codec to a sandboxed worker; sniff magic bytes; add -protocol_whitelist; strip EXIF; tenant-scope the key>
```

## Rules

- READ-ONLY audit. Never run the codec on untrusted input, never decode a sample, never mutate storage — read source + config only.
- Cite-or-halt: real codec call, real validation site, real limits, real hardening config, real key template + signer — or halt naming what's missing.
- Always print the validation verdict (magic bytes vs client type), the bomb-guard verdict, and the codec-hardening verdict — these are the RCE/SSRF/DoS spine, reported first.
- A codec on the request thread, a client-content-type gate, a missing bomb guard, a default-config codec on untrusted input, or public/non-tenant-scoped delivery is a BLOCKER — say so, not as an aside.
- Never report a sandbox/limit/hardening config you didn't read from a real file.

## Cross-references

- `.claude/rules/media-processing-discipline.md` — the hard-rule list this command enforces (async sandbox, magic-byte validation, bomb guard, codec hardening, metadata strip, signed delivery).
- `ai/patterns/media-pipeline.md` — the validated-input + sandboxed-transcode + bomb-guard + hardening + metadata-strip + signed-delivery code shapes.
- `.claude/rules/upload-safety.md` — the boundary: upload handles AV scan + size cap + storage handoff before this pipeline runs.
- `<agents-path>/media-processing-reviewer.md` — review gate that consumes these findings.
