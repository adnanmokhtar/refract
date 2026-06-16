---
description: "Pattern: Adaptive streaming delivery (HLS/DASH manifests, byte-range/206 segment serving, ABR ladder, live vs VOD, correct cache + CORS, signed delivery)"
---

# Pattern: Adaptive streaming delivery

> **Hard rule** — A stream is delivered as a SHORT-cache manifest pointing at IMMUTABLE long-cache segments; segment/file responses honor `Range` exactly (`Accept-Ranges: bytes` → `206 Partial Content` + `Content-Range`, `416` on a bad range); each artifact carries its correct `Content-Type`; CORS is set for the player's origin on the manifest AND the segments AND the key/license endpoint; and delivery URLs are signed/short-lived from a private origin, never public-guessable. Live and VOD differ in exactly one place: the live media playlist is a bounded sliding window with no `EXT-X-ENDLIST`.

## Why

Players (hls.js, Shaka, AVPlayer, ExoPlayer) are unforgiving about three things: a manifest that lies about its segments, a server that won't do range requests (seek/scrub dies, bandwidth explodes), and missing CORS on cross-origin playback (silent failure with a useless error). Get the manifest + range + CORS contract right and almost every player "just works"; get any one wrong and it fails in a way that looks like a player bug.

## The spine

```
client GET master.m3u8 (short-cache, CORS)        ← lists the ABR variants
  -> GET media.m3u8 for chosen rung (short-cache)  ← lists segments (+ EXT-X-KEY if encrypted)
     -> GET segment.ts/.m4s  (Range -> 206, immutable long-cache, signed)
        -> [if encrypted] GET key/license (authorized — see encrypted-segment-delivery.md)
```

## HLS manifests (master + media)

```m3u8
# master.m3u8 — the ABR ladder. One EXT-X-STREAM-INF per rung.
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-STREAM-INF:BANDWIDTH=628000,RESOLUTION=640x360,CODECS="avc1.4d401e,mp4a.40.2"
360p/media.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1828000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2"
720p/media.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3528000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2"
1080p/media.m3u8
```

```m3u8
# media.m3u8 (VOD) — EXACT segment durations; ENDLIST present.
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:6                  # ceil of the LONGEST segment; players reject if a segment exceeds it
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:VOD
#EXTINF:6.006,
seg-00000.ts
#EXTINF:6.006,
seg-00001.ts
#EXT-X-ENDLIST                            # VOD only — its ABSENCE is what makes a playlist "live"
```

```m3u8
# media.m3u8 (LIVE) — sliding window, NO ENDLIST, MEDIA-SEQUENCE advances each reload.
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:4
#EXT-X-MEDIA-SEQUENCE:1487                # increments as old segments roll off the window
#EXTINF:4.000,
seg-01487.ts
#EXTINF:4.000,
seg-01488.ts
#EXTINF:4.000,
seg-01489.ts
# (no EXT-X-ENDLIST) — bounded DVR window of N segments; oldest drops as new ones append
```

DASH is the same idea in XML (`.mpd`): `<MPD type="static">` (VOD) vs `type="dynamic"` (live) with `availabilityStartTime` + `timeShiftBufferDepth`; `<Representation bandwidth=... codecs=...>` per rung.

## Byte-range / 206 segment server (the part most people get wrong)

```ts
// src/modules/streams/delivery/segment.controller.ts
async function serveSegment(req: Request, res: Response) {
  const { size, contentType, read } = await locateSegment(req.params);  // private origin; signed-URL already verified by middleware

  res.setHeader('Accept-Ranges', 'bytes');
  res.setHeader('Content-Type', contentType);                            // video/mp2t | video/mp4 | video/iso.segment
  res.setHeader('Cache-Control', 'public, max-age=31536000, immutable'); // segments never change; safe ONLY because the URL is signed/unguessable

  const range = req.headers.range;
  if (!range) {
    res.setHeader('Content-Length', String(size));
    return streamFull(res, read);                                        // 200
  }

  const m = /^bytes=(\d*)-(\d*)$/.exec(range);
  let start = m?.[1] ? parseInt(m[1], 10) : 0;
  let end   = m?.[2] ? parseInt(m[2], 10) : size - 1;
  if (!m || start > end || end >= size) {
    res.setHeader('Content-Range', `bytes */${size}`);
    return res.status(416).end();                                        // Range Not Satisfiable
  }

  res.status(206);                                                       // Partial Content
  res.setHeader('Content-Range', `bytes ${start}-${end}/${size}`);
  res.setHeader('Content-Length', String(end - start + 1));
  return streamRange(res, read, start, end);
}
```

> Note: most production stacks let a CDN / object store (S3 + CloudFront, etc.) do range serving natively — then you don't hand-roll the above, but the **cache split**, **signing**, and **CORS** below still apply, and you still verify the origin honors `Range`.

## Cache + CORS contract

```ts
// Manifests CHANGE (live edge, VOD updates) → short/no cache.
manifestRes.setHeader('Cache-Control', 'no-cache');                      // live
// or for VOD that can change: 'public, max-age=10'

// Segments / init segments are immutable → long cache (URL must be signed/unguessable).
segmentRes.setHeader('Cache-Control', 'public, max-age=31536000, immutable');

// CORS for a cross-origin player — REQUIRED on manifest, segments, AND key/license endpoint.
res.setHeader('Access-Control-Allow-Origin', allowedPlayerOrigin);
res.setHeader('Access-Control-Allow-Headers', 'Range, Authorization');
res.setHeader('Access-Control-Expose-Headers', 'Content-Range, Accept-Ranges, Content-Length');
```

## Signed, private delivery

```ts
// Origin is PRIVATE; the player gets short-lived signed URLs (CDN signed URL/cookie or app-signed).
// One signed playback session → manifest + its segments authorized together; revocable.
const manifestUrl = signer.sign(`/v/${assetId}/master.m3u8`, { expiresIn: '5m', session: playbackToken });
```

## Common mistakes

### Segment server ignores Range
Returns `200` + full body for every request. Seeking re-downloads from byte 0, players stall mid-scrub, egress balloons. Fix: the `206`/`Content-Range`/`416` handler above (or a range-capable CDN/origin).

### Manifest cached as immutable
`.m3u8` served `max-age=31536000` → live edge freezes; VOD never updates. Fix: manifests are `no-cache` (live) / short max-age (VOD); only segments are immutable.

### `EXT-X-ENDLIST` on a live playlist (or missing on VOD)
Present on live → player thinks the stream ended. Missing on VOD → player waits forever for more segments. Fix: `ENDLIST` ⇔ VOD only.

### TARGETDURATION too small
A segment's `EXTINF` exceeds `EXT-X-TARGETDURATION` → spec violation, players reject. Fix: `TARGETDURATION = ceil(max segment duration)`.

### Missing CORS on the key endpoint
Manifest + segments have CORS, the key/license endpoint doesn't → playback fails ONLY for encrypted streams, cross-origin, with an opaque error. Fix: CORS on the key/license endpoint too.

### Public, guessable segment URLs
Immutable long-cache on `/<asset>/seg-00001.ts` with no signing → the whole asset is enumerable and rippable. Fix: signed/unguessable URLs from a private origin (and for encrypted content, see the encrypted pattern).

### Wrong Content-Type
`.m3u8` served as `text/plain`, segments as `application/octet-stream` → some players/CDNs misbehave. Fix: correct MIME per artifact.

## Cross-references
- `<patterns-path>/encrypted-segment-delivery.md` — when segments are encrypted: `EXT-X-KEY`, the authorized key/license endpoint, server-side-decrypt containment, key management.
- `<rules-path>/streaming-delivery-discipline.md` — the must/must-not this pattern implements.
- `<rules-path>/media-processing-discipline.md` — the transcode/packaging step that produces these segments.
- `<patterns-path>/media-pipeline.md` — sandboxed-async-transcode + signed-delivery spine shared with this domain.
