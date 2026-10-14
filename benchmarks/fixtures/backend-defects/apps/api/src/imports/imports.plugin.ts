import { FastifyInstance } from 'fastify';
import { parseCsvRows } from './csv';
import { validateImportRows } from './import-row.validator';

/** Bulk price imports: the body is a CSV file. */
export async function importsPlugin(fastify: FastifyInstance): Promise<void> {
  fastify.addContentTypeParser('*', { parseAs: 'buffer' }, (_req, body, done) => done(null, body));

  fastify.post('/prices', async (request, reply) => {
    const rows = parseCsvRows((request.body as Buffer).toString('utf8'));
    const errors = await validateImportRows(rows);
    if (errors.length > 0) return reply.code(400).send({ error: { code: 'INVALID_ROWS', message: 'Invalid rows', details: errors } });
    return reply.code(202).send({ accepted: rows.length });
  });
}
