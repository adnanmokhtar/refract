---
name: realtime-client
description: "Pattern: consuming a live server stream (WebSocket / SSE / push) on the client — connection lifecycle, reconnect-with-backoff, handshake auth + re-auth, heartbeat, backpressure/coalescing, at-least-once dedup, and reconciling live events into the query cache. The client complement to backend webhook-flow."
kind: ai-pattern
pack: frontend
---

# Pattern: Realtime Client

> **Hard rule:** A realtime connection has an explicit lifecycle — connect, authenticate the handshake, heartbeat, reconnect-with-backoff, and teardown-on-unmount — and every inbound message is deduped by id/sequence and reconciled into the cache. A bare `new WebSocket(url)` with no reconnection, no cleanup on unmount, and no dedup is forbidden. Cite the socket construction site at `<file:line>` + the missing lifecycle stage + the fix, or it is not a finding — a claim without a citation is a vibe, not a finding.

This is the **client** side: browser/app consuming a live server→client stream. The **server→server** complement (inbound signature verification, outbound signed delivery, retry/DLQ) is owned by the backend `webhook-flow` pattern — state that boundary and do not re-implement server delivery mechanics here.

**When to apply**
- The UI must reflect server-pushed changes with sub-second latency the user would notice if stale (presence, live prices/scores, collaborative cursors, chat, notifications, job-progress).
- A previously-polled surface now needs bidirectional or high-frequency updates and polling's latency/cost no longer fits.
- Adding any long-lived socket/`EventSource` — its lifecycle and cache reconciliation must be designed, not left to a bare constructor.

**When NOT to apply**
- Data that a polling / `stale-while-revalidate` refetch handles fine — realtime is a standing cost (an open connection per client, reconnect logic, dedup, backpressure). Prefer refetch until latency actually matters.
- One-shot request/response (form submit, load-once detail). That is data-fetching's job, not a stream.
- Low-frequency background updates where a visibility-triggered refetch is simpler and cheaper.

**Halt conditions / mandatory cites**
- The transport choice (WebSocket vs SSE vs long-poll) MUST cite the requirement it satisfies (bidirectional? server→client only? proxy/firewall constraints?) — not a default.
- Any reconnection claim MUST cite the backoff+jitter+cap code at `<file:line>`; "it reconnects" without the schedule is a bug.
- Any auth claim MUST cite where the token enters the handshake AND where it is refreshed on reconnect; an expired token that silently fails to reconnect is a defect.
- A live-update handler MUST cite the dedup key (id/sequence) and the cache reconcile call, or it is unshippable.
- Hand-wave grep on `etc.`, `...`, `should reconnect`, `probably deduped` is forbidden — re-enumerate each handler.
- If the project already has a realtime primitive (Socket.IO client, a `useWebSocket` composable/hook, a hosted SDK), mirror it. Never introduce a second mechanism.

## Transport choice

| Transport | Direction | Auto-reconnect | Use when |
|---|---|---|---|
| **WebSocket** | bidirectional | NO (you build it) | Client must also send (chat, collab, presence), or binary frames |
| **SSE** (`EventSource`) | server→client only | YES (built-in) + `Last-Event-ID` resume | One-way push (feeds, notifications, progress); simpler, HTTP/1.1-friendly |
| **Long-poll** | request/response loop | N/A (re-request) | Fallback where WS/SSE are blocked by a proxy; last resort |

SSE is the cheaper default when the client never needs to push — the browser reconnects and replays from `Last-Event-ID` for free. Reach for WebSocket only when you genuinely need the upstream channel.

## Reconnection — exponential backoff + jitter + cap

A dropped connection is the normal case, not the exception (sleep/wake, network switch, server redeploy, load-balancer idle-timeout). Reconnect on an **exponential backoff with jitter and a cap** — never a tight `onclose → connect()` loop (that DDoSes your own server on an outage and burns the client's battery).

```
delay = min(cap, base * 2^attempt) + random_jitter   // e.g. base 500ms, cap 30s
```

Jitter is not optional: without it, every client that dropped at the same instant (a server restart) reconnects in lockstep — a thundering herd. Reset the attempt counter only after the connection is confirmed *open and authenticated*, not merely `onopen`.

## Heartbeat / ping-pong (detect the half-open connection)

TCP can hold a socket "open" long after the peer is gone (NAT timeout, silent server death) — a **half-open** connection that delivers nothing and fires no `onclose`. Send an app-level ping on an interval and expect a pong within a timeout; on miss, treat the socket as dead and trigger the reconnect path. SSE has this partly covered (the browser notices a dead stream), but a WebSocket needs an explicit heartbeat or it silently goes stale.

## Auth — handshake AND re-auth on reconnect

- **Handshake auth**: pass the token in the connection (a `Sec-WebSocket-Protocol`/subprotocol value, a query param over `wss://`, or a cookie for same-origin; SSE rides the cookie or an `Authorization`-bearing fetch wrapper). Never send credentials as the first *data* frame after an unauthenticated open — the socket is exposed in that window.
- **Re-auth on reconnect** is the silent killer: a long-lived session's token expires, the socket drops hours later, and the reconnect replays the *old* expired token → the handshake fails quietly and the UI just stops updating with no error. Refresh the token before each reconnect attempt, and surface auth-failure distinctly from transport-failure so the UI can prompt re-login rather than spin forever.

## Backpressure — the client can't outrun a fast stream

A high-frequency stream (order book, cursor moves, telemetry) can arrive faster than the UI can render. An unbounded inbound buffer OOMs; a render-per-message loop janks the main thread and tanks INP. Apply backpressure on the client:

- **Coalesce** — keep only the latest value per key (last-write-wins for a price/position); drop superseded frames.
- **Throttle / batch** — flush accumulated updates on `requestAnimationFrame` or a fixed interval, not per-message. One render per frame, not per event.
- **Drop-oldest** on a bounded queue when you genuinely can't keep up — a bounded, lossy buffer beats an unbounded one that crashes the tab.

The render-cost side of this (why per-message renders wreck interaction latency) is owned by the performance `inp-responsiveness` pattern; the general producer-faster-than-consumer discipline by distributed-systems `backpressure`. This pattern owns *where* on the client the coalescing happens.

## At-least-once → dedup by id/sequence

Realtime delivery is **at-least-once**: a reconnect with replay (`Last-Event-ID`), a server retry, or overlapping subscriptions all deliver the same event twice. A handler with a non-idempotent side effect (increment a count, append a row, fire a toast) double-fires. Every inbound message carries a stable `id` or monotonic `sequence`; dedup against a seen-set / high-water-mark before acting. This is the client mirror of the backend `idempotency` contract (same reason: at-least-once transport).

## Reconcile live events into the query cache — don't fight it

A live update must **patch or invalidate the cached query**, not write to a parallel local state that then drifts from the next refetch. Two correct shapes:

- **Patch**: apply the event to the cached entity in place (e.g. `queryClient.setQueryData` / update the store the query hydrates) — instant, no network.
- **Invalidate**: mark the query stale so the next read refetches authoritative state — safer when the event only signals "something changed."

Optimistic local echo (show the user's own sent message immediately) must be reconciled against the server's confirmation frame — replace the optimistic entry keyed by the same client id, don't append a duplicate. If a socket update and a refetch write different shapes to the same key, the UI flickers between them: that is drift, and it is a bug. Cache reconciliation contracts live in `data-fetching`.

## Teardown on unmount

A socket opened in a component/route that isn't closed when that scope unmounts is a leak: the connection lingers, its listeners retain the old component, and a re-mount opens a *second* socket. Every `new WebSocket` / `new EventSource` / subscription MUST have a matching close + listener-removal in the unmount/cleanup path (effect cleanup, `onUnmounted`, `ngOnDestroy`, `AbortController.abort()`). Reference-count a shared singleton connection so the last consumer closes it.

## Offline / degraded UX

- **Connection-status indicator** — reflect connecting / live / reconnecting / offline so the user knows whether they're seeing live or stale data. Silent staleness erodes trust.
- **Queue-and-flush** — buffer user actions taken while disconnected and replay them on reconnect (deduped by client id so a reconnect mid-send doesn't double-apply).
- **The two-generals reality** — a message you sent is not a message that arrived. Never treat `socket.send()` as confirmation. Require a server ack (or reconcile against the next authoritative state) before showing an action as committed; otherwise a drop between send and delivery leaves the UI lying.

## Adapt to the codebase

Mirror whatever the project already uses; the column that matters is who owns reconnect and replay so you don't double-implement it.

| Primitive | Auto-reconnect? | Resume / replay? | Notes |
|---|---|---|---|
| Native `WebSocket` | NO — you build backoff+heartbeat | NO — you track sequence | `reconnecting-websocket` wraps reconnect; you still own dedup + reconcile |
| **Socket.IO** client | YES (built-in backoff) | Rooms + optional ack callbacks; buffers while offline | Heartbeat + reconnect handled; still dedup app events + re-auth in `auth` handshake |
| **SSE** `EventSource` | YES (browser) | YES — `Last-Event-ID` header on reconnect | Server→client only; needs a fetch-based polyfill to send auth headers |
| **Hosted** (Pusher / Ably / Supabase Realtime) | YES (SDK) | Varies — Ably has history/rewind; check the SDK | Auth via a token endpoint; reconnect+presence in-SDK — do not re-wrap |
| Framework hooks (VueUse `useWebSocket` / `useEventSource`, `react-use-websocket`) | Opt-in (`autoReconnect`, heartbeat opts) | NO — you track sequence | Handles lifecycle+cleanup; you configure backoff and own dedup+reconcile |
| Query-lib live integration (TanStack Query + subscription) | Depends on transport | Via cache | Wire the stream to `setQueryData` / `invalidateQueries` — the reconcile path is first-class |

## Detectors (cite-or-halt)

Each detector: BAD/GOOD + a grep. Cite `<file:line>` + the fix or it is not a finding.

**Detectors 1, 3 and 4 do not fire when the SDK owns that stage.** The Adapt table's whole point is the reconnect/replay ownership column, and on a hosted SDK (Pusher / Ably / Supabase Realtime) or Socket.IO the backoff, the heartbeat and the handshake re-auth are *in the SDK* — greps for `new WebSocket`, `ping`, and a token in an `onclose` path all come back empty **because the code is correct**. Emitting three findings there tells the developer to re-wrap a client the Adapt table explicitly says not to re-wrap, and it is the fastest way to make this pattern's output ignorable. Before running 1/3/4: identify the primitive, and for each of the three, `dismiss` with the SDK's own mechanism cited (`Ably SDK owns reconnect + rewind — connection.on('disconnected') is the SDK's, not a gap`). Detectors 2, 5, 6 and 7 fire on every primitive: teardown, dedup, backpressure and cache reconciliation are the application's job no matter who owns the socket.

1. **Bare connection, no reconnection.** BAD: `const ws = new WebSocket(url)` with only `ws.onmessage`. GOOD: a wrapper/hook with backoff+jitter+cap on `onclose`. Grep: `rg -n "new (WebSocket|EventSource)\(" ` then check each for a reconnect path.
2. **No teardown on unmount (leak).** BAD: a socket opened in a component with no `.close()` / cleanup. GOOD: matching close in the cleanup path. Grep: `rg -n "new WebSocket"` and confirm a nearby `.close()` / `removeEventListener` / `abort()` in the same scope.
3. **No heartbeat → undetected half-open.** BAD: a long-lived WebSocket with no ping/pong. GOOD: interval ping + pong-timeout → reconnect. Grep: `rg -n "new WebSocket" -A20 | rg -i "ping|heartbeat|pong"` (absence is the smell).
4. **No re-auth on reconnect.** BAD: reconnect replays a captured token/URL built once at mount. GOOD: token refreshed before each reconnect attempt. Grep: `rg -n "reconnect|onclose" -A10 | rg -i "token|auth"` (absence = expired-token silent failure).
5. **Inbound handler with no dedup.** BAD: `onmessage` appends/increments/toasts with no id check. GOOD: dedup by `msg.id` / `sequence` against a seen-set/high-water-mark before the side effect. Grep: `rg -n "onmessage|addEventListener\('message'" -A10 | rg -i "id|seq|dedup"` (absence under at-least-once = double side effects).
6. **Unbounded / un-throttled high-frequency update (render storm).** BAD: `setState` / store-write per message on a fast stream. GOOD: coalesce-by-key + flush on rAF/interval; bounded drop-oldest queue. Grep: `rg -n "onmessage" -A6 | rg -i "setState|\.value =|dispatch"` on high-rate streams — cross-ref `inp-responsiveness`.
7. **Live update mutates local state, ignores the query cache.** BAD: `onmessage` writes to a parallel `useState`/local store while a query owns the same entity → drift with the next refetch. GOOD: `setQueryData` / `invalidateQueries` (or the store the query hydrates). Grep: find `onmessage` handlers writing state near a query key for the same entity — cross-ref `data-fetching`.

## Closure verbs

- `report-with-fix` — cited defect + the fix routed through the project's existing realtime primitive.
- `halt-handoff` — server-side delivery/verification defect → hand to backend `webhook-flow`; render-cost defect → `inp-responsiveness`; producer/consumer rate mismatch → `backpressure`.
- `dismiss` — a lifecycle stage the detected primitive already owns (SDK reconnect / heartbeat / handshake re-auth per the Adapt table), or a deliberate bare-socket in a throwaway/dev-only surface. Cite the owning mechanism so the next scan does not re-flag it. Without this verb the three SDK-owned detectors fire on every correct hosted-SDK app.
- `halt-missing-cite` — refuse any lifecycle/dedup/reconcile claim that lacks `<file:line>`.

## Related

- `data-fetching` — cache reconciliation target; a live event patches/invalidates the queries this pattern owns.
- `auth-session-client` — owns the session transition that this pattern's handshake re-auth reacts to: after a silent refresh the socket re-authenticates, on logout it closes. That pattern owns the session, this one owns the connection.
- `rendering-strategy` — a route's initial-render choice; realtime layers on top of the hydrated view.
- backend `webhook-flow` — the server→server complement (inbound verification, outbound signed delivery); the boundary this pattern states.
- `idempotency` — at-least-once dedup contract this mirrors on the client (by message id/sequence).
- distributed-systems `backpressure` — producer-faster-than-consumer discipline; this pattern applies it at the client render boundary.
- performance `inp-responsiveness` — the render-cost side of coalescing/throttling high-frequency updates.
- `@data-flow-auditor` — reviews the state/cache reconciliation an inbound stream writes into.
