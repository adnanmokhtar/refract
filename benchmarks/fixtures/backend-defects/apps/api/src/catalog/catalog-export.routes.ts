import fp from 'fastify-plugin';
import { FastifyInstance } from 'fastify';

/** Public catalog feed for comparison sites: only the listed fields may leave. */
export const catalogExportRoutes = fp(async (fastify: FastifyInstance) => {
  fastify.get('/v1/catalog/feed', {
    schema: {
      response: {
        200: {
          type: 'array',
          items: {
            type: 'object',
            properties: { sku: { type: 'string' }, title: { type: 'string' }, price: { type: 'string' }, currency: { type: 'string' } },
          },
        },
      },
    },
  }, async (_request, reply) => {
    const rows = [{ sku: 'A-1', title: 'Lamp', price: '12.70', currency: 'AED', costPrice: '7.10', supplierId: 's-9' }];
    return reply.send(rows);
  });
});
