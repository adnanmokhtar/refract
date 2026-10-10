import Fastify from 'fastify';
import { registerRoutes } from './routes';

// Behind nginx-edge, whose upstream pool closes idle connections after 60 s (edge/nginx/nginx.conf).
// The server must keep an idle socket open longer than the proxy does, or the proxy reuses a socket
// the server already closed.
const app = Fastify({
  logger: true,
  keepAliveTimeout: 72_000,
  requestTimeout: 120_000,
});

const SHUTDOWN_DRAIN_TIMEOUT_MS = 30_000;

registerRoutes(app);

async function shutdown(signal: string): Promise<void> {
  app.log.info({ signal }, 'draining');
  const timer = setTimeout(() => process.exit(1), SHUTDOWN_DRAIN_TIMEOUT_MS);
  await app.close();
  clearTimeout(timer);
  process.exit(0);
}

process.on('SIGTERM', () => void shutdown('SIGTERM'));

app.listen({ host: '0.0.0.0', port: Number(process.env.PORT ?? 3000) });
