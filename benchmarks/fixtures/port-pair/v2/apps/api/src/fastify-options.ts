import type { FastifyServerOptions } from 'fastify';
import * as qs from 'qs';

// PHP-style bracket arrays (`status[]=placed&status[]=packed`), as the V1 mobile app and the
// partner integrations send them.
export const parseBracketQuery = (raw: string): Record<string, unknown> => qs.parse(raw, { arrayLimit: 100 });

export const fastifyOptions: FastifyServerOptions = {
  trustProxy: true,
  bodyLimit: 2 * 1024 * 1024,
};
