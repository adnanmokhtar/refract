---
name: realtime-client
kind: example
pack: frontend
---

# Pattern: Realtime Client

> **Hard rule:** A realtime connection has an explicit lifecycle — connect, authenticate the handshake, heartbeat, reconnect-with-backoff, teardown-on-unmount — and every inbound message is deduped by id/sequence and reconciled into the cache. A bare `new WebSocket(url)` with no reconnection, no cleanup on unmount, and no dedup is forbidden. Cite the socket site at `<file:line>` + the missing lifecycle stage + the fix.

This is the **client** side (browser consuming a server→client stream). The **server→server** complement (inbound signature verification, outbound signed delivery, retry/DLQ) is owned by backend `webhook-flow` — state that boundary, don't re-implement it here.

## Transport, reconnect, auth, backpressure

- **Transport** — WebSocket (bidirectional, YOU build reconnect); SSE/`EventSource` (server→client only, browser auto-reconnects + `Last-Event-ID` resume); long-poll (last-resort fallback). Cite the requirement, not a default. SSE is the cheaper default when the client never pushes.
- **Reconnect** — exponential backoff + **jitter** + cap (`delay = min(cap, base * 2^attempt) + jitter`); never a tight `onclose→connect()` loop. Reset the attempt counter only after open *and authenticated*.
- **Heartbeat** — app-level ping/pong on an interval to detect a half-open connection (TCP holds it "open" after the peer is gone); on miss, trigger reconnect. A WebSocket needs this explicitly.
- **Auth** — token in the handshake (subprotocol / `wss://` query param / cookie), never as the first data frame; **re-auth on reconnect** (refresh the token before each attempt) or an expired token silently fails to reconnect and the UI just stops updating.
- **Backpressure** — coalesce (last-write-wins per key), throttle/batch on rAF (one render per frame, not per message), drop-oldest on a bounded queue.

## At-least-once → dedup; reconcile into the cache

Delivery is at-least-once (replay, retry, overlapping subs): every message carries a stable `id`/`sequence`, dedup against a seen-set/high-water-mark before any non-idempotent side effect. A live update must **patch or invalidate the cached query** (`setQueryData` / `invalidateQueries`), not write a parallel local state that drifts from the next refetch. Teardown on unmount: every socket/subscription has a matching close in the cleanup path or it leaks + double-opens on re-mount.

## Adapt to the codebase

Mirror whatever the project uses; the column that matters is who owns reconnect + replay.

| Primitive | Auto-reconnect? | Resume | Notes |
|---|---|---|---|
| Native `WebSocket` | No — you build backoff+heartbeat | No — track sequence | you own dedup + reconcile |
| **Socket.IO** | Yes (built-in) | rooms + acks; offline buffer | still dedup app events + re-auth |
| **SSE** `EventSource` | Yes (browser) | Yes — `Last-Event-ID` | server→client only |
| **Hosted** (Pusher/Ably/Supabase) | Yes (SDK) | varies (Ably rewind) | token endpoint; don't re-wrap |
| Framework hooks (`useWebSocket`) | opt-in | No — track sequence | you configure backoff + own dedup |

## Detectors (cite-or-halt)

**Detectors 1, 3 and 4 do not fire when the SDK owns that stage.** On a hosted SDK (Pusher / Ably / Supabase Realtime) or Socket.IO, backoff, heartbeat and handshake re-auth live in the SDK — the greps come back empty *because the code is correct*. Identify the primitive first and `dismiss` each of the three with the SDK's own mechanism cited. Detectors 2 and 5 (teardown, dedup) fire on every primitive.

1. **Bare connection, no reconnection** — `new WebSocket(url)` with only `onmessage`.
2. **No teardown on unmount (leak)** — no `.close()`/cleanup in scope.
3. **No heartbeat → undetected half-open** — long-lived socket with no ping/pong.
4. **No re-auth on reconnect** — replays a token captured once at mount → silent expired-token failure.
5. **Inbound handler with no dedup** — appends/increments/toasts with no id check → double side effects.

Closure verbs (exactly one per finding): `report-with-fix`, `dismiss` (a stage the detected primitive already owns), `halt-handoff`, `halt-missing-cite`.

## Related

- `data-fetching.md` — cache reconciliation target; a live event patches/invalidates the queries it owns.
- backend `webhook-flow` — the server→server complement; the boundary this pattern states.
- `idempotency` — at-least-once dedup contract this mirrors on the client (by message id/sequence).
- performance `inp-responsiveness` — render-cost side of coalescing/throttling high-frequency updates.
- `@data-flow-auditor` — reviews the state/cache reconciliation an inbound stream writes into.
