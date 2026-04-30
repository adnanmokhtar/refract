---
name: realtime-discipline
description: Real-time discipline
kind: rule
---

# Real-time discipline

## Hard rule

Every socket MUST authenticate on `connect` BEFORE accepting any message, MUST have its channel ACL re-checked on every emit (not only on subscribe), MUST have a bounded outbound buffer + heartbeat, and MUST NOT carry a long-lived JWT in a URL query string. Global `io.emit()` is FORBIDDEN outside admin-broadcast paths; cross-tenant subscribe / broadcast is FORBIDDEN.

Long-lived connections concentrate every distributed-systems failure mode into one process: auth, fanout, ordering, backpressure, reconnect. Rules below are non-negotiable.

## Connection auth

- Authentication on `connect`, BEFORE the socket can send any message.
- Token via `Authorization` header on the connection request, OR a short-lived (≤ 30s) ticket fetched from a separate HTTP endpoint and exchanged on connect.
- NEVER long-lived JWT in the URL query string — leaks via referrer, browser history, server / proxy / CDN logs.
- Identity attached to socket session (`socket.data = { tenantId, userId, scopes }`); used on every later check.
- Disconnect immediately on auth fail; log with source IP.

## Channel / room scoping

- Channel names encode scope: `tenant:<tenantId>:user:<userId>:notifications`.
- Subscribe handler VERIFIES the requesting socket has access to the channel; does NOT trust the channel name to grant scope.
- Wildcard subscriptions (`tenant:*`) FORBIDDEN unless the socket is admin-scoped.
- ACL re-checked on every emit, not just on subscribe (long-lived connections persist after permission revokes).

## Cross-tenant safety

- Global `io.emit()` FORBIDDEN outside admin-broadcast paths. Default to `io.to(scope).emit()`.
- Cross-tenant broadcast = the worst kind of leak — affects every connected user simultaneously.
- "Presence" data (who else is online) limited to channel members; never returned for channels the requester can't subscribe to.

## Backpressure

- Per-client outbound buffer bounded. Defaults: 1 MB or 1k messages.
- Exceed → either drop oldest with metric, or disconnect with `slow_consumer` reason.
- Server reports per-client buffer depth; alert when sustained > threshold (worker stuck or client gone silent).
- High-rate streams use server-side coalescing (drop intermediate updates if client is behind).
- NEVER an unbounded queue — slow client = memory leak + cascading impact across the process.

## Heartbeat

- Server sends `ping` every 25-30s; client replies `pong`.
- Server terminates connections that miss N consecutive pongs.
- NAT / proxy idle-kill (60-300s without traffic) is the most common silent failure — without heartbeat, both sides think the connection is open until the next message bounces.

## Reconnect

- Client implements exponential backoff with jitter. `delay = min(maxDelay, base * 2^attempts) + random(0, base)`.
- Cap reconnect attempts (e.g. 10 in the first minute) then back off to long interval (60s+); never give up entirely.
- Server identifies reconnects via session-resume token; replays missed messages from a per-session buffer.
- Per-session buffer bounded (e.g. last 100 messages or last 60s); replay best-effort beyond.

## Message ordering

- ALWAYS document explicitly: "ordered per channel" OR "best-effort, app must dedupe + idempotency-check".
- Across-fanout-bus order is NOT free — Redis pub/sub does not guarantee order across channels; multiple emit-from-multiple-nodes is racey.
- Where ordering is guaranteed: per-channel sequence numbers, single connection per (user, channel), client tracks last-seen seq, server replays from that seq on reconnect.
- App code never assumes ordering unless docs explicitly claim it.

## Multi-node fanout

- In-process `EventEmitter` is single-node ONLY. In a fleet, events published on node A do not reach clients connected to node B.
- Use Redis pub/sub adapter (Socket.IO `@socket.io/redis-adapter`), Kafka, NATS, OR managed (Pusher / Ably / Soketi).
- Sticky sessions required for Socket.IO long-poll fallback; not required for pure WebSocket if state is session-resumable.
- Test fanout with `/test-realtime --fanout` on a multi-pod deploy.

## Resource limits

- Max connections per IP (default: 100) — defends against DoS.
- Max connections per user (default: 5) — one user opening 10k tabs.
- Max channels subscribed per connection (default: 50) — prevents subscribe-bomb.
- Process reports concurrent connection count; alert on spike.

## Graceful shutdown

- On SIGTERM: stop accepting new connections, drain existing for N seconds (e.g. 30s), send `going_away` close frame, then terminate.
- Client treats `going_away` (code 1001) as "expected, reconnect with normal backoff".
- Avoid mass disconnect storm at deploy time by rolling deploys with longer drain.

## Observability

- Counters: connections opened / closed (with reason), messages sent / received, dropped messages.
- Histograms: per-message latency from emit-server to ack-client.
- Per-tenant metrics: connections, fanout volume, channel-subscription depth.
- Alerts: connection-drop spike, fanout-lag (Redis pub/sub backlog), slow-consumer count spike.

## Forbidden

- Long-lived JWT in URL query string for auth.
- Subscribe handler without explicit ACL check.
- Global `io.emit()` from feature code.
- In-process fanout in multi-node deploy.
- Unbounded outbound queue per client.
- Connection without heartbeat.
- Tight reconnect loop (no backoff).
- Documented ordering claim not enforced by code.
- Cross-tenant subscribe / broadcast.
- Persisting raw message payloads to log without redaction.
- Holding DB transactions or external HTTP across socket lifetime.

## Enforcement

- `/realtime-audit` command — greps for `io.emit(` outside admin paths, subscribe handlers without ACL checks, JWT-in-URL patterns, unbounded queues, missing heartbeat config.
- `/test-realtime --fanout` MUST run in CI on multi-pod deploy configs to prove the Redis / Kafka adapter is wired.
- CI lint MUST reject `EventEmitter`-based fanout in any file that also imports the socket library.
- TODO: `scripts/validate-realtime-config.sh` to assert connection auth middleware, heartbeat interval, per-IP/per-user/per-channel caps, and adapter selection are explicit in the socket bootstrap file.
