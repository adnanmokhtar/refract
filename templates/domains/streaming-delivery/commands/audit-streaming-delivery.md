---
description: Audit a specific stream end-to-end — manifest generation + cache, byte-range/206 segment serving, the key/license endpoint's authn AND per-content entitlement check, key source (KMS vs hardcoded), server-side-decrypt cleartext containment, IV/rotation, and CORS — from the real code + config, never an assumed setup.
---

# /audit-streaming-delivery

Diagnose whether a specific HLS/DASH stream is both **correct** (manifest + range + cache + CORS) and **secure** (the key/license path is authorized, keys are in a KMS, and any server-side-decrypted cleartext is contained) — from the REAL code and config, not a guess.

## Premise

Real signals only. Cite the actual key/license handler at `<path:line>` and the exact entitlement-check line (or its absence), the `EXT-X-KEY:URI=` in the manifest generator, the key source (`kms.` fetch vs a literal/env key), the segment handler's `Range` branch, the manifest + segment `Cache-Control`, the bucket/CDN any decrypted cleartext is written to, and the CORS config — never narrate a stream you didn't read. Read before auditing: start at the manifest generator, follow the `EXT-X-KEY` URI to the key endpoint, and follow the decrypted bytes (if server-side) to their destination.

## Mechanical halt

Cite-or-halt: every run MUST print (1) the manifest generator at `<path:line>` + its `Cache-Control` and VOD/live markers; (2) the segment handler at `<path:line>` and whether it honors `Range` (`206`/`Content-Range`/`416`) or a verified range-capable CDN does; (3) the key/license endpoint at `<path:line>`, whether it is authenticated, and **whether it enforces a per-content entitlement check** (or "AUTH-ONLY — bypass" / "OPEN — total bypass"); (4) the key source at `<path:line>` — KMS/secret-manager vs hardcoded/env/manifest (or "HARDCODED — key leak"); (5) for server-side decrypt: where the cleartext goes at `<path:line>` (response-only vs written to a bucket — name it; "PUBLIC/SHARED-CDN — cleartext leak"); (6) IV handling + rotation/revocation; (7) CORS on manifest + segments + key endpoint. If any cannot be produced from real code/config, HALT and say which — never an assumed config.

This command is READ-ONLY. It never fetches a real key, never decrypts content, never mutates storage — it reads source + config only.

## What it does

1. **Locate manifest generation** — cite `<path:line>`; check `Cache-Control` (short/no-cache), `EXT-X-ENDLIST` ⇔ VOD, sliding window + advancing `EXT-X-MEDIA-SEQUENCE` for live, `TARGETDURATION ≥ max segment`, codecs string.
2. **Segment serving** — cite the handler; does it honor `Range` (`Accept-Ranges`/`206`/`Content-Range`/`416`) or delegate to a range-capable CDN? Ignored Range = finding (broken seek). Manifest immutable-cached = finding.
3. **Find the key/license endpoint** — follow the manifest's `EXT-X-KEY:URI` / DASH license URL to the route. Cite `<path:line>`.
4. **Authn vs authz** — does the endpoint authenticate AND check this viewer's entitlement to THIS content? Cite the `canWatch`/authz line. Auth-only = BLOCKER (any user rips any title); open = BLOCKER (total bypass).
5. **Key source** — KMS/secret manager (scoped per content) vs a literal/env/committed key vs a key in the manifest. Cite `<path:line>`. Hardcoded/manifest = BLOCKER.
6. **Key hygiene** — `no-store` on key responses; no key/IV/decrypted bytes in logs; rate-limit + access-audit on the endpoint.
7. **Scheme** — AES-128 / SAMPLE-AES / CENC-DRM / clear-key. Unique IV per segment? Clear-key/static-key in prod = BLOCKER.
8. **Server-side decrypt containment** (if model C) — trace the cleartext buffer: response-only with `private, no-store`, or written to a bucket / cached on a shared CDN? Cite the destination. Public/shared = BLOCKER.
9. **CORS** — set for the player origin on manifest, segments, AND key/license endpoint (missing on key endpoint breaks only encrypted cross-origin playback).
10. **Report** — the stream matrix + the top fix.

## Flow

```text
manifest generator (<path:line>)
  -> cache: short/no-cache | immutable                       [finding if immutable]
  -> VOD ENDLIST | live sliding window + MEDIA-SEQUENCE       [finding if mismatched]
segment handler (<path:line>)
  -> Range: 206/Content-Range/416 | range-capable CDN         [finding if ignored]
key/license endpoint (<path:line>)  ← follow EXT-X-KEY URI
  -> authenticated?                                           [BLOCKER if open]
  -> per-content ENTITLEMENT check?                           [BLOCKER if auth-only]
  -> key source: KMS | hardcoded/env/manifest                 [BLOCKER if hardcoded]
  -> no-store + no key in logs + rate-limit + audit           [finding if missing]
scheme: AES-128 | SAMPLE-AES | CENC-DRM | clear-key
  -> unique IV per segment                                    [finding if reused]
  -> clear-key/static-key in prod                             [BLOCKER]
server-side decrypt? cleartext destination (<path:line>)
  -> response-only private no-store | public/shared CDN       [BLOCKER if public]
CORS on manifest + segments + key endpoint                    [finding if missing on key]
  -> report: stream matrix + top fix
```

## Output

A matrix (manifest / range / key-authz / key-source / decrypt-containment / scheme / CORS → status + `<path:line>`), the BLOCKER list with concrete fixes + verification steps, then the single highest-leverage fix.

## Cross-references
- `<agents-path>/streaming-delivery-reviewer.md` — the review gate this audit feeds.
- `<rules-path>/streaming-delivery-discipline.md` — the must/must-not.
- `<patterns-path>/encrypted-segment-delivery.md` + `<patterns-path>/adaptive-streaming-delivery.md` — the target shapes.
