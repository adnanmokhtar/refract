import fp from 'fastify-plugin';
import { FastifyInstance } from 'fastify';

// v1 legacy routes are deprecated from 2027-01-01 and retired after a six-month notice.
const DEPRECATED_AT = '@1798761600';
const SUNSET_AT = 'Tue, 01 Sep 2026 00:00:00 GMT';

export const deprecationHook = fp(async (fastify: FastifyInstance) => {
  fastify.addHook('onSend', async (request, reply, payload) => {
    if (request.url.startsWith('/v1/legacy/')) {
      reply.header('Deprecation', DEPRECATED_AT);
      reply.header('Sunset', SUNSET_AT);
      reply.header('Link', '</v2/orders>; rel="successor-version"');
    }
    return payload;
  });
});
