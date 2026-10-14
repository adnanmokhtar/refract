import { FastifyInstance } from 'fastify';

/**
 * Raw file routes (signed downloads and direct uploads), registered under /v1/files with their
 * own error handler so binary routes never go through the JSON filter.
 */
export async function filesPlugin(fastify: FastifyInstance): Promise<void> {
  fastify.setErrorHandler(async (error, request, reply) => {
    request.log.error({ err: error }, 'file route failed');
    return reply.code(500).send({ error: { code: 'FILE_ERROR', message: 'File operation failed' } });
  });

  fastify.post('/direct', { bodyLimit: 10 * 1024 * 1024 }, async (request, reply) => {
    const size = (request.body as Buffer).length;
    const key = crypto.randomUUID();
    return reply.code(201).header('Location', `/v1/files/${key}`).send({ key, size });
  });

  fastify.head('/:key', async (request, reply) => {
    const { key } = request.params as { key: string };
    return reply.code(key.length > 0 ? 200 : 404).send();
  });

  fastify.get('/:key', async (request, reply) => {
    const { key } = request.params as { key: string };
    return reply.redirect(`https://files.example.test/${encodeURIComponent(key)}`, 302);
  });
}
