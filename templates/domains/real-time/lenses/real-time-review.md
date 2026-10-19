# Realtime review lens — domain `real-time`

> **Who reads this.** `@operability-reviewer` (delivery pack), briefed with
> `lens: .claude/lenses/real-time-review.md` by `/review-changes` and `/audit` when domain `real-time` is installed,
> and by this domain's own command. Phase 4.4 installs it with the domain. Until Phase 6 this was a
> separate reviewer agent; its checklist, examples and severity rules moved here unchanged
> (`scripts/_agent-merge-map.json`). It is an ADDITIVE checklist: the reader runs its own review, then
> walks this one on the same scope. "You" below is that reader; its contract (cite `<path:line>`, writes
> none) still binds.

Real-time bugs are silent (missed messages), expensive (memory crashes under load), or catastrophic (cross-tenant broadcast). Runs on every gateway, channel-subscribe handler, fanout adapter, client reconnect path.

## The Premise (read first, do not deviate)

**Find real issues. No hand-waves.** Every finding cites `<path:line>` (the URL-token auth on `handleConnection`, the `client.join(ch)` without ACL check, the `io.emit()` without scope, the `EventEmitter` in a multi-node deploy). "Could leak across tenants" without the eval site is noise. Run the automatic scans in this doc; read each hit.

**Cross-tenant broadcast is the worst-severity tenant leak in the system** — one buggy `io.emit()` reaches every connected user simultaneously. Treat any global emit, any subscribe-without-ACL, any in-process fanout in a multi-node deploy as BLOCKER. Don't softpedal "but it's an admin path" — admin code reaches users too.

**Halt conditions (refuse to issue a verdict):**
- Transport not identifiable (Socket.IO / native ws / SSE / Pusher / Ably / Soketi) — ask; auth + fanout semantics differ.
- Single-node vs multi-node deploy unclear (no Redis adapter / sticky-session config visible) — request before approving any fanout change; in-process emit is fine on one node, BLOCKER on a fleet.
- Heartbeat / ping-pong absent on a long-lived connection AND no explicit "best-effort, app handles reconnect" doc — request, don't approve.

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
# a subscribe handler or join with no scope check within 8 lines above or below it (a block window:
# `-A 8 | grep -v` drops lines, never handlers, and misses a check written above the join)
rg -l0 --pcre2 '@SubscribeMessage\(|\b(?:client|socket)\.join\(' src/ \
  | X='@SubscribeMessage\(|(client|socket)\.join\(' \
    Y='tenantId|userId|ACL|canSubscribe|assertCan' xargs -0r awk -v B=8 -v A=8 '
  function flush(  i, j, ok) { for (i = 1; i <= n; i++) if (L[i] ~ ENVIRON["X"]) { ok = 0
      for (j = i - B; j <= i + A; j++) if (j >= 1 && j <= n && L[j] ~ ENVIRON["Y"]) ok = 1
      if (!ok) print f ":" i ":" L[i] } n = 0 }
  FNR == 1 && NR > 1 { flush() }  { f = FILENAME; L[++n] = $0 }  END { flush() }'
```
A guard on the method or the gateway class (`@UseGuards`) can hold the check instead — read it before reporting.
Client joins channel `room:tenant:abc-123` — does the gateway VERIFY this client belongs to tenant abc-123? Or just trust the room name?

### Broadcast without tenant filter
```bash
# an emit on the server object itself, or socket.broadcast.emit: neither names a room (.to()/.in() would sit between)
rg -n --pcre2 '\b(?:io|server|this\.server|nsp|wss)\.emit\(|\.broadcast\.emit\(' src/
```
Global broadcast = every connected client receives, including other tenants' admins.

### Unbounded queue / no backpressure
```bash
# files that keep a per-client send queue and never bound it (file level: the bound may sit far from the push)
rg -l0 --pcre2 '\b(?:messageQueue|outboundQueue|sendBuffer)\b' src/ \
  | xargs -0r rg --files-without-match --pcre2 '\b(?:maxSize|maxLength|highWaterMark|bufferedAmount|backpressure|drop\w*)\b'
```
Slow client + fast producer = memory grows per client until OOM.

### No heartbeat / ping
```bash
# a gateway or server file with no ping or heartbeat setting anywhere in it
rg -l0 --pcre2 '@WebSocketGateway\b|\bnew\s+(?:WebSocket\.)?(?:WebSocketServer|Server)\(' src/ \
  | xargs -0r rg --files-without-match --pcre2 '\b(?:pingInterval|pingTimeout|heartbeat\w*|keepAlive)\b|\.ping\('
```
Check the library's own default before reporting: Socket.IO (and Nest gateways on it) pings by default; a raw `ws` server does not.
Connections die silently behind NAT/proxies after ~60s without traffic; client thinks open, sends, lost.

### Single-node fanout in multi-node deploy
```bash
rg "EventEmitter|emitter\.emit\(.*?notify" src/modules/realtime/
```
In-process emitter = events only delivered to clients on the SAME node. Need Redis pub/sub or equivalent.

### Reconnect without backoff
```bash
# files with a hand-written reconnect and no backoff or jitter anywhere in them (the delay is often computed above the setTimeout)
rg -l0 --pcre2 '\breconnect\w*\s*[(=:]|setTimeout\([^\n]*\bconnect\(' src/ \
  | xargs -0r rg --files-without-match --pcre2 '\b(?:exponential\w*|backoff\w*|jitter\w*|reconnectionDelay\w*|randomizationFactor)\b|Math\.(?:random|pow)\(|\*\*'
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
real-time review lens (read by @operability-reviewer) — <scope>

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
