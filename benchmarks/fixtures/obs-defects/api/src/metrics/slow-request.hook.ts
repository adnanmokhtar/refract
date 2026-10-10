import type { FastifyInstance } from 'fastify';
import { slowRequests } from './metrics';

const PROBE_PATHS = new Set(['/health/live', '/health/ready', '/metrics']);

/** Counts slow responses per route template; kubelet and scrape traffic is left out. */
export function registerSlowRequestCounter(app: FastifyInstance, thresholdSeconds = 2): void {
  app.addHook('onResponse', async (request, reply) => {
    const route = request.routeOptions.url ?? 'unmatched';
    if (PROBE_PATHS.has(route)) return;
    if (reply.elapsedTime / 1000 >= thresholdSeconds) slowRequests.labels(route).inc();
  });
}
