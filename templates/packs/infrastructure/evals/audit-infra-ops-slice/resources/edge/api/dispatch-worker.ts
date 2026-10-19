import Fastify from 'fastify';
import { startDispatchLoop, stopDispatchLoop } from './dispatch/loop';

// Courier dispatch: assigns paid orders to couriers and calls the courier partner's API.
const app = Fastify({ logger: true });
app.get('/livez', async () => ({ ok: true }));
app.get('/readyz', async () => ({ ok: true }));

// How long an in-flight assignment may take to finish after SIGTERM before we give up on it.
export const DRAIN_TIMEOUT_MS = 40_000;

process.on('SIGTERM', async () => {
  await stopDispatchLoop({ deadlineMs: DRAIN_TIMEOUT_MS });
  await app.close();
  process.exit(0);
});

startDispatchLoop();
app.listen({ host: '0.0.0.0', port: 3100 });
