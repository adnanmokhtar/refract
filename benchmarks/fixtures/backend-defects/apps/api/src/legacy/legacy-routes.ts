import { NestFastifyApplication } from '@nestjs/platform-fastify';
import { FastifyReply, FastifyRequest } from 'fastify';

interface LegacyOrderBody {
  customer_ref: string;
  sku: string;
  qty: number;
}

/**
 * Pre-2024 partners still post to /v1/legacy/orders. Registered on the Fastify instance so the
 * old snake_case body is accepted as-is.
 */
export function registerLegacyRoutes(app: NestFastifyApplication): void {
  app.getHttpAdapter().getInstance().post('/v1/legacy/orders', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = request.body as LegacyOrderBody;
    const id = `legacy-${body.customer_ref}-${body.sku}-${body.qty}`;
    return reply.code(201).header('Location', `/v1/orders/${id}`).send({ id });
  });
}
