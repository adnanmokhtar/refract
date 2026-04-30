---
name: websocket-fanout
description: Pattern: WebSocket gateway + Redis pub/sub fanout
kind: ai-pattern
---

# Pattern: WebSocket gateway + Redis pub/sub fanout

> **Hard rule** — Auth is verified on connect (header / short-lived ticket, NEVER URL query token); every `subscribe` is ACL-checked against `(tenantId, channel)`; cross-node fanout goes through Redis adapter, never in-process EventEmitter. Producers call `NotifyService`, never `io.emit()`.

**When to apply**
- Bidirectional real-time UX (chat, collab, live dashboards) across multiple Node processes/pods.
- Tenant-scoped channels where leaks cross security boundaries.
- Session-resume requirements on reconnect (replay missed messages).

**When NOT to apply**
- One-way server push only — use SSE, simpler ops + auto-reconnect.
- Single-process toy app — don't pull in Redis adapter prematurely.
- High-throughput peer media (gaming, voice) — WebRTC data channel, not WS fanout.

**Halt conditions / mandatory cites**
- Cite `handleConnection` auth verification at `<path:line>`. Token in URL query = halt.
- Cite the `ChannelAclService.canSubscribe()` check on every subscribe at `<path:line>`. Trusting channel name = halt.
- Cite the Redis adapter wiring (`createAdapter(pub, sub)`) at `<path:line>` for any multi-node deploy. In-process emit = halt.
- Cite the slow-consumer disconnect / bounded buffer at `<path:line>`. Unbounded outbound = OOM.
- Grep ban: "WS works in prod" without file:line for auth, ACL, Redis adapter, and slow-consumer handling.

NestJS WebSocket gateway with auth-on-connect, scoped subscribe, Redis pub/sub for cross-node fanout, bounded backpressure, session-resume on reconnect.

## Decision summary

Default real-time tech: **Socket.IO + `@socket.io/redis-adapter`**. Reasons:
- TypeScript + NestJS native (`@WebSocketGateway`).
- Built-in heartbeat, room scoping, ack pattern, fallback to long-poll.
- Redis adapter enables horizontal scaling — emit on any node, every node delivers to its connected clients.

When to choose differently:
- **Native `ws`** if you want pure WebSocket without long-poll fallback (smaller surface, less memory). You build the room logic.
- **SSE** for one-way push (server → client only): server-side simpler (regular HTTP), no special infra. Browser auto-reconnects.
- **Pusher / Ably** if you don't want to run pub/sub infra; managed channels with auth callback. Costs scale per message.
- **Soketi** as self-hosted Pusher-compatible alternative.

## File layout

```
src/realtime/
├── core/
│   ├── channel-acl.service.ts            # canSubscribe(socketData, channelName)
│   └── session-buffer.service.ts         # last-N messages per session for replay
├── application/
│   └── notify.service.ts                 # the only path producers call
└── infrastructure/
    ├── ws.gateway.ts                     # the @WebSocketGateway
    ├── redis-fanout.adapter.ts           # publishes to Redis; gateways subscribe
    └── session-store.ts                  # tracks (sessionId → lastSeq, channels)
```

## Gateway (auth + subscribe + emit)

```ts
import { WebSocketGateway, WebSocketServer, SubscribeMessage,
         OnGatewayConnection, OnGatewayDisconnect, MessageBody, ConnectedSocket } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({
  cors: { origin: ['https://app.example.com'] },
  pingInterval: 25_000,
  pingTimeout: 30_000,
  maxHttpBufferSize: 1e5,                  // 100 KB per message hard cap
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;

  constructor(
    private readonly auth: AuthService,
    private readonly acl: ChannelAclService,
    private readonly buffer: SessionBufferService,
    private readonly logger: Logger,
  ) {}

  // 1) AUTH on connect — before any message processing
  async handleConnection(client: Socket) {
    try {
      const token = (client.handshake.headers.authorization ?? '').replace('Bearer ', '');
      if (!token) throw new Error('no_token');

      const claims = await this.auth.verifyToken(token);
      client.data = {
        userId: claims.sub,
        tenantId: claims.tenantId,
        scopes: claims.scopes,
        sessionId: claims.sessionId ?? randomUUID(),
        lastSeq: 0,
      };

      this.logger.info({
        socketId: client.id, userId: client.data.userId, tenantId: client.data.tenantId,
      }, 'ws.connected');
    } catch (err) {
      this.logger.warn({ ip: client.handshake.address, err: err.message }, 'ws.auth.failed');
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    this.logger.info({ socketId: client.id, reason: client.disconnected }, 'ws.disconnected');
  }

  // 2) SUBSCRIBE — scope-checked
  @SubscribeMessage('subscribe')
  async onSubscribe(@MessageBody() channel: string, @ConnectedSocket() client: Socket) {
    if (!this.acl.canSubscribe(client.data, channel)) {
      this.logger.warn({ userId: client.data.userId, channel }, 'ws.subscribe.forbidden');
      return { error: 'forbidden' };
    }
    if (client.rooms.size >= 50) return { error: 'too_many_subscriptions' };

    await client.join(channel);
    return { ok: true };
  }

  // 3) RESUME — reconnect with last-seen seq, replay missed
  @SubscribeMessage('resume')
  async onResume(@MessageBody() input: { lastSeq: number; channels: string[] }, @ConnectedSocket() client: Socket) {
    for (const ch of input.channels) {
      if (!this.acl.canSubscribe(client.data, ch)) continue;
      await client.join(ch);

      const missed = await this.buffer.getSince(ch, input.lastSeq);
      for (const msg of missed) {
        this.safeSend(client, msg);
      }
    }
    return { ok: true };
  }

  // ---- producer-facing API ----
  async emitToChannel(channel: string, event: string, payload: unknown) {
    const seq = await this.buffer.append(channel, { event, payload });
    const msg = { seq, event, payload };
    this.server.to(channel).emit(event, msg);
  }

  // ---- helper: backpressure-aware send ----
  private safeSend(client: Socket, msg: unknown) {
    // Socket.IO does not expose bufferedAmount the same way as ws.
    // For ws-native: check `client.bufferedAmount > THRESHOLD`. For Socket.IO, monitor adapter buffer.
    if ((client as any).conn?.transport?.writable === false) {
      this.logger.warn({ userId: client.data.userId }, 'ws.slow_consumer');
      client.disconnect(true);
      return;
    }
    client.emit((msg as any).event, msg);
  }
}
```

## Channel ACL (the single source of authority)

```ts
@Injectable()
export class ChannelAclService {
  /** Channel name encodes scope. We verify the requester has it. */
  canSubscribe(data: SocketData, channel: string): boolean {
    // Pattern: tenant:<tenantId>:<entity>:<entityId?>:<resource>
    const parts = channel.split(':');
    if (parts[0] !== 'tenant') return false;

    const channelTenant = parts[1];
    if (channelTenant !== data.tenantId) return false;     // cross-tenant block

    if (parts[2] === 'user') {
      const channelUser = parts[3];
      if (channelUser !== data.userId && !data.scopes.includes('admin')) return false;
    }

    return true;
  }
}
```

## Multi-node fanout with Redis

```ts
// main.ts
import { createAdapter } from '@socket.io/redis-adapter';
import { Redis } from 'ioredis';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  const ioAdapter = new IoAdapter(app);
  const pub = new Redis(process.env.REDIS_URL!);
  const sub = pub.duplicate();
  ioAdapter.createIOServer = function (port, options) {
    const server = IoAdapter.prototype.createIOServer.call(this, port, options);
    server.adapter(createAdapter(pub, sub));
    return server;
  };
  app.useWebSocketAdapter(ioAdapter);

  await app.listen(3000);
}
```

Now `io.to(channel).emit()` on node A delivers to clients connected to node B — Redis pub/sub broadcasts the emit across all gateway processes, each delivers locally.

## Producer side (the only allowed path)

```ts
@Injectable()
export class NotifyService {
  constructor(private readonly gateway: RealtimeGateway) {}

  async notifyUser(tenantId: string, userId: string, event: string, payload: unknown) {
    const channel = `tenant:${tenantId}:user:${userId}:notifications`;
    await this.gateway.emitToChannel(channel, event, payload);
  }

  async notifyTenant(tenantId: string, event: string, payload: unknown) {
    const channel = `tenant:${tenantId}:announcements`;
    await this.gateway.emitToChannel(channel, event, payload);
  }
}
```

Producers never call `io.emit()` directly. They call `NotifyService` → which calls `gateway.emitToChannel()` → which appends to session buffer + emits to scope.

## Session buffer (resume-on-reconnect)

```ts
@Injectable()
export class SessionBufferService {
  constructor(private readonly redis: Redis) {}

  async append(channel: string, payload: unknown): Promise<number> {
    const seq = await this.redis.incr(`buffer:${channel}:seq`);
    await this.redis
      .multi()
      .zadd(`buffer:${channel}`, seq, JSON.stringify({ seq, ...payload }))
      .zremrangebyscore(`buffer:${channel}`, 0, seq - 100)         // keep last 100
      .expire(`buffer:${channel}`, 300)                            // 5 min TTL
      .exec();
    return seq;
  }

  async getSince(channel: string, lastSeq: number): Promise<unknown[]> {
    const items = await this.redis.zrangebyscore(`buffer:${channel}`, lastSeq + 1, '+inf');
    return items.map((s) => JSON.parse(s));
  }
}
```

Bounded buffer (last 100 messages or 5 min) — replay best-effort beyond.

## Client side (reference)

```ts
import { io } from 'socket.io-client';

const socket = io(WS_URL, {
  auth: (cb) => cb({ token: getAuthToken() }),
  transports: ['websocket'],            // skip long-poll if you don't need it
  reconnection: true,
  reconnectionAttempts: Infinity,
  reconnectionDelay: 1000,
  reconnectionDelayMax: 30_000,
  randomizationFactor: 0.5,             // jitter
});

let lastSeq = 0;
const channels = ['tenant:abc:user:42:notifications'];

socket.on('connect', async () => {
  if (lastSeq === 0) {
    for (const ch of channels) await socket.emitWithAck('subscribe', ch);
  } else {
    await socket.emitWithAck('resume', { lastSeq, channels });
  }
});

socket.on('event', (msg) => {
  if (msg.seq <= lastSeq) return;        // dedup
  lastSeq = msg.seq;
  handleMessage(msg);
});
```

## SSE alternative (one-way push)

```ts
@Get('events')
@UseGuards(JwtGuard)
async stream(@Req() req: FastifyRequest, @Res() res: FastifyReply, @CurrentUser() user: AuthUser) {
  res.raw.setHeader('Content-Type', 'text/event-stream');
  res.raw.setHeader('Cache-Control', 'no-cache');
  res.raw.setHeader('Connection', 'keep-alive');
  res.raw.flushHeaders();

  const channel = `tenant:${user.tenantId}:user:${user.id}:notifications`;
  const subscriber = this.redisSub.duplicate();
  await subscriber.subscribe(channel);

  subscriber.on('message', (_ch, msg) => {
    res.raw.write(`data: ${msg}\n\n`);
  });

  // heartbeat — keep proxies happy
  const heartbeat = setInterval(() => res.raw.write(':\n\n'), 25_000);

  req.raw.on('close', () => {
    clearInterval(heartbeat);
    subscriber.unsubscribe(channel).then(() => subscriber.quit());
  });
}
```

SSE pros: regular HTTP (works through any proxy), browser auto-reconnects with `Last-Event-ID` header, simpler ops. Cons: one-way only (client → server requires separate HTTP).

## Trade-off table

| Choice | Pros | Cons | When |
|---|---|---|---|
| Socket.IO + Redis adapter | first-class NestJS, fallback, presence, room scope | dependency on Socket.IO; protocol churn between v3/v4 | default for bidirectional |
| Native `ws` + custom rooms | smallest surface | you build everything (rooms, fanout, ack) | high-throughput specialty |
| SSE + Redis pub/sub | trivial reverse-proxy; auto-reconnect; no ws upgrade quirks | one-way; one HTTP connection per subscription | server-push only |
| Pusher / Ably / Soketi | managed; presence built-in; auth callback hook | per-message cost; vendor lock-in | small team, want it tomorrow |
| WebRTC data channel | P2P low-latency | signaling + NAT traversal complexity | gaming, voice, peer collab |

## Common mistakes

- **Auth via URL query token** — leaks via referrer, browser history, CDN/proxy logs. Use `Authorization` header or short-lived ticket.
- **Trusting the channel name** — `socket.join(anyName)` without ACL → tenant leak. ACL on every subscribe.
- **Global `io.emit()`** — broadcasts to every connected user. Always scope with `.to()`.
- **In-process EventEmitter for fanout** — works on one node; silently drops on multi-pod. Use Redis adapter.
- **Unbounded outbound buffer** — slow client = OOM. Drop or disconnect on threshold.
- **No heartbeat** — NAT idle-kill leaves zombie connections; both sides think open.
- **Tight reconnect loop** — outage recovery = thundering herd → server falls over again. Exponential backoff with jitter.
- **Claiming "ordered" without enforcing it** — across multi-node fanout, order isn't free.
- **Long-running DB transaction in subscribe handler** — connection is long-lived; transaction holds locks.
- **Storing connection state in process memory only** — pod restart = total disconnect; client can't resume. Persist session in Redis.
- **Sticky sessions assumed under pure WebSocket** — sticky needed for Socket.IO long-poll fallback only; not for raw WS if you have session resume.
- **No connection cap per IP/user** — 10k connections from one tab = process slow death.
- **Logging full message payloads** — PII in logs; redact event content.
