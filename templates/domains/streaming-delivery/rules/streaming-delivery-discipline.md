---
name: streaming-delivery-discipline
description: Must / must-not for serving adaptive media streams (HLS / DASH / CMAF) and for encrypted-segment delivery + decryption (AES-128 / SAMPLE-AES / CENC-DRM / clear-key). Covers manifest + byte-range correctness, entitlement-gated key/license delivery, server-side-decrypt cleartext containment, and key management.
kind: rule
---

# Streaming delivery & segment decryption discipline

> **Hard rule (TL;DR):** Serving a stream is an **authorization** problem before it is a delivery problem. Every key request, license request, and signed-playback URL MUST be gated on a **per-viewer entitlement check for that specific content** — not just "is logged in". Decryption keys live in a KMS / secret store, never in the repo, the manifest, a public object, or a log. When the **server** decrypts segments, the cleartext is ephemeral and is NEVER written to a public/CDN-cached location or served without auth. Manifests are short-cache; segments are immutable long-cache; range requests (`Range` → `206`) are honored exactly. Clear-key in production = no protection.

Applies when the project serves HLS / DASH / CMAF, manifests (`.m3u8` / `.mpd`), media segments (`.ts` / `.m4s` / `.mp4` / `.cmf*`), or decrypts encrypted segments anywhere in the path. Pairs with `<rules-path>/media-processing-discipline.md` (which owns the **transcode/packaging** that produces these segments) — this rule owns everything from the manifest outward to the player.

## Must

- **Entitlement-gate every key / license / signed-playback request.** The key endpoint (`EXT-X-KEY URI`), the DRM license endpoint, and any signed-URL/token minting MUST verify that *this* authenticated viewer is entitled to *this* content (subscription active, purchase present, geo/age allowed) before issuing anything. Authentication ≠ authorization: "valid session" is not "may watch this title".
- **Keys and license material come from a KMS / secret manager**, fetched at request time, scoped per content (and per tenant where multi-tenant). Never hard-coded, never committed, never in env files checked into the repo.
- **Key delivery over TLS only**, with short-lived, single-use-where-possible, signed key URLs. The key URI in the manifest points at an authorized endpoint — never at a public bucket object.
- **Honor `Range` requests exactly.** Segment/file responses set `Accept-Ranges: bytes`, return `206 Partial Content` with a correct `Content-Range` for a valid range, `200` for a full request, and `416 Range Not Satisfiable` for an out-of-bounds range. Seeking and progressive playback depend on this.
- **Cache headers split by artifact lifetime.** Media playlists/manifests: short or no-cache (`no-cache` for live, short max-age for VOD) — they change. Segments + init segments + encryption keys-as-files: treat as immutable content-addressed (`Cache-Control: max-age=31536000, immutable`) ONLY when the URL is unguessable/signed; never long-cache a key behind a guessable URL.
- **Correct `Content-Type` per artifact** (`application/vnd.apple.mpegurl` for `.m3u8`, `application/dash+xml` for `.mpd`, `video/mp2t` / `video/mp4` / `video/iso.segment` for segments) and **CORS** configured for the player's origin when cross-origin (manifest, segments, AND the key/license endpoint all need it, or playback silently fails).
- **Unique IV per segment** for AES-128 / SAMPLE-AES (or the documented `IV = sequence number` convention), and **rotate keys** per content and on a schedule / on entitlement revocation.
- **Server-side decryption is contained:** keys fetched into memory from KMS, segment decrypted to a scratch/in-memory buffer, delivered over an authorized + TLS channel, and the cleartext is **never** persisted to a public bucket or cached on a shared CDN. Re-encrypt for at-rest storage. Wipe scratch on completion/failure.

## Must not

- **No unauthenticated / unauthorized key or license endpoint.** A key URL that returns the AES key to anyone who requests it makes the encryption decorative — this is the #1 streaming bypass. BLOCKER.
- **No key, IV-as-key, or license secret in the manifest, the repo, a public object, a client bundle, or a log line.** Logging the key or the decrypted bytes is a leak.
- **No serving decrypted/cleartext segments from a public bucket or a shared CDN cache** when the server does the decryption. A signed URL to cleartext that a CDN then caches publicly defeats the whole pipeline.
- **No clear-key (EME `org.w3.clearkey`) or "encryption" with a static, shipped, or client-derivable key in production.** That is obfuscation, not protection — document it as unprotected if used for dev only.
- **No trusting the player.** Concurrency limits, geo-blocks, and entitlement are enforced server-side at key/license/manifest time — never only in the player UI.
- **No `200`-for-everything segment server** that ignores `Range` (breaks seek), and no manifest served with a long immutable cache (stale live edge / stale VOD updates).

## Should

- Bind playback to a **session/playback token** (short-lived, viewer- and content-scoped) so manifest → segment → key requests are correlatable and revocable mid-stream.
- Rate-limit + anomaly-watch the key/license endpoint (mass key pulls = ripping). Cross-ref `<rules-path>/rate-limiting`.
- For live: maintain a correct sliding window (`EXT-X-MEDIA-SEQUENCE`, bounded DVR window, `EXT-X-ENDLIST` only on VOD); for LL-HLS, partial segments + blocking playlist reload.
- Prefer DRM (Widevine / PlayReady / FairPlay, CENC `cbcs`) over bare AES-128 when the content's value warrants a CDM-protected key path.

## Review checklist (PRs touching manifests, segment serving, key/license endpoints, or decryption)

- [ ] Every key/license/signed-URL request enforces a per-viewer, per-content entitlement check — cite the authz site at `<path:line>`.
- [ ] Keys/licenses sourced from KMS/secret manager, not code/env/manifest — cite the fetch at `<path:line>`.
- [ ] Range handling: `Accept-Ranges`, `206` + `Content-Range`, `416` on bad range — cite the handler at `<path:line>`.
- [ ] Manifest cache vs segment cache split correctly; key-as-file never long-cached behind a guessable URL.
- [ ] If server-side decrypt: cleartext never hits a public bucket / shared CDN; scratch wiped — cite the delivery + storage at `<path:line>`.
- [ ] No key / decrypted bytes in logs; CORS set for player origin on manifest + segments + key endpoint.
- [ ] Clear-key/static-key only in non-prod, explicitly documented as unprotected.

## Anti-patterns

- **Open key endpoint** — `GET /keys/:id` returns the AES key with no auth/entitlement. Encryption is now decorative; anyone who reads the manifest rips the content.
- **Key in the public bucket** — `EXT-X-KEY:URI="https://cdn.example.com/keys/abc.key"` on a public bucket. Same as above with extra steps.
- **Cleartext on the CDN** — server decrypts, writes the `.ts` to the same public bucket the encrypted ones came from, hands back a "signed" URL the CDN caches publicly. The decrypted asset is now world-readable.
- **Ignored Range** — segment server returns `200` + full body for every request; seek/scrub re-downloads from zero, players stall, bandwidth explodes.
- **Immutable manifest** — `.m3u8` served `max-age=31536000`; the live edge freezes and VOD updates never reach players.
- **Auth-only, not authz** — any logged-in user can pull any title's key because the endpoint checks the session but not the entitlement.
- **Static shipped key** — the same AES key for all content, embedded in the app; one extraction unlocks the whole catalog.
- **Key/bytes in logs** — `logger.debug('decrypting with key', key)` leaks the secret into log aggregation forever.

## Enforcement

- `<commands-path>/audit-streaming-delivery.md` (slash: `/audit-streaming-delivery`) — traces a stream end-to-end from the real code/config: manifest generation + cache, range handling, the key/license endpoint's authz + entitlement check, key source (KMS vs hardcoded), server-side-decrypt cleartext containment, and CORS — cite-or-halt, never an assumed config.
- `<agents-path>/streaming-delivery-reviewer.md` — review gate hard-failing on an unauthorized key/license endpoint, key-in-manifest/repo/log, cleartext-on-public-CDN, clear-key/static-key in prod, ignored `Range`, and immutable-manifest.

## Cross-references

- `<patterns-path>/adaptive-streaming-delivery.md` — manifest + byte-range + ABR + segment cache/CORS + live-vs-VOD code shapes.
- `<patterns-path>/encrypted-segment-delivery.md` — key delivery, entitlement gate, server-side-decrypt containment, key management, and the per-scheme (AES-128 / SAMPLE-AES / CENC-DRM / clear-key) specifics.
- `<rules-path>/media-processing-discipline.md` — owns the transcode/packaging step that PRODUCES these segments (sandbox, magic-byte validation, hardening, EXIF strip, signed delivery).
- `<rules-path>/auth-flow.md` — the entitlement/authorization primitives the key/license gate relies on.
