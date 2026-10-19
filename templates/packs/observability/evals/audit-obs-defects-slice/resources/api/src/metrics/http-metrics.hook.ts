import type { FastifyInstance } from 'fastify';
import { handledRequests, httpDuration, httpRequests } from './metrics';

/** RED metrics for every response the API sends. */
export function registerHttpMetrics(app: FastifyInstance): void {
  app.addHook('onResponse', async (request, reply) => {
    const code = String(reply.statusCode);
    httpRequests.inc({ method: request.method, route: request.routeOptions.url ?? 'unmatched', code });
    httpDuration.labels(request.method, request.url, code).observe(reply.elapsedTime / 1000);
    handledRequests.inc();
  });
}
