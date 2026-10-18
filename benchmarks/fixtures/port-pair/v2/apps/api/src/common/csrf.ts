import type { NestFastifyApplication } from '@nestjs/platform-fastify';

// Double-submit cookie check for cookie-authenticated writes.
export const CSRF = { cookie: 'csrf_token', header: 'x-csrf-token' };

export function registerCsrf(app: NestFastifyApplication): void {
  app.getHttpAdapter().getInstance().addHook('preHandler', async (req, reply) => {
    if (['GET', 'HEAD', 'OPTIONS'].includes(req.method) || req.headers.authorization) {
      return;
    }
    const cookie = req.cookies?.[CSRF.cookie];
    if (!cookie || req.headers[CSRF.header] !== cookie) {
      await reply.status(419).send({ message: 'CSRF token mismatch.' });
    }
  });
}
