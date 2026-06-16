---
description: "Pattern: Encrypted-segment delivery & decryption — entitlement-gated key/license delivery, per-scheme specifics (HLS AES-128 / SAMPLE-AES / CENC-DRM / clear-key), server-side-decrypt cleartext containment, and KMS-backed key management"
---

# Pattern: Encrypted-segment delivery & decryption

> **Hard rule** — Encryption only protects content if the **key path is authorized**. Every key/license/playback-token request is gated on a per-viewer entitlement check for *that* content; keys come from a KMS, never from code/manifest/log/public-object; and when the **server** decrypts, the cleartext is ephemeral and never reaches a public bucket or shared CDN. Clear-key or a static shipped key in production is obfuscation, not protection.

## Why

The segments can sit on any CDN — they're ciphertext. The entire security of the system collapses to one question: **who can get the key?** The classic failure isn't weak crypto, it's an open `GET /keys/:id` that hands the AES key to anyone who read the manifest. Encryption then just adds a step to ripping. So this pattern is 10% crypto and 90% **authorization + key custody + cleartext containment**.

## Decision: where does decryption happen?

```
A. Client/player decrypts (preferred for scale)
   server packages encrypted segments + serves an AUTHORIZED key/license endpoint;
   player (hls.js / native CDM) fetches key → decrypts locally. Server never sees cleartext.

B. DRM (Widevine / PlayReady / FairPlay, CENC cbcs/cenc)
   player's CDM requests a license from YOUR license endpoint (authorized);
   CDM decrypts in a secure path. Strongest; the key never leaves the CDM.

C. Server decrypts (ingest-then-reserve)
   server holds keys, decrypts encrypted source segments, re-serves.
   ONLY safe if cleartext is contained (below). Most dangerous to get wrong.
```

Whichever model(s) you run, the **entitlement gate** and **key custody** rules are identical.

## The entitlement gate (the one that actually matters)

```ts
// src/modules/streams/keys/key.controller.ts
// HLS AES-128: the manifest's EXT-X-KEY URI points HERE. This endpoint is the lock.
async function deliverKey(req: Request, res: Response) {
  const viewer  = await authn(req);                                   // 1. authenticated?  (401 if not)
  const { contentId, keyId } = parseSignedKeyToken(req);              // 2. token is signed, content+viewer-scoped, short-lived
  if (!await entitlements.canWatch(viewer.id, contentId)) {           // 3. ENTITLED to THIS title? (sub active / purchased / geo / age)
    return res.status(403).end();                                     //    auth ≠ authz — this check is the whole point
  }
  await keyAccessLog.record(viewer.id, contentId, keyId, req.ip);     // 4. audited (mass pulls = ripping signal)
  const key = await kms.decryptDataKey(keyId, { contentId });         // 5. key from KMS, scoped, NEVER from code/manifest
  res.setHeader('Cache-Control', 'no-store');                         // 6. never cache a key response
  res.setHeader('Content-Type', 'application/octet-stream');
  return res.end(key);                                                // 16 raw bytes for AES-128, over TLS only
}
```

The manifest references it — note the key URI is an **endpoint**, not a bucket object:

```m3u8
#EXT-X-KEY:METHOD=AES-128,URI="https://api.example.com/v/streams/key?kt=<signed-token>",IV=0x<unique-per-segment-or-sequence>
#EXTINF:6.006,
seg-00000.ts
```

## Per-scheme specifics

- **HLS AES-128** — full-segment AES-128-CBC. `EXT-X-KEY:METHOD=AES-128,URI=...,IV=...`. IV unique per key (or `IV = media sequence` convention). Key = 16 bytes from KMS. Simplest; key endpoint authz is everything.
- **SAMPLE-AES** — sample-level AES (audio/video samples encrypted, container intact). `METHOD=SAMPLE-AES`. The Apple path toward **FairPlay** (`METHOD=SAMPLE-AES-CTR` + `com.apple.fps` key format → license, not raw key).
- **CENC (DASH/CMAF)** — Common Encryption (`cenc` AES-CTR or `cbcs` AES-CBC) in the `.mpd` `<ContentProtection>`; one ciphertext, multiple DRMs. Player CDM requests a license from your **license server** (Widevine/PlayReady/FairPlay), which runs the SAME entitlement gate before issuing. The content key is wrapped for the CDM; it never appears in cleartext server-side.
- **Clear-key / custom** — EME `org.w3.clearkey` or a homegrown scheme. **Dev/test only.** A static or client-derivable key is unprotected; document it as such and never ship it as "DRM".

## Server-side decryption containment (model C)

```ts
// src/modules/streams/decrypt/segment-decrypt.service.ts
// Used when the server ingests ENCRYPTED source and must decrypt before (re)serving.
async function serveDecryptedSegment(viewer, contentId, segRef, res) {
  if (!await entitlements.canWatch(viewer.id, contentId)) return res.status(403).end(); // same gate

  const key       = await kms.decryptDataKey(segRef.keyId, { contentId });  // ephemeral, in memory
  const cipher    = await privateOrigin.readToBuffer(segRef);               // ciphertext from PRIVATE store
  const cleartext = aes.decrypt(cipher, key, segRef.iv);                    // in-memory buffer

  res.setHeader('Cache-Control', 'private, no-store');                      // NEVER shared-CDN-cache cleartext
  res.setHeader('Content-Type', 'video/mp2t');
  res.end(cleartext);                                                       // over authorized + TLS channel only
  // do NOT write cleartext to the public bucket; if persisting, RE-ENCRYPT at rest.
  wipe(key); wipe(cleartext);                                               // best-effort scrub scratch/buffers
}
```

Containment rules for model C: cleartext is **ephemeral** (memory/scratch, wiped); served only over an **authorized + TLS** channel with `private, no-store`; **never** written to a public bucket or cached on a shared CDN; if cached at all, only in a per-viewer private cache; **re-encrypt** for any at-rest copy.

## Key management

- Keys + license secrets in **KMS / Vault / secret manager**, fetched at request time, **scoped per content** (and per tenant where multi-tenant). Never in code, env-in-repo, the manifest, or a log.
- **Rotate** keys per content + on a schedule + immediately on entitlement revocation / suspected leak.
- Key responses `no-store`; key files (if any) only behind signed, short-lived, unguessable URLs — never a public/long-cache object.
- **Audit** every key/license issue (viewer, content, ip, time); **rate-limit** + anomaly-watch (a viewer pulling every key in the catalog is ripping).
- Bind to a **playback session token** so manifest → segment → key are correlatable and revocable mid-stream.

## Common mistakes

### Open key endpoint
`GET /keys/:id` returns the key with no authn/authz. The single most common total bypass — encryption becomes decorative. Fix: the entitlement gate above.

### Auth without entitlement
Endpoint checks the session but not whether the viewer may watch *this* title → any logged-in user pulls any key. Fix: `entitlements.canWatch(viewer, content)`.

### Key in the manifest / repo / log / public bucket
`URI="https://cdn/keys/abc.key"` on a public bucket, a key committed to the repo, or `logger.debug('key', key)`. Any of these = the key is public. Fix: KMS + authorized endpoint + no-log.

### Cleartext on the CDN (model C)
Server decrypts, writes the `.ts` back to the same public bucket, returns a "signed" URL the CDN caches publicly → the decrypted asset is world-readable. Fix: `private, no-store`, never a public/shared cache, re-encrypt at rest.

### Clear-key / static key in prod
One shipped key for the whole catalog, or `org.w3.clearkey` with the key in the page → one extraction unlocks everything. Fix: real per-content keys via an authorized endpoint, or DRM.

### Reused / predictable IV
Same IV across segments under one key weakens CBC. Fix: unique IV per segment (or the documented sequence-number convention).

### No revocation / rotation
A leaked key is valid forever; a cancelled subscriber keeps watching. Fix: session-bound tokens, key rotation, revocation on entitlement change.

## Cross-references
- `<patterns-path>/adaptive-streaming-delivery.md` — the manifest/segment/byte-range delivery this encryption layers onto (incl. CORS on the key endpoint).
- `<rules-path>/streaming-delivery-discipline.md` — the must/must-not enforced here.
- `<rules-path>/auth-flow.md` — the entitlement/authorization primitives the key gate calls.
- `<rules-path>/media-processing-discipline.md` — the packaging/encryption step (during transcode) that produced these encrypted segments.
