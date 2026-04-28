---
description: Open a WebSocket / SSE connection, send N messages, verify ordering, delivery, auth, reconnect behavior, fanout across nodes.
---

# /test-realtime

Purpose: prove the real-time path actually works end-to-end — connection auth, channel scoping, fanout, reconnect, backpressure.

## What it does

1. Opens client connection with valid token; verifies `connect` event.
2. Subscribes to a permitted channel; verifies success.
3. Tries to subscribe to a forbidden channel; verifies rejection.
4. Triggers N events server-side (via HTTP or queue); receives via socket; checks count + order + content.
5. Drops connection mid-stream; reconnects; verifies session resume + backlog replay.
6. Stresses with bursts; observes backpressure (no message loss for slow consumer up to threshold).
7. Tests cross-node fanout: connect to pod A, trigger event from pod B, expect delivery.

## Usage

```bash
.claude/skills/test-realtime.sh                                # full battery
.claude/skills/test-realtime.sh --auth                         # auth-only
.claude/skills/test-realtime.sh --fanout                       # cross-node only
.claude/skills/test-realtime.sh --burst=1000                   # ordering + delivery under burst
.claude/skills/test-realtime.sh --reconnect                    # forced reconnect + replay
.claude/skills/test-realtime.sh --negative                     # cross-tenant subscribe (must reject)
.claude/skills/test-realtime.sh --target=wss://staging.example.com
```

## Reference script (Socket.IO + ws)

```ts
// scripts/test-realtime.ts
import { io as IOClient, Socket } from 'socket.io-client';
import WebSocket from 'ws';

const URL = process.env.WS_URL ?? 'http://localhost:3000';
const TOKEN = process.env.WS_TOKEN!;
const TENANT_ID = process.env.TENANT_ID!;

async function testAuth() {
  console.log('[1] auth — valid token');
  const valid = IOClient(URL, { extraHeaders: { Authorization: `Bearer ${TOKEN}` } });
  await once(valid, 'connect');
  console.log('   OK — connected as', valid.id);
  valid.disconnect();

  console.log('[2] auth — invalid token must reject');
  const bad = IOClient(URL, { extraHeaders: { Authorization: 'Bearer invalid' }, reconnection: false });
  const err = await Promise.race([
    once(bad, 'connect_error'),
    new Promise((_, rej) => setTimeout(() => rej('timeout'), 3000)),
  ]);
  console.log('   OK — rejected:', err);
}

async function testSubscribe() {
  const c = IOClient(URL, { extraHeaders: { Authorization: `Bearer ${TOKEN}` } });
  await once(c, 'connect');

  console.log('[3] subscribe — own channel');
  const ok = await c.emitWithAck('subscribe', `tenant:${TENANT_ID}:notifications`);
  console.log('   ack:', ok);

  console.log('[4] subscribe — forbidden channel must reject');
  const rej = await c.emitWithAck('subscribe', 'tenant:foreign-tenant:notifications');
  if (rej.error !== 'forbidden') throw new Error('cross-tenant subscribe ALLOWED — security bug');
  console.log('   OK — rejected:', rej);

  c.disconnect();
}

async function testDeliveryAndOrdering(n = 100) {
  const c = IOClient(URL, { extraHeaders: { Authorization: `Bearer ${TOKEN}` } });
  await once(c, 'connect');
  await c.emitWithAck('subscribe', `tenant:${TENANT_ID}:notifications`);

  const received: number[] = [];
  c.on('event', (msg) => received.push(msg.seq));

  // Trigger N events via HTTP API
  for (let i = 0; i < n; i++) {
    await fetch(`${API_URL}/internal/test-emit`, {
      method: 'POST', headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ channel: `tenant:${TENANT_ID}:notifications`, seq: i }),
    });
  }

  await waitUntil(() => received.length === n, 5000);
  const inOrder = received.every((v, i) => v === i);
  console.log(`[5] delivery — ${received.length}/${n}, ordered: ${inOrder}`);
  c.disconnect();
}

async function testReconnect() {
  const c = IOClient(URL, { extraHeaders: { Authorization: `Bearer ${TOKEN}` } });
  await once(c, 'connect');
  await c.emitWithAck('subscribe', `tenant:${TENANT_ID}:notifications`);

  // emit while connected
  await emit({ seq: 1 });

  // force disconnect, emit while away, reconnect
  c.disconnect();
  await emit({ seq: 2 });
  await emit({ seq: 3 });
  c.connect();
  await once(c, 'connect');
  await c.emitWithAck('resume', { lastSeq: 1 });

  const received: any[] = [];
  c.on('event', (msg) => received.push(msg.seq));
  await waitUntil(() => received.length >= 2, 3000);

  const replayed = [2, 3].every((seq) => received.includes(seq));
  console.log(`[6] reconnect replay — ${replayed ? 'OK' : 'MISSED MESSAGES'}`);
  c.disconnect();
}

async function testFanoutAcrossNodes() {
  // Trigger event via API endpoint that lands on Pod A; client connected through LB.
  // Run this against multi-pod deploy; if events arrive only when LB happens to route to right pod, fanout broken.
  const samples = 20, hits: number[] = [];
  for (let i = 0; i < samples; i++) {
    const c = IOClient(URL, { extraHeaders: { Authorization: `Bearer ${TOKEN}` } });
    await once(c, 'connect');
    await c.emitWithAck('subscribe', `tenant:${TENANT_ID}:notifications`);
    let received = false;
    c.once('event', () => { received = true; });

    await fetch(`${API_URL}/internal/test-emit`, {
      method: 'POST', headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ channel: `tenant:${TENANT_ID}:notifications`, seq: i }),
    });

    await sleep(300);
    if (received) hits.push(i);
    c.disconnect();
  }
  console.log(`[7] fanout — ${hits.length}/${samples} (need ${samples}; less = fanout broken or not multi-node)`);
}

async function testBurstBackpressure(burst = 5000) {
  // Slow consumer simulation: open connection, don't read.
  const ws = new WebSocket(URL.replace('http', 'ws'), { headers: { Authorization: `Bearer ${TOKEN}` } });
  await once(ws, 'open');

  for (let i = 0; i < burst; i++) {
    await emit({ seq: i });
  }
  await sleep(2000);

  const closed = ws.readyState === WebSocket.CLOSED;
  console.log(`[8] backpressure — slow client closed: ${closed} (expected: true with slow_consumer reason)`);
}

(async () => {
  await testAuth();
  await testSubscribe();
  await testDeliveryAndOrdering();
  await testReconnect();
  await testFanoutAcrossNodes();
  await testBurstBackpressure();
})();
```

## Output (sample)

```
/test-realtime — staging

[1] auth — valid token              OK
[2] auth — invalid token            OK rejected
[3] subscribe — own channel         OK
[4] subscribe — forbidden           OK rejected
[5] delivery — 100/100, ordered:true OK
[6] reconnect replay                OK (2 missed → both replayed)
[7] fanout — 20/20 across pods      OK
[8] backpressure — slow client      OK closed with slow_consumer

Summary: PASS — full pipeline healthy.
```

## When to run

- After any change to gateway, subscribe handler, fanout adapter, reconnect logic.
- After deploying with new connection auth scheme.
- After scaling up pods (fanout coverage check).
- Daily smoke from CI on staging.
- After load-balancer / sticky-session config changes.

## Failure modes the command surfaces

- **Cross-tenant subscribe accepted** — gateway trusts channel name. CRITICAL.
- **Reconnect doesn't replay** — session resume not implemented; messages lost during disconnect window.
- **Fanout misses** — single-node EventEmitter in a multi-pod deploy.
- **Out-of-order delivery** — claim of ordered delivery isn't enforced by code.
- **Slow consumer not disconnected** — unbounded buffer; future OOM.
- **All connections drop on deploy** — no graceful drain; client reconnect storm.

## Notes

- For SSE, replace socket.io with `EventSource`; same auth + scope checks apply.
- For Pusher / Ably / Soketi: managed channels enforce some scoping but you still need server-side `authorize` callback.
- For WebRTC: connection auth lives in your signaling server; ICE candidates carry no auth — relay through TURN with credentials.
