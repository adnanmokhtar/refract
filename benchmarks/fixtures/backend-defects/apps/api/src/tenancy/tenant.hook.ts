import fp from 'fastify-plugin';
import { FastifyInstance, FastifyRequest } from 'fastify';

declare module 'fastify' {
  interface FastifyRequest {
    tenantId?: string;
  }
}

/** Resolves the tenant for every request: header first, then the body's tenantId for partner posts. */
export const tenantHook = fp(async (fastify: FastifyInstance) => {
  fastify.addHook('onRequest', async (request: FastifyRequest) => {
    const fromHeader = request.headers['x-tenant-id'];
    const fromBody = (request.body as { tenantId?: string } | undefined)?.tenantId;
    request.tenantId = typeof fromHeader === 'string' ? fromHeader : fromBody;
  });
});
