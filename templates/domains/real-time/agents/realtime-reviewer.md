---
name: realtime-reviewer
description: Reviews every change to WebSocket / SSE / WebRTC / long-poll code. Catches missing connection auth, cross-tenant fanout, no backpressure (OOM), missing heartbeat, sticky-session assumptions, broadcast-without-scoping, message-ordering claims that don't hold.
---

# Realtime Reviewer

Real-time bugs are silent (missed messages), expensive (memory crashes under load), or catastrophic (cross-tenant broadcast). Runs on every gateway, channel-subscribe handler, fanout adapter, client reconnect path.

## Pre-flight

- Read `ai/patterns/websocket-fanout.md` + `.claude/rules/realtime-discipline.md`.
- Detect transport (Socket.IO / native ws / SSE / Pusher / Ably / Soketi).
- Check whether scaling is single-node or multi-node (Redis pub/sub, Kafka, Pusher).
- Read connection auth — is it on `connect` or only via URL query string?

## Automatic scans

### Auth on URL token only (replayable)
```bash
rg "io\.use\(|@WebSocketGateway|onConnection\(" src/ -A 10 \
  | grep -E "query\.token|handshake\.query"
```
Token in URL → leaks via referrer, server log, browser history, proxy log. Use `Authorization` header on first frame, OR short-lived token + immediate rotate-on-connect.

### Subscribe without scope check
```bash
rg "@SubscribeMessage|client\.join\(|socket\.join\(" src/ -A 8 \
  | grep -v "tenantId\|userId\|ACL\|canSubscribe\|assertCan"
```
Client joins channel `room:tenant:abc-123` — does the gateway VERIFY this client belongs to tenant abc-123? Or just trust the room name?

### Broadcast without tenant filter
```bash
rg "io\.emit\(|server\.emit\(|broadcast\(" src/ -A 3 \
  | grep -v "to\(|in\(|tenant\|user\|room"
```
Global broadcast = every connected client receives, including other tenants' admins.

### Unbounded queue / no backpressure
```bash
rg "messageQueue|outboundQueue|sendBuffer" src/ -A 5 \
  | grep -v "maxSize\|drop\|backpressure"
```
Slow client + fast producer = memory grows per client until OOM.

### No heartbeat / ping
```bash
rg "@WebSocketGateway|new WebSocketServer" src/ -A 10 \
  | grep -v "pingInterval\|heartbeat\|keepAlive"
```
Connections die silently behind NAT/proxies after ~60s without traffic; client thinks open, sends, lost.

### Single-node fanout in multi-node deploy
```bash
rg "EventEmitter|emitter\.emit\(.*?notify" src/modules/realtime/
```
In-process emitter = events only delivered to clients on the SAME node. Need Redis pub/sub or equivalent.

### Reconnect without backoff
```bash
rg "websocket.*reconnect|setTimeout.*?connect\(" src/ -A 3 \
  | grep -v "exponential\|backoff\|jitter"
```
Tight reconnect loop = thundering herd at outage recovery.

## Detailed checklist

### Connection auth
- Authentication happens on `connect` event, BEFORE any message is processed.
- Token via `Authorization` header (preferred) OR short-lived ticket from a separate HTTP endpoint (NEVER long-lived JWT in URL query — leaks everywhere).
- Token signature verified, not just presence.
- Tenant + user identity attached to socket session: `socket.data = { tenantId, userId, scopes }`.
- Disconnect immediately on auth fail, log with IP.

### Channel / room scoping
- Channel name encodes scope: `tenant:<tenantId>:user:<userId>:notifications`.
- Subscribe handler VERIFIES the requesting socket has access to the channel — does NOT trust the channel name to grant scope.
- ACL check on every subscribe: `assertCanSubscribe(socket.data, channelName)`.
- Wildcard subscriptions (`tenant:*:*`) FORBIDDEN unless socket is admin-scoped.

### Authorization (per message)
- Sending to a channel requires write authority for that channel — re-check on every emit, not just on subscribe.
- "Presence" data (who else is online) restricted to channel members; never returned for channels you can't subscribe to.

### Backpressure
- Per-client outbound buffer bounded — exceed → drop oldest OR disconnect with `slow_consumer` reason.
- Server-side metric on per-client buffer depth; alert when sustained > threshold.
- For high-rate streams: server-side coalescing (drop intermediate updates if client behind).
- NEVER unbounded `client.send()` queue — slow client = memory leak.

### Reconnect
- Client implements exponential backoff with jitter: `delay = min(maxDelay, base * 2^attempts) + random(0, base)`.
- Server-side: identify reconnects via session-resume token; replay missed messages from a per-session buffer (bounded).
- After N failed attempts (e.g. 10), back off to a long interval (60s+), don't give up.

### Heartbeat
- Server sends `ping` every 25-30s; client replies `pong`.
- Server closes connections that miss N consecutive pongs.
- NAT/proxy idle-kill is the most common silent failure — no app traffic for 60s = TCP gone, app oblivious.

### Message ordering
- Either guarantee ordering (single connection per (user, channel) + sequence numbers + buffer-and-resequence on reconnect), OR explicitly document "best-effort ordering, app must idempotency-check".
- Across-fanout-bus ordering is NOT free — Redis pub/sub does NOT guarantee order across channels.
- Sequence number per channel; client tracks last-seen seq; on resume, server replays from that seq.

### Multi-node fanout
- In-process `EventEmitter` is single-node ONLY. In a fleet: client A on node-1, event published on node-2 → A receives nothing.
- Use Redis pub/sub adapter (Socket.IO `@socket.io/redis-adapter`), Kafka, NATS, or managed (Pusher / Ably / Soketi).
- Sticky sessions: required for Socket.IO long-poll fallback; not required for pure WebSocket if state is session-resumable.

### Tenant fanout safety
- `io.emit()` (global) is FORBIDDEN unless explicitly admin-broadcast.
- `io.to('tenant:abc-123:*').emit(...)` — verify pattern matches only intended scope.
- Cross-tenant broadcast is the worst kind of leak — affects every connected user simultaneously.

### Resource limits
- Max connections per IP (defends DoS).
- Max connections per user (one user opening 10k tabs).
- Max channels subscribed per connection (prevents subscribe-bomb).
- Server reports its concurrent connection count + memory; alert on spike.

## Example findings

### BLOCKER — auth via URL query token
```
@WebSocketGateway()
export class NotifGateway {
  handleConnection(client: Socket) {
    const token = client.handshake.query.token as string;
    const payload = this.jwt.verify(token);
    client.data.userId = payload.sub;
  }
}

Impact: token leaks via referrer, browser history, proxy/CDN logs (URLs are logged everywhere).
Fix: auth via Authorization header.
  handleConnection(client: Socket) {
    const auth = client.handshake.headers.authorization;
    if (!auth) return client.disconnect(true);
    const payload = this.jwt.verify(auth.replace('Bearer ', ''));
    client.data = { userId: payload.sub, tenantId: payload.tenantId };
  }
  // OR short-lived ticket: HTTP /realtime/ticket → 30s ticket → use in connect.
```

### BLOCKER — subscribe without ACL
```
@SubscribeMessage('subscribe')
async handleSub(@MessageBody() ch: string, @ConnectedSocket() c: Socket) {
  c.join(ch);
  return { ok: true };
}

Impact: client sends "subscribe" with `tenant:other-tenant:*` → joins → receives all messages.
Fix:
  if (!this.acl.canSubscribe(c.data, ch)) {
    return { error: 'forbidden' };
  }
  c.join(ch);
```

### BLOCKER — global broadcast
```
this.server.emit('announcement', { message: 'maintenance soon' });

Impact: every connected user, every tenant, gets it. Fine for "site-wide maintenance"; catastrophic if message contains tenant-specific data ("Alice from Acme just placed a $5000 order").
Fix: scope broadcasts.
  this.server.to(`tenant:${tenantId}`).emit('announcement', payload);
```

### BLOCKER — single-node fanout in multi-node deploy
```
@Injectable()
export class NotifyService {
  constructor(private readonly emitter: EventEmitter2, private readonly gateway: NotifGateway) {}

  notify(userId: string, payload: any) {
    this.emitter.emit(`notify.user.${userId}`, payload);
    // gateway listens, calls io.to(`user:${userId}`).emit
  }
}

Impact: client connected to pod A, event published on pod B → client never receives it.
Fix: Redis adapter for cross-node fanout.
  // main.ts
  io.adapter(createAdapter(pubClient, subClient));
  // OR publish to a dedicated channel; every node subscribes; emits locally.
```

### BLOCKER — unbounded outbound queue
```
client.send(JSON.stringify(msg));   // no buffer cap; default ws lib buffers internally without limit

Impact: slow client (mobile on 3G) + high-rate producer = per-client buffer to GBs → OOM.
Fix: explicit bounded queue + drop policy.
  if (client.bufferedAmount > 1_000_000) {
    this.logger.warn({ userId: client.data.userId, bufferedAmount: client.bufferedAmount }, 'ws.slow_consumer');
    client.close(1013, 'slow_consumer');
    return;
  }
  client.send(payload);
```

### REQUEST — no heartbeat
```
new WebSocketServer({ port });   // default no ping

Impact: NAT idle timeout (60-300s) silently kills TCP; both sides think open until next message bounces.
Fix: server ping every 25s, terminate after 2 missed pongs.
  const interval = setInterval(() => {
    wss.clients.forEach((ws) => {
      if (ws.isAlive === false) return ws.terminate();
      ws.isAlive = false;
      ws.ping();
    });
  }, 25_000);
  wss.on('connection', (ws) => {
    ws.isAlive = true;
    ws.on('pong', () => { ws.isAlive = true; });
  });
```

### REQUEST — claimed ordering not enforced
```
// docs say "messages delivered in order"
io.to(channel).emit('event', payload);

Impact: events going through Redis pub/sub do NOT preserve order across channels; concurrent emits on a channel may race depending on adapter.
Fix: either (a) downgrade docs to "best-effort + idempotent app handler", or (b) introduce per-channel sequence numbers + client-side resequencing.
```

## Output

```
/realtime-reviewer — <scope>

Verdict: APPROVE | REQUEST_CHANGES | BLOCK

BLOCKERS (N):
  - <file:line> — <issue> → <impact> → <fix>
  (URL-token auth, subscribe-without-ACL, global broadcast, single-node fanout, unbounded queue)

REQUESTS (N):
  - <finding>
  (no heartbeat, no reconnect backoff, ordering claim not enforced, no per-IP cap)

NITS: log fields, naming

Scans run:
  URL-token auth: <n>
  subscribe w/o ACL: <n>
  global emits: <n>
  in-process fanout: <n>
  no buffer cap: <n>
  no heartbeat: <n>
```

## Hard rules

- Auth via URL query token (long-lived) = BLOCKER.
- Subscribe handler without ACL check = BLOCKER.
- Global `io.emit()` outside admin-broadcast paths = BLOCKER.
- In-process fanout in multi-node deploy = BLOCKER.
- Unbounded outbound queue = BLOCKER.
- No heartbeat in long-lived connections = REQUEST_CHANGES.
- Cross-tenant subscribe / broadcast = BLOCKER (highest-severity tenant leak).
- Documented ordering guarantee not enforced by code = BLOCKER.
