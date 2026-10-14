import fp from 'fastify-plugin';
import { FastifyInstance } from 'fastify';
import { FxClient } from './fx.client';

const fx = new FxClient();

/** GET /v1/fx/convert?from=AED&to=USD&amount=12.70 — served by Fastify directly for latency. */
export const fxRoutes = fp(async (fastify: FastifyInstance) => {
  fastify.get('/v1/fx/convert', {
    schema: {
      querystring: {
        type: 'object',
        required: ['from', 'to', 'amount'],
        properties: { from: { type: 'string' }, to: { type: 'string' }, amount: { type: 'string', pattern: '^\\d+(\\.\\d{1,2})?$' } },
      },
      response: {
        200: {
          type: 'object',
          properties: {
            from: { type: 'string' },
            to: { type: 'string' },
            amount: { type: 'integer' },
            converted: { type: 'number' },
          },
        },
      },
    },
  }, async (request) => {
    const q = request.query as { from: string; to: string; amount: string };
    const r = await fx.latest(q.from);
    const amount = Number(q.amount);
    return { from: q.from, to: q.to, amount, converted: amount * (r.rates[q.to] ?? 0) };
  });
});
